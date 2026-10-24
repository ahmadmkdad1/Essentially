import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/back_or_home.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/dialogs.dart';
import '../../data/models/enums.dart';
import '../../data/models/moderation.dart';
import '../../data/repositories/admin_repository.dart';
import 'admin_providers.dart';
import 'audit_log_screen.dart';

class ReportDetailScreen extends ConsumerWidget {
  const ReportDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(adminReportProvider(id));
    return Scaffold(
      appBar: AppBar(leading: const BackOrHomeButton(), title: const Text('Report')),
      body: report.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(error: e, onRetry: () => ref.invalidate(adminReportProvider(id))),
        data:
            (r) => LayoutBuilder(
              builder: (context, c) {
                final details = _ReportDetails(report: r);
                final panel = r.status == ReportStatus.open ? _ActionPanel(report: r) : _Outcome(report: r);
                if (c.maxWidth >= 1000) {
                  return ContentWidth(
                    maxWidth: 1200,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: ListView(padding: const EdgeInsets.all(20), children: [details])),
                        SizedBox(
                          width: 400,
                          child: ListView(padding: const EdgeInsets.fromLTRB(0, 20, 20, 20), children: [panel]),
                        ),
                      ],
                    ),
                  );
                }
                return ContentWidth(
                  maxWidth: 820,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [details, const SizedBox(height: 20), panel],
                  ),
                );
              },
            ),
      ),
    );
  }
}

class _ReportDetails extends StatelessWidget {
  const _ReportDetails({required this.report});
  final AdminReport report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = report;
    final t = r.targetUser;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(r.reason.label, style: theme.textTheme.headlineSmall)),
            StatusPill(label: r.status.label, color: r.status.color),
          ],
        ),
        const SizedBox(height: 6),
        Text('${r.targetType.label} report · filed ${Fmt.dateTime(r.createdAt)}', style: theme.textTheme.bodySmall),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Reporter statement', style: theme.textTheme.labelMedium?.copyWith(color: AppColors.textMuted)),
                const SizedBox(height: 8),
                Text(r.details, style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.textPrimary)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Avatar(name: r.reporterName, size: 30, color: AppColors.info),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${r.reporterName} · ${r.reporterRole.label} · ${r.reporterEmail}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        const SectionHeader('Reported account'),
        Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => context.push(Routes.adminUser(t.id)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Avatar(name: t.fullName, color: AppColors.danger),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.displayName, style: theme.textTheme.titleSmall),
                        Text('${t.role.label} · ${t.email}', style: theme.textTheme.bodySmall),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            StatusPill(label: t.status.label, color: t.status.color),
                            StatusPill(
                              label: '${t.openReports} open report(s)',
                              color: t.openReports > 1 ? AppColors.danger : AppColors.textSecondary,
                            ),
                            StatusPill(
                              label: '${t.warningCount} warning(s)',
                              color: t.warningCount > 0 ? AppColors.warning : AppColors.textSecondary,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
          ),
        ),
        if (r.listingId != null) ...[
          const SizedBox(height: 20),
          const SectionHeader('Service involved'),
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              leading: const Icon(Icons.storefront_outlined),
              title: Text(r.listingTitle ?? ''),
              subtitle: Text(r.listingPrice ?? ''),
              trailing:
                  r.listingStatus == null
                      ? null
                      : StatusPill(label: r.listingStatus!.label, color: r.listingStatus!.color),
              onTap: () => context.push(Routes.service(r.listingId!)),
            ),
          ),
        ],
        if (r.reviewId != null) ...[
          const SizedBox(height: 20),
          const SectionHeader('Review in question'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      StarRow(rating: r.reviewRating ?? 0),
                      const Spacer(),
                      if (r.reviewHidden == true) const StatusPill(label: 'Hidden', color: AppColors.violet),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '"${r.reviewComment ?? ''}"',
                    style: theme.textTheme.bodyLarge?.copyWith(fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (r.history.isNotEmpty) ...[
          const SizedBox(height: 20),
          const SectionHeader('Moderation history for this account'),
          for (final e in r.history) AuditTile(entry: e),
        ],
      ],
    );
  }
}

class _ActionPanel extends ConsumerStatefulWidget {
  const _ActionPanel({required this.report});
  final AdminReport report;

  @override
  ConsumerState<_ActionPanel> createState() => _ActionPanelState();
}

class _ActionPanelState extends ConsumerState<_ActionPanel> {
  final _note = TextEditingController();
  final _days = TextEditingController(text: '7');
  late ModerationAction _action;
  bool _saving = false;

  List<ModerationAction> get _actions {
    final r = widget.report;
    return [
      ModerationAction.none,
      ModerationAction.warnUser,
      if (r.listingId != null && r.targetType == ReportTargetType.listing && r.listingStatus != ListingStatus.removed)
        ModerationAction.removeListing,
      if (r.reviewId != null && r.reviewHidden != true) ModerationAction.removeReview,
      if (r.targetUser.status != AccountStatus.banned) ModerationAction.suspendUser,
      if (r.targetUser.status != AccountStatus.banned) ModerationAction.banUser,
    ];
  }

  @override
  void initState() {
    super.initState();
    _action = switch (widget.report.targetType) {
      ReportTargetType.listing => ModerationAction.removeListing,
      ReportTargetType.review => ModerationAction.removeReview,
      ReportTargetType.user => ModerationAction.warnUser,
    };
    if (!_actions.contains(_action)) _action = ModerationAction.warnUser;
  }

  @override
  void dispose() {
    _note.dispose();
    _days.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final note = _note.text.trim();
    if (note.length < 3) {
      showSnack(context, 'Add a short note explaining the decision', error: true);
      return;
    }
    final days = int.tryParse(_days.text);
    if (_action == ModerationAction.suspendUser && (days == null || days < 1 || days > 365)) {
      showSnack(context, 'Suspension must be between 1 and 365 days', error: true);
      return;
    }
    if (_action == ModerationAction.banUser) {
      final ok = await confirmDialog(
        context,
        title: 'Ban ${widget.report.targetUser.fullName}?',
        message: 'The account will lose access immediately and all of its open requests will be cancelled.',
        confirmLabel: 'Ban account',
        destructive: true,
      );
      if (!ok) return;
    }

    setState(() => _saving = true);
    try {
      await ref
          .read(adminRepositoryProvider)
          .resolveReport(
            widget.report.id,
            action: _action,
            note: note,
            suspendDays: _action == ModerationAction.suspendUser ? days : null,
          );
      invalidateAdminData(ref);
      if (mounted) {
        showSnack(context, _action == ModerationAction.none ? 'Report dismissed' : 'Action applied: ${_action.label}');
      }
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Take action', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('Every decision is recorded in the audit log.', style: theme.textTheme.bodySmall),
            const SizedBox(height: 14),
            for (final a in _actions)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: _action == a ? a.color.withValues(alpha: 0.08) : AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _action == a ? a.color.withValues(alpha: 0.6) : AppColors.border),
                ),
                child: RadioListTile<ModerationAction>(
                  value: a,
                  groupValue: _action,
                  onChanged: (v) => setState(() => _action = v ?? _action),
                  dense: true,
                  activeColor: a.color,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  secondary: Icon(a.icon, color: a.color),
                  title: Text(a.label),
                ),
              ),
            if (_action == ModerationAction.suspendUser) ...[
              const SizedBox(height: 6),
              TextField(
                controller: _days,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'Suspension length (days)', suffixText: 'days'),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              maxLines: 3,
              maxLength: 1000,
              decoration: const InputDecoration(
                labelText: 'Decision note',
                hintText: 'Why this action was taken (visible in the audit log)',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 8),
            LoadingButton(
              label: _action == ModerationAction.none ? 'Dismiss report' : 'Apply: ${_action.label}',
              loading: _saving,
              onPressed: _submit,
              color: _action == ModerationAction.banUser ? AppColors.danger : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _Outcome extends StatelessWidget {
  const _Outcome({required this.report});
  final AdminReport report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = report;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Outcome', style: theme.textTheme.titleMedium),
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(r.actionTaken.icon, color: r.actionTaken.color),
                const SizedBox(width: 10),
                Text(r.actionTaken.label, style: theme.textTheme.titleSmall?.copyWith(color: r.actionTaken.color)),
              ],
            ),
            if (r.resolutionNote != null) ...[
              const SizedBox(height: 12),
              Text(r.resolutionNote!, style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary)),
            ],
            const SizedBox(height: 12),
            Text(
              'By ${r.resolvedByName ?? 'admin'}${r.resolvedAt == null ? '' : ' · ${Fmt.dateTime(r.resolvedAt!)}'}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
