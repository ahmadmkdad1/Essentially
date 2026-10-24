import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/common.dart';
import '../../data/models/enums.dart';
import '../../data/models/listing.dart';
import '../customer/listing_card.dart';
import 'admin_providers.dart';
import 'moderation_actions.dart';

class ServicesModerationScreen extends ConsumerStatefulWidget {
  const ServicesModerationScreen({super.key});

  @override
  ConsumerState<ServicesModerationScreen> createState() => _ServicesModerationScreenState();
}

class _ServicesModerationScreenState extends ConsumerState<ServicesModerationScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  ListingStatus? _status;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filter = (status: _status, search: _query);
    final listings = ref.watch(adminListingsProvider(filter));

    return Scaffold(
      appBar: AppBar(title: const Text('Services')),
      body: ContentWidth(
        maxWidth: 960,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
              child: TextField(
                controller: _search,
                onChanged: (v) {
                  _debounce?.cancel();
                  _debounce = Timer(const Duration(milliseconds: 400), () => setState(() => _query = v.trim()));
                },
                decoration: const InputDecoration(
                  hintText: 'Search services or providers',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  for (final s in [null, ...ListingStatus.values])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(s?.label ?? 'All'),
                        selected: _status == s,
                        onSelected: (_) => setState(() => _status = s),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: listings.when(
                loading: () => const LoadingState(),
                error: (e, _) => ErrorState(error: e, onRetry: () => ref.invalidate(adminListingsProvider(filter))),
                data:
                    (page) =>
                        page.items.isEmpty
                            ? const EmptyState(icon: Icons.search_off_rounded, title: 'No services match')
                            : ListView(
                              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                              children: [for (final l in page.items) AdminListingTile(listing: l)],
                            ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AdminListingTile extends ConsumerWidget {
  const AdminListingTile({super.key, required this.listing, this.showProvider = true});
  final Listing listing;
  final bool showProvider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l = listing;
    final removed = l.status == ListingStatus.removed;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CategoryIcon(iconKey: l.category?.icon, size: 42),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.title, style: theme.textTheme.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(
                      [
                        Fmt.price(l.price, l.currency, l.priceUnit),
                        if (showProvider && l.provider != null) l.provider!.displayName,
                        Fmt.date(l.createdAt),
                      ].join(' · '),
                      style: theme.textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        StatusPill(label: l.status.label, color: l.status.color),
                        if (l.openReports > 0)
                          StatusPill(
                            label: '${l.openReports} open report(s)',
                            color: AppColors.danger,
                            icon: Icons.flag_rounded,
                          ),
                        if (showProvider && l.provider?.status != null && l.provider!.status != AccountStatus.active)
                          StatusPill(
                            label: 'Provider ${l.provider!.status!.label.toLowerCase()}',
                            color: l.provider!.status!.color,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Actions',
                onSelected: (action) {
                  switch (action) {
                    case 'view':
                      context.push(Routes.service(l.id));
                    case 'provider':
                      context.push(Routes.adminUser(l.providerId));
                    case 'toggle':
                      toggleListingRemoval(context, ref, l);
                  }
                },
                itemBuilder:
                    (_) => [
                      const PopupMenuItem(value: 'view', child: Text('View service')),
                      if (showProvider) const PopupMenuItem(value: 'provider', child: Text('View provider')),
                      PopupMenuItem(
                        value: 'toggle',
                        child: Text(
                          removed ? 'Restore service' : 'Remove service',
                          style: TextStyle(color: removed ? AppColors.success : AppColors.danger),
                        ),
                      ),
                    ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
