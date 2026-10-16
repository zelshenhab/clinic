-- Full-day weekly hours including an exclusive 24:00 boundary.
create or replace function public.booking_slot_valid(p_clinic uuid,p_doctor uuid,p_service uuid,p_start timestamptz,p_ignore uuid default null) returns boolean
language plpgsql security definer set search_path='' as $$
declare c public.clinics;s public.services;local_start timestamp;local_end timestamp;finish timestamptz;step integer;end_clock time;
begin
 select * into c from public.clinics where id=p_clinic and active;if not found then return false;end if;
 select s0.* into s from public.services s0 join public.specialties sp on sp.id=s0.specialty_id and sp.clinic_id=s0.clinic_id and sp.active join public.doctor_services ds on ds.clinic_id=s0.clinic_id and ds.service_id=s0.id and ds.doctor_id=p_doctor and ds.active join public.doctor_clinics dc on dc.clinic_id=ds.clinic_id and dc.doctor_id=ds.doctor_id and dc.active where s0.id=p_service and s0.clinic_id=p_clinic and s0.active;
 if not found or p_start<=now() or p_start>now()+make_interval(days=>(select booking_horizon_days from public.system_settings where id)) or not (select booking_enabled from public.system_settings where id) then return false;end if;
 finish=p_start+make_interval(mins=>s.duration_minutes);local_start=p_start at time zone c.timezone;local_end=finish at time zone c.timezone;
 end_clock=case when local_end::date=local_start::date+1 and local_end::time=time '00:00' then time '24:00' else local_end::time end;
 select coalesce((configuration->'booking'->>'slot_step_minutes')::integer,15) into step from public.clinic_settings where clinic_id=p_clinic;step=coalesce(step,15);
 if step<5 or step>60 or extract(second from local_start)<>0 or mod(extract(minute from local_start)::integer,step)<>0 or (local_start::date<>local_end::date and not (local_end::date=local_start::date+1 and local_end::time=time '00:00')) then return false;end if;
 if not (exists(select 1 from public.doctor_schedules ds where ds.clinic_id=p_clinic and ds.doctor_id=p_doctor and ds.weekday=extract(dow from local_start)::integer and local_start::time>=ds.starts_at and end_clock<=ds.ends_at and not exists(select 1 from jsonb_array_elements(ds.breaks) br where local_start::time<(br->>'end')::time and end_clock>(br->>'start')::time)) or exists(select 1 from public.schedule_exceptions ex where ex.clinic_id=p_clinic and ex.doctor_id=p_doctor and ex.available and ex.starts_at<=p_start and ex.ends_at>=finish)) then return false;end if;
 if exists(select 1 from public.schedule_exceptions ex where ex.clinic_id=p_clinic and ex.doctor_id=p_doctor and not ex.available and tstzrange(ex.starts_at,ex.ends_at,'[)')&&tstzrange(p_start,finish,'[)')) then return false;end if;
 return not exists(select 1 from public.appointments a where a.doctor_id=p_doctor and (p_ignore is null or a.id<>p_ignore) and a.status in ('pending','confirmed') and tstzrange(a.starts_at,a.ends_at,'[)')&&tstzrange(p_start,finish,'[)'));
end$$;


create or replace function public.admin_schedule_save(p_actor uuid,p_clinic uuid,p_doctor uuid,p_input jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare shift jsonb;ex jsonb;conflicts uuid[];zone text;own uuid;
begin
 own=public.admin_access(p_actor,p_clinic,array['CLINIC_ADMIN','DOCTOR']);
 if own is not null and own<>p_doctor then raise exception 'FORBIDDEN';end if;
 perform pg_advisory_xact_lock(hashtextextended('clinic:'||p_clinic::text,0));
 perform pg_advisory_xact_lock(hashtextextended(p_doctor::text,0));
 if not exists(select 1 from public.doctor_clinics where clinic_id=p_clinic and doctor_id=p_doctor) then raise exception 'NOT_FOUND';end if;
 select timezone into zone from public.clinics where id=p_clinic;
 select array_agg(a.id) into conflicts from public.appointments a where a.clinic_id=p_clinic and a.doctor_id=p_doctor and a.ends_at>now() and a.status in ('pending','confirmed') and (
  not (exists(select 1 from jsonb_array_elements(p_input->'weekly') s where (s->>'weekday')::integer=extract(dow from a.starts_at at time zone zone)::integer and (a.starts_at at time zone zone)::time>=(s->>'starts_at')::time and (case when (a.ends_at at time zone zone)::date=(a.starts_at at time zone zone)::date+1 and (a.ends_at at time zone zone)::time=time '00:00' then time '24:00' else (a.ends_at at time zone zone)::time end)<=(s->>'ends_at')::time and not exists(select 1 from jsonb_array_elements(s->'breaks') br where (a.starts_at at time zone zone)::time<(br->>'end')::time and (case when (a.ends_at at time zone zone)::date=(a.starts_at at time zone zone)::date+1 and (a.ends_at at time zone zone)::time=time '00:00' then time '24:00' else (a.ends_at at time zone zone)::time end)>(br->>'start')::time)) or exists(select 1 from jsonb_array_elements(p_input->'exceptions') e where (e->>'available')::boolean and (e->>'starts_at')::timestamptz<=a.starts_at and (e->>'ends_at')::timestamptz>=a.ends_at))
  or exists(select 1 from jsonb_array_elements(p_input->'exceptions') e where not (e->>'available')::boolean and tstzrange((e->>'starts_at')::timestamptz,(e->>'ends_at')::timestamptz,'[)')&&tstzrange(a.starts_at,a.ends_at,'[)')));
 if conflicts is not null then raise exception 'SCHEDULE_CONFLICT' using detail=array_to_json(conflicts)::text;end if;
 delete from public.doctor_schedules where clinic_id=p_clinic and doctor_id=p_doctor;
 for shift in select jsonb_array_elements(p_input->'weekly') loop
  insert into public.doctor_schedules(clinic_id,doctor_id,weekday,starts_at,ends_at,breaks) values(p_clinic,p_doctor,(shift->>'weekday')::integer,(shift->>'starts_at')::time,(shift->>'ends_at')::time,shift->'breaks');
 end loop;
 delete from public.schedule_exceptions where clinic_id=p_clinic and doctor_id=p_doctor and ends_at>now();
 for ex in select jsonb_array_elements(p_input->'exceptions') loop
  insert into public.schedule_exceptions(clinic_id,doctor_id,starts_at,ends_at,available) values(p_clinic,p_doctor,(ex->>'starts_at')::timestamptz,(ex->>'ends_at')::timestamptz,(ex->>'available')::boolean);
 end loop;
 insert into public.audit_logs(clinic_id,actor_id,action,resource_id) values(p_clinic,p_actor,'doctor.schedule_changed',p_doctor);
 return jsonb_build_object('doctor_id',p_doctor,'clinic_id',p_clinic);
end$$;

