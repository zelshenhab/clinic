-- Family profile: an account holder keeps dependants (children, parents, ...) without
-- separate logins and books for them. The appointment stays owned by the account holder
-- (patient_id), so cancellation, rescheduling, reminders and notifications are unchanged.
create table public.family_members (
 id uuid primary key default gen_random_uuid(),
 owner_id uuid not null references public.patient_profiles on delete cascade,
 full_name text not null check(length(trim(full_name)) between 2 and 120),
 relationship text not null check(relationship in ('child','spouse','parent','sibling','other')),
 date_of_birth date,
 active boolean not null default true,
 unique(id,owner_id),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create index family_members_owner on public.family_members(owner_id) where active;
alter table public.family_members enable row level security;
create trigger touch_updated_at before update on public.family_members for each row execute function public.touch_updated_at();
revoke all on public.family_members from public,anon,authenticated;
grant select,insert,update on public.family_members to service_role;

-- The composite key guarantees a family member can only be attached to its own owner's appointment.
alter table public.appointments add column family_member_id uuid,
 add foreign key(family_member_id,patient_id) references public.family_members(id,owner_id);

create or replace function public.booking_commit(p_actor uuid,p_clinic uuid,p_input jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare a public.appointments;s public.services;doctor uuid=(p_input->>'doctor_id')::uuid;patient uuid=(p_input->>'patient_id')::uuid;service uuid=(p_input->>'service_id')::uuid;start_time timestamptz=(p_input->>'starts_at')::timestamptz;member uuid=nullif(p_input->>'family_member_id','')::uuid;
begin
 perform pg_advisory_xact_lock(hashtextextended('clinic:'||p_clinic::text,0));
 perform pg_advisory_xact_lock(hashtextextended(doctor::text,0));
 if not exists(select 1 from public.clinic_memberships where clinic_id=p_clinic and user_id=patient) then raise exception 'NOT_FOUND';end if;
 if member is not null and not exists(select 1 from public.family_members where id=member and owner_id=patient and active) then raise exception 'NOT_FOUND';end if;

 select s0.* into s from public.services s0 join public.specialties sp on sp.id=s0.specialty_id and sp.clinic_id=s0.clinic_id join public.doctor_services ds on ds.service_id=s0.id and ds.clinic_id=s0.clinic_id and ds.doctor_id=doctor join public.doctor_clinics dc on dc.clinic_id=ds.clinic_id and dc.doctor_id=ds.doctor_id where s0.id=service and s0.clinic_id=p_clinic for share of s0,sp,ds,dc;

 if not public.booking_slot_valid(p_clinic,doctor,service,start_time) then raise exception 'SLOT_UNAVAILABLE';end if;
 insert into public.appointments(clinic_id,doctor_id,patient_id,service_id,starts_at,ends_at,status,price_rub,family_member_id) values(p_clinic,doctor,patient,service,start_time,start_time+make_interval(mins=>s.duration_minutes),'pending',s.price_rub,member) returning * into a;
 insert into public.appointment_status_history(clinic_id,appointment_id,status,changed_by) values(p_clinic,a.id,a.status,p_actor);
 insert into public.audit_logs(clinic_id,actor_id,action,resource_id) values(p_clinic,p_actor,'appointment.created',a.id);
 return to_jsonb(a);
end$$;

-- Staff see the person actually attending as patient_name; the account holder stays reachable
-- through patient_phone and account_holder_name.
drop view public.admin_appointments;
create view public.admin_appointments with(security_invoker=true) as
 select v.id,v.clinic_id,v.doctor_id,v.patient_id,v.service_id,v.starts_at,v.ends_at,v.status,v.created_at,v.updated_at,v.price_rub,
 coalesce(fm.full_name,v.patient_name) as patient_name,v.patient_phone,v.doctor_name,v.service_name,v.specialty_id,v.specialty_name,
 v.search_text||coalesce(' '||fm.full_name,'') as search_text,a.attendance_status,a.arrived_at,
 a.family_member_id,fm.relationship as family_relationship,v.patient_name as account_holder_name
 from public.admin_appointments_base v join public.appointments a on a.id=v.id and a.clinic_id=v.clinic_id
 left join public.family_members fm on fm.id=a.family_member_id and fm.owner_id=a.patient_id;
revoke all on public.admin_appointments from public,anon,authenticated;grant select on public.admin_appointments to service_role;
