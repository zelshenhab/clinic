import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/app_components.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/failure_message.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../authentication/presentation/bloc/auth_cubit.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(t.profile, style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 24),
          if (!state.signedIn) ...[
            AppEmptyState(
              title: t.signInProfile,
              body: t.signInProfileBody,
              icon: Icons.person_outline,
            ),
            const SizedBox(height: 20),
            AppButton(label: t.login, onPressed: () => context.push('/login')),
          ] else ...[
            AppCard(
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 34,
                    backgroundColor: AppColors.lightBlue,
                    child: Icon(
                      Icons.person_outline,
                      size: 38,
                      color: AppColors.blue,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    state.profile?.fullName ?? '',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(state.identity!.phone),
                  if (state.profile?.email != null) Text(state.profile!.email!),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (state.failure != null)
              AppErrorView(
                message: failureMessage(t, state.failure),
                retry: context.read<AuthCubit>().retryProfile,
              ),
          ],
          const SizedBox(height: 16),
          AppCard(
            child: Column(
              children: [
                if (state.signedIn)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.description_outlined),
                    title: Text(t.medicalDocuments),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/documents'),
                  ),
                if (state.signedIn)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.family_restroom_outlined),
                    title: Text(t.familyMembers),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/family'),
                  ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.settings_outlined),
                  title: Text(t.settings),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/settings'),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.local_hospital_outlined),
                  title: Text(t.switchClinic),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go('/clinics'),
                ),
              ],
            ),
          ),
          if (state.signedIn) ...[
            const SizedBox(height: 24),
            TextButton(
              onPressed: () async {
                if (await confirmationDialog(
                      context,
                      title: t.logoutTitle,
                      body: t.logoutBody,
                      confirm: t.logout,
                    ) &&
                    context.mounted) {
                  await context.read<AuthCubit>().logout();
                }
              },
              child: Text(t.logout),
            ),
          ],
        ],
      ),
    );
  }
}
