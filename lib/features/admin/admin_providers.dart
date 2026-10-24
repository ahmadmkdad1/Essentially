import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/enums.dart';
import '../../data/models/json_utils.dart';
import '../../data/models/listing.dart';
import '../../data/models/moderation.dart';
import '../../data/repositories/admin_repository.dart';

final adminStatsProvider = FutureProvider.autoDispose<AdminStats>((ref) => ref.watch(adminRepositoryProvider).stats());

/// `null` status means "all reports".
final adminReportsProvider = FutureProvider.autoDispose.family<Paginated<AdminReport>, ReportStatus?>(
  (ref, status) => ref.watch(adminRepositoryProvider).reports(status: status),
);

final adminReportProvider = FutureProvider.autoDispose.family<AdminReport, String>(
  (ref, id) => ref.watch(adminRepositoryProvider).report(id),
);

typedef UserFilter = ({Role? role, AccountStatus? status, String search});

final adminUsersProvider = FutureProvider.autoDispose.family<Paginated<AdminUserRow>, UserFilter>(
  (ref, f) => ref
      .watch(adminRepositoryProvider)
      .users(role: f.role, status: f.status, search: f.search.isEmpty ? null : f.search),
);

final adminUserProvider = FutureProvider.autoDispose.family<AdminUserDetail, String>(
  (ref, id) => ref.watch(adminRepositoryProvider).user(id),
);

typedef ListingFilter = ({ListingStatus? status, String search});

final adminListingsProvider = FutureProvider.autoDispose.family<Paginated<Listing>, ListingFilter>(
  (ref, f) => ref.watch(adminRepositoryProvider).listings(status: f.status, search: f.search.isEmpty ? null : f.search),
);

final auditLogProvider = FutureProvider.autoDispose<Paginated<AuditEntry>>(
  (ref) => ref.watch(adminRepositoryProvider).auditLog(),
);

/// Refresh every admin view after a moderation action so counts stay in sync.
void invalidateAdminData(WidgetRef ref) {
  ref.invalidate(adminStatsProvider);
  ref.invalidate(adminReportsProvider);
  ref.invalidate(adminReportProvider);
  ref.invalidate(adminUsersProvider);
  ref.invalidate(adminUserProvider);
  ref.invalidate(adminListingsProvider);
  ref.invalidate(auditLogProvider);
}
