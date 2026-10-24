import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/common.dart';
import '../../data/models/enums.dart';
import '../../data/models/service_request.dart';
import '../auth/auth_controller.dart';
import '../common/request_card.dart';
import '../shell/role_shell.dart';
import 'provider_providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(providerStatsProvider);
    final requests = ref.watch(incomingRequestsProvider);
    final user = ref.watch(currentUserProvider);
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 1200 ? 4 : (width >= 640 ? 3 : 2);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            refreshProviderData(ref);
            await ref.read(providerStatsProvider.future);
          },
          child: ContentWidth(
            maxWidth: 1200,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                GreetingHeader(
                  subtitle: user?.businessName ?? 'Here is how your business is doing',
                  trailing:
                      width >= 640
                          ? FilledButton.icon(
                            onPressed: () => context.push(Routes.newService),
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('New service'),
                          )
                          : null,
                ),
                if (user != null && !user.hasLocation) ...[
                  const SizedBox(height: 16),
                  InfoBanner(
                    color: AppColors.warning,
                    icon: Icons.location_off_outlined,
                    message: 'Set your business location so customers nearby can find you.',
                    action: TextButton(onPressed: () => context.go(Routes.business), child: const Text('Set')),
                  ),
                ],
                const SizedBox(height: 20),
                stats.when(
                  loading: () => const SizedBox(height: 200, child: LoadingState()),
                  error: (e, _) => ErrorState(error: e, onRetry: () => ref.invalidate(providerStatsProvider)),
                  data:
                      (s) => StatGrid(
                        columns: columns,
                        children: [
                          StatCard(
                            label: 'New requests',
                            value: '${s.count(RequestStatus.pending)}',
                            icon: Icons.notifications_active_outlined,
                            color: AppColors.warning,
                            caption: s.count(RequestStatus.pending) > 0 ? 'Needs your response' : null,
                            onTap: () => context.go(Routes.jobs),
                          ),
                          StatCard(
                            label: 'Active jobs',
                            value: '${s.count(RequestStatus.accepted)}',
                            icon: Icons.handshake_outlined,
                            color: AppColors.info,
                            onTap: () => context.go(Routes.jobs),
                          ),
                          StatCard(
                            label: 'Earned (completed)',
                            value: Fmt.money(s.completedRevenue),
                            icon: Icons.payments_outlined,
                            color: AppColors.accent,
                            caption: '${s.count(RequestStatus.completed)} jobs',
                          ),
                          StatCard(
                            label: 'Rating',
                            value: s.ratingAverage?.toStringAsFixed(1) ?? '—',
                            icon: Icons.star_rounded,
                            color: AppColors.accent,
                            caption: '${s.ratingCount} reviews',
                          ),
                          StatCard(
                            label: 'Acceptance rate',
                            value: Fmt.percent(s.acceptanceRate),
                            icon: Icons.trending_up_rounded,
                            color: AppColors.success,
                          ),
                          StatCard(
                            label: 'Live services',
                            value: '${s.activeListings}/${s.totalListings}',
                            icon: Icons.storefront_outlined,
                            color: AppColors.violet,
                            onTap: () => context.go(Routes.myServices),
                          ),
                        ],
                      ),
                ),
                const SizedBox(height: 28),
                SectionHeader(
                  'Needs your response',
                  subtitle: 'Accept or decline new requests quickly to keep a high acceptance rate',
                  trailing: TextButton(onPressed: () => context.go(Routes.jobs), child: const Text('See all')),
                ),
                requests.when(
                  loading: () => const SizedBox(height: 120, child: LoadingState()),
                  error: (e, _) => ErrorState(error: e, onRetry: () => ref.invalidate(incomingRequestsProvider)),
                  data: (page) {
                    final pending = page.items.where((r) => r.status == RequestStatus.pending).take(5).toList();
                    if (pending.isEmpty) {
                      return const Card(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: EmptyState(
                            icon: Icons.inbox_outlined,
                            title: 'You are all caught up',
                            message: 'New requests from nearby customers will appear here.',
                          ),
                        ),
                      );
                    }
                    return Column(
                      children: [
                        for (final ServiceRequest r in pending)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: RequestCard(
                              request: r,
                              counterpartName: r.customer?.name ?? 'Customer',
                              counterpartPhone: r.customer?.phone,
                              showDistance: true,
                              actions: providerRequestActions(context, ref, r),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton:
          width < 640
              ? FloatingActionButton(
                onPressed: () => context.push(Routes.newService),
                tooltip: 'New service',
                child: const Icon(Icons.add_rounded),
              )
              : null,
    );
  }
}
