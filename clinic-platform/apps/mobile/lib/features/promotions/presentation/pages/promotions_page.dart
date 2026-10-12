import 'package:flutter/material.dart';
import '../../../../core/widgets/catalog_list_page.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../domain/entities/promotion.dart';
import '../bloc/promotions_cubit.dart';
import '../widgets/promotion_banner.dart';

class PromotionsPage extends StatelessWidget {
  const PromotionsPage({super.key, required this.clinicId});
  final String clinicId;
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;
    return CatalogListPage<Promotion, PromotionsCubit>(
      clinicId: clinicId,
      title: t.promotions,
      empty: t.noPromotions,
      itemBuilder: (p) => PromotionBanner(promotion: p),
    );
  }
}
