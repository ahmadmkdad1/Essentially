import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/dialogs.dart';
import 'auth_controller.dart';
import 'auth_layout.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  static const _demoAccounts = [
    (label: 'Customer', icon: Icons.person_outline_rounded, email: 'user@essentially.app', password: 'Demo@1234'),
    (label: 'Provider', icon: Icons.storefront_outlined, email: 'provider@essentially.app', password: 'Demo@1234'),
    (label: 'Admin', icon: Icons.shield_outlined, email: 'admin@essentially.app', password: 'Admin@12345'),
  ];

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref.read(authControllerProvider.notifier).login(_email.text, _password.text);
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final notice = ref.watch(sessionNoticeProvider);

    return AuthLayout(
      child: Form(
        key: _formKey,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (MediaQuery.sizeOf(context).width < 960) ...[
                const Center(child: AppLogo(size: 44)),
                const SizedBox(height: 36),
              ],
              Text('Welcome back', style: theme.textTheme.headlineMedium),
              const SizedBox(height: 6),
              Text('Sign in to find services or manage your business.', style: theme.textTheme.bodyMedium),
              const SizedBox(height: 28),
              if (notice != null) ...[
                InfoBanner(message: notice, color: AppColors.warning, icon: Icons.gpp_maybe_outlined),
                const SizedBox(height: 20),
              ],
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.alternate_email_rounded)),
                validator: Validators.email,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _password,
                obscureText: _obscure,
                autofillHints: const [AutofillHints.password],
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    tooltip: _obscure ? 'Show password' : 'Hide password',
                    icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: (v) => Validators.required(v, 'Password'),
              ),
              const SizedBox(height: 24),
              LoadingButton(label: 'Sign in', loading: _loading, onPressed: _submit),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('New to Essentially?', style: theme.textTheme.bodyMedium),
                  TextButton(onPressed: () => context.go(Routes.register), child: const Text('Create an account')),
                ],
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('Try a demo account', style: theme.textTheme.bodySmall),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final demo in _demoAccounts)
                    ActionChip(
                      avatar: Icon(demo.icon, size: 18, color: AppColors.primary),
                      label: Text(demo.label),
                      onPressed:
                          _loading
                              ? null
                              : () {
                                _email.text = demo.email;
                                _password.text = demo.password;
                                _submit();
                              },
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
