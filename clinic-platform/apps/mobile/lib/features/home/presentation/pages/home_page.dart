import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/app_components.dart';
import '../../../../core/widgets/app_skeleton.dart';
import '../../../../core/widgets/contact_button.dart';
import '../../../../core/catalog/scoped_resource_cubit.dart';
import '../../../../core/catalog/catalog_list_cubit.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/failure_message.dart';
import '../../../../core/localization/catalog_format.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../clinic_selection/domain/entities/clinic.dart';
import '../../../authentication/presentation/bloc/auth_cubit.dart';
import '../../../doctors/presentation/widgets/doctor_card.dart';
import '../../../specialties/presentation/widgets/specialty_card.dart';
import '../../../services/presentation/widgets/service_card.dart';
import '../../../promotions/presentation/widgets/promotion_banner.dart';
import '../../domain/entities/home_catalog.dart';
import '../bloc/home_cubit.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.clinic});
  final Clinic clinic;
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? locale;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final value = Localizations.localeOf(context).languageCode;
    if (locale != value) {
      locale = value;
      context.read<HomeCubit>().get(widget.clinic.id, value);
    }
  }

  @override
  void didUpdateWidget(covariant HomePage old) {
    super.didUpdateWidget(old);
    if (old.clinic.id != widget.clinic.id) {
      context.read<HomeCubit>().get(widget.clinic.id, locale ?? 'ru');
    }
  }

  Widget section(BuildContext context, String title, String route) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 12),
    child: Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        TextButton(
          onPressed: () =>
              route == '/doctors' ? context.go(route) : context.push(route),
          child: Text(AppLocalizations.of(context)!.seeAll),
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return BlocBuilder<HomeCubit, ResourceState<HomeCatalog>>(
      builder: (context, state) => RefreshIndicator(
        onRefresh: () =>
            context.read<HomeCubit>().get(widget.clinic.id, locale ?? 'ru'),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            BlocBuilder<AuthCubit, AuthState>(
              builder: (context, auth) => Text(
                auth.profile?.complete == true
                    ? t.greeting(auth.profile!.fullName)
                    : t.guestGreeting,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            const SizedBox(height: 8),
            Text(t.welcomeSubtitle),
            const SizedBox(height: 24),
            if (state.clinicId != widget.clinic.id ||
                state.status == CatalogStatus.initial ||
                state.status == CatalogStatus.loading)
              const AppSkeleton()
            else if (state.status == CatalogStatus.error)
              AppErrorView(
                message: failureMessage(t, state.failure),
                retry: () => context.read<HomeCubit>().get(
                  widget.clinic.id,
                  locale ?? 'ru',
                ),
              )
            else if (state.data != null)
              ...content(context, state.data!, t),
          ],
        ),
      ),
    );
  }

  List<Widget> content(
    BuildContext context,
    HomeCatalog data,
    AppLocalizations t,
  ) => [
    if (data.promotions.isNotEmpty)
      PromotionCarousel(
        key: ValueKey(data.clinic.id),
        promotions: data.promotions,
      ),
    const SizedBox(height: 24),
    LayoutBuilder(
      builder: (context, constraints) => Wrap(
        spacing: 12,
        runSpacing: 12,
        children:
            [
                  (Icons.add_circle_outline, t.bookAppointment, '/booking'),
                  (Icons.medical_services_outlined, t.doctors, '/doctors'),
                  (Icons.receipt_long_outlined, t.services, '/services'),
                  (
                    Icons.calendar_month_outlined,
                    t.appointments,
                    '/appointments',
                  ),
                ]
                .map(
                  (action) => SizedBox(
                    width: (constraints.maxWidth - 12) / 2,
                    child: AppCard(
                      padding: const EdgeInsets.all(14),
                      child: InkWell(
                        onTap: () =>
                            ['/doctors', '/appointments'].contains(action.$3)
                            ? context.go(action.$3)
                            : context.push(action.$3),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(action.$1, color: AppColors.blue),
                            const SizedBox(height: 12),
                            Text(
                              action.$2,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
      ),
    ),
    if (data.specialties.isNotEmpty) ...[
      section(context, t.popularSpecialties, '/specialties'),
      ...data.specialties.map(
        (s) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: SpecialtyCard(specialty: s),
        ),
      ),
    ],
    if (data.doctors.isNotEmpty) ...[
      section(context, t.featuredDoctors, '/doctors'),
      ...data.doctors.map(
        (d) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: DoctorCard(doctor: d),
        ),
      ),
    ],
    if (data.services.isNotEmpty) ...[
      section(context, t.popularServices, '/services'),
      ...data.services.map(
        (s) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: ServiceCard(service: s),
        ),
      ),
    ],
    section(context, t.promotions, '/promotions'),
    const SizedBox(height: 12),
    Text(t.clinicInformation, style: Theme.of(context).textTheme.titleLarge),
    const SizedBox(height: 16),
    AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            localized(data.clinic.name, locale ?? 'ru'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Text(localized(data.clinic.description, locale ?? 'ru')),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, color: AppColors.blue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(localized(data.clinic.address, locale ?? 'ru')),
              ),
            ],
          ),
          if (data.clinic.phone != null) ...[
            const SizedBox(height: 12),
            SelectableText(data.clinic.phone!),
          ],
          const Divider(height: 32),
          Text(t.workingHours, style: Theme.of(context).textTheme.titleMedium),
          if (data.clinic.workingHours['weekdays'] != null)
            Text('${t.weekdays}: ${data.clinic.workingHours['weekdays']}'),
          if (data.clinic.workingHours['saturday'] != null)
            Text('${t.saturday}: ${data.clinic.workingHours['saturday']}'),
          const SizedBox(height: 20),
          if (data.clinic.phone != null)
            ContactButton(phone: data.clinic.phone!),
        ],
      ),
    ),
    const SizedBox(height: 24),
  ];
}
