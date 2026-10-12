import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cached_network_image/cached_network_image.dart';

class CatalogImage extends StatelessWidget {
  const CatalogImage({
    super.key,
    this.url,
    required this.asset,
    required this.label,
    this.height = 100,
    this.width = 100,
  });
  final String? url;
  final String asset, label;
  final double height, width;
  @override
  Widget build(BuildContext context) {
    final fallback = SvgPicture.asset(
      asset,
      fit: BoxFit.cover,
      semanticsLabel: label,
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: height,
        width: width,
        child: url == null
            ? fallback
            : CachedNetworkImage(
                imageUrl: url!,
                fit: BoxFit.cover,
                memCacheWidth: (width * MediaQuery.devicePixelRatioOf(context))
                    .round(),
                placeholder: (_, _) => fallback,
                errorWidget: (_, _, _) => fallback,
              ),
      ),
    );
  }
}
