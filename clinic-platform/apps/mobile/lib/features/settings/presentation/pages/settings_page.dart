import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/widgets/app_components.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/failure_message.dart';
import '../../../../core/errors/app_exception.dart';
import '../bloc/locale_cubit.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return AppScaffold(
      title: t.settings,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(t.language, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 20),
          BlocBuilder<LocaleCubit, String>(
            builder: (context, locale) => AppCard(
              child: Column(
                children: ['ru', 'en']
                    .map(
                      (code) => ListTile(
                        title: Text(code == 'ru' ? t.russian : t.english),
                        trailing: locale == code
                            ? const Icon(Icons.check_circle_outline)
                            : null,
                        onTap: () async {
                          try {
                            await context.read<LocaleCubit>().select(code);
                          } on AppException catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(failureMessage(t, e.kind)),
                                ),
                              );
                            }
                          }
                        },
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
