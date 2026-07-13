import 'package:flutter/material.dart';

/// Single source of truth for every color in the app.
///
/// HARD RULE: no widget may hardcode a hex value. Reference these named tokens
/// only — changing the brand here propagates everywhere.
///
/// Brand is migrating blue -> green. The old blue values are kept commented out
/// (NOT deleted) so we can flip back instantly if needed.
class AppColors {
  // ---- Brand: GREEN scale (active) ----
  static const brandPrimary = Color(0xFF4A5D0F); // green 700-ish
  static const brandHeader = Color(0xFF6B8519); // green mid
  static const brandLight = Color(0xFFEEF3C4); // green tint (active-child bg)

  /// Scaffold/page background — a VERY faint green (not the thick brand tint).
  static const scaffoldBg = Color(0xFFF6F8EE);

  // ---- Brand: BLUE scale (old, kept for rollback) ----
  // static const brandPrimary = Color(0xFF07376A);
  // static const brandHeader = Color(0xFF194977);
  // static const brandLight = Color(0xFFEFF6FF);

  // Sidebar active states (mirror the web sidebar)
  static const navActiveBg = brandPrimary; // selected parent bg
  static const navActiveText = white; // selected parent text
  static const navChildActiveBg = brandLight; // selected child bg
  static const navChildActiveText = brandPrimary; // selected child text

  static const textPrimary = Color(0xFF0F172A);
  static const textMuted = Color(0xFF64748B);
  static const error = Color(0xFFEF4444);
  static const success = Color(0xFF22C55E);
  static const warning = Color(0xFFF59E0B);
  static const white = Color(0xFFFFFFFF);
  static const cardBg = Color(0xFFF8FAFC);
  static const borderColor = Color(0xFFE2E8F0);
  static const offlineBanner = Color(0xFFFEF3C7);
  static const offlineBannerText = Color(0xFF92400E);

  // KPI gradient pairs [start, end]
  static const gradientNavy = [Color(0xFF07376A), Color(0xFF1E5FA3)];
  static const gradientTeal = [Color(0xFF0F766E), Color(0xFF14B8A6)];
  static const gradientPurple = [Color(0xFF7C3AED), Color(0xFFA78BFA)];
  static const gradientGold = [Color(0xFFB45309), Color(0xFFF59E0B)];
  static const gradientGreen = [Color(0xFF15803D), Color(0xFF4ADE80)];
  static const gradientRed = [Color(0xFFDC2626), Color(0xFFF87171)];

  // Chart colors for pie chart slices
  static const chartColors = [
    Color(0xFF22C55E),
    Color(0xFF3B82F6),
    Color(0xFF8B5CF6),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
    Color(0xFF06B6D4),
  ];
}
