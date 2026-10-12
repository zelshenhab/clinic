import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../utils/contact_clinic.dart';
import '../errors/app_exception.dart';
import '../localization/app_localizations.dart';
import 'app_components.dart';

class ContactButton extends StatelessWidget {
  const ContactButton({super.key, required this.phone});
  final String phone;
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return AppButton(
      label: t.contactClinic,
      icon: Icons.phone_outlined,
      onPressed: () async {
        try {
          await context.read<ContactClinic>().call(phone);
        } on AppException {
          if (context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(t.contactFailed)));
          }
        }
      },
    );
  }
}
