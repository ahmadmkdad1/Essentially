import 'enums.dart';
import 'json_utils.dart';
import 'user.dart';

/// A report as seen by the person who filed it.
class MyReport {
  const MyReport({
    required this.id,
    required this.targetType,
    required this.reason,
    required this.details,
    required this.status,
    required this.actionTaken,
    required this.createdAt,
    this.resolutionNote,
    this.resolvedAt,
    this.targetLabel,
  });

  final String id;
  final ReportTargetType targetType;
  final ReportReason reason;
  final String details;
  final ReportStatus status;
  final ModerationAction actionTaken;
  final String? resolutionNote;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final String? targetLabel;

  factory MyReport.fromJson(Json json) => MyReport(
    id: json['id'] as String,
    targetType: ReportTargetType.parse(json['targetType']),
    reason: ReportReason.parse(json['reason']),
    details: json['details'] as String? ?? '',
    status: ReportStatus.parse(json['status']),
    actionTaken: ModerationAction.parse(json['actionTaken']),
    resolutionNote: json['resolutionNote'] as String?,
    createdAt: toDate(json['createdAt']),
    resolvedAt: toDateOrNull(json['resolvedAt']),
    targetLabel: json['targetLabel'] as String?,
  );
}

class ReportedUser {
  const ReportedUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    required this.status,
    required this.warningCount,
    required this.openReports,
    this.businessName,
  });

  final String id;
  final String fullName;
  final String? businessName;
  final String email;
  final Role role;
  final AccountStatus status;
  final int warningCount;
  final int openReports;

  String get displayName => (businessName?.isNotEmpty ?? false) ? '$businessName ($fullName)' : fullName;

  factory ReportedUser.fromJson(Json json) => ReportedUser(
    id: json['id'] as String,
    fullName: json['fullName'] as String? ?? '',
    businessName: json['businessName'] as String?,
    email: json['email'] as String? ?? '',
    role: Role.parse(json['role']),
    status: AccountStatus.parse(json['status']),
    warningCount: toInt(json['warningCount']),
    openReports: toInt(json['openReports']),
  );
}

class AdminReport {
  const AdminReport({
    required this.id,
    required this.targetType,
    required this.reason,
    required this.details,
    required this.status,
    required this.actionTaken,
    required this.createdAt,
    required this.reporterName,
    required this.reporterEmail,
    required this.reporterRole,
    required this.targetUser,
    this.resolutionNote,
    this.resolvedAt,
    this.resolvedByName,
    this.listingId,
    this.listingTitle,
    this.listingStatus,
    this.listingPrice,
    this.reviewId,
    this.reviewRating,
    this.reviewComment,
    this.reviewHidden,
    this.history = const [],
  });

  final String id;
  final ReportTargetType targetType;
  final ReportReason reason;
  final String details;
  final ReportStatus status;
  final ModerationAction actionTaken;
  final String? resolutionNote;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final String? resolvedByName;
  final String reporterName;
  final String reporterEmail;
  final Role reporterRole;
  final ReportedUser targetUser;
  final String? listingId;
  final String? listingTitle;
  final ListingStatus? listingStatus;
  final String? listingPrice;
  final String? reviewId;
  final int? reviewRating;
  final String? reviewComment;
  final bool? reviewHidden;
  final List<AuditEntry> history;

  factory AdminReport.fromJson(Json json) {
    final reporter = json['reporter'] as Json? ?? const {};
    final listing = json['targetListing'] as Json?;
    final review = json['targetReview'] as Json?;
    return AdminReport(
      id: json['id'] as String,
      targetType: ReportTargetType.parse(json['targetType']),
      reason: ReportReason.parse(json['reason']),
      details: json['details'] as String? ?? '',
      status: ReportStatus.parse(json['status']),
      actionTaken: ModerationAction.parse(json['actionTaken']),
      resolutionNote: json['resolutionNote'] as String?,
      createdAt: toDate(json['createdAt']),
      resolvedAt: toDateOrNull(json['resolvedAt']),
      resolvedByName: (json['resolvedBy'] as Json?)?['fullName'] as String?,
      reporterName: reporter['fullName'] as String? ?? '',
      reporterEmail: reporter['email'] as String? ?? '',
      reporterRole: Role.parse(reporter['role']),
      targetUser: ReportedUser.fromJson(json['targetUser'] as Json),
      listingId: listing?['id'] as String?,
      listingTitle: listing?['title'] as String?,
      listingStatus: listing == null ? null : ListingStatus.parse(listing['status']),
      listingPrice:
          listing == null ? null : '${toDouble(listing['price']).toStringAsFixed(2)} ${listing['currency'] ?? 'USD'}',
      reviewId: review?['id'] as String?,
      reviewRating: review == null ? null : toInt(review['rating']),
      reviewComment: review?['comment'] as String?,
      reviewHidden: review?['isHidden'] as bool?,
      history: (json['targetUserHistory'] as List? ?? const []).map((e) => AuditEntry.fromJson(e as Json)).toList(),
    );
  }
}

class AuditEntry {
  const AuditEntry({
    required this.id,
    required this.action,
    required this.targetType,
    required this.targetId,
    required this.targetLabel,
    required this.reason,
    required this.createdAt,
    this.adminName,
    this.reportId,
  });

  final String id;
  final ModerationAction action;
  final String targetType;
  final String targetId;
  final String targetLabel;
  final String reason;
  final DateTime createdAt;
  final String? adminName;
  final String? reportId;

  factory AuditEntry.fromJson(Json json) => AuditEntry(
    id: json['id'] as String,
    action: ModerationAction.parse(json['action']),
    targetType: json['targetType'] as String? ?? '',
    targetId: json['targetId'] as String? ?? '',
    targetLabel: json['targetLabel'] as String? ?? '',
    reason: json['reason'] as String? ?? '',
    createdAt: toDate(json['createdAt']),
    adminName: (json['admin'] as Json?)?['fullName'] as String?,
    reportId: json['reportId'] as String?,
  );
}

class AdminStats {
  const AdminStats({
    required this.usersByRole,
    required this.usersByStatus,
    required this.newUsersThisWeek,
    required this.listingsByStatus,
    required this.requestsByStatus,
    required this.requestsThisWeek,
    required this.reportsByStatus,
    required this.reportsThisWeek,
  });

  final Map<Role, int> usersByRole;
  final Map<AccountStatus, int> usersByStatus;
  final int newUsersThisWeek;
  final Map<ListingStatus, int> listingsByStatus;
  final Map<RequestStatus, int> requestsByStatus;
  final int requestsThisWeek;
  final Map<ReportStatus, int> reportsByStatus;
  final int reportsThisWeek;

  int get totalUsers => usersByRole.values.fold(0, (a, b) => a + b);
  int get totalRequests => requestsByStatus.values.fold(0, (a, b) => a + b);
  int get totalListings => listingsByStatus.values.fold(0, (a, b) => a + b);

  factory AdminStats.fromJson(Json json) {
    Map<E, int> read<E extends Enum>(Object? m, List<E> values, String Function(E) key) => {
      for (final v in values) v: toInt(m is Map ? m[key(v)] : null),
    };
    Map section(String key) => json[key] is Map ? json[key] as Map : const {};
    final users = section('users');
    final listings = section('listings');
    final requests = section('requests');
    final reports = section('reports');
    return AdminStats(
      usersByRole: read(users['byRole'], Role.values, (r) => r.api),
      usersByStatus: read(users['byStatus'], AccountStatus.values, (s) => s.api),
      newUsersThisWeek: toInt(users['newThisWeek']),
      listingsByStatus: read(listings['byStatus'], ListingStatus.values, (s) => s.api),
      requestsByStatus: read(requests['byStatus'], RequestStatus.values, (s) => s.api),
      requestsThisWeek: toInt(requests['newThisWeek']),
      reportsByStatus: read(reports['byStatus'], ReportStatus.values, (s) => s.api),
      reportsThisWeek: toInt(reports['newThisWeek']),
    );
  }
}

class AdminUserRow {
  const AdminUserRow({required this.user, required this.openReports});
  final AppUser user;
  final int openReports;

  factory AdminUserRow.fromJson(Json json) =>
      AdminUserRow(user: AppUser.fromJson(json), openReports: toInt(json['openReports']));
}
