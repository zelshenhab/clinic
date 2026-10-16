-- Patient self-service, durable notifications, waitlist and clinic attendance queue.
create table public.booking_policies(clinic_id uuid primary key references public.clinics(id),cancellation_notice_minutes integer not null default 120 check(cancellation_notice_minutes between 0 and 10080),reschedule_notice_minutes integer not null default 120 check(reschedule_notice_minutes between 0 and 10080));
alter table public.booking_policies enable row level security;revoke all on public.booking_policies from public,anon,authenticated;grant select,insert,update on public.booking_policies to service_role;
insert into public.booking_policies(clinic_id) select id from public.clinics;
create function public.booking_policy(p_clinic uuid) returns jsonb language plpgsql security definer set search_path='' as $$begin if not exists(select 1 from public.clinics where id=p_clinic and active) then raise exception 'NOT_FOUND';end if;return coalesce((select to_jsonb(p)-'clinic_id' from public.booking_policies p where clinic_id=p_clinic),jsonb_build_object('cancellation_notice_minutes',120,'reschedule_notice_minutes',120));end$$;
create function public.admin_booking_policy(p_actor uuid,p_clinic uuid,p_input jsonb default null) returns jsonb language plpgsql security definer set search_path='' as $$begin perform public.admin_access(p_actor,p_clinic,array['CLINIC_ADMIN']);if p_input is not null then insert into public.booking_policies(clinic_id,cancellation_notice_minutes,reschedule_notice_minutes) values(p_clinic,(p_input->>'cancellation_notice_minutes')::int,(p_input->>'reschedule_notice_minutes')::int) on conflict(clinic_id) do update set cancellation_notice_minutes=excluded.cancellation_notice_minutes,reschedule_notice_minutes=excluded.reschedule_notice_minutes;insert into public.audit_logs(clinic_id,actor_id,action,resource_id) values(p_clinic,p_actor,'booking.policy_changed',p_clinic);end if;return public.booking_policy(p_clinic);end$$;

alter table public.appointments add column attendance_status text not null default 'scheduled' check(attendance_status in ('scheduled','arrived','waiting','in_consultation','finished')),add column arrived_at timestamptz;
update public.appointments set attendance_status='finished' where status='completed';
create table public.appointment_attendance_history(id uuid primary key default gen_random_uuid(),clinic_id uuid not null,appointment_id uuid not null,previous_status text not null,status text not null,changed_by uuid not null references auth.users(id),created_at timestamptz not null default now(),foreign key(clinic_id,appointment_id) references public.appointments(clinic_id,id));
alter table public.appointment_attendance_history enable row level security;revoke all on public.appointment_attendance_history from public,anon,authenticated;grant select,insert on public.appointment_attendance_history to service_role;
alter view public.admin_appointments rename to admin_appointments_base;
create view public.admin_appointments with(security_invoker=true) as select v.*,a.attendance_status,a.arrived_at from public.admin_appointments_base v join public.appointments a on a.id=v.id and a.clinic_id=v.clinic_id;
revoke all on public.admin_appointments from public,anon,authenticated;grant select on public.admin_appointments to service_role;
create function public.finish_attendance() returns trigger language plpgsql set search_path='' as $$begin if new.status='completed' then new.attendance_status='finished';end if;return new;end$$;
create trigger attendance_completion before update of status on public.appointments for each row execute function public.finish_attendance();
create function public.appointment_attendance(p_actor uuid,p_clinic uuid,p_id uuid,p_status text,p_expected timestamptz,p_doctor_only boolean default false) returns jsonb language plpgsql security definer set search_path='' as $$
declare own uuid;a public.appointments;clinical boolean;previous text;
begin
 if p_expected is null then raise exception 'VALIDATION_ERROR';end if;
 own=case when p_doctor_only then public.doctor_identity(p_actor,p_clinic) else public.admin_access(p_actor,p_clinic,array['CLINIC_ADMIN','RECEPTIONIST','DOCTOR']) end;
 select doctor_id into a.doctor_id from public.appointments where id=p_id and clinic_id=p_clinic;if not found then raise exception 'NOT_FOUND';end if;
 if own is not null and own<>a.doctor_id then raise exception 'FORBIDDEN';end if;
 perform pg_advisory_xact_lock(hashtextextended('clinic:'||p_clinic::text,0));perform pg_advisory_xact_lock(hashtextextended(a.doctor_id::text,0));
 select * into a from public.appointments where id=p_id and clinic_id=p_clinic for update;
 if a.updated_at<>p_expected then raise exception 'STALE_APPOINTMENT';end if;if a.status<>'confirmed' then raise exception 'INVALID_TRANSITION';end if;
 clinical=own is not null or exists(select 1 from public.staff_memberships where user_id=p_actor and active and (role='SUPER_ADMIN' or clinic_id=p_clinic and role='CLINIC_ADMIN'));
 if (p_status in ('in_consultation','finished') and not clinical) or (own is not null and p_status in ('arrived','waiting')) then raise exception 'FORBIDDEN';end if;
 if not ((a.attendance_status='scheduled' and p_status='arrived') or (a.attendance_status='arrived' and p_status='waiting') or (a.attendance_status in ('arrived','waiting') and p_status='in_consultation') or (a.attendance_status='in_consultation' and p_status='finished')) then raise exception 'INVALID_TRANSITION';end if;
 if p_status in ('in_consultation','finished') and a.starts_at>now() then raise exception 'INVALID_TRANSITION';end if;
 previous=a.attendance_status;update public.appointments set attendance_status=p_status,arrived_at=case when p_status='arrived' then now() else arrived_at end,status=case when p_status='finished' then 'completed' else status end where id=p_id returning * into a;
 insert into public.appointment_attendance_history(clinic_id,appointment_id,previous_status,status,changed_by) values(p_clinic,p_id,previous,p_status,p_actor);
 if p_status='finished' then insert into public.appointment_status_history(clinic_id,appointment_id,status,changed_by) values(p_clinic,p_id,'completed',p_actor);end if;
 insert into public.audit_logs(clinic_id,actor_id,action,resource_id,metadata) values(p_clinic,p_actor,'appointment.attendance_changed',p_id,jsonb_build_object('before',previous,'after',p_status));return to_jsonb(a);
end$$;
create function public.clinic_queue(p_actor uuid,p_clinic uuid,p_day date,p_doctor_only boolean default false) returns jsonb language plpgsql security definer set search_path='' as $$
declare own uuid;zone text;items jsonb;total int;
begin own=case when p_doctor_only then public.doctor_identity(p_actor,p_clinic) else public.admin_access(p_actor,p_clinic,array['CLINIC_ADMIN','RECEPTIONIST','DOCTOR']) end;select timezone into zone from public.clinics where id=p_clinic;
 select count(*) into total from public.admin_appointments where clinic_id=p_clinic and (own is null or doctor_id=own) and starts_at>=p_day::timestamp at time zone zone and starts_at<(p_day+1)::timestamp at time zone zone and status in ('pending','confirmed','completed');
 select coalesce(jsonb_agg(to_jsonb(x)-'search_text'),'[]') into items from(select * from public.admin_appointments where clinic_id=p_clinic and (own is null or doctor_id=own) and starts_at>=p_day::timestamp at time zone zone and starts_at<(p_day+1)::timestamp at time zone zone and status in ('pending','confirmed','completed') order by case attendance_status when 'in_consultation' then 0 when 'waiting' then 1 when 'arrived' then 2 when 'scheduled' then 3 else 4 end,arrived_at nulls last,starts_at,id limit 100)x;return jsonb_build_object('items',items,'total',total,'truncated',total>100);
end$$;

create function public.patient_change(p_actor uuid,p_clinic uuid,p_id uuid,p_expected timestamptz,p_start timestamptz default null) returns jsonb language plpgsql security definer set search_path='' as $$
declare a public.appointments;policy jsonb;minutes int;duration int;previous jsonb;
begin
 if p_expected is null then raise exception 'VALIDATION_ERROR';end if;
 select doctor_id into a.doctor_id from public.appointments where id=p_id and clinic_id=p_clinic and patient_id=p_actor;if not found then raise exception 'NOT_FOUND';end if;
 perform pg_advisory_xact_lock(hashtextextended('clinic:'||p_clinic::text,0));perform pg_advisory_xact_lock(hashtextextended(a.doctor_id::text,0));
 select * into a from public.appointments where id=p_id and clinic_id=p_clinic and patient_id=p_actor for update;
 if a.updated_at<>p_expected then raise exception 'STALE_APPOINTMENT';end if;
 if a.status not in ('pending','confirmed') or a.attendance_status<>'scheduled' then raise exception 'INVALID_TRANSITION';end if;
 policy=public.booking_policy(p_clinic);minutes=(policy->>case when p_start is null then 'cancellation_notice_minutes' else 'reschedule_notice_minutes' end)::int;
 if a.starts_at<=now()+make_interval(mins=>minutes) then raise exception 'POLICY_CUTOFF';end if;
 previous=jsonb_build_object('starts_at',a.starts_at,'ends_at',a.ends_at,'status',a.status);
 if p_start is null then update public.appointments set status='cancelled' where id=p_id returning * into a;
 else
 if p_start<=now()+make_interval(mins=>minutes) then raise exception 'POLICY_CUTOFF';end if;
 select duration_minutes into duration from public.services where clinic_id=p_clinic and id=a.service_id for share;
 if not public.booking_slot_valid(p_clinic,a.doctor_id,a.service_id,p_start,p_id) then raise exception 'SLOT_UNAVAILABLE';end if;
 update public.appointments set starts_at=p_start,ends_at=p_start+make_interval(mins=>duration) where id=p_id returning * into a;
 end if;
 insert into public.appointment_status_history(clinic_id,appointment_id,status,changed_by) values(p_clinic,p_id,a.status,p_actor);
 insert into public.audit_logs(clinic_id,actor_id,action,resource_id,metadata) values(p_clinic,p_actor,case when p_start is null then 'appointment.cancelled' else 'appointment.rescheduled' end,p_id,jsonb_build_object('before',previous,'after',jsonb_build_object('starts_at',a.starts_at,'ends_at',a.ends_at,'status',a.status)));return to_jsonb(a);
end$$;
create or replace function public.patient_cancel(p_actor uuid,p_clinic uuid,p_id uuid,p_expected timestamptz) returns jsonb language sql security definer set search_path='' as $$select public.patient_change(p_actor,p_clinic,p_id,p_expected,null)$$;

alter table public.notifications add column appointment_id uuid references public.appointments(id),add column kind text not null default 'general',add column event_key text unique,add column context jsonb not null default '{}';
create function public.notify_patient(p_clinic uuid,p_user uuid,p_kind text,p_key text,p_appointment uuid default null,p_context jsonb default '{}') returns void language plpgsql security definer set search_path='' as $$
declare title jsonb;body jsonb;
begin
 title=case p_kind when 'booked' then '{"ru":"Запись создана","en":"Appointment booked"}'::jsonb when 'confirmed' then '{"ru":"Запись подтверждена","en":"Appointment confirmed"}'::jsonb when 'cancelled' then '{"ru":"Запись отменена","en":"Appointment cancelled"}'::jsonb when 'rescheduled' then '{"ru":"Время приёма изменено","en":"Appointment rescheduled"}'::jsonb when 'waitlist' then '{"ru":"Появилось свободное время","en":"An appointment time is available"}'::jsonb else '{"ru":"Напоминание о приёме","en":"Appointment reminder"}'::jsonb end;
 body=case when p_kind='waitlist' then '{"ru":"Проверьте доступное время. Оно не зарезервировано и может быть занято другим пациентом.","en":"Check available times. No slot is reserved and another patient may book it."}'::jsonb else '{"ru":"Откройте ваши записи, чтобы проверить актуальное время и статус приёма.","en":"Open My appointments to review the current time and appointment status."}'::jsonb end;
 insert into public.notifications(clinic_id,user_id,title,body,appointment_id,kind,event_key,context) values(p_clinic,p_user,title,body,p_appointment,p_kind,p_key,p_context) on conflict(event_key) do nothing;
end$$;
create function public.appointment_patient_notice() returns trigger language plpgsql security definer set search_path='' as $$
declare kind text;
begin
 if tg_op='INSERT' then kind='booked';elsif new.status='cancelled' and old.status<>new.status then kind='cancelled';elsif new.starts_at<>old.starts_at then kind='rescheduled';elsif new.status='confirmed' and old.status<>new.status then kind='confirmed';else return new;end if;
 perform public.notify_patient(new.clinic_id,new.patient_id,kind,new.id::text||':'||kind||':'||new.updated_at::text,new.id);return new;
end$$;
create trigger patient_booking_notices after insert or update on public.appointments for each row execute function public.appointment_patient_notice();
create function public.notification_event() returns trigger language plpgsql security definer set search_path='' as $$begin perform realtime.send(jsonb_build_object('event_id',gen_random_uuid(),'clinic_id',new.clinic_id,'notification_id',new.id),'notification_changed','patient:'||new.clinic_id::text||':'||new.user_id::text,true);return new;end$$;
create trigger patient_notification_events after insert or update of read_at on public.notifications for each row execute function public.notification_event();
create function public.patient_read_notification(p_actor uuid,p_clinic uuid,p_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$declare n public.notifications;begin update public.notifications set read_at=coalesce(read_at,now()) where id=p_id and clinic_id=p_clinic and user_id=p_actor returning * into n;if not found then raise exception 'NOT_FOUND';end if;return jsonb_build_object('id',n.id,'read_at',n.read_at);end$$;

create table public.appointment_waitlist(id uuid primary key default gen_random_uuid(),clinic_id uuid not null,patient_id uuid not null,doctor_id uuid not null,service_id uuid not null,day date not null,state text not null default 'waiting' check(state in ('waiting','notified','cancelled')),created_at timestamptz not null default now(),notified_at timestamptz,last_checked_at timestamptz,offer_version integer not null default 1,foreign key(clinic_id,patient_id) references public.clinic_memberships(clinic_id,user_id),foreign key(clinic_id,doctor_id,service_id) references public.doctor_services(clinic_id,doctor_id,service_id),unique(clinic_id,patient_id,doctor_id,service_id,day));
create index waitlist_patient on public.appointment_waitlist(clinic_id,patient_id,created_at desc);
create index waitlist_rotation on public.appointment_waitlist(last_checked_at nulls first,created_at,id) where state='waiting';
create index waitlist_waiting on public.appointment_waitlist(day,clinic_id) where state='waiting';alter table public.appointment_waitlist enable row level security;revoke all on public.appointment_waitlist from public,anon,authenticated;grant select,insert,update on public.appointment_waitlist to service_role;
create function public.patient_waitlist(p_actor uuid,p_clinic uuid,p_input jsonb default null) returns jsonb language plpgsql security definer set search_path='' as $$
declare w public.appointment_waitlist;result jsonb;zone text;
begin
 if p_input is null then select coalesce(jsonb_agg(to_jsonb(x)),'[]') into result from(select wl.*,coalesce(dc.name_override,d.name) doctor_name,s.name service_name from public.appointment_waitlist wl join public.doctors d on d.id=wl.doctor_id join public.doctor_clinics dc on dc.doctor_id=wl.doctor_id and dc.clinic_id=wl.clinic_id join public.services s on s.id=wl.service_id and s.clinic_id=wl.clinic_id where wl.clinic_id=p_clinic and wl.patient_id=p_actor order by wl.created_at desc limit 50)x;return result;end if;
 if p_input ? 'id' then update public.appointment_waitlist set state='cancelled' where id=(p_input->>'id')::uuid and patient_id=p_actor and clinic_id=p_clinic returning * into w;if not found then raise exception 'NOT_FOUND';end if;insert into public.audit_logs(clinic_id,actor_id,action,resource_id) values(p_clinic,p_actor,'patient.waitlist_left',w.id);return to_jsonb(w);end if;
 if not exists(select 1 from public.patient_profiles where id=p_actor and length(trim(full_name))>=2) then raise exception 'FORBIDDEN';end if;
 select timezone into zone from public.clinics where id=p_clinic and active;if not found then raise exception 'NOT_FOUND';end if;
 if (p_input->>'day')::date<(now() at time zone zone)::date or (p_input->>'day')::date>(now() at time zone zone)::date+(select booking_horizon_days from public.system_settings where id) then raise exception 'VALIDATION_ERROR';end if;
 if jsonb_array_length(public.public_availability(p_clinic,(p_input->>'doctor_id')::uuid,(p_input->>'service_id')::uuid,(p_input->>'day')::date))>0 then raise exception 'SLOT_ALREADY_AVAILABLE';end if;
 if not exists(select 1 from public.doctor_services ds join public.services s on s.id=ds.service_id and s.clinic_id=ds.clinic_id and s.active join public.doctor_clinics dc on dc.doctor_id=ds.doctor_id and dc.clinic_id=ds.clinic_id and dc.active where ds.clinic_id=p_clinic and ds.doctor_id=(p_input->>'doctor_id')::uuid and ds.service_id=(p_input->>'service_id')::uuid and ds.active) then raise exception 'NOT_FOUND';end if;
 insert into public.clinic_memberships(clinic_id,user_id) values(p_clinic,p_actor) on conflict do nothing;
 insert into public.appointment_waitlist(clinic_id,patient_id,doctor_id,service_id,day) values(p_clinic,p_actor,(p_input->>'doctor_id')::uuid,(p_input->>'service_id')::uuid,(p_input->>'day')::date) on conflict(clinic_id,patient_id,doctor_id,service_id,day) do update set state='waiting',notified_at=null,last_checked_at=null,offer_version=public.appointment_waitlist.offer_version+1 returning * into w;
 insert into public.audit_logs(clinic_id,actor_id,action,resource_id) values(p_clinic,p_actor,'patient.waitlist_joined',w.id);return to_jsonb(w);
end$$;
create function public.process_patient_jobs() returns jsonb language plpgsql security definer set search_path='' as $$
declare a public.appointments;w public.appointment_waitlist;hours int;reminders int=0;offers int=0;
begin
 -- Single scheduler lease per transaction; safe with multiple API processes.
 if not pg_try_advisory_xact_lock(hashtextextended('patient-jobs',0)) then return jsonb_build_object('busy',true);end if;
 for a in select ap.* from public.appointments ap join public.clinics c on c.id=ap.clinic_id and c.active where ap.status in ('pending','confirmed') and ap.starts_at>now() and ap.starts_at<=now()+interval '24 hours' and exists(select 1 from unnest(array[24,1]) h where (h=1 or ap.starts_at>now()+interval '1 hour') and ap.created_at<=ap.starts_at-make_interval(hours=>h) and now()>=ap.starts_at-make_interval(hours=>h) and not exists(select 1 from public.notifications n where n.event_key=ap.id::text||':reminder:'||h::text||':'||ap.starts_at::text)) order by ap.starts_at limit 500 loop
 foreach hours in array array[24,1] loop
 if (hours=1 or a.starts_at>now()+interval '1 hour') and a.created_at<=a.starts_at-make_interval(hours=>hours) and now()>=a.starts_at-make_interval(hours=>hours) then perform public.notify_patient(a.clinic_id,a.patient_id,'reminder',a.id::text||':reminder:'||hours::text||':'||a.starts_at::text,a.id);reminders=reminders+1;end if;
 end loop;end loop;
 for w in select wl.* from public.appointment_waitlist wl join public.clinics c on c.id=wl.clinic_id and c.active where wl.state='waiting' and wl.day>=(now() at time zone c.timezone)::date order by wl.last_checked_at nulls first,wl.created_at,wl.id limit 100 for update of wl skip locked loop
 update public.appointment_waitlist set last_checked_at=clock_timestamp() where id=w.id;
 if jsonb_array_length(public.public_availability(w.clinic_id,w.doctor_id,w.service_id,w.day))>0 then
 perform public.notify_patient(w.clinic_id,w.patient_id,'waitlist',w.id::text||':offer:'||w.offer_version::text,null,jsonb_build_object('doctor_id',w.doctor_id,'service_id',w.service_id,'day',w.day));update public.appointment_waitlist set state='notified',notified_at=now() where id=w.id;offers=offers+1;
 end if;end loop;return jsonb_build_object('reminders_checked',reminders,'waitlist_notified',offers);
end$$;

create function public.next_available(p_clinic uuid,p_specialty uuid default null,p_service uuid default null,p_from date default null,p_limit int default 10) returns jsonb language plpgsql security definer set search_path='' as $$
declare zone text;day date;offset_no int;pair record;slot jsonb;items jsonb='[]';result jsonb;start_day date;total_pairs int;
begin
 select timezone into zone from public.clinics where id=p_clinic and active;if not found then raise exception 'NOT_FOUND';end if;
 if p_limit<1 or p_limit>20 then raise exception 'VALIDATION_ERROR';end if;start_day=coalesce(p_from,(now() at time zone zone)::date);if start_day<(now() at time zone zone)::date or start_day>(now() at time zone zone)::date+180 then raise exception 'VALIDATION_ERROR';end if;
 select count(*) into total_pairs from public.doctor_services ds join public.services s on s.id=ds.service_id and s.clinic_id=ds.clinic_id and s.active join public.doctor_clinics dc on dc.doctor_id=ds.doctor_id and dc.clinic_id=ds.clinic_id and dc.active where ds.clinic_id=p_clinic and ds.active and (p_specialty is null or s.specialty_id=p_specialty) and (p_service is null or s.id=p_service);
 for offset_no in 0..13 loop day=start_day+offset_no;
 for pair in select ds.doctor_id,s.id service_id,s.name service_name,coalesce(dc.name_override,d.name) doctor_name,s.price_rub,s.duration_minutes from public.doctor_services ds join public.services s on s.id=ds.service_id and s.clinic_id=ds.clinic_id and s.active join public.specialties sp on sp.id=s.specialty_id and sp.clinic_id=s.clinic_id and sp.active join public.doctor_clinics dc on dc.doctor_id=ds.doctor_id and dc.clinic_id=ds.clinic_id and dc.active join public.doctors d on d.id=ds.doctor_id where ds.clinic_id=p_clinic and ds.active and (p_specialty is null or s.specialty_id=p_specialty) and (p_service is null or s.id=p_service) order by ds.doctor_id,s.id limit 200 loop
 select jsonb_build_object('starts_at',candidate,'ends_at',candidate+make_interval(mins=>pair.duration_minutes)) into slot from generate_series(day::timestamp at time zone zone,(day+1)::timestamp at time zone zone,interval '5 minutes') candidate where candidate<((day+1)::timestamp at time zone zone) and public.booking_slot_valid(p_clinic,pair.doctor_id,pair.service_id,candidate) order by candidate limit 1;
 if slot is not null then items=items||jsonb_build_array(to_jsonb(pair)||slot||jsonb_build_object('clinic_id',p_clinic));end if;
 end loop;exit when jsonb_array_length(items)>=p_limit;end loop;
 select coalesce(jsonb_agg(x),'[]') into result from(select value x from jsonb_array_elements(items) order by value->>'starts_at',value->>'doctor_id',value->>'service_id' limit p_limit)t;
 return jsonb_build_object('items',result,'searched_until',day,'combination_limit',total_pairs>200,'specialties',(select coalesce(jsonb_agg(jsonb_build_object('id',id,'name',name) order by sort_order,id),'[]') from public.specialties where clinic_id=p_clinic and active));
end$$;

create function public.doctor_block_period(p_actor uuid,p_clinic uuid,p_start timestamptz,p_end timestamptz) returns jsonb language plpgsql security definer set search_path='' as $$
declare own uuid;schedule jsonb;
begin own=public.doctor_identity(p_actor,p_clinic);if p_start<now() or p_end<=p_start or p_end-p_start>interval '180 days' then raise exception 'VALIDATION_ERROR';end if;
 perform pg_advisory_xact_lock(hashtextextended('clinic:'||p_clinic::text,0));perform pg_advisory_xact_lock(hashtextextended(own::text,0));schedule=public.admin_schedule_get(p_actor,p_clinic,own);
 if jsonb_array_length(schedule->'exceptions')>=400 then raise exception 'VALIDATION_ERROR';end if;
 return public.doctor_schedule_save(p_actor,p_clinic,jsonb_build_object('weekly',schedule->'weekly','exceptions',(schedule->'exceptions')||jsonb_build_array(jsonb_build_object('starts_at',p_start,'ends_at',p_end,'available',false))));end$$;
create function public.doctor_copy_week(p_actor uuid,p_clinic uuid,p_source date,p_target date) returns jsonb language plpgsql security definer set search_path='' as $$
declare own uuid;zone text;source_day date;target_day date;source_start timestamptz;source_end timestamptz;target_start timestamptz;target_end timestamptz;base tstzmultirange;opened tstzmultirange;blocked tstzmultirange;desired tstzmultirange;mapped tstzmultirange;period tstzrange;exceptions jsonb='[]';schedule jsonb;shift_days int;
begin
 own=public.doctor_identity(p_actor,p_clinic);select timezone into zone from public.clinics where id=p_clinic;
 source_day=date_trunc('week',p_source)::date;target_day=date_trunc('week',p_target)::date;shift_days=target_day-source_day;
 if source_day=target_day or target_day<((now() at time zone zone)::date) or target_day>((now() at time zone zone)::date)+180 then raise exception 'VALIDATION_ERROR';end if;
 source_start=source_day::timestamp at time zone zone;source_end=(source_day+7)::timestamp at time zone zone;target_start=target_day::timestamp at time zone zone;target_end=(target_day+7)::timestamp at time zone zone;
 perform pg_advisory_xact_lock(hashtextextended('clinic:'||p_clinic::text,0));perform pg_advisory_xact_lock(hashtextextended(own::text,0));schedule=public.admin_schedule_get(p_actor,p_clinic,own);
 select coalesce(range_agg(tstzrange((d::date+s.starts_at) at time zone zone,(d::date+s.ends_at) at time zone zone,'[)')),'{}'::tstzmultirange) into base from generate_series(source_day::timestamp,(source_day+6)::timestamp,interval '1 day') d join public.doctor_schedules s on s.clinic_id=p_clinic and s.doctor_id=own and s.weekday=extract(dow from d)::int;
 select coalesce(range_agg(tstzrange((d::date+(br->>'start')::time) at time zone zone,(d::date+(br->>'end')::time) at time zone zone,'[)')),'{}'::tstzmultirange) into blocked from generate_series(source_day::timestamp,(source_day+6)::timestamp,interval '1 day') d join public.doctor_schedules s on s.clinic_id=p_clinic and s.doctor_id=own and s.weekday=extract(dow from d)::int cross join lateral jsonb_array_elements(s.breaks) br;
 base=base-blocked;
 select coalesce(range_agg(tstzrange(starts_at,ends_at,'[)')*tstzrange(source_start,source_end,'[)')),'{}'::tstzmultirange) into opened from public.schedule_exceptions where clinic_id=p_clinic and doctor_id=own and available and starts_at<source_end and ends_at>source_start;
 select coalesce(range_agg(tstzrange(starts_at,ends_at,'[)')*tstzrange(source_start,source_end,'[)')),'{}'::tstzmultirange) into blocked from public.schedule_exceptions where clinic_id=p_clinic and doctor_id=own and not available and starts_at<source_end and ends_at>source_start;
 desired=(base+opened)-blocked;mapped='{}'::tstzmultirange;
 for period in select unnest(desired) loop mapped=mapped+tstzmultirange(tstzrange(((lower(period) at time zone zone)+make_interval(days=>shift_days)) at time zone zone,((upper(period) at time zone zone)+make_interval(days=>shift_days)) at time zone zone,'[)'));end loop;
 for period in select unnest(mapped) loop exceptions=exceptions||jsonb_build_array(jsonb_build_object('starts_at',lower(period),'ends_at',upper(period),'available',true));end loop;
 for period in select unnest(tstzmultirange(tstzrange(target_start,target_end,'[)'))-mapped) loop exceptions=exceptions||jsonb_build_array(jsonb_build_object('starts_at',lower(period),'ends_at',upper(period),'available',false));end loop;
 -- Retain parts of existing exceptions outside the target week, including crossing intervals.
 for period in select part from public.schedule_exceptions e cross join lateral unnest(tstzmultirange(tstzrange(e.starts_at,e.ends_at,'[)'))-tstzmultirange(tstzrange(target_start,target_end,'[)'))) part where e.clinic_id=p_clinic and e.doctor_id=own and e.ends_at>now() and not e.available loop exceptions=exceptions||jsonb_build_array(jsonb_build_object('starts_at',lower(period),'ends_at',upper(period),'available',false));end loop;
 for period in select part from public.schedule_exceptions e cross join lateral unnest(tstzmultirange(tstzrange(e.starts_at,e.ends_at,'[)'))-tstzmultirange(tstzrange(target_start,target_end,'[)'))) part where e.clinic_id=p_clinic and e.doctor_id=own and e.ends_at>now() and e.available loop exceptions=exceptions||jsonb_build_array(jsonb_build_object('starts_at',lower(period),'ends_at',upper(period),'available',true));end loop;
 if jsonb_array_length(exceptions)>400 then raise exception 'VALIDATION_ERROR';end if;
 return public.doctor_schedule_save(p_actor,p_clinic,jsonb_build_object('weekly',schedule->'weekly','exceptions',exceptions));
end$$;

-- No browser role receives new table/RPC privileges.
revoke all on function public.booking_policy(uuid),public.admin_booking_policy(uuid,uuid,jsonb),public.finish_attendance(),public.appointment_attendance(uuid,uuid,uuid,text,timestamptz,boolean),public.clinic_queue(uuid,uuid,date,boolean),public.patient_change(uuid,uuid,uuid,timestamptz,timestamptz),public.notify_patient(uuid,uuid,text,text,uuid,jsonb),public.appointment_patient_notice(),public.notification_event(),public.patient_read_notification(uuid,uuid,uuid),public.patient_waitlist(uuid,uuid,jsonb),public.process_patient_jobs(),public.next_available(uuid,uuid,uuid,date,int),public.doctor_block_period(uuid,uuid,timestamptz,timestamptz),public.doctor_copy_week(uuid,uuid,date,date) from public,anon,authenticated;
grant execute on function public.booking_policy(uuid),public.admin_booking_policy(uuid,uuid,jsonb),public.appointment_attendance(uuid,uuid,uuid,text,timestamptz,boolean),public.clinic_queue(uuid,uuid,date,boolean),public.patient_change(uuid,uuid,uuid,timestamptz,timestamptz),public.patient_read_notification(uuid,uuid,uuid),public.patient_waitlist(uuid,uuid,jsonb),public.process_patient_jobs(),public.next_available(uuid,uuid,uuid,date,int),public.doctor_block_period(uuid,uuid,timestamptz,timestamptz),public.doctor_copy_week(uuid,uuid,date,date) to service_role;
