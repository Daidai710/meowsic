import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class EqBand {
  EqBand({
    required this.index,
    required this.centerHz,
    required this.levelMb,
    required this.minMb,
    required this.maxMb,
  });

  final int index;
  final int centerHz;
  int levelMb;
  final int minMb;
  final int maxMb;

  factory EqBand.fromMap(Map raw) => EqBand(
        index: (raw['index'] as num).toInt(),
        centerHz: (raw['centerHz'] as num).toInt(),
        levelMb: (raw['levelMb'] as num).toInt(),
        minMb: (raw['minMb'] as num).toInt(),
        maxMb: (raw['maxMb'] as num).toInt(),
      );

  String get label {
    if (centerHz >= 1000) {
      return '${(centerHz / 1000).toStringAsFixed(centerHz % 1000 == 0 ? 0 : 1)}k';
    }
    return '${centerHz}Hz';
  }
}

/// A4: Android system Equalizer via platform channel.
class EqualizerService {
  static const _ch = MethodChannel('music_hub/equalizer');

  /// EQ-only presets (+ scene curves). Labels shown in settings picker.
  static const presets = <String, String>{
    'normal': '正常 / 平坦',
    'pop': '流行',
    'bass': '低音增强',
    'vocal': '人声突出',
    'karaoke': 'K 歌 / 更弱人声',
    'treble': '高音明亮',
    'classical': '古典',
    'rock': '摇滚',
    'jazz': '爵士',
    'electronic': '电子',
    'hiphop': '嘻哈',
    'dance': '舞曲',
    'acoustic': '原声',
    'podcast': '播客/人声',
    'cinematic': '电影感',
    'lofi': 'Lo-fi',
    'sad_ballad': '伤感叙事',
    'custom': '自定义',
  };

  static const presetHints = <String, String>{
    'normal': '各频段平坦，适合对照原曲',
    'pop': '中高频略提，人声更贴耳',
    'bass': '低频加强，鼓与贝斯更有力',
    'vocal': '中频突出，歌词更清晰',
    'karaoke': '大幅压低人声中频带；连电脑时优先 Spleeter/分轨伴奏，否则用 EQ 近似',
    'treble': '高频明亮，细节更通透',
    'classical': '两端延展，舞台感',
    'rock': '低音冲击 + 高频锋利',
    'jazz': '温暖中频，自然动态',
    'electronic': '低频厚、空气感足',
    'hiphop': '重低音与节奏感',
    'dance': '舞曲感，低音与高音更足',
    'acoustic': '中频自然，原声温暖',
    'podcast': '削弱轰鸣，人声优先',
    'cinematic': '低频厚实、中高频开阔',
    'lofi': '高音柔和滚降，氛围松弛',
    'sad_ballad': '人声与中频靠前，抒情向',
    'custom': '拖动频段滑块自由调节',
  };

  String currentPreset = 'normal';
  bool available = false;
  List<EqBand> bands = [];

  Future<bool> init(int sessionId) async {
    if (kIsWeb || !Platform.isAndroid) {
      available = false;
      return false;
    }
    try {
      final ok = await _ch.invokeMethod<bool>('init', {'sessionId': sessionId});
      available = ok == true;
      if (available) {
        await refreshBands();
        if (currentPreset != 'custom') {
          await applyPreset(currentPreset);
        }
      }
      return available;
    } catch (_) {
      available = false;
      return false;
    }
  }

  Future<void> refreshBands() async {
    if (!available) return;
    try {
      final raw = await _ch.invokeMethod<List<dynamic>>('getBands');
      bands = (raw ?? [])
          .map((e) => EqBand.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      bands = [];
    }
  }

  Future<void> applyPreset(String name) async {
    currentPreset = name;
    if (!available) return;
    try {
      await _ch.invokeMethod('applyPreset', {'name': name});
      await refreshBands();
    } catch (_) {}
  }

  Future<void> setBand(int index, int levelMb) async {
    if (!available) return;
    currentPreset = 'custom';
    try {
      await _ch.invokeMethod('setBand', {'index': index, 'levelMb': levelMb});
      final i = bands.indexWhere((b) => b.index == index);
      if (i >= 0) bands[i].levelMb = levelMb;
    } catch (_) {}
  }

  Future<void> setAllBands(List<int> levels, {String presetName = 'custom'}) async {
    if (!available) return;
    currentPreset = presetName;
    try {
      await _ch.invokeMethod('setBands', {'levels': levels});
      await refreshBands();
      currentPreset = presetName;
    } catch (_) {}
  }

  Future<void> release() async {
    if (!available) return;
    try {
      await _ch.invokeMethod('release');
    } catch (_) {}
    available = false;
    bands = [];
  }
}
