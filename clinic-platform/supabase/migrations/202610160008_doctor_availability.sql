-- Direct doctor availability editing and public, non-identifying slot invalidations.
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
  not (exists(select 1 from jsonb_array_elements(p_input->'weekly') s where (s->>'weekday')::integer=extract(dow from a.starts_at at time zone zone)::integer and (a.starts_at at time zone zone)::time>=(s->>'starts_at')::time and (a.ends_at at time zone zone)::time<=(s->>'ends_at')::time and not exists(select 1 from jsonb_array_elements(s->'breaks') br where (a.starts_at at time zone zone)::time<(br->>'end')::time and (a.ends_at at time zone zone)::time>(br->>'start')::time)) or exists(select 1 from jsonb_array_elements(p_input->'exceptions') e where (e->>'available')::boolean and (e->>'starts_at')::timestamptz<=a.starts_at and (e->>'ends_at')::timestamptz>=a.ends_at))
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

create function public.doctor_schedule_save(p_actor uuid,p_clinic uuid,p_input jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare own uuid;
begin
 own=public.doctor_identity(p_actor,p_clinic);
 return public.admin_schedule_save(p_actor,p_clinic,own,p_input);
end$$;
create function public.public_availability(p_clinic uuid,p_doctor uuid,p_service uuid,p_date date) returns jsonb language plpgsql security definer set search_path='' as $$
declare zone text;result jsonb;
begin
 select timezone into zone from public.clinics where id=p_clinic and active;
 if not found then raise exception 'NOT_FOUND';end if;
 if p_date < (now() at time zone zone)::date or p_date > (now() at time zone zone)::date+(select booking_horizon_days from public.system_settings where id) then return '[]'::jsonb;end if;
 select coalesce(jsonb_agg(jsonb_build_object('starts_at',slot,'ends_at',slot+make_interval(mins=>s.duration_minutes)) order by slot),'[]') into result
 from public.services s cross join lateral generate_series(p_date::timestamp at time zone zone,(p_date+1)::timestamp at time zone zone,interval '5 minutes') slot
 where s.clinic_id=p_clinic and s.id=p_service and slot<((p_date+1)::timestamp at time zone zone) and public.booking_slot_valid(p_clinic,p_doctor,p_service,slot);
 return result;
end$$;
create function public.availability_invalidation() returns trigger language plpgsql security definer set search_path='' as $$
declare c uuid;d uuid;
begin
 if tg_op='DELETE' then c=old.clinic_id;d=old.doctor_id;else c=new.clinic_id;d=new.doctor_id;end if;
 -- Public topic deliberately contains no booking id, patient id, names, contact details or reasons.
 perform realtime.send(jsonb_build_object('event_id',gen_random_uuid(),'clinic_id',c,'doctor_id',d),'availability_changed','availability:'||c::text||':'||d::text,false);
 return null;
end$$;
create trigger appointment_availability_events after insert or update or delete on public.appointments for each row execute function public.availability_invalidation();
create trigger schedule_availability_events after insert or update or delete on public.doctor_schedules for each row execute function public.availability_invalidation();
create trigger exception_availability_events after insert or update or delete on public.schedule_exceptions for each row execute function public.availability_invalidation();
revoke all on function public.doctor_schedule_save(uuid,uuid,jsonb),public.public_availability(uuid,uuid,uuid,date),public.availability_invalidation() from public,anon,authenticated;
grant execute on function public.doctor_schedule_save(uuid,uuid,jsonb),public.public_availability(uuid,uuid,uuid,date) to service_role;
-- A patient deliberately booking their own appointment joins that clinic in the
-- same transaction. A failed booking rolls back the new relationship as well.
create or replace function public.patient_book(p_actor uuid,p_clinic uuid,p_input jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
begin
 if not exists(select 1 from public.patient_profiles where id=p_actor and length(trim(full_name))>=2) then raise exception 'FORBIDDEN';end if;
 if not exists(select 1 from public.clinics where id=p_clinic and active) then raise exception 'NOT_FOUND';end if;
 insert into public.clinic_memberships(clinic_id,user_id) values(p_clinic,p_actor) on conflict(clinic_id,user_id) do nothing;
 if found then insert into public.audit_logs(clinic_id,actor_id,action,resource_id) values(p_clinic,p_actor,'patient.self_joined',p_actor);end if;
 return public.booking_commit(p_actor,p_clinic,(p_input-'patient_id')||jsonb_build_object('patient_id',p_actor));
end$$;
