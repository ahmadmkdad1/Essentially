import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/config/app_config.dart';

class GeoPoint {
  const GeoPoint(this.latitude, this.longitude);
  final double latitude;
  final double longitude;

  String get shortLabel => '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';

  @override
  bool operator ==(Object other) => other is GeoPoint && other.latitude == latitude && other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);
}

class LocationException implements Exception {
  LocationException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Device GPS + reverse geocoding (OpenStreetMap Nominatim, no API key).
class LocationRepository {
  LocationRepository()
    : _geocoder = Dio(
        BaseOptions(
          baseUrl: 'https://nominatim.openstreetmap.org',
          connectTimeout: const Duration(seconds: 6),
          receiveTimeout: const Duration(seconds: 6),
          headers: kIsWeb ? null : {'User-Agent': AppConfig.userAgentPackage},
        ),
      );

  final Dio _geocoder;

  Future<GeoPoint> currentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw LocationException('Location services are turned off on this device.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      throw LocationException('Location permission was denied. You can pick your location on the map instead.');
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 15)),
    );
    return GeoPoint(position.latitude, position.longitude);
  }

  /// Best-effort human readable address; falls back to coordinates.
  Future<String> describe(GeoPoint point) async {
    try {
      final res = await _geocoder.get<Map<String, dynamic>>(
        '/reverse',
        queryParameters: {
          'lat': point.latitude,
          'lon': point.longitude,
          'format': 'jsonv2',
          'zoom': 16,
          'addressdetails': 1,
        },
      );
      final address = res.data?['address'] as Map<String, dynamic>?;
      if (address != null) {
        final parts =
            [
              address['road'],
              address['suburb'] ?? address['neighbourhood'] ?? address['quarter'],
              address['city'] ?? address['town'] ?? address['village'] ?? address['county'],
            ].whereType<String>().where((s) => s.isNotEmpty).toSet().toList();
        if (parts.isNotEmpty) return parts.join(', ');
      }
      final display = res.data?['display_name'] as String?;
      if (display != null && display.isNotEmpty) {
        return display.split(',').take(3).map((s) => s.trim()).join(', ');
      }
    } catch (_) {
      // Offline or rate limited — coordinates are still a valid address.
    }
    return 'Pinned location (${point.shortLabel})';
  }

  /// Forward geocoding for the location search box.
  Future<List<({GeoPoint point, String label})>> search(String query) async {
    if (query.trim().length < 3) return const [];
    try {
      final res = await _geocoder.get<List<dynamic>>(
        '/search',
        queryParameters: {'q': query.trim(), 'format': 'jsonv2', 'limit': 6},
      );
      return (res.data ?? const [])
          .whereType<Map<String, dynamic>>()
          .map((m) {
            final lat = double.tryParse('${m['lat']}');
            final lon = double.tryParse('${m['lon']}');
            if (lat == null || lon == null) return null;
            final label = (m['display_name'] as String? ?? '').split(',').take(3).map((s) => s.trim()).join(', ');
            return (point: GeoPoint(lat, lon), label: label);
          })
          .whereType<({GeoPoint point, String label})>()
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static double distanceKm(GeoPoint a, GeoPoint b) =>
      Geolocator.distanceBetween(a.latitude, a.longitude, b.latitude, b.longitude) / 1000;
}

final locationRepositoryProvider = Provider<LocationRepository>((ref) => LocationRepository());
