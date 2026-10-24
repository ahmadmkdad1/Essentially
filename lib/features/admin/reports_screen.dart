import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/common.dart';
import '../../data/models/enums.dart';
import '../../data/models/moderation.dart';
import 'admin_providers.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  ReportStatus? _status = ReportStatus.open;

  @override
  Widget build(BuildContext context) {
    final reports = ref.watch(adminReportsProvider(_status));
    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: ContentWidth(
        maxWidth: 960,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  for (final s in [ReportStatus.open, ReportStatus.resolved, ReportStatus.dismissed, null])
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
            Expanded(
              child: reports.when(
                loading: () => const LoadingState(),
                error: (e, _) => ErrorState(error: e, onRetry: () => ref.invalidate(adminReportsProvider(_status))),
                data:
                    (page) =>
                        page.items.isEmpty
                            ? EmptyState(
                              icon: Icons.verified_outlined,
                              title: _status == ReportStatus.open ? 'No open reports' : 'Nothing to show',
                              message: _status == ReportStatus.open ? 'Great — the community is behaving.' : null,
                            )
                            : RefreshIndicator(
                              onRefresh: () => ref.refresh(adminReportsProvider(_status).future),
                              child: ListView.separated(
                                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                                itemCount: page.items.length,
                                separatorBuilder: (_, _) => const SizedBox(height: 12),
                                itemBuilder: (context, i) => ReportTile(report: page.items[i]),
                              ),
                            ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ReportTile extends StatelessWidget {
  const ReportTile({super.key, required this.report});
  final AdminReport report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = report;
    final repeat = r.targetUser.openReports > 1;
    final subject = switch (r.targetType) {
      ReportTargetType.listing => r.listingTitle ?? 'Service',
      ReportTargetType.review => 'Review by ${r.targetUser.fullName}',
      ReportTargetType.user => r.targetUser.displayName,
    };

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(Routes.adminReport(r.id)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(r.targetType.icon, color: AppColors.danger, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            r.reason.label,
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        StatusPill(label: r.status.label, color: r.status.color),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${r.targetType.label}: $subject',
                      style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(r.details, style: theme.textTheme.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text('By ${r.reporterName} · ${Fmt.relative(r.createdAt)}', style: theme.textTheme.labelSmall),
                        if (repeat)
                          StatusPill(
                            label: '${r.targetUser.openReports} open reports on this account',
                            color: AppColors.danger,
                            icon: Icons.repeat_rounded,
                          ),
                        if (r.targetUser.warningCount > 0)
                          StatusPill(label: '${r.targetUser.warningCount} prior warning(s)', color: AppColors.warning),
                        if (r.status != ReportStatus.open)
                          StatusPill(label: r.actionTaken.label, color: r.actionTaken.color, icon: r.actionTaken.icon),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
