import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/common.dart';
import '../../data/models/enums.dart';
import '../../data/models/moderation.dart';
import '../shell/role_shell.dart';
import 'admin_providers.dart';
import 'reports_screen.dart';

class AdminOverviewScreen extends ConsumerWidget {
  const AdminOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(adminStatsProvider);
    final openReports = ref.watch(adminReportsProvider(ReportStatus.open));
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 1200 ? 4 : (width >= 640 ? 3 : 2);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => invalidateAdminData(ref),
          child: ContentWidth(
            maxWidth: 1200,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                const GreetingHeader(subtitle: 'Platform health and violations that need attention'),
                const SizedBox(height: 20),
                stats.when(
                  loading: () => const SizedBox(height: 240, child: LoadingState()),
                  error: (e, _) => ErrorState(error: e, onRetry: () => ref.invalidate(adminStatsProvider)),
                  data:
                      (s) => Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (s.reportsByStatus[ReportStatus.open]! > 0) ...[
                            InfoBanner(
                              color: AppColors.warning,
                              icon: Icons.report_gmailerrorred_rounded,
                              message: '${s.reportsByStatus[ReportStatus.open]} open report(s) are waiting for review.',
                              action: TextButton(
                                onPressed: () => context.go(Routes.adminReports),
                                child: const Text('Review'),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          StatGrid(
                            columns: columns,
                            children: [
                              StatCard(
                                label: 'Open reports',
                                value: '${s.reportsByStatus[ReportStatus.open]}',
                                icon: Icons.flag_outlined,
                                color: AppColors.danger,
                                caption: '${s.reportsThisWeek} this week',
                                onTap: () => context.go(Routes.adminReports),
                              ),
                              StatCard(
                                label: 'Customers',
                                value: '${s.usersByRole[Role.user]}',
                                icon: Icons.people_outline_rounded,
                                color: AppColors.info,
                                caption: '${s.totalUsers} accounts in total',
                                onTap: () => context.go(Routes.adminUsers),
                              ),
                              StatCard(
                                label: 'Providers',
                                value: '${s.usersByRole[Role.provider]}',
                                icon: Icons.storefront_outlined,
                                color: AppColors.violet,
                                caption: '+${s.newUsersThisWeek} sign-ups this week',
                                onTap: () => context.go(Routes.adminUsers),
                              ),
                              StatCard(
                                label: 'Live services',
                                value: '${s.listingsByStatus[ListingStatus.active]}',
                                icon: Icons.home_repair_service_outlined,
                                color: AppColors.primary,
                                caption: '${s.listingsByStatus[ListingStatus.removed]} removed',
                                onTap: () => context.go(Routes.adminServices),
                              ),
                              StatCard(
                                label: 'Requests',
                                value: '${s.totalRequests}',
                                icon: Icons.receipt_long_outlined,
                                color: AppColors.accent,
                                caption: '${s.requestsThisWeek} this week',
                              ),
                              StatCard(
                                label: 'Restricted accounts',
                                value:
                                    '${s.usersByStatus[AccountStatus.suspended]! + s.usersByStatus[AccountStatus.banned]!}',
                                icon: Icons.gpp_bad_outlined,
                                color: AppColors.warning,
                                caption: '${s.usersByStatus[AccountStatus.banned]} banned',
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          LayoutBuilder(
                            builder: (context, c) {
                              final wide = c.maxWidth >= 760;
                              final requests = _Breakdown(
                                title: 'Requests by status',
                                entries: [
                                  for (final st in RequestStatus.values)
                                    (label: st.label, value: s.requestsByStatus[st]!, color: st.color),
                                ],
                              );
                              final reports = _Breakdown(
                                title: 'Reports by outcome',
                                entries: [
                                  for (final st in ReportStatus.values)
                                    (label: st.label, value: s.reportsByStatus[st]!, color: st.color),
                                ],
                              );
                              return wide
                                  ? Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(child: requests),
                                      const SizedBox(width: 12),
                                      Expanded(child: reports),
                                    ],
                                  )
                                  : Column(children: [requests, const SizedBox(height: 12), reports]);
                            },
                          ),
                        ],
                      ),
                ),
                const SizedBox(height: 28),
                SectionHeader(
                  'Oldest open reports',
                  subtitle: 'Handled first-in, first-out',
                  trailing: TextButton(
                    onPressed: () => context.go(Routes.adminReports),
                    child: const Text('Open queue'),
                  ),
                ),
                openReports.when(
                  loading: () => const SizedBox(height: 120, child: LoadingState()),
                  error: (e, _) => ErrorState(error: e),
                  data:
                      (page) =>
                          page.items.isEmpty
                              ? const Card(
                                child: EmptyState(
                                  icon: Icons.verified_outlined,
                                  title: 'Queue is clear',
                                  message: 'No violations are waiting for review.',
                                ),
                              )
                              : Column(
                                children: [
                                  for (final AdminReport r in page.items.take(5))
                                    Padding(padding: const EdgeInsets.only(bottom: 12), child: ReportTile(report: r)),
                                ],
                              ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Breakdown extends StatelessWidget {
  const _Breakdown({required this.title, required this.entries});
  final String title;
  final List<({String label, int value, Color color})> entries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = entries.fold<int>(0, (a, e) => a + e.value);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleSmall),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 10,
                child:
                    total == 0
                        ? Container(color: AppColors.border)
                        : Row(
                          children: [
                            for (final e in entries)
                              if (e.value > 0) Expanded(flex: e.value, child: Container(color: e.color)),
                          ],
                        ),
              ),
            ),
            const SizedBox(height: 14),
            for (final e in entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Container(width: 10, height: 10, decoration: BoxDecoration(color: e.color, shape: BoxShape.circle)),
                    const SizedBox(width: 10),
                    Expanded(child: Text(e.label, style: theme.textTheme.bodyMedium)),
                    Text('${e.value}', style: theme.textTheme.titleSmall),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
