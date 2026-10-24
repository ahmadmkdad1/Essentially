import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/dialogs.dart';
import '../../data/models/enums.dart';
import '../../data/models/listing.dart';
import '../../data/models/user.dart';
import '../../data/repositories/admin_repository.dart';
import 'admin_providers.dart';

Future<void> _run(BuildContext context, WidgetRef ref, Future<void> Function() action, String success) async {
  try {
    await action();
    invalidateAdminData(ref);
    if (context.mounted) showSnack(context, success);
  } catch (e) {
    if (context.mounted) showErrorSnack(context, e);
  }
}

Future<void> warnUser(BuildContext context, WidgetRef ref, AppUser user) async {
  final reason = await promptText(
    context,
    title: 'Warn ${user.fullName}',
    label: 'Reason',
    message: 'Warnings are recorded on the account and shown to the user.',
    confirmLabel: 'Send warning',
  );
  if (reason == null || !context.mounted) return;
  await _run(context, ref, () => ref.read(adminRepositoryProvider).warnUser(user.id, reason), 'Warning recorded');
}

Future<void> suspendUser(BuildContext context, WidgetRef ref, AppUser user) async {
  final result = await showDialog<({int days, String reason})>(
    context: context,
    builder: (_) => _SuspendDialog(name: user.fullName),
  );
  if (result == null || !context.mounted) return;
  await _run(
    context,
    ref,
    () => ref
        .read(adminRepositoryProvider)
        .setUserStatus(user.id, AccountStatus.suspended, result.reason, suspendDays: result.days),
    'Account suspended for ${result.days} days',
  );
}

Future<void> banUser(BuildContext context, WidgetRef ref, AppUser user) async {
  final reason = await promptText(
    context,
    title: 'Ban ${user.fullName}?',
    label: 'Reason',
    message: 'The account loses access immediately and its open requests are cancelled.',
    confirmLabel: 'Ban account',
    destructive: true,
  );
  if (reason == null || !context.mounted) return;
  await _run(
    context,
    ref,
    () => ref.read(adminRepositoryProvider).setUserStatus(user.id, AccountStatus.banned, reason),
    'Account banned',
  );
}

Future<void> reactivateUser(BuildContext context, WidgetRef ref, AppUser user) async {
  final reason = await promptText(
    context,
    title: 'Reactivate ${user.fullName}?',
    label: 'Reason',
    confirmLabel: 'Reactivate',
  );
  if (reason == null || !context.mounted) return;
  await _run(
    context,
    ref,
    () => ref.read(adminRepositoryProvider).setUserStatus(user.id, AccountStatus.active, reason),
    'Account reactivated',
  );
}

Future<void> toggleListingRemoval(BuildContext context, WidgetRef ref, Listing listing) async {
  final removing = listing.status != ListingStatus.removed;
  final reason = await promptText(
    context,
    title: removing ? 'Remove "${listing.title}"?' : 'Restore "${listing.title}"?',
    label: 'Reason',
    message:
        removing
            ? 'The service disappears from search and pending requests are cancelled. The provider sees your reason.'
            : 'The service becomes visible to customers again.',
    confirmLabel: removing ? 'Remove service' : 'Restore',
    destructive: removing,
  );
  if (reason == null || !context.mounted) return;
  final repo = ref.read(adminRepositoryProvider);
  await _run(
    context,
    ref,
    () => removing ? repo.removeListing(listing.id, reason) : repo.restoreListing(listing.id, reason),
    removing ? 'Service removed' : 'Service restored',
  );
}

class _SuspendDialog extends StatefulWidget {
  const _SuspendDialog({required this.name});
  final String name;

  @override
  State<_SuspendDialog> createState() => _SuspendDialogState();
}

class _SuspendDialogState extends State<_SuspendDialog> {
  final _formKey = GlobalKey<FormState>();
  final _reason = TextEditingController();
  int _days = 7;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Suspend ${widget.name}'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('The account cannot sign in until the suspension ends.'),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: [
                  for (final d in const [1, 3, 7, 14, 30])
                    ChoiceChip(
                      label: Text('$d day${d == 1 ? '' : 's'}'),
                      selected: _days == d,
                      onSelected: (_) => setState(() => _days = d),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: '$_days',
                key: ValueKey(_days),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'Custom length', suffixText: 'days'),
                onChanged: (v) => _days = int.tryParse(v) ?? _days,
                validator: (v) {
                  final d = int.tryParse(v ?? '');
                  return d == null || d < 1 || d > 365 ? 'Between 1 and 365 days' : null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _reason,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Reason', alignLabelWithHint: true),
                validator: (v) => (v?.trim().length ?? 0) < 3 ? 'Please give a reason' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.warning, minimumSize: const Size(0, 44)),
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context, (days: _days, reason: _reason.text.trim()));
            }
          },
          child: const Text('Suspend'),
        ),
      ],
    );
  }
}
