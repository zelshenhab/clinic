begin;
alter table public.patient_profiles add column phone text;
alter table public.clinics add column email text, add column website text;
alter table public.appointments add column price_rub numeric(12,2);
update public.appointments a set price_rub=s.price_rub from public.services s where s.clinic_id=a.clinic_id and s.id=a.service_id;
alter table public.appointments alter column price_rub set not null;
alter table public.doctor_clinics add column name_override jsonb, add column photo_url text;
alter table public.doctor_services add column active boolean not null default true;
alter table public.audit_logs add column metadata jsonb not null default '{}';
create index appointments_clinic_status on public.appointments(clinic_id,status,starts_at);
create index memberships_clinic_patient on public.clinic_memberships(clinic_id,user_id);

create function public.admin_access(p_actor uuid,p_clinic uuid,p_roles text[]) returns uuid
language plpgsql security definer set search_path='' as $$
declare m public.staff_memberships;
begin
 select * into m from public.staff_memberships where user_id=p_actor and active and (role='SUPER_ADMIN' or (clinic_id=p_clinic and role=any(p_roles))) order by case role when 'SUPER_ADMIN' then 0 when 'CLINIC_ADMIN' then 1 when 'RECEPTIONIST' then 2 else 3 end limit 1;
 if not found then raise exception 'FORBIDDEN'; end if;
 if m.role='DOCTOR' then return m.doctor_id; end if;
 return null;
end$$;

-- Shared availability rule for staff and future patient booking callers.
create function public.booking_slot_valid(p_clinic uuid,p_doctor uuid,p_service uuid,p_start timestamptz,p_ignore uuid default null) returns boolean
language plpgsql security definer set search_path='' as $$
declare c public.clinics;s public.services;local_start timestamp;local_end timestamp;finish timestamptz;step integer;
begin
 select * into c from public.clinics where id=p_clinic and active;if not found then return false;end if;
 select s0.* into s from public.services s0 join public.specialties sp on sp.id=s0.specialty_id and sp.clinic_id=s0.clinic_id and sp.active join public.doctor_services ds on ds.clinic_id=s0.clinic_id and ds.service_id=s0.id and ds.doctor_id=p_doctor and ds.active join public.doctor_clinics dc on dc.clinic_id=ds.clinic_id and dc.doctor_id=ds.doctor_id and dc.active where s0.id=p_service and s0.clinic_id=p_clinic and s0.active;
 if not found or p_start<=now() or p_start>now()+make_interval(days=>(select booking_horizon_days from public.system_settings where id)) or not (select booking_enabled from public.system_settings where id) then return false;end if;
 finish=p_start+make_interval(mins=>s.duration_minutes);local_start=p_start at time zone c.timezone;local_end=finish at time zone c.timezone;
 select coalesce((configuration->'booking'->>'slot_step_minutes')::integer,15) into step from public.clinic_settings where clinic_id=p_clinic;step=coalesce(step,15);
 if step<5 or step>60 or extract(second from local_start)<>0 or mod(extract(minute from local_start)::integer,step)<>0 or local_start::date<>local_end::date then return false;end if;
 if not (exists(select 1 from public.doctor_schedules ds where ds.clinic_id=p_clinic and ds.doctor_id=p_doctor and ds.weekday=extract(dow from local_start)::integer and local_start::time>=ds.starts_at and local_end::time<=ds.ends_at and not exists(select 1 from jsonb_array_elements(ds.breaks) br where local_start::time<(br->>'end')::time and local_end::time>(br->>'start')::time)) or exists(select 1 from public.schedule_exceptions ex where ex.clinic_id=p_clinic and ex.doctor_id=p_doctor and ex.available and ex.starts_at<=p_start and ex.ends_at>=finish)) then return false;end if;
 if exists(select 1 from public.schedule_exceptions ex where ex.clinic_id=p_clinic and ex.doctor_id=p_doctor and not ex.available and tstzrange(ex.starts_at,ex.ends_at,'[)')&&tstzrange(p_start,finish,'[)')) then return false;end if;
 return not exists(select 1 from public.appointments a where a.doctor_id=p_doctor and (p_ignore is null or a.id<>p_ignore) and a.status in ('pending','confirmed') and tstzrange(a.starts_at,a.ends_at,'[)')&&tstzrange(p_start,finish,'[)'));
end$$;

create function public.admin_availability(p_actor uuid,p_clinic uuid,p_doctor uuid,p_service uuid,p_date date) returns jsonb
language plpgsql security definer set search_path='' as $$
declare own uuid;zone text;result jsonb;
begin
 own=public.admin_access(p_actor,p_clinic,array['CLINIC_ADMIN','RECEPTIONIST','DOCTOR']);if own is not null and own<>p_doctor then raise exception 'FORBIDDEN';end if;
 select timezone into zone from public.clinics where id=p_clinic and active;if not found then raise exception 'NOT_FOUND';end if;
 if p_date<((now() at time zone zone)::date) or p_date>((now() at time zone zone)::date)+(select booking_horizon_days from public.system_settings where id) then raise exception 'VALIDATION_ERROR';end if;
 select coalesce(jsonb_agg(jsonb_build_object('starts_at',slot,'ends_at',slot+make_interval(mins=>s.duration_minutes)) order by slot),'[]') into result from generate_series(p_date::timestamp at time zone zone,((p_date+1)::timestamp at time zone zone)-interval '1 minute',interval '5 minutes') slot cross join public.services s where s.id=p_service and s.clinic_id=p_clinic and public.booking_slot_valid(p_clinic,p_doctor,p_service,slot);
 return result;
end$$;

create function public.admin_book(p_actor uuid,p_clinic uuid,p_input jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare a public.appointments;s public.services;doctor uuid=(p_input->>'doctor_id')::uuid;patient uuid=(p_input->>'patient_id')::uuid;service uuid=(p_input->>'service_id')::uuid;start_time timestamptz=(p_input->>'starts_at')::timestamptz;
begin
 perform public.admin_access(p_actor,p_clinic,array['CLINIC_ADMIN','RECEPTIONIST']);
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

create function public.admin_appointment_change(p_actor uuid,p_clinic uuid,p_id uuid,p_input jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare a public.appointments;own uuid;target text=p_input->>'status';new_start timestamptz;duration integer;previous jsonb;
begin
 own=public.admin_access(p_actor,p_clinic,array['CLINIC_ADMIN','RECEPTIONIST','DOCTOR']);
 -- Serialize with availability, other appointment writes and schedule edits for this doctor.
 select doctor_id into a.doctor_id from public.appointments where id=p_id and clinic_id=p_clinic;if not found then raise exception 'NOT_FOUND';end if;
 perform pg_advisory_xact_lock(hashtextextended('clinic:'||p_clinic::text,0));
 perform pg_advisory_xact_lock(hashtextextended(a.doctor_id::text,0));
 select * into a from public.appointments where id=p_id and clinic_id=p_clinic for update;
 if own is not null and own<>a.doctor_id then raise exception 'FORBIDDEN';end if;
 previous=jsonb_build_object('status',a.status,'starts_at',a.starts_at,'ends_at',a.ends_at);
 if (p_input->>'expected_updated_at')::timestamptz<>a.updated_at then raise exception 'STALE_APPOINTMENT';end if;
 if target is not null then
  if not ((a.status='pending' and target in ('confirmed','cancelled')) or (a.status='confirmed' and target in ('completed','cancelled','no_show'))) then raise exception 'INVALID_TRANSITION';end if;
  if own is not null and target not in ('completed','no_show') then raise exception 'FORBIDDEN';end if;
  if target in ('completed','no_show') and a.starts_at>now() then raise exception 'INVALID_TRANSITION';end if;
  update public.appointments set status=target where id=p_id returning * into a;
  insert into public.appointment_status_history(clinic_id,appointment_id,status,changed_by) values(p_clinic,p_id,target,p_actor);
 else
  if own is not null then raise exception 'FORBIDDEN';end if;
  if a.status not in ('pending','confirmed') then raise exception 'INVALID_TRANSITION';end if;
  select duration_minutes into duration from public.services where id=a.service_id and clinic_id=p_clinic for share;
  new_start=(p_input->>'starts_at')::timestamptz;
  if not public.booking_slot_valid(p_clinic,a.doctor_id,a.service_id,new_start,p_id) then raise exception 'SLOT_UNAVAILABLE';end if;
  select duration_minutes into duration from public.services where id=a.service_id and clinic_id=p_clinic;
  update public.appointments set starts_at=new_start,ends_at=new_start+make_interval(mins=>duration) where id=p_id returning * into a;
 end if;
 insert into public.audit_logs(clinic_id,actor_id,action,resource_id,metadata) values(p_clinic,p_actor,case when target is null then 'appointment.rescheduled' else 'appointment.status_changed' end,p_id,jsonb_build_object('before',previous,'after',jsonb_build_object('status',a.status,'starts_at',a.starts_at,'ends_at',a.ends_at)));
 return to_jsonb(a);
end$$;

-- Small private invalidations, never full patient or appointment row broadcasts.
create function public.appointment_invalidation() returns trigger language plpgsql security definer set search_path='' as $$
declare event jsonb;recipient uuid;
begin
 event=jsonb_build_object('event_id',gen_random_uuid(),'clinic_id',new.clinic_id,'appointment_id',new.id,'operation',TG_OP);
 for recipient in select distinct user_id from public.staff_memberships where active and (role='SUPER_ADMIN' or (clinic_id=new.clinic_id and (role in ('CLINIC_ADMIN','RECEPTIONIST') or (role='DOCTOR' and doctor_id=new.doctor_id)))) loop
  perform realtime.send(event,'appointment_changed','staff:'||new.clinic_id::text||':'||recipient::text,true);
 end loop;
 perform realtime.send(event,'appointment_changed','patient:'||new.clinic_id::text||':'||new.patient_id::text,true);
 return new;
end$$;
create trigger appointment_invalidation after insert or update on public.appointments for each row execute function public.appointment_invalidation();
create policy staff_private_appointment_events on realtime.messages for select to authenticated using(
 extension='broadcast' and topic=realtime.topic() and exists(select 1 from public.staff_memberships m where m.user_id=auth.uid() and m.active and realtime.topic()='staff:'||split_part(realtime.topic(),':',2)||':'||auth.uid()::text and (m.role='SUPER_ADMIN' or m.clinic_id::text=split_part(realtime.topic(),':',2))));
create function public.can_receive_patient_event(p_topic text) returns boolean language sql stable security definer set search_path='' as $$select exists(select 1 from public.clinic_memberships cm where cm.user_id=auth.uid() and p_topic='patient:'||cm.clinic_id::text||':'||auth.uid()::text)$$;
revoke all on function public.can_receive_patient_event(text) from public,anon;
grant execute on function public.can_receive_patient_event(text) to authenticated;
create policy patient_private_appointment_events on realtime.messages for select to authenticated using(extension='broadcast' and topic=realtime.topic() and public.can_receive_patient_event(realtime.topic()));

-- RPC entry points are server-only; verified actor identity is supplied by Node, never clients.
revoke all on function public.admin_access(uuid,uuid,text[]),public.booking_slot_valid(uuid,uuid,uuid,timestamptz,uuid),public.admin_availability(uuid,uuid,uuid,uuid,date),public.admin_book(uuid,uuid,jsonb),public.admin_appointment_change(uuid,uuid,uuid,jsonb),public.appointment_invalidation() from public,anon,authenticated;
grant execute on function public.admin_access(uuid,uuid,text[]),public.admin_availability(uuid,uuid,uuid,uuid,date),public.admin_book(uuid,uuid,jsonb),public.admin_appointment_change(uuid,uuid,uuid,jsonb) to service_role;
notify pgrst,'reload schema';
commit;
