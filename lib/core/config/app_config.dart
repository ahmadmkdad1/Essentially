import 'package:flutter/foundation.dart';

/// Build-time configuration.
///
/// Override the API location with:
///   flutter run --dart-define=API_URL=http://192.168.1.10:3000/api
class AppConfig {
  AppConfig._();

  static const String appName = 'Essentially';

  static const String _apiUrlOverride = String.fromEnvironment('API_URL');

  static String get apiBaseUrl {
    if (_apiUrlOverride.isNotEmpty) return _apiUrlOverride;
    if (kIsWeb) return 'http://localhost:3000/api';
    // The Android emulator reaches the host machine through 10.0.2.2.
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000/api';
    }
    return 'http://localhost:3000/api';
  }

  /// Fallback map centre when no location is known (Beirut).
  static const double defaultLatitude = 33.8938;
  static const double defaultLongitude = 35.5018;

  /// Esri dark basemap + labels (keyless; attribution shown on every map).
  static const String darkTileUrl =
      'https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Dark_Gray_Base/MapServer/tile/{z}/{y}/{x}';
  static const String darkLabelsUrl =
      'https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Dark_Gray_Reference/MapServer/tile/{z}/{y}/{x}';
  static const String userAgentPackage = 'app.essentially.mobile';
}
