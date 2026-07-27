import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Light tactile feedback for meowsic UI. Failures are ignored (desktop/web).
class MeowsicHaptics {
  MeowsicHaptics._();

  static bool get _ok => !kIsWeb;

  /// Soft tap — list rows, chips, icon buttons.
  static Future<void> light() async {
    if (!_ok) return;
    try {
      await HapticFeedback.lightImpact();
    } catch (_) {}
  }

  /// Toggle / select — switches, scene pick, tabs.
  static Future<void> selection() async {
    if (!_ok) return;
    try {
      await HapticFeedback.selectionClick();
    } catch (_) {}
  }

  /// Primary action — play/pause, connect, scan success.
  static Future<void> medium() async {
    if (!_ok) return;
    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  /// Rare emphasis — errors optional; keep gentle.
  static Future<void> heavy() async {
    if (!_ok) return;
    try {
      await HapticFeedback.heavyImpact();
    } catch (_) {}
  }
}
