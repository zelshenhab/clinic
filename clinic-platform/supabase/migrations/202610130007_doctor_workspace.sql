-- Doctor workspace operations derive identity from active, clinic-assigned staff rows.
create function public.doctor_identity(p_actor uuid,p_clinic uuid) returns uuid
language plpgsql security definer set search_path='' as $$
declare own uuid;
begin
 select m.doctor_id into own from public.staff_memberships m join public.doctor_clinics dc on dc.clinic_id=m.clinic_id and dc.doctor_id=m.doctor_id and dc.active where m.user_id=p_actor and m.clinic_id=p_clinic and m.role='DOCTOR' and m.active;
 if own is null then raise exception 'FORBIDDEN';end if;return own;
end$$;
create function public.validate_doctor_account() returns trigger language plpgsql set search_path='' as $$
begin
 if new.role='DOCTOR' and new.active then
 perform pg_advisory_xact_lock(hashtextextended('doctor-account:'||new.user_id::text,0));
 if not exists(select 1 from public.doctor_clinics where doctor_id=new.doctor_id and clinic_id=new.clinic_id and active) or exists(select 1 from public.staff_memberships where user_id=new.user_id and role='DOCTOR' and active and doctor_id<>new.doctor_id and id<>new.id) then raise exception 'VALIDATION_ERROR';end if;
 end if;return new;
end$$;
create trigger doctor_account_assignment before insert or update on public.staff_memberships for each row execute function public.validate_doctor_account();

create table public.doctor_change_requests(
 id uuid primary key default gen_random_uuid(),clinic_id uuid not null references public.clinics(id),doctor_id uuid not null,requested_by uuid not null references auth.users(id),
 baseline jsonb,
 kind text not null check(kind in ('schedule','day_off','vacation','reschedule')),payload jsonb not null,
 reason text not null check(length(reason) between 5 and 2000),status text not null default 'pending' check(status in ('pending','approved','rejected')),
 reviewed_by uuid references auth.users(id),review_note text check(length(review_note)<=2000),created_at timestamptz not null default now(),reviewed_at timestamptz,
 foreign key(clinic_id,doctor_id) references public.doctor_clinics(clinic_id,doctor_id),
 check((status='pending' and reviewed_by is null and reviewed_at is null) or (status<>'pending' and reviewed_by is not null and reviewed_at is not null))
);
create index doctor_request_scope on public.doctor_change_requests(clinic_id,doctor_id,status,created_at desc);
alter table public.doctor_change_requests enable row level security;
revoke all on public.doctor_change_requests from public,anon,authenticated;
grant select,insert,update on public.doctor_change_requests to service_role;

create function public.doctor_read(p_actor uuid,p_clinic uuid,p_resource text,p_query jsonb default '{}') returns jsonb
language plpgsql security definer set search_path='' as $$
declare own uuid;result jsonb;total integer;page integer=coalesce((p_query->>'page')::integer,1);lim integer=coalesce((p_query->>'limit')::integer,20);zone text;day_start timestamptz;day_end timestamptz;first_day date;last_day date;
begin
 own=public.doctor_identity(p_actor,p_clinic);
 if page<1 or page>100000 or lim<1 or lim>100 then raise exception 'VALIDATION_ERROR';end if;
 select timezone into zone from public.clinics where id=p_clinic;
 day_start=((now() at time zone zone)::date)::timestamp at time zone zone;day_end=(((now() at time zone zone)::date+1)::timestamp at time zone zone);
 if p_resource='me' then
 select to_jsonb(d)-'clinic_id' into result from public.admin_doctors d where d.clinic_id=p_clinic and d.id=own;
 return result||jsonb_build_object('clinic_id',p_clinic,'timezone',zone,'user_id',p_actor);
 elsif p_resource='schedule' then return public.admin_schedule_get(p_actor,p_clinic,own);
 elsif p_resource='options' then
 return jsonb_build_object('doctors',(select jsonb_agg(jsonb_build_object('id',id,'name',name)) from public.admin_doctors where clinic_id=p_clinic and id=own),'services',(select coalesce(jsonb_agg(jsonb_build_object('id',s.id,'name',s.name)),'[]') from public.services s where clinic_id=p_clinic and exists(select 1 from public.appointments a where a.clinic_id=p_clinic and a.doctor_id=own and a.service_id=s.id) or clinic_id=p_clinic and exists(select 1 from public.doctor_services ds where ds.clinic_id=p_clinic and ds.doctor_id=own and ds.service_id=s.id and ds.active)),'specialties','[]'::jsonb);
 elsif p_resource='dashboard' then
 first_day=coalesce((p_query->>'from')::date,(now() at time zone zone)::date);last_day=coalesce((p_query->>'to')::date,first_day+6);
 if last_day<first_day or last_day-first_day>366 then raise exception 'VALIDATION_ERROR';end if;
 with scoped as(select * from public.admin_appointments where clinic_id=p_clinic and doctor_id=own),ranged as(select * from scoped where starts_at>=first_day::timestamp at time zone zone and starts_at<(last_day+1)::timestamp at time zone zone)
 select jsonb_build_object('kpis',jsonb_build_object('today',(select count(*) from scoped where starts_at>=day_start and starts_at<day_end),'upcoming',(select count(*) from scoped where starts_at>now() and status in ('pending','confirmed')),'pending',(select count(*) from ranged where status='pending'),'confirmed',(select count(*) from ranged where status='confirmed'),'completed',(select count(*) from ranged where status='completed'),'cancelled',(select count(*) from ranged where status='cancelled'),'patients',(select count(distinct patient_id) from scoped)),
 'today',(select coalesce(jsonb_agg(to_jsonb(x)-'search_text'),'[]') from(select * from scoped where starts_at>=day_start and starts_at<day_end order by starts_at limit 100)x),
 'next',(select to_jsonb(x)-'search_text' from(select * from scoped where starts_at>now() and status in ('pending','confirmed') order by starts_at limit 1)x),
 'daily',(select coalesce(jsonb_agg(to_jsonb(x) order by day),'[]') from(select (starts_at at time zone zone)::date as day,count(*) as count from ranged group by 1)x),
 'statuses',(select coalesce(jsonb_agg(to_jsonb(x)),'[]') from(select status,count(*) as count from ranged group by 1)x)) into result;
 return result||jsonb_build_object('schedule',public.admin_schedule_get(p_actor,p_clinic,own),'from',first_day,'to',last_day);
 elsif p_resource='appointments' or p_resource='appointment' then
 with scoped as(select * from public.admin_appointments a where a.clinic_id=p_clinic and a.doctor_id=own
 and (not p_query ? 'id' or a.id=(p_query->>'id')::uuid) and (not p_query ? 'patient_id' or a.patient_id=(p_query->>'patient_id')::uuid)
 and (not p_query ? 'status' or a.status::text=p_query->>'status') and (not p_query ? 'service_id' or a.service_id=(p_query->>'service_id')::uuid)
 and (not p_query ? 'from' or a.starts_at>=(p_query->>'from')::timestamptz) and (not p_query ? 'to' or a.starts_at<(p_query->>'to')::timestamptz)
 and (coalesce(p_query->>'search','')='' or position(lower(p_query->>'search') in lower(a.patient_name||' '||a.id::text))>0))
 select count(*),(select coalesce(jsonb_agg(to_jsonb(x)-'search_text'),'[]') from(select * from scoped order by case when p_query->>'sort'='oldest' then starts_at end asc,case when coalesce(p_query->>'sort','newest')='newest' then starts_at end desc,id limit lim offset (page-1)*lim)x) into total,result from scoped;
 if p_resource='appointment' then
 result=result->0;if result is null then raise exception 'NOT_FOUND';end if;
 return result||jsonb_build_object('history',(select coalesce(jsonb_agg(jsonb_build_object('id',id,'status',status,'created_at',created_at) order by created_at),'[]') from public.appointment_status_history where appointment_id=(p_query->>'id')::uuid and clinic_id=p_clinic),'audit','[]'::jsonb);
 end if;
 elsif p_resource in ('patients','patient') then
 with scoped as(select a.patient_id id,p.full_name, count(*) appointment_count,max(a.starts_at) filter(where a.starts_at<=now()) last_appointment,min(a.starts_at) filter(where a.starts_at>now() and a.status in ('pending','confirmed')) next_appointment from public.appointments a join public.patient_profiles p on p.id=a.patient_id where a.clinic_id=p_clinic and a.doctor_id=own and (not p_query ? 'id' or a.patient_id=(p_query->>'id')::uuid) and (coalesce(p_query->>'search','')='' or position(lower(p_query->>'search') in lower(p.full_name))>0) group by a.patient_id,p.full_name)
 select count(*),(select coalesce(jsonb_agg(to_jsonb(x)),'[]') from(select * from scoped order by full_name,id limit lim offset(page-1)*lim)x) into total,result from scoped;
 if p_resource='patient' then result=result->0;if result is null then raise exception 'NOT_FOUND';end if;return result;end if;
 elsif p_resource='calendar' then
 if (p_query->>'to')::timestamptz<=(p_query->>'from')::timestamptz or (p_query->>'to')::timestamptz-(p_query->>'from')::timestamptz>interval '43 days' then raise exception 'VALIDATION_ERROR';end if;
 select count(*) into total from public.appointments where clinic_id=p_clinic and doctor_id=own and starts_at<(p_query->>'to')::timestamptz and ends_at>(p_query->>'from')::timestamptz;
 select coalesce(jsonb_agg(to_jsonb(x)),'[]') into result from(select id,doctor_id,patient_name,service_name,starts_at,ends_at,status from public.admin_appointments where clinic_id=p_clinic and doctor_id=own and starts_at<(p_query->>'to')::timestamptz and ends_at>(p_query->>'from')::timestamptz order by starts_at,id limit 1000)x;
 return jsonb_build_object('items',result,'total',total,'truncated',total>1000,'schedule',public.admin_schedule_get(p_actor,p_clinic,own));
 elsif p_resource='requests' then
 select count(*) into total from public.doctor_change_requests where clinic_id=p_clinic and doctor_id=own;
 select coalesce(jsonb_agg(to_jsonb(x)),'[]') into result from(select * from public.doctor_change_requests where clinic_id=p_clinic and doctor_id=own order by created_at desc,id limit lim offset(page-1)*lim)x;
 elsif p_resource='notifications' then
 with scoped as(select l.id,l.action,l.created_at,a.id appointment_id from public.audit_logs l join public.appointments a on a.id=l.resource_id and a.clinic_id=l.clinic_id where a.clinic_id=p_clinic and a.doctor_id=own and l.action in ('appointment.created','appointment.rescheduled','appointment.status_changed')
 union all select r.id,'request.'||r.status,r.reviewed_at,null::uuid from public.doctor_change_requests r where r.clinic_id=p_clinic and r.doctor_id=own and r.reviewed_at is not null)
 select count(*),(select coalesce(jsonb_agg(to_jsonb(x)),'[]') from(select * from scoped order by created_at desc,id limit lim offset(page-1)*lim)x) into total,result from scoped;
 else raise exception 'VALIDATION_ERROR';end if;
 return jsonb_build_object('items',result,'pagination',jsonb_build_object('page',page,'limit',lim,'total',total,'hasMore',page*lim<total));
end$$;

create function public.doctor_request(p_actor uuid,p_clinic uuid,p_kind text,p_payload jsonb,p_reason text) returns jsonb language plpgsql security definer set search_path='' as $$
declare own uuid;result public.doctor_change_requests;
begin
 own=public.doctor_identity(p_actor,p_clinic);
 if p_kind not in ('schedule','day_off','vacation','reschedule') or length(trim(p_reason))<5 or length(p_reason)>2000 then raise exception 'VALIDATION_ERROR';end if;
 if p_kind='reschedule' then
 if not exists(select 1 from public.appointments where id=(p_payload->>'appointment_id')::uuid and clinic_id=p_clinic and doctor_id=own and status in ('pending','confirmed') and starts_at>now() and updated_at=(p_payload->>'expected_updated_at')::timestamptz) then raise exception 'NOT_FOUND';end if;
 if (p_payload->>'starts_at')::timestamptz<=now() then raise exception 'VALIDATION_ERROR';end if;
 elsif p_kind in ('day_off','vacation') then
 if (p_payload->>'starts_at')::timestamptz<now() or (p_payload->>'ends_at')::timestamptz<=(p_payload->>'starts_at')::timestamptz then raise exception 'VALIDATION_ERROR';end if;
 end if;
 insert into public.doctor_change_requests(clinic_id,doctor_id,requested_by,kind,payload,reason,baseline) values(p_clinic,own,p_actor,p_kind,p_payload,trim(p_reason),case when p_kind='schedule' then public.admin_schedule_get(p_actor,p_clinic,own) else null end) returning * into result;
 insert into public.audit_logs(clinic_id,actor_id,action,resource_id) values(p_clinic,p_actor,'doctor.request_created',result.id);
 return to_jsonb(result);
end$$;
create function public.admin_doctor_requests(p_actor uuid,p_clinic uuid,p_query jsonb default '{}') returns jsonb language plpgsql security definer set search_path='' as $$
declare total integer;items jsonb;page integer=coalesce((p_query->>'page')::integer,1);lim integer=coalesce((p_query->>'limit')::integer,20);
begin
 perform public.admin_access(p_actor,p_clinic,array['CLINIC_ADMIN']);
 if page<1 or lim<1 or lim>100 then raise exception 'VALIDATION_ERROR';end if;
 select count(*) into total from public.doctor_change_requests where clinic_id=p_clinic and (not p_query ? 'status' or status=p_query->>'status');
 select coalesce(jsonb_agg(to_jsonb(x)),'[]') into items from(select r.*,d.name doctor_name from public.doctor_change_requests r join public.admin_doctors d on d.id=r.doctor_id and d.clinic_id=r.clinic_id where r.clinic_id=p_clinic and (not p_query ? 'status' or r.status=p_query->>'status') order by r.created_at desc,r.id limit lim offset(page-1)*lim)x;
 return jsonb_build_object('items',items,'pagination',jsonb_build_object('page',page,'limit',lim,'total',total,'hasMore',page*lim<total));
end$$;
create function public.admin_review_doctor_request(p_actor uuid,p_clinic uuid,p_id uuid,p_approve boolean,p_note text) returns jsonb language plpgsql security definer set search_path='' as $$
declare r public.doctor_change_requests;schedule jsonb;
begin
 perform public.admin_access(p_actor,p_clinic,array['CLINIC_ADMIN']);
 select * into r from public.doctor_change_requests where id=p_id and clinic_id=p_clinic for update;
 if not found then raise exception 'NOT_FOUND';end if;
 if r.status<>'pending' then raise exception 'STALE_APPOINTMENT';end if;
 if r.requested_by=p_actor then raise exception 'FORBIDDEN';end if;
 if length(p_note)>2000 then raise exception 'VALIDATION_ERROR';end if;
 if p_approve then
 perform public.doctor_identity(r.requested_by,p_clinic);
 perform pg_advisory_xact_lock(hashtextextended('clinic:'||p_clinic::text,0));
 perform pg_advisory_xact_lock(hashtextextended(r.doctor_id::text,0));
 if r.kind='schedule' and r.baseline is distinct from public.admin_schedule_get(p_actor,p_clinic,r.doctor_id) then raise exception 'STALE_APPOINTMENT';end if;
 if r.kind='reschedule' then perform public.admin_appointment_change(p_actor,p_clinic,(r.payload->>'appointment_id')::uuid,jsonb_build_object('starts_at',r.payload->>'starts_at','expected_updated_at',r.payload->>'expected_updated_at'));
 else
 if r.kind='schedule' then schedule=r.payload;
 else
 schedule=public.admin_schedule_get(p_actor,p_clinic,r.doctor_id);
 schedule=jsonb_build_object('weekly',schedule->'weekly','exceptions',(schedule->'exceptions')||jsonb_build_array(jsonb_build_object('starts_at',r.payload->>'starts_at','ends_at',r.payload->>'ends_at','available',false)));
 end if;
 perform public.admin_schedule_save(p_actor,p_clinic,r.doctor_id,schedule);
 end if;
 end if;
 update public.doctor_change_requests set status=case when p_approve then 'approved' else 'rejected' end,reviewed_by=p_actor,reviewed_at=now(),review_note=p_note where id=r.id returning * into r;
 insert into public.audit_logs(clinic_id,actor_id,action,resource_id,metadata) values(p_clinic,p_actor,'doctor.request_reviewed',p_id,jsonb_build_object('status',r.status));
 return to_jsonb(r);
end$$;
create function public.doctor_status(p_actor uuid,p_clinic uuid,p_id uuid,p_input jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare own uuid;
begin
 own=public.doctor_identity(p_actor,p_clinic);
 if p_input->>'status' not in ('completed','no_show') or p_input ? 'starts_at' then raise exception 'FORBIDDEN';end if;
 if not exists(select 1 from public.appointments where id=p_id and clinic_id=p_clinic and doctor_id=own) then raise exception 'NOT_FOUND';end if;
 return public.admin_appointment_change(p_actor,p_clinic,p_id,p_input);
end$$;
create function public.doctor_request_invalidation() returns trigger language plpgsql security definer set search_path='' as $$
declare recipient uuid;event jsonb;
begin
 event=jsonb_build_object('event_id',gen_random_uuid(),'clinic_id',new.clinic_id,'request_id',new.id);
 for recipient in select distinct user_id from public.staff_memberships where active and ((role='SUPER_ADMIN' and clinic_id is null) or (clinic_id=new.clinic_id and (role='CLINIC_ADMIN' or role='DOCTOR' and doctor_id=new.doctor_id))) loop
 perform realtime.send(event,'doctor_request_changed','staff:'||new.clinic_id::text||':'||recipient::text,true);
 end loop;return new;
end$$;
create trigger doctor_request_events after insert or update on public.doctor_change_requests for each row execute function public.doctor_request_invalidation();
revoke all on function public.doctor_identity(uuid,uuid),public.validate_doctor_account(),public.doctor_read(uuid,uuid,text,jsonb),public.doctor_request(uuid,uuid,text,jsonb,text),public.admin_doctor_requests(uuid,uuid,jsonb),public.admin_review_doctor_request(uuid,uuid,uuid,boolean,text),public.doctor_status(uuid,uuid,uuid,jsonb),public.doctor_request_invalidation() from public,anon,authenticated;
grant execute on function public.doctor_identity(uuid,uuid),public.doctor_read(uuid,uuid,text,jsonb),public.doctor_request(uuid,uuid,text,jsonb,text),public.admin_doctor_requests(uuid,uuid,jsonb),public.admin_review_doctor_request(uuid,uuid,uuid,boolean,text),public.doctor_status(uuid,uuid,uuid,jsonb) to service_role;
