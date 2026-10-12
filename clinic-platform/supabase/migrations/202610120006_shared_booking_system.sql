begin;
create table public.system_settings(id boolean primary key default true check(id),booking_horizon_days integer not null default 90 check(booking_horizon_days between 7 and 180),booking_enabled boolean not null default true,updated_at timestamptz not null default now());
insert into public.system_settings(id) values(true);
alter table public.system_settings enable row level security;
revoke all on public.system_settings from public,anon,authenticated;
grant select,update on public.system_settings to service_role;
create function public.admin_system(p_actor uuid,p_input jsonb default null) returns jsonb language plpgsql security definer set search_path='' as $$
declare result jsonb;
begin
 perform public.admin_access(p_actor,null,array[]::text[]);
 if p_input is not null then
  if exists(select 1 from jsonb_object_keys(p_input) k where k not in ('booking_horizon_days','booking_enabled')) then raise exception 'VALIDATION_ERROR';end if;
  update public.system_settings set booking_horizon_days=coalesce((p_input->>'booking_horizon_days')::integer,booking_horizon_days),booking_enabled=coalesce((p_input->>'booking_enabled')::boolean,booking_enabled),updated_at=now() where id;
  insert into public.audit_logs(actor_id,action) values(p_actor,'system.settings_changed');
 end if;
 select to_jsonb(s)-'id' into result from public.system_settings s where id;return result;
end$$;
create function public.admin_analytics(p_actor uuid,p_from date,p_to date) returns jsonb language plpgsql security definer set search_path='' as $$
begin
 perform public.admin_access(p_actor,null,array[]::text[]);
 if p_to<p_from or p_to-p_from>366 then raise exception 'VALIDATION_ERROR';end if;
 return (select coalesce(jsonb_agg(to_jsonb(x)),'[]') from(select c.id,c.name,c.timezone,count(a.id) as appointments,count(a.id) filter(where a.status='completed') as completed,coalesce(sum(a.price_rub) filter(where a.status='completed'),0) as completed_value_rub from public.clinics c left join public.appointments a on a.clinic_id=c.id and a.starts_at>=(p_from::timestamp at time zone c.timezone) and a.starts_at<((p_to+1)::timestamp at time zone c.timezone) group by c.id order by c.created_at,c.id)x);
end$$;
-- Both patient and staff callers use the same atomic booking and availability functions.
create function public.booking_commit(p_actor uuid,p_clinic uuid,p_input jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare a public.appointments;s public.services;doctor uuid=(p_input->>'doctor_id')::uuid;patient uuid=(p_input->>'patient_id')::uuid;service uuid=(p_input->>'service_id')::uuid;start_time timestamptz=(p_input->>'starts_at')::timestamptz;
begin
 
 perform pg_advisory_xact_lock(hashtextextended('clinic:'||p_clinic::text,0));
 perform pg_advisory_xact_lock(hashtextextended(doctor::text,0));
 if not exists(select 1 from public.clinic_memberships where clinic_id=p_clinic and user_id=patient) then raise exception 'NOT_FOUND';end if;

 select s0.* into s from public.services s0 join public.specialties sp on sp.id=s0.specialty_id and sp.clinic_id=s0.clinic_id join public.doctor_services ds on ds.service_id=s0.id and ds.clinic_id=s0.clinic_id and ds.doctor_id=doctor join public.doctor_clinics dc on dc.clinic_id=ds.clinic_id and dc.doctor_id=ds.doctor_id where s0.id=service and s0.clinic_id=p_clinic for share of s0,sp,ds,dc;

 if not public.booking_slot_valid(p_clinic,doctor,service,start_time) then raise exception 'SLOT_UNAVAILABLE';end if;
 insert into public.appointments(clinic_id,doctor_id,patient_id,service_id,starts_at,ends_at,status,price_rub) values(p_clinic,doctor,patient,service,start_time,start_time+make_interval(mins=>s.duration_minutes),'pending',s.price_rub) returning * into a;
 insert into public.appointment_status_history(clinic_id,appointment_id,status,changed_by) values(p_clinic,a.id,a.status,p_actor);
 insert into public.audit_logs(clinic_id,actor_id,action,resource_id) values(p_clinic,p_actor,'appointment.created',a.id);
 return to_jsonb(a);
end$$;

create or replace function public.admin_book(p_actor uuid,p_clinic uuid,p_input jsonb) returns jsonb language plpgsql security definer set search_path='' as $$begin perform public.admin_access(p_actor,p_clinic,array['CLINIC_ADMIN','RECEPTIONIST']);return public.booking_commit(p_actor,p_clinic,p_input);end$$;
create function public.patient_book(p_actor uuid,p_clinic uuid,p_input jsonb) returns jsonb language plpgsql security definer set search_path='' as $$begin
 if not exists(select 1 from public.clinic_memberships where user_id=p_actor and clinic_id=p_clinic) then raise exception 'FORBIDDEN';end if;
 return public.booking_commit(p_actor,p_clinic,(p_input-'patient_id')||jsonb_build_object('patient_id',p_actor));end$$;
create function public.patient_availability(p_actor uuid,p_clinic uuid,p_doctor uuid,p_service uuid,p_date date) returns jsonb
language plpgsql security definer set search_path='' as $$
declare own uuid;zone text;result jsonb;
begin
 if not exists(select 1 from public.clinic_memberships where user_id=p_actor and clinic_id=p_clinic) then raise exception 'FORBIDDEN';end if;
 select timezone into zone from public.clinics where id=p_clinic and active;if not found then raise exception 'NOT_FOUND';end if;
 if p_date<((now() at time zone zone)::date) or p_date>((now() at time zone zone)::date)+(select booking_horizon_days from public.system_settings where id) then raise exception 'VALIDATION_ERROR';end if;
 select coalesce(jsonb_agg(jsonb_build_object('starts_at',slot,'ends_at',slot+make_interval(mins=>s.duration_minutes)) order by slot),'[]') into result from generate_series(p_date::timestamp at time zone zone,((p_date+1)::timestamp at time zone zone)-interval '1 minute',interval '5 minutes') slot cross join public.services s where s.id=p_service and s.clinic_id=p_clinic and public.booking_slot_valid(p_clinic,p_doctor,p_service,slot);
 return result;
end$$;

create function public.patient_cancel(p_actor uuid,p_clinic uuid,p_id uuid,p_expected timestamptz) returns jsonb language plpgsql security definer set search_path='' as $$
declare a public.appointments;
begin
 select doctor_id into a.doctor_id from public.appointments where id=p_id and clinic_id=p_clinic and patient_id=p_actor;if not found then raise exception 'NOT_FOUND';end if;
 perform pg_advisory_xact_lock(hashtextextended('clinic:'||p_clinic::text,0));
 perform pg_advisory_xact_lock(hashtextextended(a.doctor_id::text,0));
 select * into a from public.appointments where id=p_id and clinic_id=p_clinic and patient_id=p_actor for update;
 if a.updated_at<>p_expected then raise exception 'STALE_APPOINTMENT';end if;
 if a.status not in ('pending','confirmed') or a.starts_at<=now() then raise exception 'INVALID_TRANSITION';end if;
 update public.appointments set status='cancelled' where id=p_id returning * into a;
 insert into public.appointment_status_history(clinic_id,appointment_id,status,changed_by) values(p_clinic,p_id,'cancelled',p_actor);
 insert into public.audit_logs(clinic_id,actor_id,action,resource_id) values(p_clinic,p_actor,'appointment.cancelled',p_id);
 return to_jsonb(a);
end$$;
revoke all on function public.booking_commit(uuid,uuid,jsonb),public.patient_availability(uuid,uuid,uuid,uuid,date),public.patient_book(uuid,uuid,jsonb),public.patient_cancel(uuid,uuid,uuid,timestamptz),public.admin_system(uuid,jsonb),public.admin_analytics(uuid,date,date) from public,anon,authenticated;
grant execute on function public.patient_availability(uuid,uuid,uuid,uuid,date),public.patient_book(uuid,uuid,jsonb),public.patient_cancel(uuid,uuid,uuid,timestamptz),public.admin_system(uuid,jsonb),public.admin_analytics(uuid,date,date) to service_role;
create function public.bootstrap_super_admin(p_user uuid) returns uuid language plpgsql security definer set search_path='' as $$begin
 perform pg_advisory_xact_lock(hashtextextended('initial_super_admin',0));
 if exists(select 1 from public.staff_memberships where role='SUPER_ADMIN') then raise exception 'FORBIDDEN';end if;
 if not exists(select 1 from auth.users where id=p_user) then raise exception 'NOT_FOUND';end if;
 insert into public.staff_memberships(user_id,role) values(p_user,'SUPER_ADMIN');
 insert into public.audit_logs(actor_id,action,resource_id) values(p_user,'staff.bootstrap',p_user);
 return p_user;end$$;
revoke all on function public.bootstrap_super_admin(uuid) from public,anon,authenticated;
grant execute on function public.bootstrap_super_admin(uuid) to service_role;
create function public.admin_catalog_options(p_actor uuid,p_clinic uuid) returns jsonb language plpgsql security definer set search_path='' as $$begin
 perform public.admin_access(p_actor,p_clinic,array['CLINIC_ADMIN']);
 return jsonb_build_object('doctors',(select coalesce(jsonb_agg(to_jsonb(x)),'[]') from(select id,name,active from public.admin_doctors where clinic_id=p_clinic order by sort_order,id limit 100)x),'specialties',(select coalesce(jsonb_agg(to_jsonb(x)),'[]') from(select id,name,active from public.specialties where clinic_id=p_clinic order by sort_order,id limit 100)x),'services',(select coalesce(jsonb_agg(to_jsonb(x)),'[]') from(select id,name,active from public.services where clinic_id=p_clinic order by sort_order,id limit 100)x));end$$;
create function public.admin_schedule_options(p_actor uuid,p_clinic uuid) returns jsonb language plpgsql security definer set search_path='' as $$declare own uuid;begin
 own=public.admin_access(p_actor,p_clinic,array['CLINIC_ADMIN','DOCTOR']);return jsonb_build_object('doctors',(select coalesce(jsonb_agg(to_jsonb(x)),'[]') from(select id,name,active from public.admin_doctors where clinic_id=p_clinic and (own is null or id=own) order by sort_order,id limit 100)x));end$$;
revoke all on function public.admin_catalog_options(uuid,uuid),public.admin_schedule_options(uuid,uuid) from public,anon,authenticated;
grant execute on function public.admin_catalog_options(uuid,uuid),public.admin_schedule_options(uuid,uuid) to service_role;
create function public.admin_filter_options(p_actor uuid,p_clinic uuid) returns jsonb language plpgsql security definer set search_path='' as $$declare own uuid;begin
 own=public.admin_access(p_actor,p_clinic,array['CLINIC_ADMIN','RECEPTIONIST','DOCTOR']);
 return jsonb_build_object('doctors',(select coalesce(jsonb_agg(to_jsonb(x)),'[]') from(select id,name,active from public.admin_doctors where clinic_id=p_clinic and (own is null or id=own) order by sort_order,id limit 100)x),'specialties',(select coalesce(jsonb_agg(to_jsonb(x)),'[]') from(select id,name,active from public.specialties where clinic_id=p_clinic order by sort_order,id limit 100)x),'services',(select coalesce(jsonb_agg(to_jsonb(x)),'[]') from(select id,name,active from public.services where clinic_id=p_clinic order by sort_order,id limit 100)x));end$$;
revoke all on function public.admin_filter_options(uuid,uuid) from public,anon,authenticated;grant execute on function public.admin_filter_options(uuid,uuid) to service_role;
notify pgrst,'reload schema';
commit;
