import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/widgets/app_components.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/failure_message.dart';
import '../../../../core/theme/app_theme.dart';
import '../bloc/auth_cubit.dart';

class ProfileCompletionPage extends StatefulWidget {
  const ProfileCompletionPage({super.key});
  @override
  State<ProfileCompletionPage> createState() => _ProfileCompletionPageState();
}

class _ProfileCompletionPageState extends State<ProfileCompletionPage> {
  final name = TextEditingController(), email = TextEditingController();
  final form = GlobalKey<FormState>();
  bool busy = false;
  @override
  void dispose() {
    name.dispose();
    email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return AppScaffold(
      title: t.completeProfile,
      child: BlocBuilder<AuthCubit, AuthState>(
        builder: (context, state) => ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Icon(
              Icons.person_outline_rounded,
              size: 64,
              color: AppColors.blue,
            ),
            const SizedBox(height: 24),
            Text(
              t.completeProfile,
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 12),
            Text(t.completeSubtitle),
            const SizedBox(height: 28),
            if (state.status == AuthStatus.error &&
                state.profile == null &&
                !busy)
              AppErrorView(
                message: failureMessage(t, state.failure),
                retry: context.read<AuthCubit>().retryProfile,
              )
            else
              Form(
                key: form,
                child: Column(
                  children: [
                    AppTextField(
                      controller: name,
                      label: t.fullName,
                      maxLength: 120,
                      autofillHints: const [AutofillHints.name],
                      validator: (value) => (value ?? '').trim().length < 2
                          ? t.nameInvalid
                          : null,
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: email,
                      label: t.email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      validator: (value) =>
                          value == null ||
                              value.isEmpty ||
                              RegExp(
                                r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                              ).hasMatch(value)
                          ? null
                          : t.emailInvalid,
                    ),
                    const SizedBox(height: 24),
                    if (state.failure != null) ...[
                      Text(failureMessage(t, state.failure)),
                      const SizedBox(height: 16),
                    ],
                    AppButton(
                      label: t.save,
                      busy: busy,
                      onPressed: () async {
                        if (!form.currentState!.validate()) return;
                        setState(() => busy = true);
                        await context.read<AuthCubit>().complete(
                          name.text.trim(),
                          email.text.trim().isEmpty ? null : email.text.trim(),
                          Localizations.localeOf(context).languageCode,
                        );
                        if (mounted) setState(() => busy = false);
                      },
                    ),
                  ],
                ),
              ),
            TextButton(
              onPressed: () => context.read<AuthCubit>().logout(),
              child: Text(t.logout),
            ),
          ],
        ),
      ),
    );
  }
}
