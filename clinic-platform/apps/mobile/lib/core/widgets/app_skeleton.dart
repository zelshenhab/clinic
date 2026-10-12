import 'package:flutter/material.dart';
import '../localization/app_localizations.dart';
import '../theme/app_theme.dart';

class AppSkeleton extends StatefulWidget {
  const AppSkeleton({super.key});
  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}

class _AppSkeletonState extends State<AppSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: AppLocalizations.of(context)!.loading,
    child: AnimatedBuilder(
      animation: controller,
      builder: (context, _) => Opacity(
        opacity: MediaQuery.disableAnimationsOf(context)
            ? 1
            : .45 + controller.value * .4,
        child: Column(
          children: List.generate(
            3,
            (i) => Container(
              height: i == 0 ? 150 : 70,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
