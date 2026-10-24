import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/dialogs.dart';
import '../../data/models/enums.dart';
import '../common/location_picker_screen.dart';
import 'auth_controller.dart';
import 'auth_layout.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _business = TextEditingController();
  Role _role = Role.user;
  PickedLocation? _location;
  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _password, _business]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickLocation() async {
    final picked = await context.push<PickedLocation>(Routes.pickLocation, extra: _location);
    if (picked != null) setState(() => _location = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .register(
            fullName: _name.text,
            email: _email.text,
            password: _password.text,
            role: _role,
            phone: _phone.text,
            businessName: _role == Role.provider ? _business.text : null,
            latitude: _location?.point.latitude,
            longitude: _location?.point.longitude,
            address: _location?.label,
          );
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isProvider = _role == Role.provider;

    return AuthLayout(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => context.go(Routes.login),
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text('Back to sign in'),
              ),
            ),
            const SizedBox(height: 8),
            Text('Create your account', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 6),
            Text('Choose how you want to use Essentially.', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: _RoleCard(
                    selected: !isProvider,
                    icon: Icons.home_outlined,
                    title: 'Customer',
                    subtitle: 'Find & request services near me',
                    onTap: () => setState(() => _role = Role.user),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _RoleCard(
                    selected: isProvider,
                    icon: Icons.storefront_outlined,
                    title: 'Provider',
                    subtitle: 'Offer my services & get jobs',
                    onTap: () => setState(() => _role = Role.provider),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            TextFormField(
              controller: _name,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.badge_outlined)),
              validator: (v) => Validators.minLength(v, 2, 'Full name'),
            ),
            if (isProvider) ...[
              const SizedBox(height: 14),
              TextFormField(
                controller: _business,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Business name',
                  prefixIcon: Icon(Icons.business_center_outlined),
                ),
                validator: (v) => Validators.required(v, 'Business name'),
              ),
            ],
            const SizedBox(height: 14),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.alternate_email_rounded)),
              validator: Validators.email,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: isProvider ? 'Business phone' : 'Phone (optional)',
                prefixIcon: const Icon(Icons.phone_outlined),
              ),
              validator:
                  (v) =>
                      isProvider && (v == null || v.trim().isEmpty)
                          ? 'Customers need a number to reach you'
                          : Validators.optionalPhone(v),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _password,
              obscureText: _obscure,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: 'Password',
                helperText: 'At least 8 characters, with a letter and a number',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: Validators.password,
            ),
            const SizedBox(height: 18),
            _LocationTile(location: _location, isProvider: isProvider, onTap: _pickLocation),
            const SizedBox(height: 24),
            LoadingButton(label: 'Create account', loading: _loading, onPressed: _submit),
          ],
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF0E3B2E) : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: selected ? AppColors.primary : AppColors.border, width: selected ? 1.5 : 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: selected ? AppColors.primary : AppColors.textSecondary),
                  const Spacer(),
                  Icon(
                    selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                    size: 18,
                    color: selected ? AppColors.primary : AppColors.textMuted,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(subtitle, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocationTile extends StatelessWidget {
  const _LocationTile({required this.location, required this.isProvider, required this.onTap});
  final PickedLocation? location;
  final bool isProvider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasLocation = location != null;
    return Card(
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Icon(
          hasLocation ? Icons.location_on_rounded : Icons.add_location_alt_outlined,
          color: hasLocation ? AppColors.primary : AppColors.textSecondary,
        ),
        title: Text(
          hasLocation ? location!.label : (isProvider ? 'Business location' : 'Home location'),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall,
        ),
        subtitle: Text(
          hasLocation
              ? 'Tap to change'
              : 'Recommended — used to show ${isProvider ? 'your services to nearby customers' : 'services close to you'}',
          style: theme.textTheme.bodySmall,
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}
