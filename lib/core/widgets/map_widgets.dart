import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../config/app_config.dart';
import '../theme/app_colors.dart';

/// Dark basemap (Esri World Dark Gray, no API key) with a labels overlay.
class DarkTileLayer extends StatelessWidget {
  const DarkTileLayer({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        TileLayer(
          urlTemplate: AppConfig.darkTileUrl,
          userAgentPackageName: AppConfig.userAgentPackage,
          maxNativeZoom: 16,
        ),
        TileLayer(
          urlTemplate: AppConfig.darkLabelsUrl,
          userAgentPackageName: AppConfig.userAgentPackage,
          maxNativeZoom: 16,
        ),
      ],
    );
  }
}

class MapAttribution extends StatelessWidget {
  const MapAttribution({super.key});

  @override
  Widget build(BuildContext context) => Text(
    'Esri, HERE, Garmin, © OpenStreetMap contributors',
    style: TextStyle(fontSize: 9, color: Colors.white.withValues(alpha: 0.55)),
  );
}

class MapPin extends StatelessWidget {
  const MapPin({super.key, this.color = AppColors.primary, this.icon = Icons.location_on_rounded, this.size = 38});
  final Color color;
  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) =>
      Icon(icon, color: color, size: size, shadows: const [Shadow(color: Colors.black87, blurRadius: 8)]);
}

/// "You are here" dot.
class UserDot extends StatelessWidget {
  const UserDot({super.key});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppColors.info,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 3),
      boxShadow: [BoxShadow(color: AppColors.info.withValues(alpha: 0.5), blurRadius: 12, spreadRadius: 4)],
    ),
  );
}

/// Static, non-interactive map preview of a single point.
class MapPreview extends StatelessWidget {
  const MapPreview({
    super.key,
    required this.latitude,
    required this.longitude,
    this.height = 180,
    this.radiusKm,
    this.secondary,
  });

  final double latitude;
  final double longitude;
  final double height;
  final double? radiusKm;

  /// Optional second point (e.g. the customer's location).
  final LatLng? secondary;

  @override
  Widget build(BuildContext context) {
    final center = LatLng(latitude, longitude);
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                initialCenter: center,
                initialZoom: radiusKm != null && radiusKm! > 10 ? 10.5 : 13.5,
                interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
              ),
              children: [
                const DarkTileLayer(),
                if (radiusKm != null)
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: center,
                        radius: radiusKm! * 1000,
                        useRadiusInMeter: true,
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderColor: AppColors.primary.withValues(alpha: 0.5),
                        borderStrokeWidth: 1.5,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    if (secondary != null) Marker(point: secondary!, width: 18, height: 18, child: const UserDot()),
                    Marker(point: center, width: 40, height: 40, alignment: Alignment.topCenter, child: const MapPin()),
                  ],
                ),
              ],
            ),
            const Positioned(right: 6, bottom: 4, child: MapAttribution()),
          ],
        ),
      ),
    );
  }
}
