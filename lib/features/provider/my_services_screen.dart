import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/dialogs.dart';
import '../../data/models/enums.dart';
import '../../data/models/listing.dart';
import '../../data/repositories/marketplace_repository.dart';
import '../customer/listing_card.dart';
import 'provider_providers.dart';

class MyServicesScreen extends ConsumerWidget {
  const MyServicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listings = ref.watch(myListingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('My services')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.newService),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New service'),
      ),
      body: listings.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(error: e, onRetry: () => ref.invalidate(myListingsProvider)),
        data:
            (items) =>
                items.isEmpty
                    ? EmptyState(
                      icon: Icons.storefront_outlined,
                      title: 'Publish your first service',
                      message: 'Add a title, price and location so nearby customers can find and request you.',
                      action: FilledButton(
                        onPressed: () => context.push(Routes.newService),
                        child: const Text('Create service'),
                      ),
                    )
                    : RefreshIndicator(
                      onRefresh: () => ref.refresh(myListingsProvider.future),
                      child: ContentWidth(
                        maxWidth: 860,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
                          itemCount: items.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (context, i) => _MyListingTile(listing: items[i]),
                        ),
                      ),
                    ),
      ),
    );
  }
}

class _MyListingTile extends ConsumerWidget {
  const _MyListingTile({required this.listing});
  final Listing listing;

  Future<void> _toggle(BuildContext context, WidgetRef ref) async {
    final next = listing.status == ListingStatus.active ? ListingStatus.paused : ListingStatus.active;
    try {
      await ref.read(marketplaceRepositoryProvider).setListingStatus(listing.id, next);
      ref.invalidate(myListingsProvider);
      ref.invalidate(providerStatsProvider);
      if (context.mounted) {
        showSnack(
          context,
          next == ListingStatus.active ? 'Service is live again' : 'Service paused and hidden from customers',
        );
      }
    } catch (e) {
      if (context.mounted) showErrorSnack(context, e);
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await confirmDialog(
      context,
      title: 'Delete service?',
      message: '"${listing.title}" will be removed permanently. Past requests and reviews are kept.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    try {
      await ref.read(marketplaceRepositoryProvider).deleteListing(listing.id);
      ref.invalidate(myListingsProvider);
      ref.invalidate(providerStatsProvider);
      if (context.mounted) showSnack(context, 'Service deleted');
    } catch (e) {
      if (context.mounted) showErrorSnack(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final removed = listing.status == ListingStatus.removed;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CategoryIcon(iconKey: listing.category?.icon, size: 44),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(listing.title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(
                        '${listing.category?.name ?? ''} · ${listing.serviceRadiusKm} km radius',
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          StatusPill(label: listing.status.label, color: listing.status.color),
                          RatingBadge(average: listing.ratingAverage, count: listing.ratingCount),
                        ],
                      ),
                    ],
                  ),
                ),
                Text(
                  Fmt.price(listing.price, listing.currency, listing.priceUnit),
                  style: theme.textTheme.titleMedium?.copyWith(color: AppColors.accent),
                ),
              ],
            ),
            if (removed) ...[
              const SizedBox(height: 12),
              InfoBanner(
                color: AppColors.danger,
                icon: Icons.gpp_bad_outlined,
                message: 'Removed by moderation: ${listing.removalReason ?? 'policy violation'}',
              ),
            ],
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 4),
            // Wraps onto a second line on narrow phones instead of overflowing.
            Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: () => context.push(Routes.service(listing.id)),
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  label: const Text('Preview'),
                ),
                if (!removed) ...[
                  TextButton.icon(
                    onPressed: () => _toggle(context, ref),
                    icon: Icon(
                      listing.status == ListingStatus.active ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      size: 18,
                    ),
                    label: Text(listing.status == ListingStatus.active ? 'Pause' : 'Activate'),
                  ),
                  TextButton.icon(
                    onPressed: () => context.push(Routes.editService(listing.id), extra: listing),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Edit'),
                  ),
                ],
                IconButton(
                  tooltip: 'Delete',
                  onPressed: () => _delete(context, ref),
                  icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
