import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/category_style.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/common.dart';
import '../../data/models/listing.dart';

class CategoryIcon extends StatelessWidget {
  const CategoryIcon({super.key, required this.iconKey, this.size = 48});
  final String? iconKey;
  final double size;

  @override
  Widget build(BuildContext context) {
    final style = CategoryStyle.of(iconKey);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: style.color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(size * 0.3),
        border: Border.all(color: style.color.withValues(alpha: 0.25)),
      ),
      child: Icon(style.icon, color: style.color, size: size * 0.52),
    );
  }
}

class ListingCard extends StatelessWidget {
  const ListingCard({super.key, required this.listing, required this.onTap, this.trailing});
  final Listing listing;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outside = listing.withinServiceArea == false;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CategoryIcon(iconKey: listing.category?.icon),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      listing.title,
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      listing.provider?.displayName ?? listing.category?.name ?? '',
                      style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        RatingBadge(average: listing.ratingAverage, count: listing.ratingCount),
                        if (listing.distanceKm != null)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.near_me_outlined, size: 14, color: AppColors.textMuted),
                              const SizedBox(width: 3),
                              Text(Fmt.distance(listing.distanceKm), style: theme.textTheme.bodySmall),
                            ],
                          ),
                        if (outside) const StatusPill(label: 'Outside service area', color: AppColors.warning),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    Fmt.money(listing.price, listing.currency),
                    style: theme.textTheme.titleMedium?.copyWith(color: AppColors.accent, fontWeight: FontWeight.w800),
                  ),
                  if (listing.priceUnit.suffix.isNotEmpty)
                    Text(listing.priceUnit.suffix, style: theme.textTheme.bodySmall),
                  if (trailing != null) ...[const SizedBox(height: 8), trailing!],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
