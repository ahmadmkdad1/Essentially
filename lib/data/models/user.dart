import 'enums.dart';
import 'json_utils.dart';

class AppUser {
  const AppUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    required this.status,
    required this.createdAt,
    this.phone,
    this.statusReason,
    this.suspendedUntil,
    this.warningCount = 0,
    this.businessName,
    this.bio,
    this.latitude,
    this.longitude,
    this.address,
    this.lastLoginAt,
  });

  final String id;
  final String fullName;
  final String email;
  final String? phone;
  final Role role;
  final AccountStatus status;
  final String? statusReason;
  final DateTime? suspendedUntil;
  final int warningCount;
  final String? businessName;
  final String? bio;
  final double? latitude;
  final double? longitude;
  final String? address;
  final DateTime createdAt;
  final DateTime? lastLoginAt;

  bool get hasLocation => latitude != null && longitude != null;
  String get displayName => (businessName?.isNotEmpty ?? false) ? businessName! : fullName;

  factory AppUser.fromJson(Json json) => AppUser(
    id: json['id'] as String,
    fullName: json['fullName'] as String? ?? '',
    email: json['email'] as String? ?? '',
    phone: json['phone'] as String?,
    role: Role.parse(json['role']),
    status: AccountStatus.parse(json['status']),
    statusReason: json['statusReason'] as String?,
    suspendedUntil: toDateOrNull(json['suspendedUntil']),
    warningCount: toInt(json['warningCount']),
    businessName: json['businessName'] as String?,
    bio: json['bio'] as String?,
    latitude: toDoubleOrNull(json['latitude']),
    longitude: toDoubleOrNull(json['longitude']),
    address: json['address'] as String?,
    createdAt: toDate(json['createdAt']),
    lastLoginAt: toDateOrNull(json['lastLoginAt']),
  );
}

/// Provider details that are safe to show publicly.
class PublicProvider {
  const PublicProvider({
    required this.id,
    required this.fullName,
    this.businessName,
    this.phone,
    this.bio,
    this.address,
    this.createdAt,
    this.email,
    this.status,
  });

  final String id;
  final String fullName;
  final String? businessName;
  final String? phone;
  final String? bio;
  final String? address;
  final DateTime? createdAt;

  /// Only present in admin views.
  final String? email;
  final AccountStatus? status;

  String get displayName => (businessName?.isNotEmpty ?? false) ? businessName! : fullName;

  factory PublicProvider.fromJson(Json json) => PublicProvider(
    id: json['id'] as String,
    fullName: json['fullName'] as String? ?? '',
    businessName: json['businessName'] as String?,
    phone: json['phone'] as String?,
    bio: json['bio'] as String?,
    address: json['address'] as String?,
    createdAt: toDateOrNull(json['createdAt']),
    email: json['email'] as String?,
    status: json['status'] == null ? null : AccountStatus.parse(json['status']),
  );
}

class AuthSession {
  const AuthSession({required this.token, required this.user});
  final String token;
  final AppUser user;

  factory AuthSession.fromJson(Json json) =>
      AuthSession(token: json['accessToken'] as String, user: AppUser.fromJson(json['user'] as Json));
}
