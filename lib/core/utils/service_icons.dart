import 'package:flutter/material.dart';

/// Category-specific icons for service grids (booking, vendor services).
/// Matches on slug + name keywords so new categories get a sensible
/// icon automatically instead of one generic spanner.
IconData serviceIconFor(String? slug, String? name) {
  final hay = '${slug ?? ''} ${name ?? ''}'.toLowerCase();

  if (hay.contains('tow')) return Icons.local_shipping_outlined;
  if (hay.contains('wash') && hay.contains('bay')) {
    return Icons.water_drop_outlined;
  }
  if (hay.contains('wash') || hay.contains('clean') || hay.contains('detail')) {
    return Icons.local_car_wash_outlined;
  }
  if (hay.contains('tire') || hay.contains('tyre') || hay.contains('wheel')) {
    return Icons.tire_repair_outlined;
  }
  if (hay.contains('batter') || hay.contains('electr')) {
    return Icons.battery_charging_full_outlined;
  }
  if (hay.contains('oil') ||
      hay.contains('lubric') ||
      hay.contains('fuel') ||
      hay.contains('gas') ||
      hay.contains('petrol')) {
    return Icons.oil_barrel_outlined;
  }
  if (hay.contains('inspect') ||
      hay.contains('diagnos') ||
      hay.contains('check')) {
    return Icons.fact_check_outlined;
  }
  if (hay.contains('deliver') ||
      hay.contains('spare') ||
      hay.contains('part')) {
    return Icons.delivery_dining_outlined;
  }
  if (hay.contains('paint') || hay.contains('body')) {
    return Icons.format_paint_outlined;
  }
  if (hay.contains('key') || hay.contains('lock')) {
    return Icons.key_outlined;
  }
  if (hay.contains('mechanic') ||
      hay.contains('repair') ||
      hay.contains('engine') ||
      hay.contains('service') ||
      hay.contains('maint')) {
    return Icons.car_repair_outlined;
  }
  return Icons.handyman_outlined;
}

/// A distinct brand color per service category so the booking grid is
/// scannable at a glance. Same keyword matching as [serviceIconFor].
Color serviceColorFor(String? slug, String? name) {
  final hay = '${slug ?? ''} ${name ?? ''}'.toLowerCase();

  if (hay.contains('tow')) return const Color(0xFF9A3412); // burnt orange
  if (hay.contains('wash') && hay.contains('bay')) {
    return const Color(0xFF0E7490); // cyan
  }
  if (hay.contains('wash') || hay.contains('clean') || hay.contains('detail')) {
    return const Color(0xFF2563EB); // blue
  }
  if (hay.contains('tire') || hay.contains('tyre') || hay.contains('wheel')) {
    return const Color(0xFF475569); // slate
  }
  if (hay.contains('batter') || hay.contains('electr')) {
    return const Color(0xFFB45309); // amber
  }
  if (hay.contains('oil') ||
      hay.contains('lubric') ||
      hay.contains('fuel') ||
      hay.contains('gas') ||
      hay.contains('petrol')) {
    return const Color(0xFF78350F); // brown
  }
  if (hay.contains('inspect') ||
      hay.contains('diagnos') ||
      hay.contains('check')) {
    return const Color(0xFF7C3AED); // purple
  }
  if (hay.contains('deliver') ||
      hay.contains('spare') ||
      hay.contains('part')) {
    return const Color(0xFF4F46E5); // indigo
  }
  if (hay.contains('paint') || hay.contains('body')) {
    return const Color(0xFFDB2777); // pink
  }
  if (hay.contains('key') || hay.contains('lock')) {
    return const Color(0xFF0D9488); // teal
  }
  if (hay.contains('mechanic') ||
      hay.contains('repair') ||
      hay.contains('engine') ||
      hay.contains('service') ||
      hay.contains('maint')) {
    return const Color(0xFFDC2626); // red
  }
  return const Color(0xFF16A34A); // SOGO green fallback
}
