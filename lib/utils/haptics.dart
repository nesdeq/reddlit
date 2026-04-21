import 'package:flutter/services.dart';

/// Thin wrapper around HapticFeedback that honors the user's setting.
/// [enabled] is mirrored from ThemeProvider so call sites don't need a
/// BuildContext — haptic decisions happen on every tap.
class Haptics {
  Haptics._();

  /// Current user preference. Defaults to true; updated by ThemeProvider once
  /// preferences load.
  static bool enabled = true;

  /// Discrete selection tick (picking from a list, collapsing a comment).
  static void selectionClick() {
    if (enabled) HapticFeedback.selectionClick();
  }

  /// Soft tap for toggles (favorites, switches).
  static void lightImpact() {
    if (enabled) HapticFeedback.lightImpact();
  }
}
