import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/back_or_home.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/map_widgets.dart';
import '../../data/models/enums.dart';
import '../../data/models/json_utils.dart';
import '../../data/models/listing.dart';
import '../../data/repositories/marketplace_repository.dart';
import '../auth/auth_controller.dart';
import '../common/location_controller.dart';
import '../common/report_sheet.dart';
import 'listing_card.dart';
import 'request_sheet.dart';

final listingDetailProvider = FutureProvider.autoDispose.family<Listing, String>((ref, id) {
  final loc = ref.watch(locationControllerProvider.select((s) => s.point));
  return ref.watch(marketplaceRepositoryProvider).listing(id, latitude: loc.latitude, longitude: loc.longitude);
});

final listingReviewsProvider = FutureProvider.autoDispose.family<Paginated<Review>, String>(
  (ref, id) => ref.watch(marketplaceRepositoryProvider).reviews(listingId: id),
);

class ServiceDetailsScreen extends ConsumerWidget {
  const ServiceDetailsScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listing = ref.watch(listingDetailProvider(id));
    final user = ref.watch(currentUserProvider);
    final isCustomer = user?.role == Role.user;

    return Scaffold(
      appBar: AppBar(
        leading: const BackOrHomeButton(),
        title: const Text('Service'),
        actions: [
          if (isCustomer && listing.hasValue)
            IconButton(
              tooltip: 'Report this service',
              icon: const Icon(Icons.flag_outlined),
              onPressed:
                  () => showReportSheet(
                    context,
                    targetType: ReportTargetType.listing,
                    targetId: id,
                    targetLabel: listing.requireValue.title,
                  ),
            ),
        ],
      ),
      body: listing.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(error: e, onRetry: () => ref.invalidate(listingDetailProvider(id))),
        data: (l) => _Details(listing: l),
      ),
      bottomNavigationBar:
          isCustomer && listing.hasValue && listing.requireValue.status == ListingStatus.active
              ? SafeArea(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    border: Border(top: BorderSide(color: AppColors.border)),
                  ),
                  child: ContentWidth(
                    maxWidth: 860,
                    shrinkHeight: true,
                    child: Row(
                      children: [
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              Fmt.price(
                                listing.requireValue.price,
                                listing.requireValue.currency,
                                listing.requireValue.priceUnit,
                              ),
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppColors.accent),
                            ),
                            Text(listing.requireValue.priceUnit.label, style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => showRequestSheet(context, listing.requireValue),
                            icon: const Icon(Icons.send_rounded, size: 20),
                            label: const Text('Request service'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              : null,
    );
  }
}

class _Details extends ConsumerWidget {
  const _Details({required this.listing});
  final Listing listing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final loc = ref.watch(locationControllerProvider);
    final reviews = ref.watch(listingReviewsProvider(listing.id));
    final provider = listing.provider;

    return ContentWidth(
      maxWidth: 860,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          if (listing.status != ListingStatus.active) ...[
            InfoBanner(
              color: listing.status.color,
              icon: listing.status == ListingStatus.removed ? Icons.gpp_bad_outlined : Icons.pause_circle_outline,
              message:
                  listing.status == ListingStatus.removed
                      ? 'Removed by moderation: ${listing.removalReason ?? 'policy violation'}'
                      : 'This service is paused and hidden from customers.',
            ),
            const SizedBox(height: 16),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CategoryIcon(iconKey: listing.category?.icon, size: 56),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(listing.title, style: theme.textTheme.headlineSmall),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 10,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (listing.category != null)
                          StatusPill(label: listing.category!.name, color: AppColors.primary),
                        RatingBadge(average: listing.ratingAverage, count: listing.ratingCount),
                        if (listing.distanceKm != null)
                          Text('${Fmt.distance(listing.distanceKm)} away', style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (listing.withinServiceArea == false) ...[
            InfoBanner(
              color: AppColors.warning,
              icon: Icons.wrong_location_outlined,
              message:
                  'You are outside this provider\'s ${listing.serviceRadiusKm} km service area. They may decline the request.',
            ),
            const SizedBox(height: 16),
          ],
          Text('About this service', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            listing.description,
            style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 24),
          MapPreview(
            latitude: listing.latitude,
            longitude: listing.longitude,
            radiusKm: listing.serviceRadiusKm.toDouble(),
            secondary: LatLng(loc.point.latitude, loc.point.longitude),
            height: 200,
          ),
          const SizedBox(height: 10),
          KeyValueRow(icon: Icons.place_outlined, label: 'Based in', value: listing.address),
          KeyValueRow(icon: Icons.radar_rounded, label: 'Service area', value: 'Up to ${listing.serviceRadiusKm} km'),
          KeyValueRow(
            icon: Icons.sell_outlined,
            label: 'Pricing',
            value: '${Fmt.price(listing.price, listing.currency, listing.priceUnit)} · ${listing.priceUnit.label}',
          ),
          if (provider != null) ...[
            const SizedBox(height: 24),
            Text('Provided by', style: theme.textTheme.titleMedium),
            const SizedBox(height: 10),
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Avatar(name: provider.displayName),
                title: Text(provider.displayName, style: theme.textTheme.titleSmall),
                subtitle: Text(
                  [provider.fullName, if (provider.phone != null) provider.phone!].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push(Routes.provider(provider.id)),
              ),
            ),
          ],
          const SizedBox(height: 24),
          SectionHeader(
            'Reviews',
            subtitle:
                listing.ratingCount == 0
                    ? 'No reviews yet'
                    : '${listing.ratingCount} verified review${listing.ratingCount == 1 ? '' : 's'}',
          ),
          reviews.when(
            loading: () => const Padding(padding: EdgeInsets.all(16), child: LoadingState()),
            error: (e, _) => Text(e.toString()),
            data:
                (page) =>
                    page.items.isEmpty
                        ? Text(
                          'Be the first to review after your service is completed.',
                          style: theme.textTheme.bodyMedium,
                        )
                        : Column(children: [for (final r in page.items.take(10)) ReviewTile(review: r)]),
          ),
        ],
      ),
    );
  }
}

class ReviewTile extends ConsumerWidget {
  const ReviewTile({super.key, required this.review, this.showListing = false});
  final Review review;
  final bool showListing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final canReport = ref.watch(currentUserProvider)?.role == Role.provider;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Avatar(name: review.authorName, size: 32, color: AppColors.info),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(review.authorName, style: theme.textTheme.titleSmall),
                        Text(Fmt.relative(review.createdAt), style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                  StarRow(rating: review.rating, size: 15),
                  if (canReport)
                    IconButton(
                      tooltip: 'Report review',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.flag_outlined, size: 18),
                      onPressed:
                          () => showReportSheet(
                            context,
                            targetType: ReportTargetType.review,
                            targetId: review.id,
                            targetLabel: '"${review.comment}" — ${review.authorName}',
                          ),
                    ),
                ],
              ),
              if (showListing && review.listingTitle != null) ...[
                const SizedBox(height: 8),
                Text(review.listingTitle!, style: theme.textTheme.labelMedium?.copyWith(color: AppColors.primary)),
              ],
              if (review.comment.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(review.comment, style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
