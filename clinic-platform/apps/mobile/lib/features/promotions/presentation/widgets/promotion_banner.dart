import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/catalog_format.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/catalog_image.dart';
import '../../domain/entities/promotion.dart';

class PromotionBanner extends StatelessWidget {
  const PromotionBanner({super.key, required this.promotion});
  final Promotion promotion;
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!,
        locale = Localizations.localeOf(context).languageCode;
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.lightBlue, Color(0xFFD8EBFB)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  localized(promotion.title, locale),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(width: 12),
              CatalogImage(
                url: promotion.imageUrl,
                asset: 'assets/images/banner.svg',
                label: t.promotionalIllustration,
                height: 64,
                width: 64,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(localized(promotion.description, locale)),
          if (promotion.action != null) ...[
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => promotion.action == 'doctors'
                  ? context.go('/doctors')
                  : context.push('/${promotion.action}'),
              child: Text(t.moreDetails),
            ),
          ],
        ],
      ),
    );
  }
}

class PromotionCarousel extends StatefulWidget {
  const PromotionCarousel({super.key, required this.promotions});
  final List<Promotion> promotions;
  @override
  State<PromotionCarousel> createState() => _PromotionCarouselState();
}

class _PromotionCarouselState extends State<PromotionCarousel> {
  int index = 0;
  final controller = PageController(viewportFraction: .96);
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      SizedBox(
        height: 300 * MediaQuery.textScalerOf(context).scale(1),
        child: PageView.builder(
          controller: controller,
          itemCount: widget.promotions.length,
          onPageChanged: (i) => setState(() => index = i),
          itemBuilder: (context, i) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: SingleChildScrollView(
              child: PromotionBanner(promotion: widget.promotions[i]),
            ),
          ),
        ),
      ),
      const SizedBox(height: 12),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          widget.promotions.length,
          (i) => AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: index == i ? 22 : 6,
            height: 6,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: index == i ? AppColors.blue : AppColors.border,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
    ],
  );
}
