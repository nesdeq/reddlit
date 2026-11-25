import 'package:flutter/services.dart';

/// HapticFeedback gated by the user's setting, mirrored from SettingsProvider so taps need no BuildContext.
class Haptics {
  Haptics._();

  /// Current user preference; SettingsProvider updates it once preferences load.
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
