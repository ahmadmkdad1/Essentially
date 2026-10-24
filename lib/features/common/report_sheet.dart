import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/dialogs.dart';
import '../../data/models/enums.dart';
import '../../data/repositories/marketplace_repository.dart';

/// Lets customers and providers flag a violation for the admin team.
Future<void> showReportSheet(
  BuildContext context, {
  required ReportTargetType targetType,
  required String targetId,
  required String targetLabel,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ReportSheet(targetType: targetType, targetId: targetId, targetLabel: targetLabel),
  );
}

class _ReportSheet extends ConsumerStatefulWidget {
  const _ReportSheet({required this.targetType, required this.targetId, required this.targetLabel});
  final ReportTargetType targetType;
  final String targetId;
  final String targetLabel;

  @override
  ConsumerState<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends ConsumerState<_ReportSheet> {
  final _formKey = GlobalKey<FormState>();
  final _details = TextEditingController();
  ReportReason _reason = ReportReason.misleadingPricing;
  bool _sending = false;

  List<ReportReason> get _reasons => switch (widget.targetType) {
    ReportTargetType.review => const [
      ReportReason.harassment,
      ReportReason.inappropriateContent,
      ReportReason.spam,
      ReportReason.other,
    ],
    _ => ReportReason.values,
  };

  @override
  void initState() {
    super.initState();
    _reason = _reasons.first;
  }

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(marketplaceRepositoryProvider)
          .report(targetType: widget.targetType, targetId: widget.targetId, reason: _reason, details: _details.text);
      if (!mounted) return;
      Navigator.pop(context);
      showSnack(context, 'Report sent. Our moderators will review it shortly.');
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.flag_outlined, color: AppColors.danger),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Report ${widget.targetType.label.toLowerCase()}', style: theme.textTheme.titleLarge),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(widget.targetLabel, style: theme.textTheme.bodyMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 18),
              Text('What is the problem?', style: theme.textTheme.titleSmall),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final r in _reasons)
                    ChoiceChip(
                      label: Text(r.label),
                      selected: _reason == r,
                      onSelected: (_) => setState(() => _reason = r),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _details,
                maxLines: 4,
                maxLength: 2000,
                decoration: const InputDecoration(
                  labelText: 'Details',
                  hintText: 'Describe what happened so moderators can act on it.',
                  alignLabelWithHint: true,
                ),
                validator: (v) => (v?.trim().length ?? 0) < 10 ? 'Please give at least 10 characters of detail' : null,
              ),
              const SizedBox(height: 8),
              const InfoBanner(
                message: 'False reports may lead to action on your own account.',
                icon: Icons.shield_outlined,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: 16),
              LoadingButton(label: 'Submit report', loading: _sending, onPressed: _submit, color: AppColors.danger),
            ],
          ),
        ),
      ),
    );
  }
}
