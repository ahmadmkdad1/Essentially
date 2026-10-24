import 'package:flutter/material.dart';

/// Dark palette used across the app.
abstract final class AppColors {
  static const background = Color(0xFF0A0E13);
  static const surface = Color(0xFF111720);
  static const surfaceRaised = Color(0xFF17202B);
  static const surfaceHigh = Color(0xFF1E2935);
  static const border = Color(0xFF253241);

  static const primary = Color(0xFF34D399); // emerald
  static const primaryDeep = Color(0xFF059669);
  static const onPrimary = Color(0xFF032018);

  static const accent = Color(0xFFF5B942); // amber — prices & ratings
  static const info = Color(0xFF60A5FA);
  static const warning = Color(0xFFFBBF24);
  static const danger = Color(0xFFF87171);
  static const success = Color(0xFF4ADE80);
  static const violet = Color(0xFFA78BFA);

  static const textPrimary = Color(0xFFE6EDF3);
  static const textSecondary = Color(0xFF9AA7B4);
  static const textMuted = Color(0xFF6B7785);

  static const heroGradient = LinearGradient(
    colors: [Color(0xFF0F2A22), Color(0xFF0A0E13)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
