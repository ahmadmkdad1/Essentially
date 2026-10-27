import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/common.dart';
import '../../data/models/enums.dart';
import '../auth/auth_controller.dart';

class ShellDestination {
  const ShellDestination(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// Adaptive navigation: bottom bar on phones, side rail on tablets and web.
class RoleShell extends ConsumerWidget {
  const RoleShell({super.key, required this.navigationShell, required this.destinations, required this.roleLabel});

  final StatefulNavigationShell navigationShell;
  final List<ShellDestination> destinations;
  final String roleLabel;

  void _go(int index) => navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex);

  Widget _icon(ShellDestination d, bool selected) => Icon(selected ? d.selectedIcon : d.icon);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    if (!wide) {
      return Scaffold(
        body: navigationShell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: _go,
          destinations: [
            for (final d in destinations)
              NavigationDestination(icon: _icon(d, false), selectedIcon: _icon(d, true), label: d.label),
          ],
        ),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(right: BorderSide(color: AppColors.border)),
            ),
            child: NavigationRail(
              extended: MediaQuery.sizeOf(context).width >= 1200,
              minExtendedWidth: 230,
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: _go,
              leading: Padding(
                padding: const EdgeInsets.fromLTRB(8, 20, 8, 24),
                child: Column(
                  children: [
                    AppLogo(size: 36, showName: MediaQuery.sizeOf(context).width >= 1200),
                    const SizedBox(height: 10),
                    StatusPill(label: roleLabel, color: AppColors.primary),
                  ],
                ),
              ),
              trailing: Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: AccountMenu(showName: MediaQuery.sizeOf(context).width >= 1200),
                  ),
                ),
              ),
              destinations: [
                for (final d in destinations)
                  NavigationRailDestination(icon: _icon(d, false), selectedIcon: _icon(d, true), label: Text(d.label)),
              ],
            ),
          ),
          Expanded(child: navigationShell),
        ],
      ),
    );
  }
}

/// Small header greeting used at the top of role home screens.
class GreetingHeader extends ConsumerWidget {
  const GreetingHeader({super.key, required this.subtitle, this.trailing});
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good morning' : (hour < 18 ? 'Good afternoon' : 'Good evening');
    final firstName = (user?.fullName ?? '').split(' ').first;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$greeting${firstName.isEmpty ? '' : ', $firstName'}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
        if (trailing != null) trailing!,
        if (user != null && MediaQuery.sizeOf(context).width < 900) ...[const SizedBox(width: 8), const AccountMenu()],
      ],
    );
  }
}

/// Avatar that opens a menu with the account page and sign-out.
class AccountMenu extends ConsumerWidget {
  const AccountMenu({super.key, this.showName = false});
  final bool showName;

  String _accountRoute(Role role) => switch (role) {
    Role.user => Routes.account,
    Role.provider => Routes.business,
    Role.admin => Routes.adminAccount,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return PopupMenuButton<String>(
      tooltip: 'Account menu',
      position: PopupMenuPosition.under,
      color: AppColors.surfaceRaised,
      onSelected: (value) async {
        switch (value) {
          case 'account':
            final route = _accountRoute(user.role);
            user.role == Role.admin ? context.push(route) : context.go(route);
          case 'signOut':
            // The router redirects to the login screen once the session is cleared.
            await ref.read(authControllerProvider.notifier).logout();
        }
      },
      itemBuilder:
          (_) => [
            PopupMenuItem<String>(
              enabled: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.displayName, style: theme.textTheme.titleSmall?.copyWith(color: AppColors.textPrimary)),
                  Text('${user.role.label} · ${user.email}', style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'account',
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.manage_accounts_outlined),
                title: Text('My account'),
              ),
            ),
            const PopupMenuItem(
              value: 'signOut',
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.logout_rounded, color: AppColors.primary),
                title: Text('Sign out'),
              ),
            ),
          ],
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Avatar(name: user.fullName, size: 40),
            if (showName) ...[
              const SizedBox(width: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 130),
                child: Text(user.fullName, style: theme.textTheme.titleSmall, overflow: TextOverflow.ellipsis),
              ),
            ],
            const Icon(Icons.expand_more_rounded, size: 18, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
