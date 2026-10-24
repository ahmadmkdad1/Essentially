import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/listing.dart';
import '../../data/repositories/marketplace_repository.dart';
import '../../features/admin/admin_overview_screen.dart';
import '../../features/admin/audit_log_screen.dart';
import '../../features/admin/report_detail_screen.dart';
import '../../features/admin/reports_screen.dart';
import '../../features/admin/services_moderation_screen.dart';
import '../../features/admin/user_detail_screen.dart';
import '../../features/admin/users_screen.dart';
import '../../features/auth/auth_controller.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/register_screen.dart';
import '../../features/auth/splash_screen.dart';
import '../../features/common/location_picker_screen.dart';
import '../../features/common/my_reports_screen.dart';
import '../../features/common/profile_screen.dart';
import '../../features/customer/explore_screen.dart';
import '../../features/customer/my_requests_screen.dart';
import '../../features/customer/provider_profile_screen.dart';
import '../../features/customer/service_details_screen.dart';
import '../../features/provider/dashboard_screen.dart';
import '../../features/provider/my_services_screen.dart';
import '../../features/provider/provider_requests_screen.dart';
import '../../features/provider/service_form_screen.dart';
import '../../features/shell/role_shell.dart';
import '../widgets/common.dart';
import 'routes.dart';

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

GoRoute _route(String path, Widget Function(GoRouterState s) build) =>
    GoRoute(path: path, pageBuilder: (context, state) => NoTransitionPage(key: state.pageKey, child: build(state)));

GoRoute _pushed(String path, Widget Function(GoRouterState s) build) =>
    GoRoute(path: path, parentNavigatorKey: _rootKey, builder: (context, state) => build(state));

final routerProvider = Provider<GoRouter>((ref) {
  // Re-run redirects whenever the auth state changes.
  final refresh = ValueNotifier<int>(0);
  ref.listen(authControllerProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final location = state.matchedLocation;
      // Remember deep links across the splash and login screens.
      final from = state.uri.queryParameters['from'];
      String withFrom(String target) {
        final next = from ?? state.uri.toString();
        final keep = next != Routes.splash && !next.startsWith(Routes.login) && next != '/';
        return keep ? Uri(path: target, queryParameters: {'from': next}).toString() : target;
      }

      if (!auth.hasValue) {
        return location == Routes.splash ? null : withFrom(Routes.splash);
      }

      final user = auth.value;
      final onAuthPage = location == Routes.login || location == Routes.register;
      if (user == null) {
        if (onAuthPage || location == Routes.pickLocation) return null;
        return withFrom(Routes.login);
      }
      if (onAuthPage || location == Routes.splash) {
        if (from != null && Routes.allowed(user.role, Uri.parse(from).path)) return from;
        return Routes.home(user.role);
      }
      if (!Routes.allowed(user.role, location)) return Routes.home(user.role);
      return null;
    },
    routes: [
      GoRoute(path: Routes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(path: Routes.login, builder: (_, _) => const LoginScreen()),
      GoRoute(path: Routes.register, builder: (_, _) => const RegisterScreen()),

      // Customer ---------------------------------------------------------------
      StatefulShellRoute.indexedStack(
        builder:
            (context, state, shell) => RoleShell(
              navigationShell: shell,
              roleLabel: 'Customer',
              destinations: const [
                ShellDestination('Explore', Icons.explore_outlined, Icons.explore_rounded),
                ShellDestination('Requests', Icons.receipt_long_outlined, Icons.receipt_long_rounded),
                ShellDestination('Account', Icons.person_outline_rounded, Icons.person_rounded),
              ],
            ),
        branches: [
          StatefulShellBranch(routes: [_route(Routes.explore, (_) => const ExploreScreen())]),
          StatefulShellBranch(routes: [_route(Routes.requests, (_) => const MyRequestsScreen())]),
          StatefulShellBranch(routes: [_route(Routes.account, (_) => const ProfileScreen())]),
        ],
      ),

      // Provider ---------------------------------------------------------------
      StatefulShellRoute.indexedStack(
        builder:
            (context, state, shell) => RoleShell(
              navigationShell: shell,
              roleLabel: 'Provider',
              destinations: const [
                ShellDestination('Dashboard', Icons.space_dashboard_outlined, Icons.space_dashboard_rounded),
                ShellDestination('Jobs', Icons.work_outline_rounded, Icons.work_rounded),
                ShellDestination('Services', Icons.storefront_outlined, Icons.storefront_rounded),
                ShellDestination('Business', Icons.business_outlined, Icons.business_rounded),
              ],
            ),
        branches: [
          StatefulShellBranch(routes: [_route(Routes.dashboard, (_) => const DashboardScreen())]),
          StatefulShellBranch(routes: [_route(Routes.jobs, (_) => const ProviderRequestsScreen())]),
          StatefulShellBranch(routes: [_route(Routes.myServices, (_) => const MyServicesScreen())]),
          StatefulShellBranch(routes: [_route(Routes.business, (_) => const ProfileScreen())]),
        ],
      ),
      _pushed(Routes.newService, (_) => const ServiceFormScreen()),
      _pushed('/my-services/:id/edit', (s) {
        final extra = s.extra;
        return extra is Listing ? ServiceFormScreen(existing: extra) : _EditServiceLoader(id: s.pathParameters['id']!);
      }),

      // Admin ------------------------------------------------------------------
      StatefulShellRoute.indexedStack(
        builder:
            (context, state, shell) => RoleShell(
              navigationShell: shell,
              roleLabel: 'Admin',
              destinations: const [
                ShellDestination('Overview', Icons.insights_outlined, Icons.insights_rounded),
                ShellDestination('Reports', Icons.flag_outlined, Icons.flag_rounded),
                ShellDestination('Users', Icons.group_outlined, Icons.group_rounded),
                ShellDestination('Services', Icons.storefront_outlined, Icons.storefront_rounded),
                ShellDestination('Audit', Icons.history_rounded, Icons.history_rounded),
              ],
            ),
        branches: [
          StatefulShellBranch(routes: [_route(Routes.adminOverview, (_) => const AdminOverviewScreen())]),
          StatefulShellBranch(routes: [_route(Routes.adminReports, (_) => const ReportsScreen())]),
          StatefulShellBranch(routes: [_route(Routes.adminUsers, (_) => const UsersScreen())]),
          StatefulShellBranch(routes: [_route(Routes.adminServices, (_) => const ServicesModerationScreen())]),
          StatefulShellBranch(routes: [_route(Routes.adminAudit, (_) => const AuditLogScreen())]),
        ],
      ),
      _pushed('/moderation/reports/:id', (s) => ReportDetailScreen(id: s.pathParameters['id']!)),
      _pushed('/moderation/users/:id', (s) => UserDetailScreen(id: s.pathParameters['id']!)),
      _pushed(Routes.adminAccount, (_) => const ProfileScreen()),

      // Shared -----------------------------------------------------------------
      _pushed('/service/:id', (s) => ServiceDetailsScreen(id: s.pathParameters['id']!)),
      _pushed('/providers/:id', (s) => ProviderProfileScreen(id: s.pathParameters['id']!)),
      _pushed(Routes.myReports, (_) => const MyReportsScreen()),
      _pushed(
        Routes.pickLocation,
        (s) => LocationPickerScreen(initial: s.extra is PickedLocation ? s.extra as PickedLocation : null),
      ),
    ],
  );
});

/// Deep-link fallback when the edit screen is opened without the listing in memory.
class _EditServiceLoader extends ConsumerWidget {
  const _EditServiceLoader({required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<Listing>(
      future: ref.read(marketplaceRepositoryProvider).listing(id),
      builder: (context, snap) {
        if (snap.hasData) return ServiceFormScreen(existing: snap.data);
        return Scaffold(appBar: AppBar(), body: snap.hasError ? ErrorState(error: snap.error!) : const LoadingState());
      },
    );
  }
}
