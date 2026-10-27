-- Medical documents: staff and the patient's own doctor attach reports, lab results and imaging
-- to a patient (optionally an appointment or family member); the account holder reads them in the app.
-- Files live in a private bucket and are only reachable through short-lived signed URLs from the API.
alter table public.medical_records
 add column kind text not null default 'other' check(kind in ('report','lab_result','imaging','prescription','other')),
 add column title text not null default 'Document' check(length(trim(title)) between 1 and 200),
 add column family_member_id uuid,
 add column doctor_id uuid references public.doctors(id),
 add column file_name text not null default 'document' check(length(file_name) between 1 and 200),
 add column mime_type text not null default 'application/pdf' check(mime_type in ('application/pdf','image/jpeg','image/png')),
 add column size_bytes integer not null default 1 check(size_bytes between 1 and 10485760),
 add column uploaded_by uuid references auth.users on delete set null,
 add column deleted_at timestamptz,
 add unique(storage_path),
 add foreign key(family_member_id,patient_id) references public.family_members(id,owner_id);
alter table public.medical_records alter column kind drop default,alter column title drop default,alter column file_name drop default,alter column mime_type drop default,alter column size_bytes drop default;
create index medical_records_patient on public.medical_records(clinic_id,patient_id,created_at desc) where deleted_at is null;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('medical-records','medical-records',false,10485760,array['application/pdf','image/jpeg','image/png']) on conflict(id) do update set public=false,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;

create function public.medical_record_row(r public.medical_records) returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object('id',r.id,'clinic_id',r.clinic_id,'patient_id',r.patient_id,'appointment_id',r.appointment_id,'family_member_id',r.family_member_id,
  'family_member_name',(select fm.full_name from public.family_members fm where fm.id=r.family_member_id),
  'doctor_id',r.doctor_id,'doctor_name',(select coalesce(dc.name_override,d.name) from public.doctors d left join public.doctor_clinics dc on dc.doctor_id=d.id and dc.clinic_id=r.clinic_id where d.id=r.doctor_id),
  'kind',r.kind,'title',r.title,'file_name',r.file_name,'mime_type',r.mime_type,'size_bytes',r.size_bytes,'created_at',r.created_at)
$$;

-- Staff access: clinic administrators and receptionists for any clinic patient, doctors only for
-- patients they have an appointment with in this clinic.
create function public.medical_record_access(p_actor uuid,p_clinic uuid,p_patient uuid,p_doctor_only boolean) returns uuid language plpgsql security definer set search_path='' as $$
declare own uuid;
begin
 own=case when p_doctor_only then public.doctor_identity(p_actor,p_clinic) else public.admin_access(p_actor,p_clinic,array['CLINIC_ADMIN','RECEPTIONIST','DOCTOR']) end;
 if not exists(select 1 from public.clinic_memberships where clinic_id=p_clinic and user_id=p_patient) then raise exception 'NOT_FOUND';end if;
 if own is not null and not exists(select 1 from public.appointments where clinic_id=p_clinic and patient_id=p_patient and doctor_id=own) then raise exception 'FORBIDDEN';end if;
 return own;
end$$;

create function public.medical_record_save(p_actor uuid,p_clinic uuid,p_patient uuid,p_input jsonb,p_doctor_only boolean default false) returns jsonb language plpgsql security definer set search_path='' as $$
declare own uuid;r public.medical_records;appointment uuid=nullif(p_input->>'appointment_id','')::uuid;member uuid=nullif(p_input->>'family_member_id','')::uuid;author uuid;
begin
 own=public.medical_record_access(p_actor,p_clinic,p_patient,p_doctor_only);
 if appointment is not null then
  select family_member_id,doctor_id into member,author from public.appointments where id=appointment and clinic_id=p_clinic and patient_id=p_patient and (own is null or doctor_id=own);
  if not found then raise exception 'NOT_FOUND';end if;
 elsif member is not null and not exists(select 1 from public.family_members where id=member and owner_id=p_patient and active) then raise exception 'NOT_FOUND';
 end if;
 insert into public.medical_records(clinic_id,patient_id,appointment_id,family_member_id,doctor_id,kind,title,file_name,mime_type,size_bytes,storage_path,uploaded_by)
 values(p_clinic,p_patient,appointment,member,coalesce(own,author),p_input->>'kind',trim(p_input->>'title'),p_input->>'file_name',p_input->>'mime_type',(p_input->>'size_bytes')::int,p_input->>'storage_path',p_actor) returning * into r;
 insert into public.audit_logs(clinic_id,actor_id,action,resource_id) values(p_clinic,p_actor,'medical_record.created',r.id);
 insert into public.notifications(clinic_id,user_id,title,body,kind,event_key,context) values(p_clinic,p_patient,
  '{"ru":"Новый медицинский документ","en":"New medical document"}'::jsonb,
  jsonb_build_object('ru','Документ «'||r.title||'» доступен в разделе «Медицинские документы».','en','“'||r.title||'” is available in Medical documents.'),
  'document','record:'||r.id::text,jsonb_build_object('record_id',r.id));
 return public.medical_record_row(r);
end$$;

create function public.medical_record_list(p_actor uuid,p_clinic uuid,p_patient uuid,p_doctor_only boolean default false) returns jsonb language plpgsql security definer set search_path='' as $$
begin
 perform public.medical_record_access(p_actor,p_clinic,p_patient,p_doctor_only);
 return (select coalesce(jsonb_agg(public.medical_record_row(r) order by r.created_at desc,r.id),'[]') from (select * from public.medical_records where clinic_id=p_clinic and patient_id=p_patient and deleted_at is null order by created_at desc limit 200) r);
end$$;

-- Returns the storage path so the API can sign a download; staff reads are audited.
create function public.medical_record_file(p_actor uuid,p_clinic uuid,p_id uuid,p_as text) returns jsonb language plpgsql security definer set search_path='' as $$
declare r public.medical_records;
begin
 select * into r from public.medical_records where id=p_id and clinic_id=p_clinic and deleted_at is null;
 if not found then raise exception 'NOT_FOUND';end if;
 if p_as='patient' then
  if r.patient_id<>p_actor then raise exception 'NOT_FOUND';end if;
 else
  perform public.medical_record_access(p_actor,p_clinic,r.patient_id,p_as='doctor');
  insert into public.audit_logs(clinic_id,actor_id,action,resource_id) values(p_clinic,p_actor,'medical_record.downloaded',r.id);
 end if;
 return jsonb_build_object('storage_path',r.storage_path,'file_name',r.file_name,'mime_type',r.mime_type);
end$$;

-- Soft removal; administrators remove any document, a doctor only documents they authored.
create function public.medical_record_delete(p_actor uuid,p_clinic uuid,p_id uuid,p_doctor_only boolean default false) returns jsonb language plpgsql security definer set search_path='' as $$
declare r public.medical_records;own uuid;
begin
 select * into r from public.medical_records where id=p_id and clinic_id=p_clinic and deleted_at is null for update;
 if not found then raise exception 'NOT_FOUND';end if;
 own=public.medical_record_access(p_actor,p_clinic,r.patient_id,p_doctor_only);
 if own is not null and r.uploaded_by is distinct from p_actor then raise exception 'FORBIDDEN';end if;
 update public.medical_records set deleted_at=now() where id=r.id returning * into r;
 insert into public.audit_logs(clinic_id,actor_id,action,resource_id) values(p_clinic,p_actor,'medical_record.deleted',r.id);
 return public.medical_record_row(r);
end$$;

create function public.patient_medical_records(p_actor uuid,p_clinic uuid) returns jsonb language sql stable security definer set search_path='' as $$
 select coalesce(jsonb_agg(public.medical_record_row(r) order by r.created_at desc,r.id),'[]') from (select * from public.medical_records where clinic_id=p_clinic and patient_id=p_actor and deleted_at is null order by created_at desc limit 200) r
$$;

revoke all on function public.medical_record_row(public.medical_records),public.medical_record_access(uuid,uuid,uuid,boolean),public.medical_record_save(uuid,uuid,uuid,jsonb,boolean),public.medical_record_list(uuid,uuid,uuid,boolean),public.medical_record_file(uuid,uuid,uuid,text),public.medical_record_delete(uuid,uuid,uuid,boolean),public.patient_medical_records(uuid,uuid) from public,anon,authenticated;
grant execute on function public.medical_record_save(uuid,uuid,uuid,jsonb,boolean),public.medical_record_list(uuid,uuid,uuid,boolean),public.medical_record_file(uuid,uuid,uuid,text),public.medical_record_delete(uuid,uuid,uuid,boolean),public.patient_medical_records(uuid,uuid) to service_role;
notify pgrst,'reload schema';
