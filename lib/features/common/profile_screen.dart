import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/dialogs.dart';
import '../../core/widgets/map_widgets.dart';
import '../../data/models/enums.dart';
import '../../data/models/user.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/location_repository.dart';
import '../auth/auth_controller.dart';
import 'location_picker_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _changeLocation(BuildContext context, WidgetRef ref, AppUser user) async {
    final picked = await context.push<PickedLocation>(
      Routes.pickLocation,
      extra: user.hasLocation ? PickedLocation(GeoPoint(user.latitude!, user.longitude!), user.address ?? '') : null,
    );
    if (picked == null || !context.mounted) return;
    try {
      final updated = await ref
          .read(authRepositoryProvider)
          .updateLocation(picked.point.latitude, picked.point.longitude, picked.label);
      ref.read(authControllerProvider.notifier).updateUser(updated);
      if (context.mounted) showSnack(context, 'Location updated');
    } catch (e) {
      if (context.mounted) showErrorSnack(context, e);
    }
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final ok = await confirmDialog(
      context,
      title: 'Sign out?',
      message: 'You will need to sign in again to use Essentially.',
      confirmLabel: 'Sign out',
    );
    if (ok) await ref.read(authControllerProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const Scaffold(body: LoadingState());
    final theme = Theme.of(context);
    final isProvider = user.role == Role.provider;

    return Scaffold(
      appBar: AppBar(title: Text(isProvider ? 'Business profile' : 'Account')),
      body: ContentWidth(
        maxWidth: 760,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Avatar(name: user.fullName, size: 64),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user.displayName, style: theme.textTheme.titleLarge),
                          if (isProvider && user.businessName != null)
                            Text(user.fullName, style: theme.textTheme.bodyMedium),
                          const SizedBox(height: 4),
                          Text(user.email, style: theme.textTheme.bodySmall),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              StatusPill(label: user.role.label, color: AppColors.primary),
                              if (user.warningCount > 0)
                                StatusPill(
                                  label: '${user.warningCount} warning${user.warningCount == 1 ? '' : 's'}',
                                  color: AppColors.warning,
                                  icon: Icons.warning_amber_rounded,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (user.warningCount > 0) ...[
              const SizedBox(height: 12),
              const InfoBanner(
                message: 'Your account has received moderation warnings. Further violations may lead to suspension.',
                color: AppColors.warning,
                icon: Icons.gpp_maybe_outlined,
              ),
            ],
            const SizedBox(height: 24),
            SectionHeader(
              'Details',
              trailing: TextButton.icon(
                onPressed:
                    () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => _EditProfileSheet(user: user),
                    ),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit'),
              ),
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Column(
                  children: [
                    KeyValueRow(icon: Icons.badge_outlined, label: 'Full name', value: user.fullName),
                    if (isProvider)
                      KeyValueRow(icon: Icons.storefront_outlined, label: 'Business', value: user.businessName ?? '—'),
                    KeyValueRow(icon: Icons.phone_outlined, label: 'Phone', value: user.phone ?? 'Not set'),
                    if (isProvider)
                      KeyValueRow(
                        icon: Icons.notes_rounded,
                        label: 'About',
                        value: (user.bio?.isNotEmpty ?? false) ? user.bio! : 'Tell customers about your business',
                      ),
                    KeyValueRow(
                      icon: Icons.calendar_today_outlined,
                      label: 'Member since',
                      value: Fmt.date(user.createdAt),
                    ),
                  ],
                ),
              ),
            ),
            if (user.role != Role.admin) ...[
              const SizedBox(height: 24),
              SectionHeader(
                isProvider ? 'Business location' : 'Home location',
                subtitle: isProvider ? 'Default location for new services' : 'Used to find services near you',
                trailing: TextButton.icon(
                  onPressed: () => _changeLocation(context, ref, user),
                  icon: const Icon(Icons.edit_location_alt_outlined, size: 18),
                  label: Text(user.hasLocation ? 'Change' : 'Set'),
                ),
              ),
              if (user.hasLocation) ...[
                MapPreview(latitude: user.latitude!, longitude: user.longitude!, height: 160),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.place_outlined, size: 18, color: AppColors.textMuted),
                    const SizedBox(width: 8),
                    Expanded(child: Text(user.address ?? '', style: theme.textTheme.bodyMedium)),
                  ],
                ),
              ] else
                InfoBanner(
                  message: 'No location set yet.',
                  action: TextButton(
                    onPressed: () => _changeLocation(context, ref, user),
                    child: const Text('Set now'),
                  ),
                ),
            ],
            const SizedBox(height: 24),
            const SectionHeader('Security & activity'),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.password_rounded),
                    title: const Text('Change password'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap:
                        () => showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          builder: (_) => const _ChangePasswordSheet(),
                        ),
                  ),
                  if (user.role != Role.admin) ...[
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.flag_outlined),
                      title: const Text('My reports'),
                      subtitle: const Text('Track the violations you reported'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => context.push(Routes.myReports),
                    ),
                  ],
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.logout_rounded, color: AppColors.danger),
                    title: const Text('Sign out', style: TextStyle(color: AppColors.danger)),
                    onTap: () => _logout(context, ref),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditProfileSheet extends ConsumerStatefulWidget {
  const _EditProfileSheet({required this.user});
  final AppUser user;

  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.user.fullName);
  late final _phone = TextEditingController(text: widget.user.phone ?? '');
  late final _business = TextEditingController(text: widget.user.businessName ?? '');
  late final _bio = TextEditingController(text: widget.user.bio ?? '');
  bool _saving = false;

  bool get _isProvider => widget.user.role == Role.provider;

  @override
  void dispose() {
    for (final c in [_name, _phone, _business, _bio]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final updated = await ref
          .read(authRepositoryProvider)
          .updateProfile(
            fullName: _name.text.trim(),
            phone: _phone.text.trim(),
            businessName: _isProvider ? _business.text.trim() : null,
            bio: _isProvider ? _bio.text.trim() : null,
          );
      ref.read(authControllerProvider.notifier).updateUser(updated);
      if (!mounted) return;
      Navigator.pop(context);
      showSnack(context, 'Profile updated');
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Edit profile', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 18),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Full name'),
                validator: (v) => Validators.minLength(v, 2, 'Full name'),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone'),
                validator: Validators.optionalPhone,
              ),
              if (_isProvider) ...[
                const SizedBox(height: 14),
                TextFormField(
                  controller: _business,
                  decoration: const InputDecoration(labelText: 'Business name'),
                  validator: (v) => Validators.required(v, 'Business name'),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _bio,
                  maxLines: 4,
                  maxLength: 1000,
                  decoration: const InputDecoration(labelText: 'About your business', alignLabelWithHint: true),
                ),
              ],
              const SizedBox(height: 16),
              LoadingButton(label: 'Save changes', loading: _saving, onPressed: _save),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChangePasswordSheet extends ConsumerStatefulWidget {
  const _ChangePasswordSheet();

  @override
  ConsumerState<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends ConsumerState<_ChangePasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_current, _next, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(authRepositoryProvider).changePassword(_current.text, _next.text);
      if (!mounted) return;
      Navigator.pop(context);
      showSnack(context, 'Password changed');
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Change password', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 18),
            TextFormField(
              controller: _current,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Current password'),
              validator: (v) => Validators.required(v, 'Current password'),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _next,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New password'),
              validator: Validators.password,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _confirm,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Confirm new password'),
              validator: (v) => v != _next.text ? 'Passwords do not match' : null,
            ),
            const SizedBox(height: 18),
            LoadingButton(label: 'Update password', loading: _saving, onPressed: _save),
          ],
        ),
      ),
    );
  }
}
