begin;
create extension if not exists btree_gist;
create table public.clinics (
 id uuid primary key default gen_random_uuid(), slug text not null unique,
 name jsonb not null, address jsonb not null, timezone text not null default 'Europe/Moscow',
 phone text, working_hours jsonb not null default '{}', active boolean not null default true,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.clinic_settings (
 id uuid primary key default gen_random_uuid(), clinic_id uuid not null unique references public.clinics,
 configuration jsonb not null default '{}', public boolean not null default true,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.patient_profiles (
 id uuid primary key references auth.users on delete cascade, full_name text not null default '',
 email text, date_of_birth date, language text not null default 'ru' check(language in ('ru','en')),
 notification_preferences jsonb not null default '{}',
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.clinic_memberships (
 id uuid primary key default gen_random_uuid(), clinic_id uuid not null references public.clinics,
 user_id uuid not null references public.patient_profiles on delete cascade, unique(clinic_id,user_id),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.doctors (
 id uuid primary key default gen_random_uuid(), name jsonb not null,
 qualifications jsonb not null default '{}', photo_url text, languages text[] not null default array['ru'],
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.doctor_clinics (
 id uuid primary key default gen_random_uuid(), clinic_id uuid not null references public.clinics,
 doctor_id uuid not null references public.doctors, description jsonb not null default '{}',
 active boolean not null default true, unique(clinic_id,doctor_id),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.staff_memberships (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users on delete cascade,
 clinic_id uuid references public.clinics, role text not null check(role in ('SUPER_ADMIN','CLINIC_ADMIN','RECEPTIONIST','DOCTOR')),
 doctor_id uuid, active boolean not null default true,
 check((role='SUPER_ADMIN' and clinic_id is null) or (role<>'SUPER_ADMIN' and clinic_id is not null)),
 check(role<>'DOCTOR' or doctor_id is not null),
 foreign key(clinic_id,doctor_id) references public.doctor_clinics(clinic_id,doctor_id),
 unique nulls not distinct(user_id,clinic_id,role),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.specialties (
 id uuid primary key default gen_random_uuid(), clinic_id uuid not null references public.clinics,
 name jsonb not null, unique(clinic_id,id),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.services (
 id uuid primary key default gen_random_uuid(), clinic_id uuid not null references public.clinics,
 specialty_id uuid not null, name jsonb not null, description jsonb not null default '{}',
 price_rub numeric(12,2) not null check(price_rub>=0), duration_minutes integer not null check(duration_minutes between 5 and 480),
 unique(clinic_id,id), foreign key(clinic_id,specialty_id) references public.specialties(clinic_id,id),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.doctor_specialties (
 id uuid primary key default gen_random_uuid(), clinic_id uuid not null, doctor_id uuid not null, specialty_id uuid not null,
 foreign key(clinic_id,doctor_id) references public.doctor_clinics(clinic_id,doctor_id),
 foreign key(clinic_id,specialty_id) references public.specialties(clinic_id,id), unique(clinic_id,doctor_id,specialty_id),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.doctor_services (
 id uuid primary key default gen_random_uuid(), clinic_id uuid not null, doctor_id uuid not null, service_id uuid not null,
 foreign key(clinic_id,doctor_id) references public.doctor_clinics(clinic_id,doctor_id),
 foreign key(clinic_id,service_id) references public.services(clinic_id,id), unique(clinic_id,doctor_id,service_id),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.doctor_schedules (
 id uuid primary key default gen_random_uuid(), clinic_id uuid not null, doctor_id uuid not null,
 weekday integer not null check(weekday between 0 and 6), starts_at time not null, ends_at time not null,
 breaks jsonb not null default '[]', check(ends_at>starts_at),
 foreign key(clinic_id,doctor_id) references public.doctor_clinics(clinic_id,doctor_id), unique(clinic_id,doctor_id,weekday,starts_at),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.schedule_exceptions (
 id uuid primary key default gen_random_uuid(), clinic_id uuid not null, doctor_id uuid not null,
 starts_at timestamptz not null, ends_at timestamptz not null, available boolean not null default false,
 check(ends_at>starts_at), foreign key(clinic_id,doctor_id) references public.doctor_clinics(clinic_id,doctor_id),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.appointments (
 id uuid primary key default gen_random_uuid(), clinic_id uuid not null, doctor_id uuid not null,
 patient_id uuid not null, service_id uuid not null, starts_at timestamptz not null, ends_at timestamptz not null,
 status text not null default 'pending' check(status in ('pending','confirmed','completed','cancelled','no_show')),
 check(ends_at>starts_at), unique(clinic_id,id),
 foreign key(clinic_id,doctor_id,service_id) references public.doctor_services(clinic_id,doctor_id,service_id),
 foreign key(clinic_id,patient_id) references public.clinic_memberships(clinic_id,user_id),
 -- Global doctor identity prevents overlapping bookings even across different clinics.
 exclude using gist(doctor_id with =, tstzrange(starts_at,ends_at,'[)') with &&) where(status in ('pending','confirmed')),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.appointment_status_history (
 id uuid primary key default gen_random_uuid(), clinic_id uuid not null, appointment_id uuid not null,
 status text not null check(status in ('pending','confirmed','completed','cancelled','no_show')),
 changed_by uuid references auth.users, foreign key(clinic_id,appointment_id) references public.appointments(clinic_id,id),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.notifications (
 id uuid primary key default gen_random_uuid(), clinic_id uuid not null, user_id uuid not null,
 title jsonb not null, body jsonb not null, read_at timestamptz,
 foreign key(clinic_id,user_id) references public.clinic_memberships(clinic_id,user_id),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.promotions (
 id uuid primary key default gen_random_uuid(), clinic_id uuid not null references public.clinics,
 title jsonb not null, description jsonb not null default '{}', image_url text,
 starts_at timestamptz not null, ends_at timestamptz not null, check(ends_at>starts_at),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.medical_records (
 id uuid primary key default gen_random_uuid(), clinic_id uuid not null, patient_id uuid not null,
 appointment_id uuid, storage_path text not null,
 foreign key(clinic_id,patient_id) references public.clinic_memberships(clinic_id,user_id),
 foreign key(clinic_id,appointment_id) references public.appointments(clinic_id,id),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.audit_logs (
 id uuid primary key default gen_random_uuid(), clinic_id uuid references public.clinics,
 actor_id uuid references auth.users on delete set null, action text not null, resource_id uuid,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create index appointments_clinic_start on public.appointments(clinic_id,starts_at);
create index appointments_patient on public.appointments(patient_id,starts_at);
create index staff_user on public.staff_memberships(user_id) where active;
create index notifications_recipient on public.notifications(user_id,clinic_id);
create function public.touch_updated_at() returns trigger language plpgsql set search_path='' as $$begin new.updated_at=now();return new;end$$;
create function public.has_clinic_role(cid uuid, roles text[]) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.staff_memberships s where s.user_id=auth.uid() and s.active and (s.role='SUPER_ADMIN' or (s.clinic_id=cid and s.role=any(roles))));
$$;
revoke all on function public.has_clinic_role(uuid,text[]) from public;
grant execute on function public.has_clinic_role(uuid,text[]) to authenticated;
-- Default deny all writes from clients. Business mutations go through the authorized API.
do $$declare t text;begin
 foreach t in array array['clinics','clinic_settings','patient_profiles','clinic_memberships','staff_memberships','doctors','doctor_clinics','specialties','services','doctor_specialties','doctor_services','doctor_schedules','schedule_exceptions','appointments','appointment_status_history','notifications','promotions','medical_records','audit_logs'] loop
 execute format('alter table public.%I enable row level security',t);
 execute format('create trigger touch_updated_at before update on public.%I for each row execute function public.touch_updated_at()',t);
 execute format('revoke all on public.%I from anon, authenticated',t);
 end loop;end$$;
grant select on public.appointments,public.notifications,public.patient_profiles,public.staff_memberships to authenticated;
create policy appointment_read on public.appointments for select to authenticated using(
 patient_id=auth.uid() or public.has_clinic_role(clinic_id,array['CLINIC_ADMIN','RECEPTIONIST']) or exists(
 select 1 from public.staff_memberships s where s.user_id=auth.uid() and s.active and s.role='DOCTOR' and s.clinic_id=appointments.clinic_id and s.doctor_id=appointments.doctor_id));
create policy notification_read on public.notifications for select to authenticated using(user_id=auth.uid());
create policy profile_read on public.patient_profiles for select to authenticated using(id=auth.uid());
create policy staff_self_read on public.staff_memberships for select to authenticated using(user_id=auth.uid());
-- Medical records intentionally have no client policy or grant.
alter publication supabase_realtime add table public.appointments,public.notifications;
commit;
