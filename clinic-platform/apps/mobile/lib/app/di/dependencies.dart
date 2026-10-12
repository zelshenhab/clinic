import '../../features/home/data/repositories/api_home_repository.dart';
import '../../features/home/domain/usecases/load_home.dart';
import '../../features/home/presentation/bloc/home_cubit.dart';
import '../../features/services/data/repositories/api_service_repository.dart';
import '../../features/services/domain/usecases/load_services.dart';
import '../../features/services/presentation/bloc/services_cubit.dart';
import '../../features/promotions/data/repositories/api_promotion_repository.dart';
import '../../features/promotions/domain/usecases/load_promotions.dart';
import '../../features/promotions/presentation/bloc/promotions_cubit.dart';
import '../../features/notifications/data/repositories/api_notification_repository.dart';
import '../../features/notifications/domain/usecases/load_notifications.dart';
import '../../features/notifications/presentation/bloc/notifications_cubit.dart';
import '../../features/doctors/presentation/bloc/doctor_detail_cubit.dart';
import '../../features/specialties/presentation/bloc/specialty_detail_cubit.dart';
import '../../features/services/presentation/bloc/service_detail_cubit.dart';
import '../../features/appointments/data/repositories/api_booking_context_repository.dart';
import '../../features/appointments/domain/usecases/prepare_booking.dart';
import '../../features/appointments/presentation/bloc/booking_entry_cubit.dart';
import '../../core/utils/contact_clinic.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/app_config.dart';
import '../../core/storage/preferences.dart';
import '../../core/security/secure_session_storage.dart';
import '../../core/network/api_client.dart';
import '../../core/network/clinic_scope.dart';
import '../../features/clinic_selection/data/datasources/clinic_remote_source.dart';
import '../../features/clinic_selection/data/repositories/api_clinic_repository.dart';
import '../../features/clinic_selection/domain/repositories/clinic_repository.dart';
import '../../features/clinic_selection/domain/usecases/load_clinics.dart';
import '../../features/clinic_selection/presentation/bloc/clinic_cubit.dart';
import '../../features/authentication/data/repositories/supabase_auth_repository.dart';
import '../../features/authentication/data/repositories/api_profile_repository.dart';
import '../../features/authentication/domain/repositories/auth_repository.dart';
import '../../features/authentication/domain/repositories/profile_repository.dart';
import '../../features/authentication/domain/usecases/auth_actions.dart';
import '../../features/authentication/presentation/bloc/auth_cubit.dart';
import '../../features/settings/presentation/bloc/locale_cubit.dart';
import '../../features/doctors/data/repositories/api_doctor_repository.dart';
import '../../features/doctors/domain/usecases/load_doctors.dart';
import '../../features/doctors/presentation/bloc/doctors_cubit.dart';
import '../../features/specialties/data/repositories/api_specialty_repository.dart';
import '../../features/specialties/domain/usecases/load_specialties.dart';
import '../../features/specialties/presentation/bloc/specialties_cubit.dart';
import '../../features/appointments/data/repositories/api_appointment_repository.dart';
import '../../features/appointments/domain/usecases/load_appointments.dart';
import '../../features/appointments/presentation/bloc/appointments_cubit.dart';

Future<GetIt> configureDependencies(AppConfig config) async {
  final di = GetIt.asNewInstance();
  SupabaseClient? client;
  if (config.authConfigured) {
    await Supabase.initialize(
      url: config.supabaseUrl,
      publishableKey: config.anonKey,
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        localStorage: SecureSessionStorage(FlutterSecureStorage()),
        detectSessionInUri: false,
      ),
    );
    client = Supabase.instance.client;
  }
  di.registerSingleton<AppConfig>(config);
  di.registerSingleton<Preferences>(
    AppPreferences(await SharedPreferences.getInstance()),
  );
  di.registerSingleton<ClinicScope>(ClinicScope());
  di.registerSingleton<AuthRepository>(
    SupabaseAuthRepository(client, smsEnabled: config.smsEnabled),
  );
  di.registerSingleton<ApiClient>(
    ApiClient(config.apiUrl, auth: di<AuthRepository>()),
  );
  di.registerSingleton<ClinicRepository>(
    ApiClinicRepository(ClinicRemoteSource(di<ApiClient>())),
  );
  di.registerSingleton<ProfileRepository>(
    ApiProfileRepository(di<ApiClient>()),
  );
  di.registerSingleton<ClinicCubit>(
    ClinicCubit(
      LoadClinics(di<ClinicRepository>()),
      di<Preferences>(),
      di<ClinicScope>(),
    ),
  );
  di.registerSingleton<AuthCubit>(
    AuthCubit(
      AuthActions(di<AuthRepository>(), di<ProfileRepository>()),
      di<ClinicScope>(),
    ),
  );
  di.registerSingleton<LocaleCubit>(LocaleCubit(di<Preferences>()));
  di.registerSingleton<LoadDoctors>(
    LoadDoctors(ApiDoctorRepository(di<ApiClient>())),
  );
  di.registerSingleton<LoadSpecialties>(
    LoadSpecialties(ApiSpecialtyRepository(di<ApiClient>())),
  );
  di.registerSingleton<ContactClinic>(ContactClinic());
  di.registerFactory<DoctorsCubit>(
    () => DoctorsCubit(di<ClinicScope>(), di<LoadDoctors>()),
  );
  di.registerFactory<SpecialtiesCubit>(
    () => SpecialtiesCubit(di<ClinicScope>(), di<LoadSpecialties>()),
  );
  di.registerFactory<AppointmentsCubit>(
    () => AppointmentsCubit(
      di<ClinicScope>(),
      LoadAppointments(ApiAppointmentRepository(di<ApiClient>())),
    ),
  );
  di.registerSingleton<LoadHome>(LoadHome(ApiHomeRepository(di<ApiClient>())));
  di.registerFactory<HomeCubit>(
    () => HomeCubit(di<ClinicScope>(), di<LoadHome>()),
  );
  di.registerSingleton<LoadServices>(
    LoadServices(ApiServiceRepository(di<ApiClient>())),
  );
  di.registerFactory<ServicesCubit>(
    () => ServicesCubit(di<ClinicScope>(), di<LoadServices>()),
  );
  di.registerSingleton<LoadPromotions>(
    LoadPromotions(ApiPromotionRepository(di<ApiClient>())),
  );
  di.registerFactory<PromotionsCubit>(
    () => PromotionsCubit(di<ClinicScope>(), di<LoadPromotions>()),
  );
  di.registerSingleton<LoadNotifications>(
    LoadNotifications(ApiNotificationRepository(di<ApiClient>())),
  );
  di.registerFactory<NotificationsCubit>(
    () => NotificationsCubit(di<ClinicScope>(), di<LoadNotifications>()),
  );
  di.registerFactory<DoctorDetailCubit>(
    () => DoctorDetailCubit(di<ClinicScope>(), di<LoadDoctors>()),
  );
  di.registerFactory<SpecialtyDetailCubit>(
    () => SpecialtyDetailCubit(di<ClinicScope>(), di<LoadSpecialties>()),
  );
  di.registerFactory<ServiceDetailCubit>(
    () => ServiceDetailCubit(di<ClinicScope>(), di<LoadServices>()),
  );
  di.registerSingleton<PrepareBooking>(
    PrepareBooking(ApiBookingContextRepository(di<ApiClient>())),
  );
  di.registerFactory<BookingEntryCubit>(
    () => BookingEntryCubit(di<ClinicScope>(), di<PrepareBooking>()),
  );
  return di;
}
