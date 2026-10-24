import 'package:flutter/material.dart';

/// Visual identity per category icon key sent by the API.
class CategoryStyle {
  const CategoryStyle(this.icon, this.color);
  final IconData icon;
  final Color color;

  static CategoryStyle of(String? key) => switch (key) {
    'gas' => const CategoryStyle(Icons.local_fire_department_rounded, Color(0xFFFB923C)),
    'water' => const CategoryStyle(Icons.water_drop_rounded, Color(0xFF38BDF8)),
    'electricity' => const CategoryStyle(Icons.bolt_rounded, Color(0xFFFACC15)),
    'wifi' => const CategoryStyle(Icons.wifi_rounded, Color(0xFF818CF8)),
    'satellite' => const CategoryStyle(Icons.satellite_alt_rounded, Color(0xFFC084FC)),
    'solar' => const CategoryStyle(Icons.solar_power_rounded, Color(0xFFFBBF24)),
    'plumbing' => const CategoryStyle(Icons.plumbing_rounded, Color(0xFF2DD4BF)),
    'maintenance' => const CategoryStyle(Icons.handyman_rounded, Color(0xFFF472B6)),
    _ => const CategoryStyle(Icons.home_repair_service_rounded, Color(0xFF94A3B8)),
  };
}
