import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../models/enums.dart';
import '../models/json_utils.dart';
import '../models/user.dart';

class AuthRepository {
  AuthRepository(this._api);
  final ApiClient _api;

  Future<AuthSession> login(String email, String password) async {
    final json = await _api.post<Json>('/auth/login', body: {'email': email.trim(), 'password': password});
    return AuthSession.fromJson(json);
  }

  Future<AuthSession> register({
    required String fullName,
    required String email,
    required String password,
    required Role role,
    String? phone,
    String? businessName,
    double? latitude,
    double? longitude,
    String? address,
  }) async {
    final json = await _api.post<Json>(
      '/auth/register',
      body: {
        'fullName': fullName.trim(),
        'email': email.trim(),
        'password': password,
        'role': role.api,
        if (phone != null && phone.isNotEmpty) 'phone': phone.trim(),
        if (businessName != null && businessName.isNotEmpty) 'businessName': businessName.trim(),
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (address != null && address.isNotEmpty) 'address': address,
      },
    );
    return AuthSession.fromJson(json);
  }

  Future<AppUser> me() async => AppUser.fromJson(await _api.get<Json>('/users/me'));

  Future<AppUser> updateProfile({String? fullName, String? phone, String? businessName, String? bio}) async {
    final json = await _api.patch<Json>(
      '/users/me',
      body: {
        if (fullName != null) 'fullName': fullName,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (businessName != null) 'businessName': businessName,
        if (bio != null) 'bio': bio,
      },
    );
    return AppUser.fromJson(json);
  }

  Future<AppUser> updateLocation(double latitude, double longitude, String address) async {
    final json = await _api.patch<Json>(
      '/users/me/location',
      body: {'latitude': latitude, 'longitude': longitude, 'address': address},
    );
    return AppUser.fromJson(json);
  }

  Future<void> changePassword(String current, String next) async {
    await _api.patch<dynamic>('/users/me/password', body: {'currentPassword': current, 'newPassword': next});
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository(ref.watch(apiClientProvider)));
