import '../../data/models/enums.dart';

abstract final class Routes {
  static const splash = '/splash';
  static const login = '/login';
  static const register = '/register';

  // Customer
  static const explore = '/explore';
  static const requests = '/requests';
  static const account = '/account';

  // Provider
  static const dashboard = '/dashboard';
  static const jobs = '/jobs';
  static const myServices = '/my-services';
  static const newService = '/my-services/new';
  static String editService(String id) => '/my-services/$id/edit';
  static const business = '/business';

  // Admin
  static const adminOverview = '/moderation/overview';
  static const adminReports = '/moderation/reports';
  static String adminReport(String id) => '/moderation/reports/$id';
  static const adminUsers = '/moderation/users';
  static String adminUser(String id) => '/moderation/users/$id';
  static const adminServices = '/moderation/services';
  static const adminAudit = '/moderation/audit';
  static const adminAccount = '/admin-account';

  // Shared
  static String service(String id) => '/service/$id';
  static String provider(String id) => '/providers/$id';
  static const pickLocation = '/pick-location';
  static const myReports = '/my-reports';

  static String home(Role role) => switch (role) {
    Role.user => explore,
    Role.provider => dashboard,
    Role.admin => adminOverview,
  };

  static const _shared = ['/service/', '/providers/', pickLocation];

  static const _byRole = {
    Role.user: [explore, requests, account, myReports],
    Role.provider: [dashboard, jobs, myServices, business, myReports],
    Role.admin: ['/moderation', adminAccount],
  };

  /// Whether a signed-in user with [role] may open [location].
  static bool allowed(Role role, String location) {
    bool matches(String prefix) =>
        location == prefix || location.startsWith(prefix.endsWith('/') ? prefix : '$prefix/');
    return _shared.any(matches) || _byRole[role]!.any(matches);
  }
}
