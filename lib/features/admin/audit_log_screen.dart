import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/common.dart';
import '../../data/models/moderation.dart';
import 'admin_providers.dart';

class AuditLogScreen extends ConsumerWidget {
  const AuditLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final log = ref.watch(auditLogProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Audit log')),
      body: ContentWidth(
        maxWidth: 900,
        child: log.when(
          loading: () => const LoadingState(),
          error: (e, _) => ErrorState(error: e, onRetry: () => ref.invalidate(auditLogProvider)),
          data:
              (page) =>
                  page.items.isEmpty
                      ? const EmptyState(
                        icon: Icons.history_toggle_off_rounded,
                        title: 'No moderation actions yet',
                        message: 'Every warning, suspension, ban and removal will be recorded here.',
                      )
                      : RefreshIndicator(
                        onRefresh: () => ref.refresh(auditLogProvider.future),
                        child: ListView(
                          padding: const EdgeInsets.all(20),
                          children: [for (final e in page.items) AuditTile(entry: e, showAdmin: true)],
                        ),
                      ),
        ),
      ),
    );
  }
}

class AuditTile extends StatelessWidget {
  const AuditTile({super.key, required this.entry, this.showAdmin = false});
  final AuditEntry entry;
  final bool showAdmin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final e = entry;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: e.action.color.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                    border: Border.all(color: e.action.color.withValues(alpha: 0.4)),
                  ),
                  child: Icon(e.action.icon, size: 16, color: e.action.color),
                ),
                Expanded(child: Container(width: 1.5, color: AppColors.border)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(e.action.label, style: theme.textTheme.titleSmall?.copyWith(color: e.action.color)),
                      ),
                      Text(Fmt.relative(e.createdAt), style: theme.textTheme.bodySmall),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${e.targetType.toLowerCase()} · ${e.targetLabel}',
                    style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(e.reason, style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary)),
                  if (showAdmin && e.adminName != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'by ${e.adminName}${e.reportId != null ? ' · from a report' : ''}',
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
