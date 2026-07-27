import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';

import '../models/models.dart';

/// Scan device audio into local [Song] entries (negative ids).
class LocalMusicScanner {
  LocalMusicScanner._();

  static const _channel = MethodChannel('music_hub/local_media');

  static const _audioExt = {
    '.mp3',
    '.m4a',
    '.aac',
    '.flac',
    '.wav',
    '.ogg',
    '.opus',
    '.wma',
    '.aiff',
    '.aif',
    '.alac',
  };

  /// Request media/storage permission. Returns false if permanently denied.
  static Future<bool> ensurePermission() async {
    if (kIsWeb) return false;
    if (Platform.isAndroid) {
      var status = await Permission.audio.status;
      if (!status.isGranted) {
        status = await Permission.audio.request();
      }
      if (status.isGranted) return true;
      var storage = await Permission.storage.status;
      if (!storage.isGranted) {
        storage = await Permission.storage.request();
      }
      return storage.isGranted || status.isGranted;
    }
    if (Platform.isIOS) {
      final s = await Permission.mediaLibrary.request();
      return s.isGranted;
    }
    return true;
  }

  static Future<List<Song>> scan() async {
    if (kIsWeb) return [];
    final ok = await ensurePermission();
    if (!ok && (Platform.isAndroid || Platform.isIOS)) {
      throw StateError('需要「音乐与音频」权限才能扫描本机歌曲');
    }

    if (Platform.isAndroid) {
      try {
        final list = await _scanWithMediaStore();
        if (list.isNotEmpty) return list;
      } catch (e) {
        debugPrint('MediaStore scan failed: $e');
      }
    }

    return _scanFolders();
  }

  /// Android MediaStore via native MethodChannel (no third-party plugin).
  static Future<List<Song>> _scanWithMediaStore() async {
    final raw = await _channel.invokeMethod<List<dynamic>>('scanAudio');
    if (raw == null || raw.isEmpty) return [];

    final out = <Song>[];
    final seen = <String>{};
    for (final item in raw) {
      if (item is! Map) continue;
      final m = Map<String, dynamic>.from(item);
      final path = '${m['path'] ?? m['uri'] ?? ''}'.trim();
      if (path.isEmpty) continue;
      final key = path.toLowerCase();
      if (!seen.add(key)) continue;

      final title = '${m['title'] ?? ''}'.trim();
      final artist = '${m['artist'] ?? ''}'.trim();
      final album = '${m['album'] ?? ''}'.trim();
      final durMs = (m['durationMs'] as num?)?.toInt() ?? 0;
      final mediaId = (m['id'] as num?)?.toInt();
      final fmt = _formatOf(path, m['format'] as String?);

      out.add(
        Song(
          id: _localId(path, mediaId),
          title: title.isNotEmpty ? title : p.basenameWithoutExtension(path),
          artist: artist.isEmpty || artist == '<unknown>' ? 'Unknown' : artist,
          album: album.isEmpty || album == '<unknown>' ? '本机' : album,
          format: fmt,
          streamUrl: path,
          duration: durMs > 0 ? durMs / 1000.0 : null,
          isLocal: true,
          localPath: path,
        ),
      );
    }
    out.sort((a, b) {
      final c = a.artist.toLowerCase().compareTo(b.artist.toLowerCase());
      if (c != 0) return c;
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
    return out;
  }

  static Future<List<Song>> _scanFolders() async {
    final roots = <Directory>[];
    if (Platform.isWindows) {
      final home = Platform.environment['USERPROFILE'];
      if (home != null) {
        roots.add(Directory(p.join(home, 'Music')));
        roots.add(Directory(p.join(home, 'Downloads')));
      }
    } else if (Platform.isAndroid) {
      roots.add(Directory('/storage/emulated/0/Music'));
      roots.add(Directory('/storage/emulated/0/Download'));
      roots.add(Directory('/storage/emulated/0/Podcasts'));
      roots.add(Directory('/storage/emulated/0/Audiobooks'));
    } else if (Platform.isLinux || Platform.isMacOS) {
      final home = Platform.environment['HOME'];
      if (home != null) {
        roots.add(Directory(p.join(home, 'Music')));
        roots.add(Directory(p.join(home, 'Downloads')));
      }
    }

    final out = <Song>[];
    final seen = <String>{};
    for (final root in roots) {
      if (!await root.exists()) continue;
      await for (final ent in root.list(recursive: true, followLinks: false)) {
        if (ent is! File) continue;
        final path = ent.path;
        final ext = p.extension(path).toLowerCase();
        if (!_audioExt.contains(ext)) continue;
        final key = path.toLowerCase();
        if (!seen.add(key)) continue;
        final name = p.basenameWithoutExtension(path);
        out.add(
          Song(
            id: _localId(path, null),
            title: name,
            artist: 'Unknown',
            album: p.basename(p.dirname(path)),
            format: ext.replaceFirst('.', ''),
            streamUrl: path,
            isLocal: true,
            localPath: path,
          ),
        );
      }
    }
    out.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return out;
  }

  static String _formatOf(String path, String? ext) {
    final e = (ext ?? p.extension(path)).replaceFirst('.', '').toLowerCase();
    return e.isEmpty ? 'audio' : e;
  }

  /// Stable negative id so local tracks never collide with server song ids.
  static int _localId(String path, int? mediaId) {
    if (mediaId != null && mediaId > 0) {
      return -mediaId;
    }
    var h = path.toLowerCase().hashCode & 0x7fffffff;
    if (h == 0) h = 1;
    return -h;
  }
}
