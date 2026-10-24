import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../data/repositories/location_repository.dart';
import '../auth/auth_controller.dart';

enum LocationSource { device, saved, manual, fallback }

class LocationState {
  const LocationState({
    required this.point,
    required this.label,
    required this.source,
    this.loading = false,
    this.error,
  });

  final GeoPoint point;
  final String label;
  final LocationSource source;
  final bool loading;
  final String? error;

  bool get isApproximate => source == LocationSource.fallback;

  LocationState copyWith({
    GeoPoint? point,
    String? label,
    LocationSource? source,
    bool? loading,
    String? error,
    bool clearError = false,
  }) => LocationState(
    point: point ?? this.point,
    label: label ?? this.label,
    source: source ?? this.source,
    loading: loading ?? this.loading,
    error: clearError ? null : (error ?? this.error),
  );
}

/// The location the customer is browsing from. Starts from the saved
/// profile address, can be switched to live GPS or a point picked on the map.
class LocationController extends Notifier<LocationState> {
  bool _autoLocateAttempted = false;

  @override
  LocationState build() {
    // Rebuild when the signed-in account or its saved address changes.
    final saved = ref.watch(
      currentUserProvider.select((u) => (id: u?.id, lat: u?.latitude, lng: u?.longitude, address: u?.address)),
    );
    if (saved.lat != null && saved.lng != null) {
      return LocationState(
        point: GeoPoint(saved.lat!, saved.lng!),
        label: saved.address ?? 'Saved location',
        source: LocationSource.saved,
      );
    }
    return const LocationState(
      point: GeoPoint(AppConfig.defaultLatitude, AppConfig.defaultLongitude),
      label: 'Beirut (approximate)',
      source: LocationSource.fallback,
    );
  }

  /// Tries GPS once when we only have an approximate location.
  Future<void> autoLocateIfNeeded() async {
    if (_autoLocateAttempted || state.source != LocationSource.fallback) return;
    _autoLocateAttempted = true;
    await useDeviceLocation();
  }

  Future<void> useDeviceLocation() async {
    state = state.copyWith(loading: true, clearError: true);
    final repo = ref.read(locationRepositoryProvider);
    try {
      final point = await repo.currentPosition();
      state = state.copyWith(point: point, label: 'Current location', source: LocationSource.device, loading: false);
      final label = await repo.describe(point);
      if (state.point == point) state = state.copyWith(label: label);
    } on LocationException catch (e) {
      state = state.copyWith(loading: false, error: e.message);
    } catch (_) {
      state = state.copyWith(loading: false, error: 'Could not determine your location.');
    }
  }

  void setManual(GeoPoint point, String label) {
    state = LocationState(point: point, label: label, source: LocationSource.manual);
  }

  void clearError() => state = state.copyWith(clearError: true);
}

final locationControllerProvider = NotifierProvider<LocationController, LocationState>(LocationController.new);
