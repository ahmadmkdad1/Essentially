import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../models/enums.dart';
import '../models/json_utils.dart';
import '../models/listing.dart';
import '../models/moderation.dart';
import '../models/user.dart';

class UserReportSummary {
  const UserReportSummary({
    required this.id,
    required this.reason,
    required this.status,
    required this.details,
    required this.createdAt,
    required this.targetType,
  });

  final String id;
  final ReportReason reason;
  final ReportStatus status;
  final String details;
  final DateTime createdAt;
  final ReportTargetType targetType;

  factory UserReportSummary.fromJson(Json json) => UserReportSummary(
    id: json['id'] as String,
    reason: ReportReason.parse(json['reason']),
    status: ReportStatus.parse(json['status']),
    details: json['details'] as String? ?? '',
    createdAt: toDate(json['createdAt']),
    targetType: ReportTargetType.parse(json['targetType']),
  );
}

class AdminUserDetail {
  const AdminUserDetail({
    required this.user,
    required this.listings,
    required this.totalRequests,
    required this.reportsFiled,
    required this.reportsAgainst,
    required this.history,
  });

  final AppUser user;
  final List<Listing> listings;
  final int totalRequests;
  final int reportsFiled;
  final List<UserReportSummary> reportsAgainst;
  final List<AuditEntry> history;

  factory AdminUserDetail.fromJson(Json json) {
    final totals = json['totals'] as Json? ?? const {};
    return AdminUserDetail(
      user: AppUser.fromJson(json['user'] as Json),
      listings: (json['listings'] as List? ?? const []).map((e) => Listing.fromJson(e as Json)).toList(),
      totalRequests: toInt(totals['requests']),
      reportsFiled: toInt(totals['reportsFiled']),
      reportsAgainst:
          (json['reportsAgainst'] as List? ?? const []).map((e) => UserReportSummary.fromJson(e as Json)).toList(),
      history: (json['history'] as List? ?? const []).map((e) => AuditEntry.fromJson(e as Json)).toList(),
    );
  }
}

class AdminRepository {
  AdminRepository(this._api);
  final ApiClient _api;

  Future<AdminStats> stats() async => AdminStats.fromJson(await _api.get<Json>('/admin/stats'));

  Future<Paginated<AdminReport>> reports({ReportStatus? status, int page = 1}) async {
    final json = await _api.get<Json>('/admin/reports', query: {'status': status?.api, 'page': page, 'limit': 50});
    return Paginated.fromJson(json, AdminReport.fromJson);
  }

  Future<AdminReport> report(String id) async => AdminReport.fromJson(await _api.get<Json>('/admin/reports/$id'));

  Future<AdminReport> resolveReport(
    String id, {
    required ModerationAction action,
    required String note,
    int? suspendDays,
  }) async {
    final json = await _api.post<Json>(
      '/admin/reports/$id/resolve',
      body: {'action': action.api, 'note': note.trim(), if (suspendDays != null) 'suspendDays': suspendDays},
    );
    return AdminReport.fromJson(json);
  }

  Future<Paginated<AdminUserRow>> users({Role? role, AccountStatus? status, String? search, int page = 1}) async {
    final json = await _api.get<Json>(
      '/admin/users',
      query: {'role': role?.api, 'status': status?.api, 'q': search, 'page': page, 'limit': 50},
    );
    return Paginated.fromJson(json, AdminUserRow.fromJson);
  }

  Future<AdminUserDetail> user(String id) async => AdminUserDetail.fromJson(await _api.get<Json>('/admin/users/$id'));

  Future<void> setUserStatus(String id, AccountStatus status, String reason, {int? suspendDays}) async {
    await _api.patch<Json>(
      '/admin/users/$id/status',
      body: {'status': status.api, 'reason': reason.trim(), if (suspendDays != null) 'suspendDays': suspendDays},
    );
  }

  Future<void> warnUser(String id, String reason) async {
    await _api.post<Json>('/admin/users/$id/warn', body: {'reason': reason.trim()});
  }

  Future<Paginated<Listing>> listings({ListingStatus? status, String? search, int page = 1}) async {
    final json = await _api.get<Json>(
      '/admin/services',
      query: {'status': status?.api, 'q': search, 'page': page, 'limit': 50},
    );
    return Paginated.fromJson(json, Listing.fromJson);
  }

  Future<void> removeListing(String id, String reason) async {
    await _api.patch<Json>('/admin/services/$id/remove', body: {'reason': reason.trim()});
  }

  Future<void> restoreListing(String id, String reason) async {
    await _api.patch<Json>('/admin/services/$id/restore', body: {'reason': reason.trim()});
  }

  Future<Paginated<AuditEntry>> auditLog({int page = 1}) async {
    final json = await _api.get<Json>('/admin/audit-log', query: {'page': page, 'limit': 50});
    return Paginated.fromJson(json, AuditEntry.fromJson);
  }
}

final adminRepositoryProvider = Provider<AdminRepository>((ref) => AdminRepository(ref.watch(apiClientProvider)));
