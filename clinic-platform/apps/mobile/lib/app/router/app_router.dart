import '../../features/appointments/presentation/bloc/booking_flow_cubit.dart';
import '../../features/clinic_selection/domain/entities/clinic.dart';
import '../../core/catalog/catalog_query.dart';
import '../../core/widgets/catalog_image.dart';
import '../../features/home/presentation/bloc/home_cubit.dart';
import '../../features/doctors/presentation/bloc/doctor_detail_cubit.dart';
import '../../features/doctors/presentation/pages/doctor_detail_page.dart';
import '../../features/specialties/presentation/bloc/specialty_detail_cubit.dart';
import '../../features/specialties/presentation/pages/specialty_detail_page.dart';
import '../../features/services/presentation/bloc/services_cubit.dart';
import '../../features/services/presentation/pages/services_page.dart';
import '../../features/services/presentation/bloc/service_detail_cubit.dart';
import '../../features/services/presentation/pages/service_detail_page.dart';
import '../../features/promotions/presentation/bloc/promotions_cubit.dart';
import '../../features/promotions/presentation/pages/promotions_page.dart';
import '../../features/appointments/presentation/bloc/booking_entry_cubit.dart';
import '../../features/appointments/presentation/pages/booking_entry_page.dart';
import '../../features/notifications/presentation/bloc/notifications_cubit.dart';
import '../../features/notifications/presentation/pages/notifications_page.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/widgets/app_components.dart';
import '../../features/clinic_selection/presentation/bloc/clinic_cubit.dart';
import '../../features/clinic_selection/presentation/pages/clinic_selection_page.dart';
import '../../features/authentication/presentation/bloc/auth_cubit.dart';
import '../../features/authentication/presentation/pages/login_page.dart';
import '../../features/authentication/presentation/pages/otp_page.dart';
import '../../features/authentication/presentation/pages/profile_completion_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/doctors/presentation/bloc/doctors_cubit.dart';
import '../../features/doctors/presentation/pages/doctors_page.dart';
import '../../features/specialties/presentation/bloc/specialties_cubit.dart';
import '../../features/specialties/presentation/pages/specialties_page.dart';
import '../../features/appointments/presentation/bloc/appointments_cubit.dart';
import '../../features/appointments/presentation/pages/appointments_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import 'route_guard.dart';

class RouterRefresh extends ChangeNotifier {
  RouterRefresh(ClinicCubit clinic, AuthCubit auth) {
    subscriptions = [
      clinic.stream.listen((_) => notifyListeners()),
      auth.stream.listen((_) => notifyListeners()),
    ];
  }
  late final List<StreamSubscription<dynamic>> subscriptions;
  @override
  void dispose() {
    for (final sub in subscriptions) {
      sub.cancel();
    }
    super.dispose();
  }
}

GoRouter createRouter(GetIt di, RouterRefresh refresh) => GoRouter(
  initialLocation: '/splash',
  refreshListenable: refresh,
  errorBuilder: (context, state) => AppScaffold(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: AppErrorView(
        message: AppLocalizations.of(context)!.notFoundError,
        retry: () => context.go('/home'),
      ),
    ),
  ),
  redirect: (context, state) {
    if (di<AuthCubit>().state.status == AuthStatus.authenticated &&
        state.uri.queryParameters['from'] == 'booking') {
      final params = Map<String, String>.from(state.uri.queryParameters)
        ..remove('from');
      return Uri(path: '/booking', queryParameters: params).toString();
    }
    if (di<AuthCubit>().state.status == AuthStatus.authenticated &&
        const [
          'appointments',
          'notifications',
        ].contains(state.uri.queryParameters['from'])) {
      return '/${state.uri.queryParameters['from']}';
    }
    final redirect = guardRoute(
      path: state.uri.path,
      ready: di<ClinicCubit>().state.restored && di<AuthCubit>().ready,
      clinicSelected: di<ClinicCubit>().state.selected != null,
      auth: di<AuthCubit>().state,
    );
    if (redirect == '/profile-completion' &&
        state.uri.queryParameters['from'] == 'booking') {
      return Uri(
        path: '/profile-completion',
        queryParameters: state.uri.queryParameters,
      ).toString();
    }
    if (redirect == '/profile-completion' &&
        const [
          'appointments',
          'notifications',
        ].contains(state.uri.queryParameters['from'])) {
      return '/profile-completion?from=${state.uri.queryParameters['from']}';
    }
    return redirect;
  },
  routes: [
    GoRoute(path: '/splash', builder: (_, _) => const SplashPage()),
    GoRoute(path: '/clinics', builder: (_, _) => const ClinicSelectionPage()),
    GoRoute(
      path: '/login',
      builder: (_, _) => LoginPage(config: di<AppConfig>()),
    ),
    GoRoute(path: '/otp', builder: (_, _) => const OtpPage()),
    GoRoute(
      path: '/profile-completion',
      builder: (_, _) => const ProfileCompletionPage(),
    ),
    GoRoute(path: '/settings', builder: (_, _) => const SettingsPage()),
    GoRoute(
      path: '/specialties',
      builder: (_, _) => clinicRoute(
        (clinic) => BlocProvider(
          create: (_) => di<SpecialtiesCubit>(),
          child: SpecialtiesPage(clinicId: clinic.id),
        ),
      ),
    ),
    GoRoute(
      path: '/doctors/:id',
      builder: (_, state) => clinicRoute(
        (clinic) => BlocProvider(
          create: (_) => di<DoctorDetailCubit>(),
          child: DoctorDetailPage(
            key: ValueKey(state.uri.toString()),
            clinicId: clinic.id,
            id: state.pathParameters['id']!,
            serviceId: state.uri.queryParameters['serviceId'],
          ),
        ),
      ),
    ),
    GoRoute(
      path: '/specialties/:id',
      builder: (_, state) => clinicRoute(
        (clinic) => BlocProvider(
          create: (_) => di<SpecialtyDetailCubit>(),
          child: SpecialtyDetailPage(
            key: ValueKey(state.uri.toString()),
            clinicId: clinic.id,
            id: state.pathParameters['id']!,
          ),
        ),
      ),
    ),
    GoRoute(
      path: '/services/:id',
      builder: (_, state) => clinicRoute(
        (clinic) => BlocProvider(
          create: (_) => di<ServiceDetailCubit>(),
          child: ServiceDetailPage(
            key: ValueKey(state.uri.toString()),
            clinicId: clinic.id,
            id: state.pathParameters['id']!,
            doctorId: state.uri.queryParameters['doctorId'],
          ),
        ),
      ),
    ),
    GoRoute(
      path: '/services',
      builder: (_, state) => clinicRoute(
        (clinic) => MultiBlocProvider(
          providers: [
            BlocProvider(create: (_) => di<ServicesCubit>()),
            BlocProvider(create: (_) => di<SpecialtiesCubit>()),
          ],
          child: ServicesPage(clinicId: clinic.id, query: routeQuery(state)),
        ),
      ),
    ),
    GoRoute(
      path: '/promotions',
      builder: (_, _) => clinicRoute(
        (clinic) => BlocProvider(
          create: (_) => di<PromotionsCubit>(),
          child: PromotionsPage(clinicId: clinic.id),
        ),
      ),
    ),
    GoRoute(
      path: '/notifications',
      builder: (_, _) => clinicRoute(
        (clinic) => BlocProvider(
          create: (_) => di<NotificationsCubit>(),
          child: NotificationsPage(clinicId: clinic.id),
        ),
      ),
    ),
    GoRoute(
      path: '/booking',
      builder: (_, state) => clinicRoute(
        (clinic) => BlocProvider(
          create: (_) => di<BookingEntryCubit>(),
          child: BlocProvider(
            create: (_) => di<BookingFlowCubit>(),
            child: BookingEntryPage(
              key: ValueKey(state.uri.toString()),
              clinicId: clinic.id,
              query: routeQuery(state),
            ),
          ),
        ),
      ),
    ),
    ShellRoute(
      builder: (context, state, child) =>
          ApplicationShell(path: state.uri.path, child: child),
      routes: [
        GoRoute(
          path: '/home',
          builder: (_, _) => clinicRoute(
            (clinic) => BlocProvider(
              create: (_) => di<HomeCubit>(),
              child: HomePage(clinic: clinic),
            ),
          ),
        ),
        GoRoute(
          path: '/doctors',
          builder: (_, state) => clinicRoute(
            (clinic) => MultiBlocProvider(
              providers: [
                BlocProvider(create: (_) => di<DoctorsCubit>()),
                BlocProvider(create: (_) => di<SpecialtiesCubit>()),
              ],
              child: DoctorsPage(clinicId: clinic.id, query: routeQuery(state)),
            ),
          ),
        ),
        GoRoute(
          path: '/appointments',
          builder: (_, _) => clinicRoute(
            (clinic) => BlocProvider(
              create: (_) => di<AppointmentsCubit>(),
              child: AppointmentsPage(
                clinicId: clinic.id,
                timezone: clinic.timezone,
              ),
            ),
          ),
        ),
        GoRoute(path: '/profile', builder: (_, _) => const ProfilePage()),
      ],
    ),
  ],
);

// Rebuild and replace scoped providers immediately when the selected UUID changes.
Widget clinicRoute(Widget Function(Clinic) build) =>
    BlocBuilder<ClinicCubit, ClinicState>(
      buildWhen: (previous, current) =>
          previous.selected?.id != current.selected?.id,
      builder: (context, state) {
        final clinic = state.selected;
        if (clinic == null) return const SizedBox.shrink();
        return KeyedSubtree(key: ValueKey(clinic.id), child: build(clinic));
      },
    );
CatalogQuery routeQuery(GoRouterState state) {
  final q = state.uri.queryParameters;
  return CatalogQuery(
    specialtyId: q['specialtyId'],
    serviceId: q['serviceId'],
    doctorId: q['doctorId'],
    search: q['search'] ?? '',
    category: q['category'],
  );
}

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return AppScaffold(
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 650),
          builder: (context, value, child) =>
              Opacity(opacity: value, child: child),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.health_and_safety_rounded,
                size: 80,
                color: AppColors.blue,
              ),
              const SizedBox(height: 20),
              Text(
                t.appTitle,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              Text(t.healthCare),
              const SizedBox(height: 32),
              const CircularProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}

class ApplicationShell extends StatelessWidget {
  const ApplicationShell({super.key, required this.path, required this.child});
  final String path;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final routes = ['/home', '/doctors', '/appointments', '/profile'];
    final clinic = context.watch<ClinicCubit>().state.selected;
    final locale = Localizations.localeOf(context).languageCode;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            SizedBox(
              width: 34,
              height: 34,
              child: CatalogImage(
                url: clinic?.logoUrl,
                asset: 'assets/images/clinic.svg',
                label: t.appTitle,
                height: 34,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    clinic?.text(clinic.name, locale) ?? t.appTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (clinic != null)
                    Text(
                      clinic.text(clinic.address, locale),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: t.notifications,
            onPressed: () => context.push('/notifications'),
            icon: const Icon(Icons.notifications_outlined),
          ),
          IconButton(
            tooltip: t.switchClinic,
            onPressed: () => context.go('/clinics'),
            icon: const Icon(Icons.swap_horiz_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: child,
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: routes.contains(path) ? routes.indexOf(path) : 0,
        onDestinationSelected: (index) => context.go(routes[index]),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home_rounded),
            label: t.home,
          ),
          NavigationDestination(
            icon: const Icon(Icons.medical_services_outlined),
            label: t.doctors,
          ),
          NavigationDestination(
            icon: const Icon(Icons.calendar_month_outlined),
            label: t.appointments,
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            label: t.profile,
          ),
        ],
      ),
    );
  }
}
