# Phase 3 source inventory

Catalog, services, promotions, booking preparation and notification feature files are introduced or extended within existing modules. Doctor/specialty list entities, models, repositories, use cases, Cubits and pages replace their Phase 2 basic-list behavior; no duplicate client or clinic-specific screen tree was added. Core composition/localization and the existing catalog route/seed were modified. Database changes use migration 003 only.

## Backend and shared contracts

- [backend/src/modules/catalog/types.ts](../backend/src/modules/catalog/types.ts)
- [backend/src/modules/catalog/repository.ts](../backend/src/modules/catalog/repository.ts)
- [backend/src/modules/catalog/service.ts](../backend/src/modules/catalog/service.ts)
- [backend/src/modules/doctors/routes.ts](../backend/src/modules/doctors/routes.ts)
- [backend/src/modules/clinics/repository.ts](../backend/src/modules/clinics/repository.ts)
- [backend/src/modules/auth/routes.ts](../backend/src/modules/auth/routes.ts)
- [backend/src/modules/patients/repository.ts](../backend/src/modules/patients/repository.ts)
- [packages/shared-contracts/catalog.js](../packages/shared-contracts/catalog.js)
- [packages/shared-contracts/catalog.d.ts](../packages/shared-contracts/catalog.d.ts)
- [packages/shared-contracts/package.json](../packages/shared-contracts/package.json)
- [package-lock.json](../package-lock.json)

## Incremental database and repeatable seed

- [supabase/migrations/202610120003_medical_catalog.sql](../supabase/migrations/202610120003_medical_catalog.sql)
- [supabase/seeds/catalog.sql](../supabase/seeds/catalog.sql)

## Flutter composition and clinic models

- [apps/mobile/lib/app/app.dart](../apps/mobile/lib/app/app.dart)
- [apps/mobile/lib/app/di/dependencies.dart](../apps/mobile/lib/app/di/dependencies.dart)
- [apps/mobile/lib/app/router/app_router.dart](../apps/mobile/lib/app/router/app_router.dart)
- [apps/mobile/lib/app/router/route_guard.dart](../apps/mobile/lib/app/router/route_guard.dart)
- [apps/mobile/lib/features/authentication/presentation/pages/login_page.dart](../apps/mobile/lib/features/authentication/presentation/pages/login_page.dart)
- [apps/mobile/lib/features/clinic_selection/domain/entities/clinic.dart](../apps/mobile/lib/features/clinic_selection/domain/entities/clinic.dart)
- [apps/mobile/lib/features/clinic_selection/data/models/clinic_model.dart](../apps/mobile/lib/features/clinic_selection/data/models/clinic_model.dart)
- [apps/mobile/pubspec.yaml](../apps/mobile/pubspec.yaml)
- [apps/mobile/pubspec.lock](../apps/mobile/pubspec.lock)

## Shared mobile catalog and design components

- [apps/mobile/lib/core/catalog/catalog_list_cubit.dart](../apps/mobile/lib/core/catalog/catalog_list_cubit.dart)
- [apps/mobile/lib/core/catalog/catalog_page.dart](../apps/mobile/lib/core/catalog/catalog_page.dart)
- [apps/mobile/lib/core/catalog/catalog_parser.dart](../apps/mobile/lib/core/catalog/catalog_parser.dart)
- [apps/mobile/lib/core/catalog/catalog_query.dart](../apps/mobile/lib/core/catalog/catalog_query.dart)
- [apps/mobile/lib/core/catalog/scoped_resource_cubit.dart](../apps/mobile/lib/core/catalog/scoped_resource_cubit.dart)
- [apps/mobile/lib/core/localization/catalog_format.dart](../apps/mobile/lib/core/localization/catalog_format.dart)
- [apps/mobile/lib/core/utils/contact_clinic.dart](../apps/mobile/lib/core/utils/contact_clinic.dart)
- [apps/mobile/lib/core/widgets/app_components.dart](../apps/mobile/lib/core/widgets/app_components.dart)
- [apps/mobile/lib/core/widgets/catalog_detail_page.dart](../apps/mobile/lib/core/widgets/catalog_detail_page.dart)
- [apps/mobile/lib/core/widgets/catalog_filters.dart](../apps/mobile/lib/core/widgets/catalog_filters.dart)
- [apps/mobile/lib/core/widgets/catalog_image.dart](../apps/mobile/lib/core/widgets/catalog_image.dart)
- [apps/mobile/lib/core/widgets/catalog_list_page.dart](../apps/mobile/lib/core/widgets/catalog_list_page.dart)
- [apps/mobile/lib/core/widgets/contact_button.dart](../apps/mobile/lib/core/widgets/contact_button.dart)

## Localized resources and original illustration assets

- [apps/mobile/lib/core/localization/app_ru.arb](../apps/mobile/lib/core/localization/app_ru.arb)
- [apps/mobile/lib/core/localization/app_en.arb](../apps/mobile/lib/core/localization/app_en.arb)
- [apps/mobile/lib/core/localization/app_localizations.dart](../apps/mobile/lib/core/localization/app_localizations.dart)
- [apps/mobile/lib/core/localization/app_localizations_ru.dart](../apps/mobile/lib/core/localization/app_localizations_ru.dart)
- [apps/mobile/lib/core/localization/app_localizations_en.dart](../apps/mobile/lib/core/localization/app_localizations_en.dart)
- [apps/mobile/assets/images/doctor.svg](../apps/mobile/assets/images/doctor.svg)
- [apps/mobile/assets/images/banner.svg](../apps/mobile/assets/images/banner.svg)

## Flutter home: data / domain / presentation

- [apps/mobile/lib/features/home/data/repositories/api_home_repository.dart](../apps/mobile/lib/features/home/data/repositories/api_home_repository.dart)
- [apps/mobile/lib/features/home/domain/entities/home_catalog.dart](../apps/mobile/lib/features/home/domain/entities/home_catalog.dart)
- [apps/mobile/lib/features/home/domain/repositories/home_repository.dart](../apps/mobile/lib/features/home/domain/repositories/home_repository.dart)
- [apps/mobile/lib/features/home/domain/usecases/load_home.dart](../apps/mobile/lib/features/home/domain/usecases/load_home.dart)
- [apps/mobile/lib/features/home/presentation/bloc/home_cubit.dart](../apps/mobile/lib/features/home/presentation/bloc/home_cubit.dart)
- [apps/mobile/lib/features/home/presentation/pages/home_page.dart](../apps/mobile/lib/features/home/presentation/pages/home_page.dart)

## Flutter doctors: data / domain / presentation

- [apps/mobile/lib/features/doctors/data/models/doctor_model.dart](../apps/mobile/lib/features/doctors/data/models/doctor_model.dart)
- [apps/mobile/lib/features/doctors/data/repositories/api_doctor_repository.dart](../apps/mobile/lib/features/doctors/data/repositories/api_doctor_repository.dart)
- [apps/mobile/lib/features/doctors/domain/entities/doctor.dart](../apps/mobile/lib/features/doctors/domain/entities/doctor.dart)
- [apps/mobile/lib/features/doctors/domain/entities/doctor_detail.dart](../apps/mobile/lib/features/doctors/domain/entities/doctor_detail.dart)
- [apps/mobile/lib/features/doctors/domain/repositories/doctor_repository.dart](../apps/mobile/lib/features/doctors/domain/repositories/doctor_repository.dart)
- [apps/mobile/lib/features/doctors/domain/usecases/load_doctors.dart](../apps/mobile/lib/features/doctors/domain/usecases/load_doctors.dart)
- [apps/mobile/lib/features/doctors/presentation/bloc/doctor_detail_cubit.dart](../apps/mobile/lib/features/doctors/presentation/bloc/doctor_detail_cubit.dart)
- [apps/mobile/lib/features/doctors/presentation/bloc/doctors_cubit.dart](../apps/mobile/lib/features/doctors/presentation/bloc/doctors_cubit.dart)
- [apps/mobile/lib/features/doctors/presentation/pages/doctor_detail_page.dart](../apps/mobile/lib/features/doctors/presentation/pages/doctor_detail_page.dart)
- [apps/mobile/lib/features/doctors/presentation/pages/doctors_page.dart](../apps/mobile/lib/features/doctors/presentation/pages/doctors_page.dart)
- [apps/mobile/lib/features/doctors/presentation/widgets/doctor_card.dart](../apps/mobile/lib/features/doctors/presentation/widgets/doctor_card.dart)

## Flutter specialties: data / domain / presentation

- [apps/mobile/lib/features/specialties/data/models/specialty_model.dart](../apps/mobile/lib/features/specialties/data/models/specialty_model.dart)
- [apps/mobile/lib/features/specialties/data/repositories/api_specialty_repository.dart](../apps/mobile/lib/features/specialties/data/repositories/api_specialty_repository.dart)
- [apps/mobile/lib/features/specialties/domain/entities/specialty.dart](../apps/mobile/lib/features/specialties/domain/entities/specialty.dart)
- [apps/mobile/lib/features/specialties/domain/entities/specialty_detail.dart](../apps/mobile/lib/features/specialties/domain/entities/specialty_detail.dart)
- [apps/mobile/lib/features/specialties/domain/repositories/specialty_repository.dart](../apps/mobile/lib/features/specialties/domain/repositories/specialty_repository.dart)
- [apps/mobile/lib/features/specialties/domain/usecases/load_specialties.dart](../apps/mobile/lib/features/specialties/domain/usecases/load_specialties.dart)
- [apps/mobile/lib/features/specialties/presentation/bloc/specialties_cubit.dart](../apps/mobile/lib/features/specialties/presentation/bloc/specialties_cubit.dart)
- [apps/mobile/lib/features/specialties/presentation/bloc/specialty_detail_cubit.dart](../apps/mobile/lib/features/specialties/presentation/bloc/specialty_detail_cubit.dart)
- [apps/mobile/lib/features/specialties/presentation/pages/specialties_page.dart](../apps/mobile/lib/features/specialties/presentation/pages/specialties_page.dart)
- [apps/mobile/lib/features/specialties/presentation/pages/specialty_detail_page.dart](../apps/mobile/lib/features/specialties/presentation/pages/specialty_detail_page.dart)
- [apps/mobile/lib/features/specialties/presentation/widgets/specialty_card.dart](../apps/mobile/lib/features/specialties/presentation/widgets/specialty_card.dart)

## Flutter services: data / domain / presentation

- [apps/mobile/lib/features/services/data/models/service_model.dart](../apps/mobile/lib/features/services/data/models/service_model.dart)
- [apps/mobile/lib/features/services/data/repositories/api_service_repository.dart](../apps/mobile/lib/features/services/data/repositories/api_service_repository.dart)
- [apps/mobile/lib/features/services/domain/entities/medical_service.dart](../apps/mobile/lib/features/services/domain/entities/medical_service.dart)
- [apps/mobile/lib/features/services/domain/entities/service_detail.dart](../apps/mobile/lib/features/services/domain/entities/service_detail.dart)
- [apps/mobile/lib/features/services/domain/repositories/service_repository.dart](../apps/mobile/lib/features/services/domain/repositories/service_repository.dart)
- [apps/mobile/lib/features/services/domain/usecases/load_services.dart](../apps/mobile/lib/features/services/domain/usecases/load_services.dart)
- [apps/mobile/lib/features/services/presentation/bloc/service_detail_cubit.dart](../apps/mobile/lib/features/services/presentation/bloc/service_detail_cubit.dart)
- [apps/mobile/lib/features/services/presentation/bloc/services_cubit.dart](../apps/mobile/lib/features/services/presentation/bloc/services_cubit.dart)
- [apps/mobile/lib/features/services/presentation/pages/service_detail_page.dart](../apps/mobile/lib/features/services/presentation/pages/service_detail_page.dart)
- [apps/mobile/lib/features/services/presentation/pages/services_page.dart](../apps/mobile/lib/features/services/presentation/pages/services_page.dart)
- [apps/mobile/lib/features/services/presentation/widgets/service_card.dart](../apps/mobile/lib/features/services/presentation/widgets/service_card.dart)

## Flutter promotions: data / domain / presentation

- [apps/mobile/lib/features/promotions/data/models/promotion_model.dart](../apps/mobile/lib/features/promotions/data/models/promotion_model.dart)
- [apps/mobile/lib/features/promotions/data/repositories/api_promotion_repository.dart](../apps/mobile/lib/features/promotions/data/repositories/api_promotion_repository.dart)
- [apps/mobile/lib/features/promotions/domain/entities/promotion.dart](../apps/mobile/lib/features/promotions/domain/entities/promotion.dart)
- [apps/mobile/lib/features/promotions/domain/repositories/promotion_repository.dart](../apps/mobile/lib/features/promotions/domain/repositories/promotion_repository.dart)
- [apps/mobile/lib/features/promotions/domain/usecases/load_promotions.dart](../apps/mobile/lib/features/promotions/domain/usecases/load_promotions.dart)
- [apps/mobile/lib/features/promotions/presentation/bloc/promotions_cubit.dart](../apps/mobile/lib/features/promotions/presentation/bloc/promotions_cubit.dart)
- [apps/mobile/lib/features/promotions/presentation/pages/promotions_page.dart](../apps/mobile/lib/features/promotions/presentation/pages/promotions_page.dart)
- [apps/mobile/lib/features/promotions/presentation/widgets/promotion_banner.dart](../apps/mobile/lib/features/promotions/presentation/widgets/promotion_banner.dart)

## Flutter notifications: data / domain / presentation

- [apps/mobile/lib/features/notifications/data/repositories/api_notification_repository.dart](../apps/mobile/lib/features/notifications/data/repositories/api_notification_repository.dart)
- [apps/mobile/lib/features/notifications/domain/entities/clinic_notification.dart](../apps/mobile/lib/features/notifications/domain/entities/clinic_notification.dart)
- [apps/mobile/lib/features/notifications/domain/repositories/notification_repository.dart](../apps/mobile/lib/features/notifications/domain/repositories/notification_repository.dart)
- [apps/mobile/lib/features/notifications/domain/usecases/load_notifications.dart](../apps/mobile/lib/features/notifications/domain/usecases/load_notifications.dart)
- [apps/mobile/lib/features/notifications/presentation/bloc/notifications_cubit.dart](../apps/mobile/lib/features/notifications/presentation/bloc/notifications_cubit.dart)
- [apps/mobile/lib/features/notifications/presentation/pages/notifications_page.dart](../apps/mobile/lib/features/notifications/presentation/pages/notifications_page.dart)

## Booking preparation within the existing appointments feature

- [apps/mobile/lib/features/appointments/data/repositories/api_booking_context_repository.dart](../apps/mobile/lib/features/appointments/data/repositories/api_booking_context_repository.dart)
- [apps/mobile/lib/features/appointments/domain/entities/booking_context.dart](../apps/mobile/lib/features/appointments/domain/entities/booking_context.dart)
- [apps/mobile/lib/features/appointments/domain/repositories/booking_context_repository.dart](../apps/mobile/lib/features/appointments/domain/repositories/booking_context_repository.dart)
- [apps/mobile/lib/features/appointments/domain/usecases/prepare_booking.dart](../apps/mobile/lib/features/appointments/domain/usecases/prepare_booking.dart)
- [apps/mobile/lib/features/appointments/presentation/bloc/booking_entry_cubit.dart](../apps/mobile/lib/features/appointments/presentation/bloc/booking_entry_cubit.dart)
- [apps/mobile/lib/features/appointments/presentation/pages/booking_entry_page.dart](../apps/mobile/lib/features/appointments/presentation/pages/booking_entry_page.dart)

## Tests (production code does not depend on fixtures)

- [backend/tests/catalog.test.ts](../backend/tests/catalog.test.ts)
- [backend/tests/accounts.test.ts](../backend/tests/accounts.test.ts)
- [apps/mobile/test/catalog_api_test.dart](../apps/mobile/test/catalog_api_test.dart)
- [apps/mobile/test/catalog_state_test.dart](../apps/mobile/test/catalog_state_test.dart)
- [apps/mobile/test/catalog_widget_test.dart](../apps/mobile/test/catalog_widget_test.dart)
- [apps/mobile/test/support/catalog_fixtures.dart](../apps/mobile/test/support/catalog_fixtures.dart)
- [apps/mobile/test/widget_test.dart](../apps/mobile/test/widget_test.dart)

## Documentation

- [README.md](../README.md)
- [apps/mobile/README.md](../apps/mobile/README.md)
- [docs/openapi.yaml](../docs/openapi.yaml)
- [docs/catalog-api.md](../docs/catalog-api.md)
- [docs/phase-3.md](../docs/phase-3.md)
- [docs/phase-3-files.md](../docs/phase-3-files.md)
- [docs/phase-status.md](../docs/phase-status.md)
- [docs/verification.md](../docs/verification.md)
