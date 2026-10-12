begin;
alter table public.clinics add column description jsonb not null default '{"ru":"","en":""}';
alter table public.clinics add column image_url text;
update public.clinics set description = '{"ru":"Современная медицинская помощь и внимательное отношение к каждому пациенту. Демонстрационная клиника.","en":"Modern medical care with personal attention to every patient. Demonstration clinic."}' where slug in ('clinic_001','clinic_002');
-- Preserve auth identities and keep profile creation idempotent through the API.
commit;
