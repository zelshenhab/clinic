import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/widgets/app_components.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/failure_message.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/usecases/phone_number.dart';
import '../bloc/auth_cubit.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.config});
  final AppConfig config;
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  Timer? timer;
  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  final form = GlobalKey<FormState>();
  final phone = TextEditingController();
  final prefix = TextEditingController(text: '+7');
  @override
  void dispose() {
    timer?.cancel();
    phone.dispose();
    prefix.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return AppScaffold(
      title: t.appTitle,
      child: BlocConsumer<AuthCubit, AuthState>(
        listener: (context, state) {
          if (state.status == AuthStatus.codeSent) {
            final from = GoRouterState.of(context).uri.queryParameters['from'];
            context.go(
              const ['appointments', 'notifications', 'booking'].contains(from)
                  ? Uri(
                      path: '/otp',
                      queryParameters: GoRouterState.of(
                        context,
                      ).uri.queryParameters,
                    ).toString()
                  : '/otp',
            );
          }
        },
        builder: (context, state) => ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 28),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.lightBlue,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Icon(
                  Icons.phone_iphone_rounded,
                  size: 40,
                  color: AppColors.blue,
                ),
              ),
            ),
            const SizedBox(height: 28),
            Text(t.login, style: Theme.of(context).textTheme.headlineLarge),
            const SizedBox(height: 12),
            Text(t.loginSubtitle),
            const SizedBox(height: 32),
            if (!context.read<AuthCubit>().configured) ...[
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.config.developmentBrowsing
                          ? t.developmentTitle
                          : t.authUnavailable,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (widget.config.developmentBrowsing) ...[
                      const SizedBox(height: 12),
                      Text(t.developmentBody),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ] else
              Form(
                key: form,
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 115,
                          child: AppTextField(
                            controller: prefix,
                            label: t.countryCode,
                            keyboardType: TextInputType.phone,
                            maxLength: 4,
                            validator: (value) =>
                                RegExp(
                                  r'^\+[1-9][0-9]{0,2}$',
                                ).hasMatch(value ?? '')
                                ? null
                                : t.phoneInvalid,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppTextField(
                            controller: phone,
                            label: t.phone,
                            keyboardType: TextInputType.phone,
                            autofillHints: const [
                              AutofillHints.telephoneNumberNational,
                            ],
                            validator: (value) =>
                                PhoneNumber.normalize(
                                      prefix.text,
                                      value ?? '',
                                    ) ==
                                    null
                                ? t.phoneInvalid
                                : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    if (state.failure != null) ...[
                      Text(
                        failureMessage(t, state.failure),
                        style: const TextStyle(color: AppColors.darkBlue),
                      ),
                      const SizedBox(height: 16),
                    ],
                    AppButton(
                      label: context.read<AuthCubit>().resendSeconds > 0
                          ? '${t.resendIn} ${context.read<AuthCubit>().resendSeconds} ${t.seconds}'
                          : t.sendCode,
                      busy: state.status == AuthStatus.sending,
                      onPressed: context.read<AuthCubit>().resendSeconds > 0
                          ? null
                          : () {
                              if (form.currentState!.validate()) {
                                context.read<AuthCubit>().send(
                                  PhoneNumber.normalize(
                                    prefix.text,
                                    phone.text,
                                  )!,
                                );
                              }
                            },
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 18),
            TextButton(
              onPressed: () => context.go('/home'),
              child: Text(t.browseGuest),
            ),
          ],
        ),
      ),
    );
  }
}
