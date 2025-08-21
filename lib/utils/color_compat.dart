import 'package:flutter/material.dart';

/// Compatibilité Flutter :
/// - Flutter ≥ 3.22 : Color.withValues(alpha: ...)
/// - Avant : Color.withOpacity(...)
extension ColorCompat on Color {
  Color withAlphaCompat(double a) {
    try {
      // Flutter ≥ 3.22
      return withValues(alpha: a);
    } catch (_) {
      // Versions antérieures
      // ignore: deprecated_member_use
      return withOpacity(a);
    }
  }
}
