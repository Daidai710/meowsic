import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Pushes now-playing info to the Android home-screen widget.
class WidgetBridge {
  static const _ch = MethodChannel('music_hub/widget');

  static Future<void> update({
    required String title,
    required String artist,
    required bool playing,
    String? coverUrl,
  }) async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await _ch.invokeMethod('update', {
        'title': title,
        'artist': artist,
        'playing': playing,
        'coverUrl': coverUrl ?? '',
      });
    } catch (_) {}
  }

  static Future<void> clear() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await _ch.invokeMethod('clear');
    } catch (_) {}
  }
}
