import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/back_or_home.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/common.dart';
import '../../data/models/enums.dart';
import '../../data/models/listing.dart';
import '../../data/repositories/marketplace_repository.dart';
import '../auth/auth_controller.dart';
import '../common/report_sheet.dart';
import 'listing_card.dart';
import 'service_details_screen.dart';

final providerProfileProvider = FutureProvider.autoDispose.family<ProviderProfile, String>(
  (ref, id) => ref.watch(marketplaceRepositoryProvider).providerProfile(id),
);

class ProviderProfileScreen extends ConsumerWidget {
  const ProviderProfileScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(providerProfileProvider(id));
    final me = ref.watch(currentUserProvider);
    final canReport = me != null && me.role != Role.admin && me.id != id;

    return Scaffold(
      appBar: AppBar(
        leading: const BackOrHomeButton(),
        title: const Text('Provider'),
        actions: [
          if (canReport && profile.hasValue)
            IconButton(
              tooltip: 'Report this provider',
              icon: const Icon(Icons.flag_outlined),
              onPressed:
                  () => showReportSheet(
                    context,
                    targetType: ReportTargetType.user,
                    targetId: id,
                    targetLabel: profile.requireValue.provider.displayName,
                  ),
            ),
        ],
      ),
      body: profile.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(error: e, onRetry: () => ref.invalidate(providerProfileProvider(id))),
        data: (p) {
          final theme = Theme.of(context);
          return ContentWidth(
            maxWidth: 860,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
              children: [
                Row(
                  children: [
                    Avatar(name: p.provider.displayName, size: 68),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.provider.displayName, style: theme.textTheme.headlineSmall),
                          Text(p.provider.fullName, style: theme.textTheme.bodyMedium),
                          if (p.provider.createdAt != null)
                            Text(
                              'On Essentially since ${Fmt.date(p.provider.createdAt!)}',
                              style: theme.textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        label: 'Rating',
                        value: p.ratingAverage?.toStringAsFixed(1) ?? '—',
                        caption: '${p.ratingCount} reviews',
                        icon: Icons.star_rounded,
                        color: AppColors.accent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatCard(
                        label: 'Jobs done',
                        value: '${p.completedJobs}',
                        caption: 'via Essentially',
                        icon: Icons.task_alt_rounded,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatCard(
                        label: 'Services',
                        value: '${p.listings.length}',
                        caption: 'currently active',
                        icon: Icons.storefront_outlined,
                        color: AppColors.info,
                      ),
                    ),
                  ],
                ),
                if ((p.provider.bio ?? '').isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text('About', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(p.provider.bio!, style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary)),
                ],
                const SizedBox(height: 16),
                if (p.provider.phone != null)
                  KeyValueRow(icon: Icons.phone_outlined, label: 'Phone', value: p.provider.phone!),
                if (p.provider.address != null)
                  KeyValueRow(icon: Icons.place_outlined, label: 'Based in', value: p.provider.address!),
                const SizedBox(height: 24),
                const SectionHeader('Services'),
                if (p.listings.isEmpty)
                  Text('No active services right now.', style: theme.textTheme.bodyMedium)
                else
                  for (final l in p.listings)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ListingCard(listing: l, onTap: () => context.push(Routes.service(l.id))),
                    ),
                const SizedBox(height: 12),
                const SectionHeader('Latest reviews'),
                if (p.reviews.isEmpty)
                  Text('No reviews yet.', style: theme.textTheme.bodyMedium)
                else
                  for (final r in p.reviews) ReviewTile(review: r, showListing: true),
              ],
            ),
          );
        },
      ),
    );
  }
}
