begin;
set local search_path=public,extensions;
create or replace view public.catalog_doctors with(security_invoker=true) as
 select d.id,dc.clinic_id,coalesce(dc.name_override,d.name) as name,coalesce(dc.photo_url,d.photo_url) as photo_url,dc.description,dc.professional_title,dc.experience_years,dc.education,dc.biography,dc.qualifications,
 coalesce(dc.languages,d.languages) as languages,dc.featured,dc.sort_order,
 coalesce(dc.name_override,d.name)->>'ru' as name_ru,coalesce(dc.name_override,d.name)->>'en' as name_en,(coalesce(dc.name_override,d.name)->>'ru')||' '||(coalesce(dc.name_override,d.name)->>'en') as search_text,
 coalesce((select jsonb_agg(jsonb_build_object('id',s.id,'name',s.name) order by s.sort_order,s.id) from public.doctor_specialties ds join public.specialties s on s.clinic_id=ds.clinic_id and s.id=ds.specialty_id and s.active where ds.clinic_id=dc.clinic_id and ds.doctor_id=d.id),'[]') as specialties,
 coalesce((select array_agg(s.id) from public.doctor_specialties ds join public.specialties s on s.clinic_id=ds.clinic_id and s.id=ds.specialty_id and s.active where ds.clinic_id=dc.clinic_id and ds.doctor_id=d.id),array[]::uuid[]) as specialty_ids,
 coalesce((select array_agg(s.id) from public.doctor_services ds join public.catalog_services s on s.clinic_id=ds.clinic_id and s.id=ds.service_id where ds.clinic_id=dc.clinic_id and ds.doctor_id=d.id and ds.active),array[]::uuid[]) as service_ids,
 (select min(s.price_rub) from public.doctor_services ds join public.catalog_services s on s.clinic_id=ds.clinic_id and s.id=ds.service_id where ds.clinic_id=dc.clinic_id and ds.doctor_id=d.id and ds.active) as starting_price_rub
 from public.doctor_clinics dc join public.doctors d on d.id=dc.doctor_id join public.clinics c on c.id=dc.clinic_id and c.active where dc.active;
create or replace view public.catalog_services with(security_invoker=true) as
 select s.id,s.clinic_id,s.specialty_id,s.name,s.description,s.price_rub,s.duration_minutes,s.category_key,s.category,s.featured,s.sort_order,
 sp.name as specialty_name,s.name->>'ru' as name_ru,s.name->>'en' as name_en,(s.name->>'ru')||' '||(s.name->>'en') as search_text,
 coalesce((select array_agg(ds.doctor_id) from public.doctor_services ds join public.doctor_clinics dc on dc.clinic_id=ds.clinic_id and dc.doctor_id=ds.doctor_id and dc.active where ds.clinic_id=s.clinic_id and ds.service_id=s.id and ds.active),array[]::uuid[]) as doctor_ids
 from public.services s join public.specialties sp on sp.clinic_id=s.clinic_id and sp.id=s.specialty_id and sp.active join public.clinics c on c.id=s.clinic_id and c.active where s.active;
create view public.admin_doctors with(security_invoker=true) as
 select d.id,dc.clinic_id,coalesce(dc.name_override,d.name) as name,coalesce(dc.photo_url,d.photo_url) as photo_url,dc.description,dc.professional_title,dc.experience_years,dc.education,dc.biography,dc.qualifications,coalesce(dc.languages,d.languages) as languages,dc.featured,dc.sort_order,dc.active,
 coalesce((select jsonb_agg(jsonb_build_object('id',s.id,'name',s.name)) from public.doctor_specialties ds join public.specialties s on s.id=ds.specialty_id and s.clinic_id=ds.clinic_id where ds.clinic_id=dc.clinic_id and ds.doctor_id=d.id),'[]') as specialties,
 coalesce((select jsonb_agg(specialty_id) from public.doctor_specialties ds where ds.clinic_id=dc.clinic_id and ds.doctor_id=d.id),'[]') as specialty_ids,
 coalesce((select jsonb_agg(service_id) from public.doctor_services ds where ds.clinic_id=dc.clinic_id and ds.doctor_id=d.id and ds.active),'[]') as service_ids,
 (select min(s.price_rub) from public.doctor_services ds join public.services s on s.id=ds.service_id and s.clinic_id=ds.clinic_id where ds.clinic_id=dc.clinic_id and ds.doctor_id=d.id and ds.active and s.active) as starting_price_rub,
 (coalesce(dc.name_override,d.name)->>'ru')||' '||(coalesce(dc.name_override,d.name)->>'en') as search_text,dc.updated_at,dc.created_at
 from public.doctor_clinics dc join public.doctors d on d.id=dc.doctor_id;
create view public.admin_appointments with(security_invoker=true) as
 select a.*,p.full_name as patient_name,p.phone as patient_phone,coalesce(dc.name_override,d.name) as doctor_name,s.name as service_name,sp.id as specialty_id,sp.name as specialty_name,
 p.full_name||' '||coalesce(p.phone,'')||' '||a.id::text as search_text
 from public.appointments a join public.patient_profiles p on p.id=a.patient_id join public.doctors d on d.id=a.doctor_id join public.doctor_clinics dc on dc.clinic_id=a.clinic_id and dc.doctor_id=a.doctor_id join public.services s on s.id=a.service_id and s.clinic_id=a.clinic_id join public.specialties sp on sp.id=s.specialty_id and sp.clinic_id=a.clinic_id;
create view public.admin_patients with(security_invoker=true) as
 select cm.clinic_id,p.id,p.full_name,p.phone,p.email,p.language,cm.created_at,p.updated_at,
 p.full_name||' '||coalesce(p.phone,'')||' '||coalesce(p.email,'') as search_text,
 (select count(*) from public.appointments a where a.patient_id=p.id and a.clinic_id=cm.clinic_id) as appointment_count
 from public.clinic_memberships cm join public.patient_profiles p on p.id=cm.user_id;
revoke all on public.admin_doctors,public.admin_appointments,public.admin_patients from public,anon,authenticated;
grant select on public.admin_doctors,public.admin_appointments,public.admin_patients to service_role;

create function public.admin_list(p_actor uuid,p_clinic uuid,p_resource text,p_query jsonb default '{}') returns jsonb
language plpgsql security definer set search_path='' as $$
declare own uuid;sql_text text;view_name text;result jsonb;rows_json jsonb;total bigint;page_no integer=coalesce((p_query->>'page')::integer,1);page_limit integer=coalesce((p_query->>'limit')::integer,20);condition text;search text;ordering text;
begin
 own=public.admin_access(p_actor,p_clinic,case p_resource when 'appointments' then array['CLINIC_ADMIN','RECEPTIONIST','DOCTOR'] when 'patients' then array['CLINIC_ADMIN','RECEPTIONIST'] when 'schedules' then array['CLINIC_ADMIN','DOCTOR'] else array['CLINIC_ADMIN'] end);
 if page_no<1 or page_no>1000 or page_limit<1 or page_limit>100 then raise exception 'VALIDATION_ERROR';end if;
 view_name=case p_resource when 'doctors' then 'admin_doctors' when 'appointments' then 'admin_appointments' when 'patients' then 'admin_patients' when 'specialties' then 'specialties' when 'services' then 'services' when 'promotions' then 'promotions' when 'schedules' then 'doctor_schedules' when 'staff' then 'staff_memberships' else null end;
 if view_name is null then raise exception 'VALIDATION_ERROR';end if;
 if p_resource='staff' then perform public.admin_access(p_actor,p_clinic,array[]::text[]);end if;
 condition=format('clinic_id=%L::uuid',p_clinic);
 if own is not null then condition=condition||format(' and doctor_id=%L::uuid',own);end if;
 if p_query ? 'id' then condition=condition||format(' and id=%L::uuid',p_query->>'id');end if;
 search=p_query->>'search';
 if coalesce(search,'')<>'' then
  condition=condition||format(' and %s ilike %L',case when p_resource in ('doctors','appointments','patients') then 'search_text' when p_resource='promotions' then '(title->>''ru'')||'' ''||(title->>''en'')' else '(name->>''ru'')||'' ''||(name->>''en'')' end,'%'||replace(replace(replace(search,'\','\\'),'%','\%'),'_','\_')||'%');
 end if;
 if p_resource='appointments' then
  if p_query ? 'status' then condition=condition||format(' and status=%L',p_query->>'status');end if;
  if p_query ? 'from' then condition=condition||format(' and starts_at>=%L::timestamptz',p_query->>'from');end if;
  if p_query ? 'to' then condition=condition||format(' and starts_at<%L::timestamptz',p_query->>'to');end if;
  if p_query ? 'patient_id' then condition=condition||format(' and patient_id=%L::uuid',p_query->>'patient_id');end if;
 end if;
 if p_resource in ('appointments','schedules') and p_query ? 'doctor_id' then condition=condition||format(' and doctor_id=%L::uuid',p_query->>'doctor_id');end if;
 if p_resource in ('appointments','services') and p_query ? 'specialty_id' then condition=condition||format(' and specialty_id=%L::uuid',p_query->>'specialty_id');end if;
 if p_resource='appointments' and p_query ? 'service_id' then condition=condition||format(' and service_id=%L::uuid',p_query->>'service_id');end if;
 if p_resource in ('doctors','specialties','services','promotions') and p_query ? 'active' then condition=condition||format(' and active=%L::boolean',p_query->>'active');end if;
 ordering=case when p_resource='appointments' then case when p_query->>'sort'='oldest' then 'starts_at asc,id' else 'starts_at desc,id' end when p_resource='patients' then 'full_name,id' when p_resource='schedules' then 'doctor_id,weekday,starts_at,id' when p_resource='staff' then 'created_at,id' else 'sort_order,id' end;
 execute format('select count(*) from public.%I where %s',view_name,condition) into total;
 execute format('select coalesce(jsonb_agg(to_jsonb(row)-''search_text''),''[]'') from (select * from public.%I where %s order by %s limit %s offset %s) row',view_name,condition,ordering,page_limit,(page_no-1)*page_limit) into rows_json;
 result=jsonb_build_object('items',rows_json,'pagination',jsonb_build_object('page',page_no,'limit',page_limit,'total',total,'hasMore',page_no*page_limit<total));
 return result;
end$$;

create function public.admin_dashboard(p_actor uuid,p_clinic uuid,p_from date,p_to date) returns jsonb
language plpgsql security definer set search_path='' as $$
declare own uuid;zone text;result jsonb;start_time timestamptz;end_time timestamptz;today_start timestamptz;
begin
 own=public.admin_access(p_actor,p_clinic,array['CLINIC_ADMIN','RECEPTIONIST','DOCTOR']);
 if p_to<p_from or p_to-p_from>366 then raise exception 'VALIDATION_ERROR';end if;
 select timezone into zone from public.clinics where id=p_clinic;if not found then raise exception 'NOT_FOUND';end if;
 start_time=p_from::timestamp at time zone zone;end_time=(p_to+1)::timestamp at time zone zone;today_start=((now() at time zone zone)::date)::timestamp at time zone zone;
 with scoped as(select * from public.admin_appointments where clinic_id=p_clinic and (own is null or doctor_id=own)),ranged as(select * from scoped where starts_at>=start_time and starts_at<end_time)
 select jsonb_build_object('timezone',zone,'kpis',jsonb_build_object(
 'today',(select count(*) from scoped where starts_at>=today_start and starts_at<(((now() at time zone zone)::date+1)::timestamp at time zone zone)),
 'upcoming',(select count(*) from scoped where starts_at>now() and status in ('pending','confirmed')),
 'pending',(select count(*) from ranged where status='pending'),'confirmed',(select count(*) from ranged where status='confirmed'),
 'completed',(select count(*) from ranged where status='completed'),'cancelled',(select count(*) from ranged where status='cancelled'),
 'doctors',(select count(*) from public.doctor_clinics where clinic_id=p_clinic and active and (own is null or doctor_id=own)),
 'patients',case when own is null then (select count(*) from public.clinic_memberships where clinic_id=p_clinic) else (select count(distinct patient_id) from scoped) end),
 'daily',(select coalesce(jsonb_agg(x order by x.day),'[]') from(select (starts_at at time zone zone)::date as day,count(*) as count from ranged group by 1)x),
 'monthly',(select coalesce(jsonb_agg(x order by x.month),'[]') from(select to_char(starts_at at time zone zone,'YYYY-MM') as month,count(*) as count from ranged group by 1)x),
 'statuses',(select coalesce(jsonb_agg(x),'[]') from(select status,count(*) as count from ranged group by 1)x),
 'specialties',(select coalesce(jsonb_agg(x),'[]') from(select specialty_id,specialty_name as name,count(*) as count from ranged group by 1,2 order by count(*) desc limit 8)x),
 'services',(select coalesce(jsonb_agg(x),'[]') from(select service_id,service_name as name,count(*) as count from ranged group by 1,2 order by count(*) desc limit 8)x),
 'workload',(select coalesce(jsonb_agg(x),'[]') from(select doctor_id,doctor_name as name,count(*) as count from ranged group by 1,2 order by count(*) desc limit 20)x),
 'today',(select coalesce(jsonb_agg(to_jsonb(x)-'search_text'),'[]') from(select * from scoped where starts_at>=today_start and starts_at<(((now() at time zone zone)::date+1)::timestamp at time zone zone) order by starts_at limit 8)x),
 'recent',(select coalesce(jsonb_agg(to_jsonb(x)-'search_text'),'[]') from(select * from scoped order by created_at desc limit 8)x),
 'upcoming',(select coalesce(jsonb_agg(to_jsonb(x)-'search_text'),'[]') from(select * from scoped where starts_at>now() and status in ('pending','confirmed') order by starts_at limit 8)x)) into result;
 return result;
end$$;

create function public.admin_detail(p_actor uuid,p_clinic uuid,p_resource text,p_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare page jsonb;row_data jsonb;
begin
 page=public.admin_list(p_actor,p_clinic,p_resource,jsonb_build_object('id',p_id));row_data=page->'items'->0;if row_data is null then raise exception 'NOT_FOUND';end if;
 if p_resource='appointments' then
  row_data=row_data||jsonb_build_object('history',(select coalesce(jsonb_agg(to_jsonb(h) order by h.created_at),'[]') from public.appointment_status_history h where h.clinic_id=p_clinic and h.appointment_id=p_id),'audit',(select coalesce(jsonb_agg(jsonb_build_object('action',action,'created_at',created_at,'metadata',metadata) order by created_at),'[]') from public.audit_logs where clinic_id=p_clinic and resource_id=p_id));
 elsif p_resource='specialties' then
  row_data=row_data||jsonb_build_object('doctor_ids',(select coalesce(jsonb_agg(doctor_id),'[]') from public.doctor_specialties where clinic_id=p_clinic and specialty_id=p_id));
 elsif p_resource='services' then
  row_data=row_data||jsonb_build_object('doctor_ids',(select coalesce(jsonb_agg(doctor_id),'[]') from public.doctor_services where clinic_id=p_clinic and service_id=p_id and active));
 elsif p_resource='patients' then
  row_data=row_data||jsonb_build_object('appointments',public.admin_list(p_actor,p_clinic,'appointments',jsonb_build_object('patient_id',p_id,'limit',20)));
 end if;
 return row_data;
end$$;

create function public.admin_write(p_actor uuid,p_clinic uuid,p_resource text,p_id uuid,p_input jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare table_name text;columns_text text;select_text text;changes_text text;data jsonb=p_input;result jsonb;doctor uuid;key text;related uuid;
begin
 perform public.admin_access(p_actor,p_clinic,array['CLINIC_ADMIN']);
 perform pg_advisory_xact_lock(hashtextextended('clinic:'||p_clinic::text,0));
 if not exists(select 1 from public.clinics where id=p_clinic) then raise exception 'NOT_FOUND';end if;
 if p_resource='doctors' then
  doctor=p_id;
  if doctor is null then
   doctor=(p_input->>'doctor_id')::uuid;
   if doctor is not null then perform public.admin_access(p_actor,p_clinic,array[]::text[]);if not exists(select 1 from public.doctors where id=doctor) then raise exception 'NOT_FOUND';end if;
   else insert into public.doctors(name) values(data->'name') returning id into doctor;end if;
   insert into public.doctor_clinics(clinic_id,doctor_id) values(p_clinic,doctor);
  end if;
  perform pg_advisory_xact_lock(hashtextextended(doctor::text,0));
  if not exists(select 1 from public.doctor_clinics where clinic_id=p_clinic and doctor_id=doctor) then raise exception 'NOT_FOUND';end if;
  data=data-'doctor_id'-'specialty_ids'-'service_ids';
  if data ? 'name' then data=(data-'name')||jsonb_build_object('name_override',data->'name');end if;
  table_name='doctor_clinics';p_id=doctor;
 elsif p_resource in ('specialties','services','promotions') then
  if p_resource='services' then
   for doctor in select distinct d from (select doctor_id as d from public.doctor_services where clinic_id=p_clinic and service_id=p_id union select jsonb_array_elements_text(coalesce(p_input->'doctor_ids','[]'))::uuid as d)x order by d loop perform pg_advisory_xact_lock(hashtextextended(doctor::text,0));end loop;
  end if;
  table_name=p_resource;data=data-'doctor_ids';
 else raise exception 'VALIDATION_ERROR';end if;
 -- Keys are allow-listed again at the transaction boundary.
 for key in select jsonb_object_keys(data) loop
  if not key=any(case p_resource when 'doctors' then array['name_override','photo_url','description','professional_title','experience_years','education','biography','qualifications','languages','featured','sort_order','active'] when 'specialties' then array['name','description','icon','active','sort_order'] when 'services' then array['name','description','specialty_id','duration_minutes','price_rub','active','featured','sort_order','category_key','category'] else array['title','description','image_url','starts_at','ends_at','sort_order','active','action_kind'] end) then raise exception 'VALIDATION_ERROR';end if;
 end loop;
 select string_agg(format('%I',k),','),string_agg(format('r.%I',k),','),string_agg(format('%I=r.%I',k,k),',') into columns_text,select_text,changes_text from jsonb_object_keys(data) k;
 if p_id is null then
  execute format('insert into public.%I(%s,clinic_id) select %s,$2 from jsonb_populate_record(null::public.%I,$1) r returning to_jsonb(%I.*)',table_name,columns_text,select_text,table_name,table_name) using data,p_clinic into result;
  p_id=(result->>'id')::uuid;
 else
  if changes_text is not null then
   execute format('update public.%I t set %s from jsonb_populate_record(null::public.%I,$1) r where t.clinic_id=$2 and t.%I=$3 returning to_jsonb(t)',table_name,changes_text,table_name,case when p_resource='doctors' then 'doctor_id' else 'id' end) using data,p_clinic,p_id into result;
   if result is null then raise exception 'NOT_FOUND';end if;
  else execute format('select to_jsonb(t) from public.%I t where clinic_id=$1 and %I=$2',table_name,case when p_resource='doctors' then 'doctor_id' else 'id' end) using p_clinic,p_id into result;if result is null then raise exception 'NOT_FOUND';end if;end if;
 end if;
 if p_resource='doctors' then
  if p_input ? 'specialty_ids' then
   delete from public.doctor_specialties where clinic_id=p_clinic and doctor_id=doctor;
   for related in select jsonb_array_elements_text(p_input->'specialty_ids')::uuid loop insert into public.doctor_specialties(clinic_id,doctor_id,specialty_id) values(p_clinic,doctor,related);end loop;
  end if;
  if p_input ? 'service_ids' then
   update public.doctor_services set active=false where clinic_id=p_clinic and doctor_id=doctor;
   for related in select jsonb_array_elements_text(p_input->'service_ids')::uuid loop insert into public.doctor_services(clinic_id,doctor_id,service_id,active) values(p_clinic,doctor,related,true) on conflict(clinic_id,doctor_id,service_id) do update set active=true;end loop;
  end if;
 elsif p_resource in ('services','specialties') and p_input ? 'doctor_ids' then
  if p_resource='services' then
   update public.doctor_services set active=false where clinic_id=p_clinic and service_id=p_id;
   for doctor in select jsonb_array_elements_text(p_input->'doctor_ids')::uuid loop
    insert into public.doctor_services(clinic_id,doctor_id,service_id,active) values(p_clinic,doctor,p_id,true) on conflict(clinic_id,doctor_id,service_id) do update set active=true;
   end loop;
  else
   delete from public.doctor_specialties where clinic_id=p_clinic and specialty_id=p_id;
   for doctor in select jsonb_array_elements_text(p_input->'doctor_ids')::uuid loop insert into public.doctor_specialties(clinic_id,doctor_id,specialty_id) values(p_clinic,doctor,p_id);end loop;
  end if;
 end if;
 insert into public.audit_logs(clinic_id,actor_id,action,resource_id) values(p_clinic,p_actor,p_resource||'.saved',p_id);
 return jsonb_build_object('id',p_id,'clinic_id',p_clinic);
end$$;

create function public.admin_schedule_save(p_actor uuid,p_clinic uuid,p_doctor uuid,p_input jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare shift jsonb;ex jsonb;conflicts uuid[];zone text;
begin
 perform public.admin_access(p_actor,p_clinic,array['CLINIC_ADMIN']);
 perform pg_advisory_xact_lock(hashtextextended('clinic:'||p_clinic::text,0));
 perform pg_advisory_xact_lock(hashtextextended(p_doctor::text,0));
 if not exists(select 1 from public.doctor_clinics where clinic_id=p_clinic and doctor_id=p_doctor) then raise exception 'NOT_FOUND';end if;
 select timezone into zone from public.clinics where id=p_clinic;
 select array_agg(a.id) into conflicts from public.appointments a where a.clinic_id=p_clinic and a.doctor_id=p_doctor and a.starts_at>now() and a.status in ('pending','confirmed') and (
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
create function public.admin_schedule_get(p_actor uuid,p_clinic uuid,p_doctor uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare own uuid;
begin
 own=public.admin_access(p_actor,p_clinic,array['CLINIC_ADMIN','DOCTOR']);if own is not null and own<>p_doctor then raise exception 'FORBIDDEN';end if;
 if not exists(select 1 from public.doctor_clinics where clinic_id=p_clinic and doctor_id=p_doctor) then raise exception 'NOT_FOUND';end if;
 return jsonb_build_object('weekly',(select coalesce(jsonb_agg(to_jsonb(s) order by weekday,starts_at),'[]') from public.doctor_schedules s where clinic_id=p_clinic and doctor_id=p_doctor),'exceptions',(select coalesce(jsonb_agg(to_jsonb(e) order by starts_at),'[]') from public.schedule_exceptions e where clinic_id=p_clinic and doctor_id=p_doctor and ends_at>now()));
end$$;
create function public.admin_settings(p_actor uuid,p_clinic uuid,p_input jsonb default null) returns jsonb
language plpgsql security definer set search_path='' as $$
declare result jsonb;key text;changes text;data jsonb;
begin
 perform public.admin_access(p_actor,p_clinic,array['CLINIC_ADMIN']);
 perform pg_advisory_xact_lock(hashtextextended('clinic:'||p_clinic::text,0));
 if p_input is not null then
  if p_input ? 'active' then perform public.admin_access(p_actor,p_clinic,array[]::text[]);end if;
  if p_input ? 'timezone' and (p_input->>'timezone') is distinct from (select timezone from public.clinics where id=p_clinic) and exists(select 1 from public.appointments where clinic_id=p_clinic and ends_at>now() and status in ('pending','confirmed')) then raise exception 'SCHEDULE_CONFLICT';end if;
  if p_input ? 'timezone' and not exists(select 1 from pg_timezone_names where name=p_input->>'timezone') then raise exception 'VALIDATION_ERROR';end if;
  data=p_input-'booking';
  for key in select jsonb_object_keys(data) loop if not key=any(array['name','description','address','phone','email','website','timezone','logo_url','image_url','working_hours','active']) then raise exception 'VALIDATION_ERROR';end if;end loop;
  select string_agg(format('%I=r.%I',k,k),',') into changes from jsonb_object_keys(data) k;
  if changes is not null then execute format('update public.clinics c set %s from jsonb_populate_record(null::public.clinics,$1) r where c.id=$2',changes) using data,p_clinic;end if;
  if p_input ? 'booking' then
   insert into public.clinic_settings(clinic_id,configuration) values(p_clinic,jsonb_build_object('booking',p_input->'booking')) on conflict(clinic_id) do update set configuration=public.clinic_settings.configuration||excluded.configuration;
  end if;
  insert into public.audit_logs(clinic_id,actor_id,action,resource_id) values(p_clinic,p_actor,'clinic.settings_changed',p_clinic);
 end if;
 select to_jsonb(c)||jsonb_build_object('booking',coalesce(cs.configuration->'booking','{"slot_step_minutes":15}')) into result from public.clinics c left join public.clinic_settings cs on cs.clinic_id=c.id where c.id=p_clinic;
 if result is null then raise exception 'NOT_FOUND';end if;return result;
end$$;
create function public.admin_patient_link(p_actor uuid,p_clinic uuid,p_user uuid,p_input jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
begin
 perform public.admin_access(p_actor,p_clinic,array['CLINIC_ADMIN','RECEPTIONIST']);
 if not exists(select 1 from auth.users where id=p_user) then raise exception 'NOT_FOUND';end if;
 if exists(select 1 from public.patient_profiles where id=p_user) and not exists(select 1 from public.clinic_memberships where user_id=p_user and clinic_id=p_clinic) and not exists(select 1 from public.staff_memberships where user_id=p_actor and role='SUPER_ADMIN' and active) then raise exception 'FORBIDDEN';end if;
 insert into public.patient_profiles(id,full_name,email,phone,language) values(p_user,p_input->>'full_name',p_input->>'email',p_input->>'phone',coalesce(p_input->>'language','ru')) on conflict(id) do nothing;
 insert into public.clinic_memberships(clinic_id,user_id) values(p_clinic,p_user) on conflict do nothing;
 insert into public.audit_logs(clinic_id,actor_id,action,resource_id) values(p_clinic,p_actor,'patient.linked',p_user);
 return jsonb_build_object('id',p_user,'clinic_id',p_clinic);
end$$;
create function public.admin_staff_save(p_actor uuid,p_clinic uuid,p_user uuid,p_input jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare result public.staff_memberships;
begin
 perform public.admin_access(p_actor,p_clinic,array[]::text[]);
 if p_actor=p_user then raise exception 'FORBIDDEN';end if;
 if p_input->>'role' not in ('CLINIC_ADMIN','RECEPTIONIST','DOCTOR') then raise exception 'VALIDATION_ERROR';end if;
 insert into public.staff_memberships(user_id,clinic_id,role,doctor_id,active) values(p_user,p_clinic,p_input->>'role',(p_input->>'doctor_id')::uuid,coalesce((p_input->>'active')::boolean,true)) on conflict(user_id,clinic_id,role) do update set active=excluded.active,doctor_id=excluded.doctor_id returning * into result;
 insert into public.audit_logs(clinic_id,actor_id,action,resource_id,metadata) values(p_clinic,p_actor,'staff.assignment_changed',result.id,jsonb_build_object('role',result.role,'active',result.active));
 return to_jsonb(result);
end$$;
create function public.admin_options(p_actor uuid,p_clinic uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare own uuid;
begin
 own=public.admin_access(p_actor,p_clinic,array['CLINIC_ADMIN','RECEPTIONIST','DOCTOR']);
 return jsonb_build_object('doctors',(select coalesce(jsonb_agg(to_jsonb(x)),'[]') from(select id,name,specialties from public.catalog_doctors where clinic_id=p_clinic and (own is null or id=own) order by sort_order,id limit 100)x),'services',(select coalesce(jsonb_agg(to_jsonb(x)),'[]') from(select id,name,specialty_id,price_rub,duration_minutes,doctor_ids from public.catalog_services where clinic_id=p_clinic and (own is null or own=any(doctor_ids)) order by sort_order,id limit 100)x),'specialties',(select coalesce(jsonb_agg(to_jsonb(x)),'[]') from(select id,name from public.catalog_specialties where clinic_id=p_clinic order by sort_order,id limit 100)x));
end$$;
create function public.admin_calendar(p_actor uuid,p_clinic uuid,p_from timestamptz,p_to timestamptz,p_doctor uuid default null) returns jsonb
language plpgsql security definer set search_path='' as $$
declare own uuid;result jsonb;
begin
 own=public.admin_access(p_actor,p_clinic,array['CLINIC_ADMIN','RECEPTIONIST','DOCTOR']);
 if p_to<=p_from or p_to-p_from>interval '43 days' then raise exception 'VALIDATION_ERROR';end if;
 with rows as(select id,doctor_id,doctor_name,patient_name,service_name,starts_at,ends_at,status from public.admin_appointments where clinic_id=p_clinic and starts_at>=p_from and starts_at<p_to and (own is null or doctor_id=own) and (p_doctor is null or doctor_id=p_doctor))
 select jsonb_build_object('items',(select coalesce(jsonb_agg(to_jsonb(x) order by starts_at),'[]') from(select * from rows order by starts_at,id limit 1000)x),'total',(select count(*) from rows),'truncated',(select count(*)>1000 from rows)) into result;
 return result;
end$$;
revoke all on function public.admin_calendar(uuid,uuid,timestamptz,timestamptz,uuid) from public,anon,authenticated;
grant execute on function public.admin_calendar(uuid,uuid,timestamptz,timestamptz,uuid) to service_role;
-- Public bucket contains only approved catalog artwork, never patient documents.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('clinic-catalog','clinic-catalog',true,5242880,array['image/jpeg','image/png','image/webp']) on conflict(id) do update set file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;

revoke all on function public.admin_list(uuid,uuid,text,jsonb),public.admin_detail(uuid,uuid,text,uuid),public.admin_dashboard(uuid,uuid,date,date),public.admin_write(uuid,uuid,text,uuid,jsonb),public.admin_schedule_save(uuid,uuid,uuid,jsonb),public.admin_schedule_get(uuid,uuid,uuid),public.admin_settings(uuid,uuid,jsonb),public.admin_patient_link(uuid,uuid,uuid,jsonb),public.admin_staff_save(uuid,uuid,uuid,jsonb),public.admin_options(uuid,uuid) from public,anon,authenticated;
grant execute on function public.admin_list(uuid,uuid,text,jsonb),public.admin_detail(uuid,uuid,text,uuid),public.admin_dashboard(uuid,uuid,date,date),public.admin_write(uuid,uuid,text,uuid,jsonb),public.admin_schedule_save(uuid,uuid,uuid,jsonb),public.admin_schedule_get(uuid,uuid,uuid),public.admin_settings(uuid,uuid,jsonb),public.admin_patient_link(uuid,uuid,uuid,jsonb),public.admin_staff_save(uuid,uuid,uuid,jsonb),public.admin_options(uuid,uuid) to service_role;
notify pgrst,'reload schema';
commit;
