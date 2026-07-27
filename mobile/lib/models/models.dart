import 'dart:math' as math;

class Song {
  Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.format,
    required this.streamUrl,
    this.duration,
    this.coverUrl,
    this.needsTranscode = false,
    this.tagOk = true,
    this.replayGainDb,
    this.isLocal = false,
    this.localPath,
    this.isOnline = false,
    this.onlinePreviewOnly = false,
  });

  final int id;
  final String title;
  final String artist;
  final String album;
  final String format;
  final String streamUrl;
  final double? duration;
  final String? coverUrl;
  final bool needsTranscode;
  final bool tagOk;
  /// ReplayGain track gain in dB (from tags), if known.
  final double? replayGainDb;

  /// Device-local track (phone/PC filesystem), not from Music Hub server.
  final bool isLocal;
  /// Absolute file path or content:// URI for local playback.
  final String? localPath;

  /// Session-only online search hit (e.g. iTunes preview). Not persisted.
  final bool isOnline;
  /// True when stream is a short preview clip rather than full track.
  final bool onlinePreviewOnly;

  factory Song.fromJson(Map<String, dynamic> j) => Song(
        id: j['id'] as int,
        title: (j['title'] ?? '') as String,
        artist: (j['artist'] ?? '') as String,
        album: (j['album'] ?? '') as String,
        format: (j['format'] ?? '') as String,
        streamUrl: (j['stream_url'] ?? '') as String,
        duration: (j['duration'] as num?)?.toDouble(),
        coverUrl: j['cover_url'] as String?,
        needsTranscode: j['needs_transcode'] == true,
        tagOk: j['tag_ok'] != false,
        replayGainDb: (j['replaygain_db'] as num?)?.toDouble(),
        isLocal: j['is_local'] == true,
        localPath: j['local_path'] as String?,
        isOnline: j['is_online'] == true,
        onlinePreviewOnly: j['online_preview_only'] == true,
      );

  Map<String, dynamic> toLocalJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'album': album,
        'format': format,
        'stream_url': streamUrl,
        'duration': duration,
        'cover_url': coverUrl,
        'needs_transcode': needsTranscode,
        'tag_ok': tagOk,
        'replaygain_db': replayGainDb,
        'is_local': true,
        'local_path': localPath ?? streamUrl,
      };

  factory Song.fromLocalJson(Map<String, dynamic> j) {
    final path = (j['local_path'] ?? j['stream_url'] ?? '') as String;
    return Song(
      id: (j['id'] as num).toInt(),
      title: (j['title'] ?? '') as String,
      artist: (j['artist'] ?? 'Unknown') as String,
      album: (j['album'] ?? '本机') as String,
      format: (j['format'] ?? '') as String,
      streamUrl: (j['stream_url'] ?? path) as String,
      duration: (j['duration'] as num?)?.toDouble(),
      coverUrl: j['cover_url'] as String?,
      needsTranscode: false,
      tagOk: true,
      isLocal: true,
      localPath: path,
    );
  }

  String absoluteStreamUrl(
    String base, {
    bool forceTranscode = false,
    /// `accomp` = karaoke accompaniment stem (server Spleeter / cache).
    String? stem,
  }) {
    if (isLocal) {
      final p = localPath ?? streamUrl;
      if (p.startsWith('file:') || p.startsWith('content:')) return p;
      return Uri.file(p).toString();
    }
    // Absolute HTTP(S) stream (online preview / remote URL).
    if (streamUrl.startsWith('http://') || streamUrl.startsWith('https://')) {
      return streamUrl;
    }
    final need = forceTranscode || needsTranscode || !tagOk;
    final path = streamUrl.startsWith('/') ? streamUrl : '/$streamUrl';
    final params = <String>[];
    if (need) params.add('transcode=true');
    if (stem != null && stem.isNotEmpty) params.add('stem=${Uri.encodeQueryComponent(stem)}');
    final q = params.isEmpty ? '' : '?${params.join('&')}';
    return '$base$path$q';
  }

  String? absoluteCoverUrl(String base) {
    if (coverUrl == null) return null;
    if (coverUrl!.startsWith('http://') ||
        coverUrl!.startsWith('https://') ||
        coverUrl!.startsWith('file:') ||
        coverUrl!.startsWith('content:')) {
      return coverUrl;
    }
    if (isLocal) {
      return Uri.file(coverUrl!).toString();
    }
    final path = coverUrl!.startsWith('/') ? coverUrl! : '/$coverUrl';
    return '$base$path';
  }

  /// Linear gain multiplier from ReplayGain tag (or mild fallback).
  double loudnessGain({bool fallbackSoft = true}) {
    final rg = replayGainDb;
    if (rg != null) {
      final db = rg.clamp(-18.0, 12.0);
      return math.pow(10.0, db / 20.0).toDouble().clamp(0.2, 3.5);
    }
    // No tag: slight headroom so tracks don't clip as hard when match is on.
    return fallbackSoft ? 0.88 : 1.0;
  }
}

class Playlist {
  Playlist({
    required this.id,
    required this.name,
    required this.songCount,
    this.createdAt,
  });

  final int id;
  final String name;
  final int songCount;
  final String? createdAt;

  factory Playlist.fromJson(Map<String, dynamic> j) => Playlist(
        id: j['id'] as int,
        name: (j['name'] ?? '') as String,
        songCount: (j['song_count'] as num?)?.toInt() ?? 0,
        createdAt: j['created_at'] as String?,
      );
}

class HubStatus {
  HubStatus({
    required this.version,
    required this.libraryPath,
    required this.songCount,
    required this.playlistCount,
    required this.ffmpeg,
    this.ffmpegPath,
    this.lanIp,
    this.lanUrl,
    this.port = 8787,
    this.authRequired = false,
    this.libraryPaths = const [],
  });

  final String version;
  final String libraryPath;
  final List<String> libraryPaths;
  final int songCount;
  final int playlistCount;
  final bool ffmpeg;
  final String? ffmpegPath;
  final String? lanIp;
  final String? lanUrl;
  final int port;
  final bool authRequired;

  factory HubStatus.fromJson(Map<String, dynamic> j) {
    final paths = <String>[];
    final raw = j['library_paths'];
    if (raw is List) {
      for (final e in raw) {
        paths.add('$e');
      }
    }
    final primary = (j['library_path'] ?? '') as String;
    if (paths.isEmpty && primary.isNotEmpty) paths.add(primary);
    return HubStatus(
      version: (j['version'] ?? '') as String,
      libraryPath: primary,
      libraryPaths: paths,
      songCount: (j['song_count'] as num?)?.toInt() ?? 0,
      playlistCount: (j['playlist_count'] as num?)?.toInt() ?? 0,
      ffmpeg: j['ffmpeg'] == true,
      ffmpegPath: j['ffmpeg_path'] as String?,
      lanIp: j['lan_ip'] as String?,
      lanUrl: j['lan_url'] as String?,
      port: (j['port'] as num?)?.toInt() ?? 8787,
      authRequired: j['auth_required'] == true,
    );
  }
}

class ResumeProgress {
  ResumeProgress({
    this.songId,
    this.position = 0,
    this.song,
  });

  final int? songId;
  final double position;
  final Song? song;

  factory ResumeProgress.fromJson(Map<String, dynamic> j) {
    Song? s;
    final raw = j['song'];
    if (raw is Map<String, dynamic>) {
      s = Song.fromJson(raw);
    } else if (raw is Map) {
      s = Song.fromJson(Map<String, dynamic>.from(raw));
    }
    return ResumeProgress(
      songId: (j['song_id'] as num?)?.toInt(),
      position: (j['position'] as num?)?.toDouble() ?? 0,
      song: s,
    );
  }
}

class LyricLine {
  LyricLine({required this.line, this.t});
  final String line;
  final double? t; // seconds

  factory LyricLine.fromJson(Map<String, dynamic> j) => LyricLine(
        line: (j['line'] ?? j['text'] ?? '') as String,
        t: (j['t'] as num?)?.toDouble() ?? (j['time'] as num?)?.toDouble(),
      );
}

class LyricsData {
  LyricsData({this.source, this.plain, this.lines = const []});

  final String? source;
  final String? plain;
  final List<LyricLine> lines;

  bool get isEmpty => lines.isEmpty && (plain == null || plain!.trim().isEmpty);

  factory LyricsData.fromJson(Map<String, dynamic> j) {
    final rawLines = j['lines'] ?? j['lrc'] ?? j['synced'];
    final lines = <LyricLine>[];
    if (rawLines is List) {
      for (final e in rawLines) {
        if (e is Map<String, dynamic>) {
          lines.add(LyricLine.fromJson(e));
        } else if (e is Map) {
          lines.add(LyricLine.fromJson(Map<String, dynamic>.from(e)));
        }
      }
    }
    // plain-only fallback
    final plain = j['plain'] as String? ?? j['text'] as String?;
    if (lines.isEmpty && plain != null && plain.trim().isNotEmpty) {
      for (final row in plain.split('\n')) {
        if (row.trim().isEmpty) continue;
        lines.add(LyricLine(line: row));
      }
    }
    return LyricsData(
      source: j['source'] as String?,
      plain: plain,
      lines: lines,
    );
  }
}
