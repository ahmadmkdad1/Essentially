import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../data/models/enums.dart';
import '../../data/models/user.dart';
import '../../data/repositories/auth_repository.dart';

/// Message shown on the login screen after a forced sign-out
/// (expired session, suspension, ban).
class SessionNotice extends Notifier<String?> {
  @override
  String? build() => null;

  void show(String message) => state = message;
  void clear() => state = null;
}

final sessionNoticeProvider = NotifierProvider<SessionNotice, String?>(SessionNotice.new);

/// Holds the signed-in user (`null` when signed out).
class AuthController extends AsyncNotifier<AppUser?> {
  AuthRepository get _repo => ref.read(authRepositoryProvider);
  ApiClient get _api => ref.read(apiClientProvider);

  @override
  Future<AppUser?> build() async {
    _api.onSessionExpired = _handleSessionExpired;

    final token = await ref.read(tokenStorageProvider).read();
    if (token == null) return null;
    _api.token = token;
    try {
      return await _repo.me();
    } on ApiException catch (e) {
      if (e.isUnauthorized || e.isAccountBlocked) {
        await _clearSession();
        if (e.isAccountBlocked) ref.read(sessionNoticeProvider.notifier).show(e.message);
        return null;
      }
      rethrow;
    }
  }

  Future<void> login(String email, String password) async {
    final session = await _repo.login(email, password);
    await _storeSession(session);
  }

  Future<void> register({
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
    final session = await _repo.register(
      fullName: fullName,
      email: email,
      password: password,
      role: role,
      phone: phone,
      businessName: businessName,
      latitude: latitude,
      longitude: longitude,
      address: address,
    );
    await _storeSession(session);
  }

  Future<void> logout() async {
    await _clearSession();
    state = const AsyncData(null);
  }

  /// Replace the cached user after a profile/location update.
  void updateUser(AppUser user) => state = AsyncData(user);

  Future<void> _storeSession(AuthSession session) async {
    await ref.read(tokenStorageProvider).write(session.token);
    _api.token = session.token;
    ref.read(sessionNoticeProvider.notifier).clear();
    state = AsyncData(session.user);
  }

  Future<void> _clearSession() async {
    _api.token = null;
    await ref.read(tokenStorageProvider).clear();
  }

  void _handleSessionExpired(ApiException error) {
    if (state.value == null) return;
    ref
        .read(sessionNoticeProvider.notifier)
        .show(error.isAccountBlocked ? error.message : 'Your session has expired. Please sign in again.');
    logout();
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, AppUser?>(AuthController.new);

/// Convenience accessor for widgets that are only shown when signed in.
final currentUserProvider = Provider<AppUser?>((ref) => ref.watch(authControllerProvider).value);
