import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/app_components.dart';
import '../../../../core/widgets/app_skeleton.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/failure_message.dart';
import '../../../../core/theme/app_theme.dart';
import '../bloc/clinic_cubit.dart';
import '../widgets/clinic_card.dart';

class ClinicSelectionPage extends StatelessWidget {
  const ClinicSelectionPage({super.key});
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return AppScaffold(
      actions: [
        IconButton(
          tooltip: t.chooseLanguage,
          onPressed: () => context.push('/settings'),
          icon: const Icon(Icons.language),
        ),
      ],
      title: t.appTitle,
      child: BlocBuilder<ClinicCubit, ClinicState>(
        builder: (context, state) => RefreshIndicator(
          onRefresh: context.read<ClinicCubit>().load,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(t.ourClinics, style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(height: 12),
              Text(
                t.chooseClinic,
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 12),
              Text(t.chooseSubtitle),
              const SizedBox(height: 28),
              if (state.status == ClinicStatus.loading ||
                  state.status == ClinicStatus.initial)
                const AppSkeleton()
              else if (state.status == ClinicStatus.error)
                AppErrorView(
                  message: failureMessage(t, state.failure),
                  retry: context.read<ClinicCubit>().load,
                )
              else if (state.clinics.isEmpty)
                AppEmptyState(
                  title: t.noClinics,
                  icon: Icons.local_hospital_outlined,
                )
              else
                ...state.clinics.map(
                  (clinic) => Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: ClinicCard(
                      clinic: clinic,
                      select: () async {
                        await context.read<ClinicCubit>().select(clinic);
                        if (context.mounted &&
                            context.read<ClinicCubit>().state.selected !=
                                null) {
                          context.go('/home');
                        }
                      },
                    ),
                  ),
                ),
              const Icon(
                Icons.health_and_safety_outlined,
                color: AppColors.blue,
              ),
              const SizedBox(height: 8),
              Text(t.healthCare, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
