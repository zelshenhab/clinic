begin;
set local search_path = public, extensions;
create extension if not exists pg_trgm;
alter table public.clinics add column logo_url text;
alter table public.doctor_clinics
 add column professional_title jsonb not null default '{"ru":"","en":""}',
 add column education jsonb not null default '{"ru":"","en":""}',
 add column biography jsonb not null default '{"ru":"","en":""}',
 add column qualifications jsonb not null default '{"ru":"","en":""}',
 add column experience_years integer check(experience_years between 0 and 80),
 add column languages text[], add column featured boolean not null default false,
 add column sort_order integer not null default 0;
alter table public.specialties
 add column description jsonb not null default '{"ru":"","en":""}',
 add column icon text not null default 'medical',add column sort_order integer not null default 0,
 add column active boolean not null default true;
alter table public.services
 add column category_key text not null default 'consultations',
 add column category jsonb not null default '{"ru":"Консультации","en":"Consultations"}',
 add column active boolean not null default true, add column featured boolean not null default false,
 add column sort_order integer not null default 0;
alter table public.promotions add column active boolean not null default true,
 add column sort_order integer not null default 0,
 add column action_kind text check(action_kind in ('doctors','specialties','services'));
create index doctor_assignments_catalog on public.doctor_clinics(clinic_id,sort_order,doctor_id) where active;
create index specialty_catalog on public.specialties(clinic_id,sort_order,id) where active;
create index service_catalog on public.services(clinic_id,specialty_id,category_key,price_rub,id) where active;
create index promotion_catalog on public.promotions(clinic_id,starts_at,ends_at) where active;
create index doctor_name_search on public.doctors using gin (((name->>'ru')||' '||(name->>'en')) gin_trgm_ops);
create index service_name_search on public.services using gin (((name->>'ru')||' '||(name->>'en')) gin_trgm_ops);
create index specialty_name_search on public.specialties using gin (((name->>'ru')||' '||(name->>'en')) gin_trgm_ops);
create view public.catalog_specialties with(security_invoker=true) as
 select s.id,s.clinic_id,s.name,s.description,s.icon,s.sort_order,
 s.name->>'ru' as name_ru,s.name->>'en' as name_en,(s.name->>'ru')||' '||(s.name->>'en') as search_text,
 (select count(*)::integer from public.doctor_specialties ds join public.doctor_clinics dc on dc.clinic_id=ds.clinic_id and dc.doctor_id=ds.doctor_id and dc.active where ds.clinic_id=s.clinic_id and ds.specialty_id=s.id) as doctor_count
 from public.specialties s join public.clinics c on c.id=s.clinic_id and c.active where s.active;
create view public.catalog_services with(security_invoker=true) as
 select s.id,s.clinic_id,s.specialty_id,s.name,s.description,s.price_rub,s.duration_minutes,s.category_key,s.category,s.featured,s.sort_order,
 sp.name as specialty_name,s.name->>'ru' as name_ru,s.name->>'en' as name_en,(s.name->>'ru')||' '||(s.name->>'en') as search_text,
 coalesce((select array_agg(ds.doctor_id) from public.doctor_services ds join public.doctor_clinics dc on dc.clinic_id=ds.clinic_id and dc.doctor_id=ds.doctor_id and dc.active where ds.clinic_id=s.clinic_id and ds.service_id=s.id),array[]::uuid[]) as doctor_ids
 from public.services s join public.specialties sp on sp.clinic_id=s.clinic_id and sp.id=s.specialty_id and sp.active
 join public.clinics c on c.id=s.clinic_id and c.active where s.active;
create view public.catalog_doctors with(security_invoker=true) as
 select d.id,dc.clinic_id,d.name,d.photo_url,dc.description,dc.professional_title,dc.experience_years,dc.education,dc.biography,dc.qualifications,
 coalesce(dc.languages,d.languages) as languages,dc.featured,dc.sort_order,
 d.name->>'ru' as name_ru,d.name->>'en' as name_en,(d.name->>'ru')||' '||(d.name->>'en') as search_text,
 coalesce((select jsonb_agg(jsonb_build_object('id',s.id,'name',s.name) order by s.sort_order,s.id) from public.doctor_specialties ds join public.specialties s on s.clinic_id=ds.clinic_id and s.id=ds.specialty_id and s.active where ds.clinic_id=dc.clinic_id and ds.doctor_id=d.id),'[]') as specialties,
 coalesce((select array_agg(s.id) from public.doctor_specialties ds join public.specialties s on s.clinic_id=ds.clinic_id and s.id=ds.specialty_id and s.active where ds.clinic_id=dc.clinic_id and ds.doctor_id=d.id),array[]::uuid[]) as specialty_ids,
 coalesce((select array_agg(s.id) from public.doctor_services ds join public.catalog_services s on s.clinic_id=ds.clinic_id and s.id=ds.service_id where ds.clinic_id=dc.clinic_id and ds.doctor_id=d.id),array[]::uuid[]) as service_ids,
 (select min(s.price_rub) from public.doctor_services ds join public.catalog_services s on s.clinic_id=ds.clinic_id and s.id=ds.service_id where ds.clinic_id=dc.clinic_id and ds.doctor_id=d.id) as starting_price_rub
 from public.doctor_clinics dc join public.doctors d on d.id=dc.doctor_id join public.clinics c on c.id=dc.clinic_id and c.active where dc.active;
create view public.catalog_categories with(security_invoker=true) as
 select distinct clinic_id,category_key,category from public.catalog_services;
revoke all on public.catalog_doctors,public.catalog_specialties,public.catalog_services,public.catalog_categories from anon,authenticated;
grant select on public.catalog_doctors,public.catalog_specialties,public.catalog_services,public.catalog_categories to service_role;
notify pgrst, 'reload schema';
commit;
