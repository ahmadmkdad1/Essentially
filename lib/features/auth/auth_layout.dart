import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/common.dart';

/// Split layout for auth screens: brand panel on wide screens, form only on phones.
class AuthLayout extends StatelessWidget {
  const AuthLayout({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 960;
    final form = Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440), child: child),
      ),
    );

    if (!wide) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: AppColors.heroGradient),
          child: SafeArea(child: form),
        ),
      );
    }

    return Scaffold(
      body: Row(children: [const Expanded(flex: 5, child: _BrandPanel()), Expanded(flex: 6, child: form)]),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0E3B2E), Color(0xFF0A1A16), AppColors.background],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      // Fills the height when there is room, scrolls when the window is short.
      child: LayoutBuilder(
        builder:
            (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.all(56),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: (constraints.maxHeight - 112).clamp(0, double.infinity)),
                child: _content(theme),
              ),
            ),
      ),
    );
  }

  /// Logo, pitch and footer pushed apart; a min-height column grows with the
  /// window without needing intrinsic measurement.
  Widget _content(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppLogo(size: 44),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Essential home services,\nright around the corner.',
                style: theme.textTheme.headlineMedium?.copyWith(height: 1.2, fontSize: 34),
              ),
              const SizedBox(height: 16),
              Text(
                'Find trusted gas, water, electricity, internet and maintenance providers near you — '
                'compare prices, request in seconds and track every job.',
                style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 40),
              const _Feature(
                icon: Icons.near_me_rounded,
                title: 'Location-aware search',
                text: 'Services sorted by real distance from you.',
              ),
              const _Feature(
                icon: Icons.verified_user_outlined,
                title: 'Moderated marketplace',
                text: 'Admins act on every reported violation.',
              ),
              const _Feature(
                icon: Icons.bolt_rounded,
                title: 'Fast responses',
                text: 'Providers accept or decline requests instantly.',
              ),
            ],
          ),
        ),
        Text('© ${DateTime.now().year} Essentially', style: theme.textTheme.bodySmall),
      ],
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.title, required this.text});
  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                Text(text, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
