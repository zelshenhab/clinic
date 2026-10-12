import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/app_components.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/failure_message.dart';
import '../../../../core/theme/app_theme.dart';
import '../bloc/auth_cubit.dart';

class OtpPage extends StatefulWidget {
  const OtpPage({super.key});
  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> {
  final code = TextEditingController();
  final form = GlobalKey<FormState>();
  Timer? timer;
  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    final auth = context.read<AuthCubit>();
    return AppScaffold(
      title: t.otpTitle,
      child: BlocBuilder<AuthCubit, AuthState>(
        builder: (context, state) => ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 24),
            const Icon(Icons.sms_outlined, size: 64, color: AppColors.blue),
            const SizedBox(height: 28),
            Text(t.otpTitle, style: Theme.of(context).textTheme.headlineLarge),
            const SizedBox(height: 12),
            Text(t.otpSubtitle),
            Text(state.phone, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 32),
            Form(
              key: form,
              child: AppTextField(
                controller: code,
                label: t.otpCode,
                keyboardType: TextInputType.number,
                maxLength: 6,
                autofillHints: const [AutofillHints.oneTimeCode],
                validator: (value) =>
                    RegExp(r'^[0-9]{6}$').hasMatch(value ?? '')
                    ? null
                    : t.otpInvalidInput,
              ),
            ),
            const SizedBox(height: 20),
            if (state.failure != null) ...[
              Text(failureMessage(t, state.failure)),
              const SizedBox(height: 16),
            ],
            AppButton(
              label: t.verify,
              busy: state.status == AuthStatus.verifying,
              onPressed: state.status == AuthStatus.sending
                  ? null
                  : () {
                      if (form.currentState!.validate()) auth.verify(code.text);
                    },
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed:
                  auth.resendSeconds == 0 &&
                      state.status != AuthStatus.sending &&
                      state.status != AuthStatus.verifying
                  ? () => auth.send(state.phone)
                  : null,
              child: Text(
                auth.resendSeconds > 0
                    ? '${t.resendIn} ${auth.resendSeconds} ${t.seconds}'
                    : t.resend,
              ),
            ),
            TextButton(
              onPressed: () => context.go('/login'),
              child: Text(t.changePhone),
            ),
          ],
        ),
      ),
    );
  }
}
