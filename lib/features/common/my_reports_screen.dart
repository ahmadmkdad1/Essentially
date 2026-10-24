import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/back_or_home.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/common.dart';
import '../../data/models/enums.dart';
import '../../data/models/json_utils.dart';
import '../../data/models/moderation.dart';
import '../../data/repositories/marketplace_repository.dart';

final myReportsProvider = FutureProvider.autoDispose<Paginated<MyReport>>(
  (ref) => ref.watch(marketplaceRepositoryProvider).myReports(),
);

class MyReportsScreen extends ConsumerWidget {
  const MyReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reports = ref.watch(myReportsProvider);
    return Scaffold(
      appBar: AppBar(leading: const BackOrHomeButton(), title: const Text('My reports')),
      body: ContentWidth(
        maxWidth: 760,
        child: reports.when(
          loading: () => const LoadingState(),
          error: (e, _) => ErrorState(error: e, onRetry: () => ref.invalidate(myReportsProvider)),
          data:
              (page) =>
                  page.items.isEmpty
                      ? const EmptyState(
                        icon: Icons.verified_user_outlined,
                        title: 'No reports yet',
                        message: 'If something goes wrong with a service or account, use the flag icon to report it.',
                      )
                      : RefreshIndicator(
                        onRefresh: () => ref.refresh(myReportsProvider.future),
                        child: ListView.separated(
                          padding: const EdgeInsets.all(20),
                          itemCount: page.items.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (context, i) => _ReportCard(report: page.items[i]),
                        ),
                      ),
        ),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report});
  final MyReport report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(report.targetType.icon, size: 20, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    report.targetLabel ?? report.targetType.label,
                    style: theme.textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                StatusPill(label: report.status.label, color: report.status.color),
              ],
            ),
            const SizedBox(height: 8),
            Text('${report.reason.label} · ${Fmt.relative(report.createdAt)}', style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            Text(report.details, style: theme.textTheme.bodyMedium),
            if (report.status != ReportStatus.open) ...[
              const SizedBox(height: 12),
              InfoBanner(
                color: report.status.color,
                icon: report.actionTaken.icon,
                message:
                    report.actionTaken == ModerationAction.none
                        ? 'Reviewed — no violation found.'
                        : 'Action taken: ${report.actionTaken.label}.',
              ),
            ],
          ],
        ),
      ),
    );
  }
}
