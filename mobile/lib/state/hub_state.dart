import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'dart:io' show Platform;

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show NetworkImage;
import 'package:just_audio/just_audio.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/music_hub_api.dart';

import '../api/party_client.dart';
import '../audio/equalizer_service.dart';
import '../audio/hub_audio_handler.dart';
import '../audio/scene_presets.dart';
import '../models/models.dart';
import '../util/local_music_scanner.dart';
import 'ui_theme.dart';

/// off = stop at end of queue; all = list loop; one = single track
enum LoopMode { off, all, one }

/// K 歌弱人声深度（EQ 兜底）
enum KaraokeDepth {
  light, // 浅
  medium, // 中
  deep, // 深
}

/// Pipeline item state for independent K 歌 mode.
enum KaraokePipeState {
  queued,
  running,
  ready,
  error,
}

class KaraokePipeItem {
  KaraokePipeItem({
    required this.song,
    this.state = KaraokePipeState.queued,
    this.message,
    this.error,
    this.engine,
  });

  final Song song;
  KaraokePipeState state;
  String? message;
  String? error;
  String? engine;

  bool get isReady => state == KaraokePipeState.ready;
  bool get isError => state == KaraokePipeState.error;
}

class HubState extends ChangeNotifier {
  HubState({HubAudioHandler? audioHandler}) {
    _handler = audioHandler;
    _initPlayer();
    _restoreBase();
  }

  HubAudioHandler? _handler;
  final EqualizerService equalizer = EqualizerService();
  AudioPlayer get player => _handler?.player ?? _fallbackPlayer;
  final AudioPlayer _fallbackPlayer = AudioPlayer();
  late MusicHubApi api = MusicHubApi('http://127.0.0.1:8787');
  List<Map<String, dynamic>> devices = [];

  String baseUrl = 'http://127.0.0.1:8787';
  String? authToken;
  String deviceId = 'flutter';
  HubStatus? status;
  ResumeProgress? pendingResume;
  List<Song> songs = [];
  /// Full unfiltered list for the current library tab (not affected by search).
  /// Used when starting playback from a search hit so the queue is the whole 曲库.
  List<Song> librarySongs = [];
  List<Song> recent = [];
  List<Playlist> playlists = [];
  List<Song> queue = [];
  int queueIndex = -1;
  bool shuffle = false;
  LoopMode loopMode = LoopMode.all;
  List<Song> _orderQueue = [];
  bool loading = false;
  String? error;
  String? connectionHint;
  String search = '';
  bool connected = false;
  /// Local-only session: no Music Hub server required.
  bool offlineMode = false;
  bool reconnecting = false;

  /// Main shell is open when online (server) or offline (本机).
  bool get sessionActive => connected || offlineMode;

  // Soft link health (do NOT full-disconnect on transient LAN blips)
  int _missedPings = 0;
  bool _pingInFlight = false;
  static const int _warnAfterMisses = 2;
  static const int _maxMissesKeepConnected = 12; // ~4 min at 20s interval

  /// Guards against double-advance when track completion fires from multiple
  /// streams (audio_service + just_audio playerStateStream).
  bool _advancingTrack = false;
  /// Bumped on every intentional source change; stale completed events ignore.
  int _trackEpoch = 0;

  // ---- Independent K 歌 mode (pipeline + EQ fallback; session cache) ----
  bool karaokeMode = false;
  KaraokeDepth karaokeDepth = KaraokeDepth.medium;
  String? _eqBeforeKaraoke;
  /// True when current track is playing server-separated accompaniment.
  bool karaokeUsingStem = false;
  String karaokeStatusHint = '';
  /// Local pipeline queue (mirrors server serial job).
  List<KaraokePipeItem> karaokePipe = [];
  Map<String, dynamic>? karaokeEngineInfo;
  Timer? _karaokePollTimer;
  bool _karaokePurging = false;

  static const karaokeDepthLabels = <KaraokeDepth, String>{
    KaraokeDepth.light: '浅',
    KaraokeDepth.medium: '中',
    KaraokeDepth.deep: '深',
  };

  /// 5-band scoop templates (mB); mapped onto device band count.
  static const Map<KaraokeDepth, List<int>> karaokeEqLevels = {
    KaraokeDepth.light: [300, -200, -700, -550, 80],
    KaraokeDepth.medium: [400, -400, -1100, -1000, -150],
    KaraokeDepth.deep: [450, -550, -1400, -1300, -250],
  };

  int get karaokeReadyCount =>
      karaokePipe.where((e) => e.state == KaraokePipeState.ready).length;
  int get karaokeRunningCount =>
      karaokePipe.where((e) => e.state == KaraokePipeState.running).length;
  bool get karaokePipelineBusy =>
      karaokePipe.any((e) =>
          e.state == KaraokePipeState.queued || e.state == KaraokePipeState.running);

  // ---- Online search (session cache, wiped on app close) ----
  /// Online / cloud search removed (local hub + 本机 only).
  List<Song> onlineResults = [];
  bool onlineSearching = false;
  String? onlineSearchError;
  String onlineSearchQuery = '';

  // Sleep timer + fade-out (A7)
  Timer? _sleepTimer;
  Timer? _fadeTimer;
  Timer? _heartbeat;
  Timer? _progressTimer;
  DateTime? sleepUntil;
  int? sleepMinutesLeft;
  static const int sleepFadeSeconds = 30;
  double _userVolume = 1.0;
  bool _fadingOut = false;

  // Playback speed (A6) — picker options; arbitrary speeds also allowed (scenes)
  double speed = 1.0;
  static const List<double> speedOptions = [
    0.5, 0.75, 0.9, 0.95, 1.0, 1.1, 1.25, 1.5, 1.75, 2.0,
  ];

  // Listening scene (EQ + speed + soft volume)
  String currentSceneId = 'default';
  double _sceneVolume = 1.0;

  // Loudness match (8)
  bool loudnessMatch = false;
  double _trackLoudnessGain = 1.0;

  // Multi-library paths from server (10)
  List<String> libraryPaths = [];

  /// Selected library filter for 曲库 tab.
  /// `null` = 总曲库（远端 + 本机）；`0/1/2…` = 曲库 A/B/C；
  /// [kLocalLibraryIndex] = 本机扫描曲库。
  int? selectedLibraryIndex;

  /// Sentinel index for device-local music library.
  static const int kLocalLibraryIndex = -1;

  /// Songs scanned from the phone/PC (persisted).
  List<Song> localSongs = [];
  bool scanningLocal = false;

  // Optional UI theme binding (cover color / etc.)
  UiTheme? uiTheme;

  // Listen-together (party)
  PartyClient? party;
  bool partyApplying = false;
  bool followRoomScene = true;
  String? partyError;

  Song? get current =>
      (queueIndex >= 0 && queueIndex < queue.length) ? queue[queueIndex] : null;

  bool get inParty => party?.isInRoom == true;
  bool get partyIsHost => party?.isHost == true;

  bool get isSleeping => sleepUntil != null;
  bool get isFadingOut => _fadingOut;

  Future<void> _initPlayer() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
    } catch (_) {}
    final h = _handler;
    if (h != null) {
      // Notification / lock-screen / headset → app player
      h.onPlay = () async {
        await player.play();
        notifyListeners();
      };
      h.onPause = () async {
        await player.pause();
        notifyListeners();
      };
      h.onSkipNext = () async {
        await next();
      };
      h.onSkipPrevious = () async {
        await prev();
      };
      // Single completion path via handler (see also fallback below).
      h.onCompleted = () {
        _onTrackEnded();
      };
    }
    player.playerStateStream.listen((s) {
      // When HubAudioHandler is present it already calls onCompleted on
      // processingState.completed — do NOT call _onTrackEnded again here
      // (that double-fired next() and skipped a song after natural end).
      if (_handler == null && s.processingState == ProcessingState.completed) {
        _onTrackEnded();
      }
      notifyListeners();
    });
    player.positionStream.listen((_) => notifyListeners());
  }

  Future<void> _restoreBase() async {
    final sp = await SharedPreferences.getInstance();
    deviceId = sp.getString('device_id') ??
        'flutter-${DateTime.now().millisecondsSinceEpoch}';
    await sp.setString('device_id', deviceId);
    final loop = sp.getString('loop_mode');
    if (loop != null) {
      loopMode = LoopMode.values.firstWhere(
        (e) => e.name == loop,
        orElse: () => LoopMode.all,
      );
    }
    speed = sp.getDouble('playback_speed') ?? 1.0;
    if (speed < 0.5 || speed > 2.0) speed = 1.0;
    _userVolume = sp.getDouble('user_volume') ?? 1.0;
    _sceneVolume = sp.getDouble('scene_volume') ?? 1.0;
    currentSceneId = sp.getString('scene_id') ?? 'default';
    equalizer.currentPreset = sp.getString('eq_preset') ?? 'normal';
    loudnessMatch = sp.getBool('loudness_match') ?? false;
    final kd = sp.getString('karaoke_depth');
    if (kd != null) {
      karaokeDepth = KaraokeDepth.values.firstWhere(
        (e) => e.name == kd,
        orElse: () => KaraokeDepth.medium,
      );
    }
    // karaokeMode is session-only (independent mode); not restored from prefs
    authToken = sp.getString('hub_token');
    await _loadLocalSongs(sp);
    await _applyEffectiveVolume();
    await player.setSpeed(speed);
    final saved = sp.getString('hub_base_url');
    if (saved != null && saved.isNotEmpty) {
      baseUrl = saved;
      api = MusicHubApi(baseUrl, token: authToken);
      notifyListeners();
      await connect(baseUrl);
    }
  }

  Future<void> _loadLocalSongs(SharedPreferences sp) async {
    final raw = sp.getString('local_songs_v1');
    if (raw == null || raw.isEmpty) return;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      localSongs = list
          .whereType<Map>()
          .map((e) => Song.fromLocalJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      localSongs = [];
    }
  }

  Future<void> _persistLocalSongs() async {
    final sp = await SharedPreferences.getInstance();
    final payload = localSongs.map((s) => s.toLocalJson()).toList();
    await sp.setString('local_songs_v1', jsonEncode(payload));
  }

  List<Song> _filterLocalBySearch(String q) {
    if (q.isEmpty) return List<Song>.from(localSongs);
    final needle = q.toLowerCase();
    return localSongs
        .where(
          (s) =>
              s.title.toLowerCase().contains(needle) ||
              s.artist.toLowerCase().contains(needle) ||
              s.album.toLowerCase().contains(needle),
        )
        .toList();
  }

  void disconnect({String? hint, bool clearLibrary = true}) {
    connected = false;
    offlineMode = false;
    status = null;
    if (clearLibrary) {
      songs = [];
      librarySongs = [];
      recent = [];
      playlists = [];
    }
    reconnecting = false;
    _missedPings = 0;
    connectionHint = hint ?? '已断开，可重新连接';
    _heartbeat?.cancel();
    _progressTimer?.cancel();
    cancelSleepTimer();
    notifyListeners();
  }

  /// Enter local-only mode (no server). Opens main shell on 本机曲库.
  Future<void> enterOfflineMode() async {
    offlineMode = true;
    connected = false;
    reconnecting = false;
    connectionHint = null;
    status = null;
    _missedPings = 0;
    _heartbeat?.cancel();
    _progressTimer?.cancel();
    // Leave party if any
    try {
      party?.leave();
    } catch (_) {}
    party = null;
    partyError = null;
    selectedLibraryIndex = kLocalLibraryIndex;
    librarySongs = List<Song>.from(localSongs);
    songs = _filterLocalBySearch(search);
    recent = [];
    playlists = [];
    notifyListeners();
  }

  /// Leave offline mode and return to the connect screen (without wiping local cache).
  void leaveOfflineToConnect() {
    offlineMode = false;
    connected = false;
    connectionHint = null;
    notifyListeners();
  }

  /// App returned to foreground — refresh link without wiping library.
  Future<void> onAppResumed() async {
    if (offlineMode) return;
    if (baseUrl.isEmpty) return;
    await consumeWidgetAction();
    final ok = await softPing(force: true);
    if (!ok && !connected) {
      // Cold offline: full connect once.
      await connect(baseUrl);
      return;
    }
    if (ok && connected && songs.isEmpty) {
      try {
        await refreshLibrary();
        await refreshPlaylists();
      } catch (_) {}
    }
  }

  /// Legacy no-op (home widget removed).
  Future<void> consumeWidgetAction() async {}

  /// Lightweight health check. Never clears songs/queue; never calls full connect.
  Future<bool> softPing({bool force = false}) async {
    if (offlineMode) return false;
    if (_pingInFlight) return _missedPings == 0;
    if (!connected && !force) return false;
    // Need a base URL for force-ping after resume.
    if (baseUrl.isEmpty) return false;
    _pingInFlight = true;
    try {
      api = MusicHubApi(baseUrl, token: authToken);
      status = await api.status();
      final hb = await api.deviceHeartbeat(
        deviceId: deviceId,
        name: _deviceName(),
        platform: _platformName(),
      );
      if (hb['kicked'] == true) {
        disconnect(hint: '你已被管理员踢下线');
        try {
          await player.stop();
        } catch (_) {}
        return false;
      }
      final recovered = reconnecting || _missedPings > 0;
      _missedPings = 0;
      reconnecting = false;
      connectionHint = null;
      if (!connected) {
        connected = true;
      }
      libraryPaths = status?.libraryPaths ?? libraryPaths;
      // ensure timers alive after long background (Android may drop them)
      if (_heartbeat == null || !(_heartbeat?.isActive ?? false)) {
        _startHeartbeat();
      }
      if (_progressTimer == null || !(_progressTimer?.isActive ?? false)) {
        _startProgressSync();
      }
      // (5) After flaky link recovers, re-bind stream URL without restarting from 0.
      if (recovered && current != null) {
        unawaited(softRefreshStream());
      }
      notifyListeners();
      return true;
    } catch (_) {
      _missedPings += 1;
      reconnecting = true;
      if (_missedPings >= _warnAfterMisses) {
        connectionHint =
            '与电脑连接不稳（$_missedPings 次探测失败）。本地队列继续播；回前台或点重连即可恢复同步';
      }
      // Intentionally keep connected=true when we already had a session, so
      // HomeShell does not bounce to the login/connect screen on a Wi‑Fi blip.
      if (_missedPings >= _maxMissesKeepConnected) {
        connectionHint = '长时间连不上服务端，请确认电脑 Music Hub 与 Wi‑Fi；点「重连」';
      }
      notifyListeners();
      return false;
    } finally {
      _pingInFlight = false;
    }
  }

  Future<void> setBaseUrl(String url) async {
    var u = url.trim();
    // support QR like http://ip:8787/?token=xxx
    final uri = Uri.tryParse(u.startsWith('http') ? u : 'http://$u');
    if (uri != null) {
      final t = uri.queryParameters['token'];
      if (t != null && t.isNotEmpty) {
        authToken = t;
      }
      u = '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
    }
    if (u.endsWith('/')) u = u.substring(0, u.length - 1);
    if (!u.startsWith('http://') && !u.startsWith('https://')) {
      u = 'http://$u';
    }
    baseUrl = u;
    api = MusicHubApi(baseUrl, token: authToken);
    final sp = await SharedPreferences.getInstance();
    await sp.setString('hub_base_url', baseUrl);
    if (authToken != null) await sp.setString('hub_token', authToken!);
    notifyListeners();
  }

  Future<bool> connect(String url, {String? password}) async {
    loading = true;
    error = null;
    connectionHint = null;
    pendingResume = null;
    offlineMode = false;
    notifyListeners();
    try {
      await setBaseUrl(url);
      if (password != null && password.isNotEmpty) {
        final t = await api.login(password);
        authToken = t;
        api.token = t;
        final sp = await SharedPreferences.getInstance();
        if (t != null) await sp.setString('hub_token', t);
      }
      status = await api.status();
      libraryPaths = status?.libraryPaths ?? [];
      if (status!.authRequired && (authToken == null || authToken!.isEmpty)) {
        connected = false;
        connectionHint = '服务器已启用密码，请输入访问密码';
        loading = false;
        notifyListeners();
        return false;
      }
      connected = true;
      await refreshLibrary();
      await refreshPlaylists();
      await refreshRecent();
      try {
        await api.deviceHeartbeat(
          deviceId: deviceId,
          name: _deviceName(),
          platform: _platformName(),
        );
      } catch (_) {}
      try {
        pendingResume = await api.getProgressLatest(excludeDevice: deviceId);
        if (pendingResume?.songId == null) {
          pendingResume = await api.getProgress(deviceId);
        }
      } catch (_) {}
      _startHeartbeat();
      _startProgressSync();
      loading = false;
      notifyListeners();
      return true;
    } catch (e) {
      connected = false;
      error = e.toString();
      connectionHint = _friendlyConnectError(e.toString());
      loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> resumePending() async {
    final p = pendingResume;
    if (p?.song == null) return;
    final song = p!.song!;
    await playList([song], 0);
    final pos = Duration(milliseconds: (p.position * 1000).round());
    if (pos.inSeconds > 2) {
      await player.seek(pos);
    }
    pendingResume = null;
    notifyListeners();
  }

  void dismissResume() {
    pendingResume = null;
    notifyListeners();
  }

  Future<LyricsData?> loadLyrics(int songId) async {
    try {
      return await api.lyrics(songId);
    } catch (_) {
      return null;
    }
  }

  Future<List<Song>> loadBroken() => api.brokenSongs();

  Future<String> fixBrokenSong(int id) async {
    final msg = await api.fixSong(id);
    await refreshLibrary();
    return msg;
  }

  String _friendlyConnectError(String raw) {
    final s = raw.toLowerCase();
    if (s.contains('timeout') || s.contains('timed out')) {
      return '连接超时：确认电脑服务已启动，且手机与电脑同一 Wi‑Fi';
    }
    if (s.contains('connection refused') || s.contains('failed host')) {
      return '连不上服务器：检查地址/端口，电脑防火墙是否放行 8787';
    }
    if (s.contains('socket') || s.contains('network')) {
      return '网络异常：请检查 Wi‑Fi，或点重新连接';
    }
    return '连接失败：$raw';
  }

  void _startHeartbeat() {
    _heartbeat?.cancel();
    // Longer interval: Android Doze throttles timers; avoid stacking full reconnect storms.
    _heartbeat = Timer.periodic(const Duration(seconds: 20), (_) async {
      if (!connected) return;
      await softPing();
    });
  }

  String _deviceName() {
    if (kIsWeb) return 'Web';
    try {
      if (Platform.isAndroid) return 'Android';
      if (Platform.isWindows) return 'Windows';
      if (Platform.isIOS) return 'iOS';
    } catch (_) {}
    return 'Device';
  }

  String _platformName() {
    if (kIsWeb) return 'web';
    try {
      return Platform.operatingSystem;
    } catch (_) {
      return 'unknown';
    }
  }

  Future<void> refreshDevices() async {
    try {
      devices = await api.listDevices();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> kickDevice(String id) async {
    await api.kickDevice(id);
    await refreshDevices();
  }

  Future<void> setEqPreset(String name) async {
    await equalizer.applyPreset(name);
    final sp = await SharedPreferences.getInstance();
    await sp.setString('eq_preset', name);
    // Switching EQ manually leaves scene as-is unless it was default mapping
    notifyListeners();
  }

  Future<void> setEqBand(int index, int levelMb) async {
    await equalizer.setBand(index, levelMb);
    final sp = await SharedPreferences.getInstance();
    await sp.setString('eq_preset', 'custom');
    notifyListeners();
  }

  Future<void> applyScene(ScenePreset scene, {bool fromParty = false}) async {
    currentSceneId = scene.id;
    _sceneVolume = scene.volume;
    final sp = await SharedPreferences.getInstance();
    await sp.setString('scene_id', scene.id);
    await sp.setDouble('scene_volume', _sceneVolume);
    if (scene.id != 'default') {
      await equalizer.applyPreset(scene.eqPreset);
      await sp.setString('eq_preset', scene.eqPreset);
    }
    speed = scene.speed.clamp(0.5, 2.0);
    await player.setSpeed(speed);
    await sp.setDouble('playback_speed', speed);
    await _applyEffectiveVolume();
    notifyListeners();
    if (!fromParty && !partyApplying && inParty && party!.can('set_scene')) {
      party!.control('set_scene', {'scene_id': scene.id});
    }
  }

  void _ensurePartyClient() {
    party ??= PartyClient(baseUrl: baseUrl, authToken: authToken);
    party!
      ..baseUrl = baseUrl
      ..authToken = authToken
      ..onState = (room, you) {
        unawaited(_applyPartyRoom(room));
      }
      ..onError = (m) {
        partyError = m;
        notifyListeners();
      }
      ..onKicked = (m) {
        partyError = m;
        notifyListeners();
      }
      ..onLeft = () {
        notifyListeners();
      }
      ..hostTickProvider = () {
        final song = current;
        if (song == null) return null;
        return {
          'song_id': song.id,
          'position': player.position.inMilliseconds / 1000.0,
          'playing': player.playing,
          'speed': speed,
        };
      };
  }

  Future<String?> partyCreate({String? displayName}) async {
    try {
      _ensurePartyClient();
      await party!.create(
        deviceId: deviceId,
        name: displayName ?? _deviceName(),
        platform: _platformName(),
      );
      partyError = null;
      _partyBroadcastQueueIfAllowed();
      notifyListeners();
      return null;
    } catch (e) {
      partyError = e.toString();
      notifyListeners();
      return partyError;
    }
  }

  Future<String?> partyJoin(String code, {String? displayName}) async {
    try {
      _ensurePartyClient();
      await party!.join(
        roomCode: code,
        deviceId: deviceId,
        name: displayName ?? _deviceName(),
        platform: _platformName(),
      );
      partyError = null;
      notifyListeners();
      return null;
    } catch (e) {
      partyError = e.toString();
      notifyListeners();
      return partyError;
    }
  }

  Future<void> partyLeave() async {
    party?.leave();
    notifyListeners();
  }

  void partySetRole(String targetId, String role, Map<String, bool> perms) {
    party?.setRole(targetId, role, perms);
  }

  void partyKick(String targetId) => party?.kick(targetId);

  void partyTransferHost(String targetId) => party?.transferHost(targetId);

  void _partyBroadcastQueueIfAllowed() {
    final p = party;
    if (p == null || !p.isInRoom || partyApplying) return;
    final song = current;
    if (song == null) return;
    if (p.isHost || p.can('set_queue')) {
      p.control('set_queue', {
        'queue': queue.map((s) => s.id).toList(),
        'queue_index': queueIndex,
        'position': player.position.inMilliseconds / 1000.0,
        'playing': player.playing,
      });
    } else if (p.can('set_song')) {
      p.control('set_song', {
        'song_id': song.id,
        'position': player.position.inMilliseconds / 1000.0,
        'playing': player.playing,
      });
    }
  }

  Song? _findSongById(int id) {
    for (final s in queue) {
      if (s.id == id) return s;
    }
    for (final s in songs) {
      if (s.id == id) return s;
    }
    for (final s in recent) {
      if (s.id == id) return s;
    }
    return null;
  }

  Future<void> _applyPartyRoom(Map<String, dynamic> room) async {
    final st = room['state'];
    if (st is! Map) {
      notifyListeners();
      return;
    }
    partyApplying = true;
    notifyListeners();
    try {
      final sceneId = st['scene_id']?.toString();
      if (followRoomScene && sceneId != null && sceneId != currentSceneId) {
        final scene = scenePresets.firstWhere(
          (s) => s.id == sceneId,
          orElse: () => scenePresets.first,
        );
        await applyScene(scene, fromParty: true);
      }
      final spd = (st['speed'] as num?)?.toDouble();
      if (spd != null && (spd - speed).abs() > 0.01) {
        speed = spd.clamp(0.5, 2.0);
        await player.setSpeed(speed);
      }

      final targetId = st['song_id'] is num ? (st['song_id'] as num).toInt() : null;
      final qIds = <int>[];
      final rawQ = st['queue'];
      if (rawQ is List) {
        for (final x in rawQ) {
          if (x is num) qIds.add(x.toInt());
        }
      }
      final needSong = targetId != null && (current == null || current!.id != targetId);
      if (needSong || (qIds.isNotEmpty && queue.isEmpty)) {
        final list = <Song>[];
        for (final id in qIds) {
          final s = _findSongById(id);
          if (s != null) list.add(s);
        }
        if (list.isEmpty && targetId != null) {
          final one = _findSongById(targetId);
          if (one != null) list.add(one);
        }
        if (list.isEmpty && targetId != null && songs.isEmpty) {
          try {
            await refreshLibrary();
            final one = _findSongById(targetId);
            if (one != null) list.add(one);
          } catch (_) {}
        }
        if (list.isNotEmpty) {
          var idx = list.indexWhere((s) => s.id == targetId);
          if (idx < 0) idx = 0;
          queue = list;
          queueIndex = idx;
          _orderQueue = List<Song>.from(list);
          await _playCurrent();
        }
      }

      final est = (st['estimated_position'] as num?)?.toDouble() ??
          (st['position'] as num?)?.toDouble() ??
          0.0;
      final playing = st['playing'] == true;
      try {
        final curSec = player.position.inMilliseconds / 1000.0;
        if ((curSec - est).abs() > 1.25) {
          await player.seek(Duration(milliseconds: (est * 1000).round()));
        }
      } catch (_) {}
      if (playing && !player.playing) {
        await player.play();
      } else if (!playing && player.playing) {
        await player.pause();
      }
    } finally {
      Future<void>.delayed(const Duration(milliseconds: 350), () {
        partyApplying = false;
        notifyListeners();
      });
    }
    notifyListeners();
  }

  ScenePreset get currentScene {
    return scenePresets.firstWhere(
      (s) => s.id == currentSceneId,
      orElse: () => scenePresets.first,
    );
  }

  void _startProgressSync() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      await flushProgressNow();
    });
  }

  /// Persist playhead (used by timer + app pause). Failures are silent.
  Future<void> flushProgressNow() async {
    final song = current;
    if (!connected || song == null) return;
    if (reconnecting && _missedPings >= _warnAfterMisses) return;
    try {
      await api.saveProgress(
        deviceId: deviceId,
        songId: song.id,
        position: player.position.inMilliseconds / 1000.0,
      );
    } catch (_) {}
  }

  /// Load songs for the current library tab. [q] null/empty = full list.
  Future<List<Song>> _loadLibrarySongs({String? q}) async {
    final query = (q == null || q.isEmpty) ? null : q;
    if (selectedLibraryIndex == kLocalLibraryIndex) {
      return _filterLocalBySearch(query ?? '');
    }
    if (selectedLibraryIndex == null) {
      List<Song> remote = [];
      if (connected) {
        try {
          remote = await api.allSongs(q: query);
          status = await api.status();
          libraryPaths = status?.libraryPaths ?? libraryPaths;
        } catch (e) {
          error = e.toString();
          connectionHint = _friendlyConnectError(e.toString());
        }
      }
      final local = _filterLocalBySearch(query ?? '');
      return [...remote, ...local];
    }
    if (!connected) return [];
    final list = await api.allSongs(
      q: query,
      libraryIndex: selectedLibraryIndex,
    );
    status = await api.status();
    libraryPaths = status?.libraryPaths ?? libraryPaths;
    return list;
  }

  /// Ensure [librarySongs] holds the full unfiltered list for this tab.
  Future<List<Song>> _ensureFullLibrarySongs() async {
    if (librarySongs.isNotEmpty) return librarySongs;
    try {
      librarySongs = await _loadLibrarySongs();
    } catch (e) {
      error = e.toString();
      connectionHint = _friendlyConnectError(e.toString());
    }
    return librarySongs;
  }

  Future<void> refreshLibrary() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      if (search.isEmpty) {
        songs = await _loadLibrarySongs();
        librarySongs = List<Song>.from(songs);
      } else {
        songs = await _loadLibrarySongs(q: search);
        // Keep full-library snapshot for play-from-library; refresh if empty
        // (e.g. first open landed on a search, or library tab just switched).
        if (librarySongs.isEmpty) {
          librarySongs = await _loadLibrarySongs();
        }
      }
      libraryOrderShuffled = false;
    } catch (e) {
      error = e.toString();
      connectionHint = _friendlyConnectError(e.toString());
    }
    loading = false;
    notifyListeners();
  }

  /// Switch library sidebar selection. [index] null = 总曲库；[kLocalLibraryIndex] = 本机.
  Future<void> selectLibrary(int? index) async {
    if (selectedLibraryIndex == index) return;
    selectedLibraryIndex = index;
    librarySongs = [];
    notifyListeners();
    await refreshLibrary();
  }

  /// Display label for library sidebar: 总曲库 / 本机 / 曲库 A / …
  String libraryLabel(int? index) {
    if (index == null) return '总曲库';
    if (index == kLocalLibraryIndex) return '本机';
    const letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    if (index >= 0 && index < letters.length) {
      return '曲库 ${letters[index]}';
    }
    return '曲库 ${index + 1}';
  }

  /// Folder basename for a library path (hint under the button).
  String libraryPathHint(int index) {
    if (index == kLocalLibraryIndex) {
      return localSongs.isEmpty ? '点扫描' : '${localSongs.length} 首';
    }
    if (index < 0 || index >= libraryPaths.length) return '未配置';
    final p = libraryPaths[index].replaceAll('\\', '/');
    final parts = p.split('/').where((e) => e.isNotEmpty).toList();
    return parts.isEmpty ? libraryPaths[index] : parts.last;
  }

  /// Scan phone/PC audio files into the 本机 library.
  Future<String?> scanLocalLibrary() async {
    scanningLocal = true;
    error = null;
    notifyListeners();
    try {
      final found = await LocalMusicScanner.scan();
      localSongs = found;
      await _persistLocalSongs();
      selectedLibraryIndex = kLocalLibraryIndex;
      librarySongs = List<Song>.from(localSongs);
      songs = _filterLocalBySearch(search);
      scanningLocal = false;
      notifyListeners();
      return null;
    } catch (e) {
      scanningLocal = false;
      final msg = e.toString().replaceFirst('Bad state: ', '');
      error = msg;
      notifyListeners();
      return msg;
    }
  }

  /// Whether the current library tab can filter fully on-device (no server query).
  bool get canInstantLocalSearch =>
      offlineMode || selectedLibraryIndex == kLocalLibraryIndex;

  Future<void> searchSongs(String q) async {
    search = q;
    // 本机 / 离线：本地即时过滤，不打服务器
    if (canInstantLocalSearch) {
      librarySongs = List<Song>.from(localSongs);
      songs = _filterLocalBySearch(q);
      notifyListeners();
      if (q.trim().isEmpty) {
        clearOnlineResults(keepCache: true);
      }
      return;
    }
    await refreshLibrary();
    if (q.trim().isEmpty) {
      clearOnlineResults(keepCache: true);
    }
  }

  /// Apply karaoke EQ curve for [karaokeDepth] onto current session bands.
  Future<void> _applyKaraokeEq() async {
    final template = karaokeEqLevels[karaokeDepth] ?? karaokeEqLevels[KaraokeDepth.medium]!;
    try {
      await equalizer.refreshBands();
      final n = equalizer.bands.length;
      if (n <= 0) {
        await equalizer.applyPreset('karaoke');
        return;
      }
      final levels = List<int>.generate(n, (i) {
        final idx = (i * template.length) ~/ n;
        return template[idx.clamp(0, template.length - 1)];
      });
      await equalizer.setAllBands(levels, presetName: 'karaoke');
      final sp = await SharedPreferences.getInstance();
      await sp.setString('eq_preset', 'karaoke');
    } catch (_) {
      try {
        await equalizer.applyPreset('karaoke');
      } catch (_) {}
    }
  }

  /// Enter independent K 歌 mode (EQ on; pipeline empty until user adds songs).
  Future<void> enterKaraokeMode() async {
    if (karaokeMode) return;
    if (offlineMode || !connected) {
      error = 'K 歌模式需要连接电脑 Music Hub（Spleeter 在电脑端运行）';
      notifyListeners();
      return;
    }
    karaokeMode = true;
    karaokeUsingStem = false;
    karaokeStatusHint = 'K 歌模式：选歌加入流水线';
    try {
      _eqBeforeKaraoke = equalizer.currentPreset == 'karaoke'
          ? 'normal'
          : equalizer.currentPreset;
      await _applyKaraokeEq();
      karaokeEngineInfo = await api.karaokeEngine();
      final gui = karaokeEngineInfo?['spleeter_gui'];
      if (gui != null) {
        karaokeStatusHint = '引擎就绪 · SpleeterGUI';
      } else if (karaokeEngineInfo?['spleeter'] == true) {
        karaokeStatusHint = '引擎就绪 · Spleeter';
      } else if (karaokeEngineInfo?['ffmpeg'] == true) {
        karaokeStatusHint = '仅 ffmpeg 近似（无 Spleeter 时）';
      } else {
        karaokeStatusHint = '无分轨引擎 · 仅 EQ 弱人声';
      }
    } catch (e) {
      karaokeStatusHint = '引擎探测失败 · 使用 EQ 兜底';
    }
    _startKaraokePoll();
    notifyListeners();
  }

  /// Exit K 歌 mode: cancel pipeline, delete session stems, restore EQ.
  Future<void> exitKaraokeMode({bool purgeCache = true}) async {
    if (!karaokeMode && karaokePipe.isEmpty) {
      if (purgeCache) await purgeKaraokeSession(silent: true);
      return;
    }
    karaokeMode = false;
    karaokeUsingStem = false;
    karaokeStatusHint = '';
    _stopKaraokePoll();
    try {
      if (purgeCache) {
        await purgeKaraokeSession(silent: true);
      }
      final restore = _eqBeforeKaraoke ?? 'normal';
      _eqBeforeKaraoke = null;
      final sp = await SharedPreferences.getInstance();
      if (restore == 'karaoke' || restore == 'custom') {
        await equalizer.applyPreset('normal');
        await sp.setString('eq_preset', 'normal');
      } else {
        await equalizer.applyPreset(restore);
        await sp.setString('eq_preset', restore);
      }
      // Leave stem stream if still on accomp
      if (current != null && !current!.isLocal && !current!.isOnline) {
        await softRefreshStream();
      }
    } catch (_) {}
    karaokePipe = [];
    notifyListeners();
  }

  Future<void> toggleKaraokeMode() async {
    if (karaokeMode) {
      await exitKaraokeMode(purgeCache: true);
    } else {
      await enterKaraokeMode();
    }
  }

  /// App background / close: wipe K 歌 session cache on PC.
  Future<void> purgeKaraokeSession({bool silent = false}) async {
    if (_karaokePurging) return;
    _karaokePurging = true;
    _stopKaraokePoll();
    try {
      if (connected && !offlineMode) {
        await api.karaokePipelineClear(deviceId, deleteFiles: true);
      }
    } catch (_) {}
    karaokePipe = [];
    karaokeUsingStem = false;
    if (!silent) karaokeStatusHint = '已清除 K 歌缓存';
    _karaokePurging = false;
    if (!silent) notifyListeners();
  }

  /// Add hub songs to K 歌 pipeline (serial Spleeter on PC).
  Future<String?> karaokeAddSongs(List<Song> list, {bool append = true}) async {
    if (!karaokeMode) await enterKaraokeMode();
    if (offlineMode || !connected) return '需要连接电脑';
    final hubSongs = list
        .where((s) => !s.isLocal && !s.isOnline && s.id > 0)
        .toList();
    if (hubSongs.isEmpty) return '请选择电脑曲库中的歌曲（本机/联网试听不支持分轨）';

    final existingIds = karaokePipe.map((e) => e.song.id).toSet();
    final toAdd = <Song>[];
    for (final s in hubSongs) {
      if (!existingIds.contains(s.id)) {
        toAdd.add(s);
        existingIds.add(s.id);
      }
    }
    if (toAdd.isEmpty) return '这些歌已在 K 歌队列';

    if (!append) karaokePipe = [];
    for (final s in toAdd) {
      karaokePipe.add(KaraokePipeItem(song: s, state: KaraokePipeState.queued, message: '排队中'));
    }
    notifyListeners();

    try {
      final ids = karaokePipe.map((e) => e.song.id).toList();
      final st = await api.karaokePipelineSet(
        deviceId: deviceId,
        songIds: ids,
        append: false,
      );
      _applyPipelineStatus(st);
      _startKaraokePoll();
      karaokeStatusHint =
          '流水线 ${karaokeReadyCount}/${karaokePipe.length} 就绪 · 串行分轨中';
      notifyListeners();
      return '已加入 ${toAdd.length} 首 · 流水线串行分离';
    } catch (e) {
      karaokeStatusHint = '提交流水线失败 · EQ 兜底仍可用';
      notifyListeners();
      return '提交失败: $e';
    }
  }

  Future<void> karaokeRemoveAt(int index) async {
    if (index < 0 || index >= karaokePipe.length) return;
    karaokePipe.removeAt(index);
    notifyListeners();
    if (!connected || offlineMode) return;
    try {
      final ids = karaokePipe.map((e) => e.song.id).toList();
      if (ids.isEmpty) {
        await api.karaokePipelineClear(deviceId, deleteFiles: true);
      } else {
        await api.karaokePipelineSet(deviceId: deviceId, songIds: ids, append: false);
        final st = await api.karaokePipelineStatus(deviceId);
        _applyPipelineStatus(st);
      }
    } catch (_) {}
    notifyListeners();
  }

  /// Play K 歌 queue from [index]; uses stem when ready, else original + EQ.
  Future<void> karaokePlayFrom(int index) async {
    if (karaokePipe.isEmpty) return;
    if (index < 0 || index >= karaokePipe.length) index = 0;
    if (!karaokeMode) await enterKaraokeMode();
    final list = karaokePipe.map((e) => e.song).toList();
    await playList(list, index);
  }

  void _startKaraokePoll() {
    _karaokePollTimer?.cancel();
    _karaokePollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      unawaited(_pollKaraokePipeline());
    });
  }

  void _stopKaraokePoll() {
    _karaokePollTimer?.cancel();
    _karaokePollTimer = null;
  }

  Future<void> _pollKaraokePipeline() async {
    if (!karaokeMode || !connected || offlineMode) return;
    if (karaokePipe.isEmpty) return;
    try {
      final st = await api.karaokePipelineStatus(deviceId);
      final prevReady = karaokeReadyCount;
      _applyPipelineStatus(st);
      // If current song just became ready, hot-swap to accomp stem.
      final cur = current;
      if (cur != null && karaokeMode && !karaokeUsingStem) {
        KaraokePipeItem? item;
        for (final e in karaokePipe) {
          if (e.song.id == cur.id) {
            item = e;
            break;
          }
        }
        if (item != null && item.isReady) {
          await _switchToAccompStem(cur);
        }
      }
      if (karaokeReadyCount != prevReady || karaokePipelineBusy) {
        karaokeStatusHint =
            '流水线 ${karaokeReadyCount}/${karaokePipe.length} 就绪'
            '${karaokeRunningCount > 0 ? ' · 分离中' : karaokePipelineBusy ? ' · 排队' : ' · 完成'}';
      }
      notifyListeners();
    } catch (_) {}
  }

  void _applyPipelineStatus(Map<String, dynamic> st) {
    final raw = st['items'];
    if (raw is! List) return;
    final byId = <int, Map<String, dynamic>>{};
    for (final e in raw) {
      if (e is Map) {
        final id = (e['song_id'] as num?)?.toInt();
        if (id != null) byId[id] = Map<String, dynamic>.from(e);
      }
    }
    for (final item in karaokePipe) {
      final j = byId[item.song.id];
      if (j == null) continue;
      final s = '${j['state'] ?? ''}';
      item.state = switch (s) {
        'ready' => KaraokePipeState.ready,
        'running' => KaraokePipeState.running,
        'error' => KaraokePipeState.error,
        _ => KaraokePipeState.queued,
      };
      item.message = j['message'] as String?;
      item.error = j['error'] as String?;
      item.engine = j['engine'] as String?;
    }
  }

  Future<void> _switchToAccompStem(Song song) async {
    if (!karaokeMode || current?.id != song.id) return;
    final pos = player.position;
    final wasPlaying = player.playing;
    try {
      final url = song.absoluteStreamUrl(baseUrl, stem: 'accomp');
      await player.setUrl(url);
      if (pos.inMilliseconds > 400) {
        await player.seek(pos);
      }
      await player.setSpeed(speed);
      await _applyEffectiveVolume();
      if (wasPlaying) await player.play();
      karaokeUsingStem = true;
      karaokeStatusHint = '正在播 AI 伴奏轨';
      notifyListeners();
    } catch (_) {
      karaokeUsingStem = false;
      karaokeStatusHint = '伴奏加载失败 · EQ 弱人声';
      notifyListeners();
    }
  }

  /// Change K 歌 EQ depth; reapplies if mode is on.
  Future<void> setKaraokeDepth(KaraokeDepth depth) async {
    if (karaokeDepth == depth) return;
    karaokeDepth = depth;
    final sp = await SharedPreferences.getInstance();
    await sp.setString('karaoke_depth', depth.name);
    if (karaokeMode) {
      await _applyKaraokeEq();
    }
    notifyListeners();
  }

  String get karaokeDepthLabel => karaokeDepthLabels[karaokeDepth] ?? '中';

  /// Cloud online search disabled — only local hub / 本机曲库.
  Future<void> searchOnline(String q, {bool onlyIfLocalEmpty = false}) async {
    clearOnlineResults(keepCache: true);
  }

  void clearOnlineResults({bool keepCache = false}) {
    onlineResults = [];
    onlineSearchError = null;
    onlineSearchQuery = '';
    onlineSearching = false;
    notifyListeners();
  }

  /// Compatibility no-op (online session cache removed).
  Future<void> purgeOnlineSessionCache() async {
    clearOnlineResults(keepCache: true);
  }

  Future<void> refreshPlaylists() async {
    if (!connected) {
      playlists = [];
      notifyListeners();
      return;
    }
    try {
      playlists = await api.playlists();
      notifyListeners();
    } catch (e) {
      error = e.toString();
      notifyListeners();
    }
  }

  Future<void> refreshRecent() async {
    if (!connected) {
      recent = [];
      notifyListeners();
      return;
    }
    try {
      recent = await api.recent(limit: 80);
      notifyListeners();
    } catch (_) {}
  }

  Future<List<Song>> loadPlaylistSongs(int id) => api.playlistSongs(id);

  Future<void> createPlaylist(String name) async {
    await api.createPlaylist(name);
    await refreshPlaylists();
  }

  Future<void> addSongToPlaylist(int playlistId, int songId) async {
    await api.addToPlaylist(playlistId, [songId]);
    await refreshPlaylists();
  }

  Future<void> scanLibrary() async {
    if (!connected) {
      error = offlineMode ? '离线模式：请用「扫描本机」' : '未连接服务器';
      notifyListeners();
      return;
    }
    loading = true;
    notifyListeners();
    try {
      await api.scan();
      await refreshLibrary();
    } catch (e) {
      error = e.toString();
    }
    loading = false;
    notifyListeners();
  }

  Future<void> setLoopMode(LoopMode mode) async {
    loopMode = mode;
    final sp = await SharedPreferences.getInstance();
    await sp.setString('loop_mode', loopMode.name);
    notifyListeners();
  }

  Future<void> cycleLoopMode() async {
    switch (loopMode) {
      case LoopMode.off:
        await setLoopMode(LoopMode.all);
        break;
      case LoopMode.all:
        await setLoopMode(LoopMode.one);
        break;
      case LoopMode.one:
        await setLoopMode(LoopMode.off);
        break;
    }
  }

  String get loopModeLabel {
    switch (loopMode) {
      case LoopMode.off:
        return '播完停止';
      case LoopMode.all:
        return '列表循环';
      case LoopMode.one:
        return '单曲循环';
    }
  }

  String get loopModeDescription {
    switch (loopMode) {
      case LoopMode.off:
        return '队列最后一首播完后停止';
      case LoopMode.all:
        return '列表循环到头继续播';
      case LoopMode.one:
        return '当前歌曲无限循环';
    }
  }

  static const loopModeChoices = <(LoopMode, String, String)>[
    (LoopMode.off, '播完停止', '队列最后一首结束后停止播放'),
    (LoopMode.all, '列表循环', '整队播完后从头再播'),
    (LoopMode.one, '单曲循环', '只循环当前这一首'),
  ];

  /// Whether the library list was manually shuffled (can restore via refresh).
  bool libraryOrderShuffled = false;

  /// 打乱曲库列表显示顺序（不改变「随机播放」开关，仅重排当前列表）。
  void shuffleLibraryOrder() {
    if (songs.length < 2) return;
    songs = List<Song>.from(songs)..shuffle(Random());
    // Keep full-library order in sync when not searching.
    if (search.isEmpty) {
      librarySongs = List<Song>.from(songs);
    } else if (librarySongs.length >= 2) {
      librarySongs = List<Song>.from(librarySongs)..shuffle(Random());
    }
    libraryOrderShuffled = true;
    notifyListeners();
  }

  /// 恢复曲库列表为服务端/本机原始顺序（取消「打乱列表」）。
  Future<void> restoreLibraryOrder() async {
    libraryOrderShuffled = false;
    await refreshLibrary();
  }

  /// 曲库列表点歌（含搜索结果）。
  /// - 当前没有在播歌曲：以点击的歌为起点，整份曲库作为播放队列
  /// - 当前已有在播：若在队列中则跳到该位置；否则跳到完整曲库中该歌位置
  /// Returns a short user-facing status for SnackBar (null if denied).
  Future<String?> playLibrarySong(Song song) async {
    if (inParty &&
        !partyApplying &&
        !partyIsHost &&
        !(party?.can('set_song') == true) &&
        !(party?.can('set_queue') == true)) {
      error = '一起听中：仅房主/有权限的管理员可点歌';
      notifyListeners();
      return null;
    }

    // Already have a playback session: prefer jumping inside the current queue.
    if (current != null && queue.isNotEmpty) {
      final qi = queue.indexWhere((s) => s.id == song.id);
      if (qi >= 0) {
        if (qi == queueIndex) {
          if (!player.playing) await player.play();
          return '正在播放该曲 · 队列 ${qi + 1}/${queue.length}';
        }
        await playQueueIndex(qi);
        return '已跳到队列第 ${qi + 1}/${queue.length} 首';
      }
    }

    final hadSession = current != null;
    // Nothing playing, or song not in queue → full 曲库 from this track.
    final full = await _ensureFullLibrarySongs();
    final li = full.indexWhere((s) => s.id == song.id);
    if (li >= 0) {
      await playList(full, li);
      final msg = '已从曲库第 ${li + 1}/${full.length} 首起播';
      return hadSession ? '$msg（已切换队列）' : msg;
    }
    // Edge: song only in filtered view / snapshot lag — start with it, then rest.
    if (full.isEmpty) {
      await playList([song], 0);
      return '已开始播放';
    }
    await playList([song, ...full.where((s) => s.id != song.id)], 0);
    return '已从该曲起播 · 曲库 ${full.length + 1} 首';
  }

  /// 打乱播放队列顺序；可选把当前曲固定在首位。
  /// 随机播放开启时不覆盖 [_orderQueue]，以便「换回顺序」仍能还原。
  void shuffleQueueOrder({bool keepCurrentFirst = true}) {
    if (queue.length < 2) return;
    final cur = current;
    if (keepCurrentFirst && cur != null) {
      final rest = queue.where((s) => s.id != cur.id).toList()..shuffle(Random());
      queue = [cur, ...rest];
      queueIndex = 0;
    } else {
      queue = List<Song>.from(queue)..shuffle(Random());
      if (cur != null) {
        queueIndex = queue.indexWhere((s) => s.id == cur.id);
        if (queueIndex < 0) queueIndex = 0;
      }
    }
    // Only snapshot as the new "order" when not in shuffle mode.
    if (!shuffle) {
      _orderQueue = List<Song>.from(queue);
    }
    if (inParty && partyIsHost) _partyBroadcastQueueIfAllowed();
    notifyListeners();
  }

  /// Toggle random play. Off → restore sequential queue and **locate** current track index.
  void toggleShuffle() {
    final cur = current;
    if (cur == null || queue.isEmpty) {
      shuffle = !shuffle;
      notifyListeners();
      return;
    }

    if (!shuffle) {
      // Entering shuffle: remember ordered queue, then reshuffle rest after current.
      _orderQueue = List<Song>.from(queue);
      final rest = queue.where((s) => s.id != cur.id).toList()..shuffle(Random());
      queue = [cur, ...rest];
      queueIndex = 0;
      shuffle = true;
    } else {
      // Leaving shuffle: restore order and keep playing the same song (定位 index).
      if (_orderQueue.isNotEmpty) {
        final byId = <int, Song>{};
        for (final s in _orderQueue) {
          byId[s.id] = s;
        }
        for (final s in queue) {
          byId.putIfAbsent(s.id, () => s);
        }
        final orderedIds = _orderQueue.map((s) => s.id).toList();
        final extras = queue.where((s) => !orderedIds.contains(s.id)).toList();
        queue = [
          for (final id in orderedIds)
            if (byId.containsKey(id)) byId[id]!,
          ...extras,
        ];
      }
      var idx = queue.indexWhere((s) => s.id == cur.id);
      if (idx < 0) {
        queue = [cur, ...queue.where((s) => s.id != cur.id)];
        idx = 0;
      }
      queueIndex = idx;
      shuffle = false;
    }
    if (inParty && partyIsHost) _partyBroadcastQueueIfAllowed();
    notifyListeners();
  }

  Future<void> playList(List<Song> list, int index) async {
    if (list.isEmpty) return;
    if (inParty && !partyApplying && !partyIsHost && !(party?.can('set_song') == true) && !(party?.can('set_queue') == true)) {
      error = '一起听中：仅房主/有权限的管理员可点歌';
      notifyListeners();
      return;
    }
    _orderQueue = List<Song>.from(list);
    if (shuffle) {
      final cur = list[index];
      final rest = list.where((s) => s.id != cur.id).toList()..shuffle(Random());
      queue = [cur, ...rest];
      queueIndex = 0;
    } else {
      queue = List<Song>.from(list);
      queueIndex = index;
    }
    await _playCurrent();
    if (inParty && !partyApplying) _partyBroadcastQueueIfAllowed();
  }

  /// 即刻播放 [song]：不把搜索结果整表当成新队列。
  /// · 已在队列中 → 从原位置**拉出**，移到当前播放位并立刻播
  /// · 不在队列中 → 插入到当前播放位（原当前曲顺延为下一首）
  Future<void> playNow(Song song) async {
    if (inParty && !partyApplying && !partyIsHost && !(party?.can('set_song') == true) && !(party?.can('set_queue') == true)) {
      error = '一起听中：仅房主/有权限的管理员可点歌';
      notifyListeners();
      return;
    }
    if (queue.isEmpty || queueIndex < 0) {
      await playList([song], 0);
      return;
    }
    if (current?.id == song.id) {
      await _playCurrent();
      return;
    }

    final wasCurrent = current!;

    // 已在队列：先从原位拿掉（不是跳过去）
    final existing = queue.indexWhere((s) => s.id == song.id);
    if (existing >= 0) {
      queue.removeAt(existing);
      if (existing < queueIndex) queueIndex -= 1;
    }

    // 插入当前播放位；原先正在播的歌顺延为下一首
    final insertAt = queueIndex.clamp(0, queue.length);
    queue.insert(insertAt, song);
    queueIndex = insertAt;

    if (_orderQueue.isNotEmpty) {
      _orderQueue.removeWhere((s) => s.id == song.id);
      final oi = _orderQueue.indexWhere((s) => s.id == wasCurrent.id);
      if (oi >= 0) {
        _orderQueue.insert(oi, song);
      } else {
        _orderQueue.add(song);
      }
    }

    await _playCurrent();
    if (inParty && !partyApplying) _partyBroadcastQueueIfAllowed();
  }

  Future<void> playShuffleAll([List<Song>? list]) async {
    final src = list ?? songs;
    if (src.isEmpty) return;
    shuffle = true;
    final i = Random().nextInt(src.length);
    await playList(src, i);
  }

  /// A8: insert as next track (plays after current finishes / next tap).
  void playNext(Song song) {
    if (queue.isEmpty || queueIndex < 0) {
      playList([song], 0);
      return;
    }
    final insertAt = queueIndex + 1;
    queue.insert(insertAt, song);
    // keep order queue loosely in sync
    if (_orderQueue.isNotEmpty) {
      final oi = _orderQueue.indexWhere((s) => s.id == current?.id);
      if (oi >= 0) {
        _orderQueue.insert(oi + 1, song);
      } else {
        _orderQueue.add(song);
      }
    }
    notifyListeners();
  }

  /// A8: append to end of queue.
  void addToQueueEnd(Song song) {
    if (queue.isEmpty || queueIndex < 0) {
      playList([song], 0);
      return;
    }
    queue.add(song);
    _orderQueue.add(song);
    notifyListeners();
  }

  Future<void> playQueueIndex(int index) async {
    if (index < 0 || index >= queue.length) return;
    queueIndex = index;
    await _playCurrent();
  }

  Future<void> setSpeed(double v) async {
    speed = double.parse(v.clamp(0.5, 2.0).toStringAsFixed(2));
    await player.setSpeed(speed);
    final sp = await SharedPreferences.getInstance();
    await sp.setDouble('playback_speed', speed);
    notifyListeners();
  }

  Future<void> cycleSpeed() async {
    // Cycle among common steps only
    const common = [0.75, 1.0, 1.25, 1.5];
    final nearest = common.reduce((a, b) => (a - speed).abs() < (b - speed).abs() ? a : b);
    final i = common.indexOf(nearest);
    await setSpeed(common[(i + 1) % common.length]);
  }

  Future<void> setUserVolume(double v) async {
    _userVolume = v.clamp(0.0, 1.0);
    if (!_fadingOut) {
      await _applyEffectiveVolume();
    }
    final sp = await SharedPreferences.getInstance();
    await sp.setDouble('user_volume', _userVolume);
    notifyListeners();
  }

  Future<void> setLoudnessMatch(bool v) async {
    loudnessMatch = v;
    final sp = await SharedPreferences.getInstance();
    await sp.setBool('loudness_match', loudnessMatch);
    final song = current;
    _trackLoudnessGain = loudnessMatch ? (song?.loudnessGain() ?? 0.88) : 1.0;
    await _applyEffectiveVolume();
    notifyListeners();
  }

  double get _effectiveVolume =>
      (_userVolume * _sceneVolume * (loudnessMatch ? _trackLoudnessGain : 1.0)).clamp(0.0, 1.0);

  Future<void> _applyEffectiveVolume() async {
    if (_fadingOut) return;
    await player.setVolume(_effectiveVolume);
  }

  /// Re-open current stream URL, keep playhead (soft reconnect).
  Future<void> _applyCoverTheme(Song song) async {
    final ui = uiTheme;
    if (ui == null || !ui.coverThemeEnabled) return;
    final url = song.absoluteCoverUrl(baseUrl);
    if (url == null) return;
    try {
      final palette = await PaletteGenerator.fromImageProvider(
        NetworkImage(url),
        maximumColorCount: 10,
        timeout: const Duration(seconds: 4),
      );
      final c = palette.vibrantColor?.color ??
          palette.dominantColor?.color ??
          palette.mutedColor?.color;
      if (c != null) await ui.applyCoverAccent(c);
    } catch (_) {}
  }

  Future<void> softRefreshStream() async {
    final song = current;
    if (song == null) return;
    final pos = player.position;
    final wasPlaying = player.playing;
    try {
      await _setPlayerSource(song, forceTranscode: false);
      if (pos.inMilliseconds > 400) {
        await player.seek(pos);
      }
      await player.setSpeed(speed);
      await _applyEffectiveVolume();
      if (wasPlaying) await player.play();
      await _handler?.setMedia(
        id: '${song.id}',
        title: song.title,
        artist: song.artist,
        album: song.album,
        artUri: song.absoluteCoverUrl(baseUrl),
        duration: song.duration != null
            ? Duration(milliseconds: (song.duration! * 1000).round())
            : null,
      );
    } catch (_) {}
  }

  Future<void> _setPlayerSource(Song song, {bool forceTranscode = false}) async {
    karaokeUsingStem = false;
    if (song.isLocal) {
      final path = (song.localPath ?? song.streamUrl).trim();
      if (path.startsWith('content://') || path.startsWith('file:')) {
        await player.setAudioSource(AudioSource.uri(Uri.parse(path)));
      } else {
        await player.setFilePath(path);
      }
      return;
    }
    // Online previews / absolute URLs skip hub base + transcode.
    if (song.isOnline ||
        song.streamUrl.startsWith('http://') ||
        song.streamUrl.startsWith('https://')) {
      await player.setUrl(song.streamUrl);
      return;
    }
    // K 歌模式：流水线已就绪则播伴奏轨，否则原曲 + EQ 兜底
    if (karaokeMode && !forceTranscode) {
      final pipeReady = karaokePipe.any(
        (e) => e.song.id == song.id && e.state == KaraokePipeState.ready,
      );
      if (pipeReady) {
        try {
          final url = song.absoluteStreamUrl(baseUrl, stem: 'accomp');
          await player.setUrl(url);
          karaokeUsingStem = true;
          karaokeStatusHint = 'AI 伴奏轨';
          return;
        } catch (_) {}
      }
      try {
        final st = await api.karaokeStatus(song.id);
        if (st['ready'] == true) {
          final url = song.absoluteStreamUrl(baseUrl, stem: 'accomp');
          await player.setUrl(url);
          karaokeUsingStem = true;
          karaokeStatusHint = 'AI 伴奏轨';
          return;
        }
      } catch (_) {}
    }
    final url = song.absoluteStreamUrl(baseUrl, forceTranscode: forceTranscode);
    await player.setUrl(url);
  }

  Future<void> refreshLibraries() async {
    try {
      libraryPaths = await api.listLibraries();
      notifyListeners();
    } catch (_) {}
  }

  Future<String?> addLibraryPath(String path) async {
    try {
      libraryPaths = await api.addLibrary(path.trim());
      notifyListeners();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> removeLibraryPath(String path) async {
    try {
      libraryPaths = await api.removeLibrary(path);
      notifyListeners();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  void removeFromQueue(int index) {
    if (index < 0 || index >= queue.length) return;
    final removingCurrent = index == queueIndex;
    queue.removeAt(index);
    if (queue.isEmpty) {
      queueIndex = -1;
      player.stop();
      notifyListeners();
      return;
    }
    if (index < queueIndex) {
      queueIndex -= 1;
    } else if (removingCurrent) {
      if (queueIndex >= queue.length) queueIndex = 0;
      _playCurrent();
    }
    notifyListeners();
  }

  void clearQueueKeepCurrent() {
    final cur = current;
    if (cur == null) {
      queue = [];
      queueIndex = -1;
    } else {
      queue = [cur];
      queueIndex = 0;
      _orderQueue = [cur];
    }
    notifyListeners();
  }

  Future<void> _playCurrent({bool forceTranscode = false, int attempt = 0}) async {
    final song = current;
    if (song == null) return;
    // New source → invalidate any pending "completed" from previous track.
    if (attempt == 0 && !forceTranscode) {
      _trackEpoch++;
    }
    final epoch = _trackEpoch;
    try {
      await _setPlayerSource(song, forceTranscode: forceTranscode);
      if (epoch != _trackEpoch) return;
      await player.setSpeed(speed);
      _trackLoudnessGain = song.loudnessGain();
      await _applyEffectiveVolume();
      // A4 equalizer binds to audio session
      try {
        final sid = player.androidAudioSessionId;
        if (sid != null) {
          await equalizer.init(sid);
          if (karaokeMode) {
            await _applyKaraokeEq();
          } else {
            final sp = await SharedPreferences.getInstance();
            final preset = sp.getString('eq_preset') ?? equalizer.currentPreset;
            if (preset != 'custom' && preset != 'karaoke') {
              await equalizer.applyPreset(preset);
            } else if (preset == 'custom') {
              equalizer.currentPreset = 'custom';
              await equalizer.refreshBands();
            } else {
              await equalizer.applyPreset(preset == 'karaoke' ? 'normal' : preset);
            }
          }
        }
      } catch (_) {}
      // A5+ notification metadata
      await _handler?.setMedia(
        id: '${song.id}',
        title: song.title,
        artist: song.artist,
        album: song.album,
        artUri: song.absoluteCoverUrl(baseUrl),
        duration: song.duration != null ? Duration(milliseconds: (song.duration! * 1000).round()) : null,
      );
      await player.play();
      unawaited(_applyCoverTheme(song));
      // Soft success: clear flaky banner without full library reload
      if (reconnecting) {
        unawaited(softPing());
      }
      // best-effort recent + device presence (never fails playback)
      if (!song.isLocal && !song.isOnline && connected) {
        unawaited(api.recordPlay(song.id, device: deviceId).then((_) => refreshRecent()).catchError((_) {}));
        unawaited(api
            .deviceHeartbeat(deviceId: deviceId, name: _deviceName(), platform: _platformName())
            .catchError((_) => <String, dynamic>{}));
      }
      // K 歌：未就绪时保持 EQ；流水线 poll 会在 ready 后热切换伴奏
    } catch (e) {
      // Local / online: no hub transcode path.
      if (song.isLocal) {
        error = '本机播放失败: $e';
        notifyListeners();
        return;
      }
      if (song.isOnline) {
        error = '联网试听失败: $e';
        notifyListeners();
        return;
      }
      // Retry network blips a couple times before falling back to transcode.
      if (attempt < 2 && !forceTranscode) {
        await Future<void>.delayed(Duration(milliseconds: 400 * (attempt + 1)));
        await _playCurrent(forceTranscode: false, attempt: attempt + 1);
        return;
      }
      if (!forceTranscode) {
        await _playCurrent(forceTranscode: true, attempt: 0);
        return;
      }
      error = '播放失败: $e';
      connectionHint = _friendlyConnectError(e.toString());
    }
    notifyListeners();
  }

  Future<void> _onTrackEnded() async {
    // Re-entrancy: processingState + playerState both used to fire completed;
    // also next()/prev() can race with a late completed from the previous source.
    if (_advancingTrack) return;
    final epochAtStart = _trackEpoch;
    _advancingTrack = true;
    try {
      // 一起听：非房主等房主推进，避免各端自己切歌
      if (inParty && !partyIsHost && !partyApplying) return;
      // User already skipped away; ignore stale completion for old source.
      if (epochAtStart != _trackEpoch) return;
      if (loopMode == LoopMode.one) {
        await player.seek(Duration.zero);
        await player.play();
        return;
      }
      if (queue.isEmpty) return;
      if (queueIndex >= queue.length - 1) {
        if (loopMode == LoopMode.all) {
          if (shuffle) {
            final cur = current!;
            final base = _orderQueue.isNotEmpty ? _orderQueue : queue;
            final rest = base.where((s) => s.id != cur.id).toList()..shuffle(Random());
            queue = [cur, ...rest];
            queueIndex = rest.isEmpty ? 0 : 1;
          } else {
            queueIndex = 0;
          }
          await _playCurrent();
          if (inParty && partyIsHost) _partyBroadcastQueueIfAllowed();
        } else {
          // off: stop
          await player.pause();
          await player.seek(Duration.zero);
          if (inParty && partyIsHost) {
            party?.control('pause', {'position': 0.0});
          }
          notifyListeners();
        }
        return;
      }
      await next();
    } finally {
      _advancingTrack = false;
    }
  }

  Future<void> togglePlay() async {
    if (inParty && !partyApplying && !partyIsHost && !(party?.can('play_pause') == true)) {
      error = '一起听中：无播放/暂停权限';
      notifyListeners();
      return;
    }
    if (current == null) {
      if (songs.isNotEmpty) await playList(songs, 0);
      return;
    }
    if (player.playing) {
      await player.pause();
      if (inParty && !partyApplying && (partyIsHost || party?.can('play_pause') == true)) {
        party?.control('pause', {'position': player.position.inMilliseconds / 1000.0});
      }
    } else {
      await player.play();
      if (inParty && !partyApplying && (partyIsHost || party?.can('play_pause') == true)) {
        party?.control('play', {'position': player.position.inMilliseconds / 1000.0});
      }
    }
    notifyListeners();
  }

  Future<void> next() async {
    if (queue.isEmpty) return;
    if (inParty && !partyApplying && !partyIsHost) {
      if (party?.can('skip') != true) {
        error = '一起听中：无切歌权限';
        notifyListeners();
        return;
      }
      party?.control('next');
      return;
    }
    if (loopMode == LoopMode.one) {
      // next still advances when user taps next
    }
    if (queueIndex >= queue.length - 1) {
      if (loopMode == LoopMode.off && !shuffle) {
        return;
      }
      if (shuffle) {
        final cur = current!;
        final base = _orderQueue.isNotEmpty ? _orderQueue : queue;
        final rest = base.where((s) => s.id != cur.id).toList()..shuffle(Random());
        queue = [cur, ...rest];
        queueIndex = rest.isEmpty ? 0 : 1;
      } else {
        queueIndex = 0;
      }
    } else {
      queueIndex += 1;
    }
    await _playCurrent();
    if (inParty && !partyApplying && partyIsHost) _partyBroadcastQueueIfAllowed();
  }

  Future<void> prev() async {
    if (queue.isEmpty) return;
    if (inParty && !partyApplying && !partyIsHost) {
      if (player.position > const Duration(seconds: 3)) {
        if (party?.can('seek') != true) {
          error = '一起听中：无拖动进度权限';
          notifyListeners();
          return;
        }
        party?.control('seek', {'position': 0.0});
        return;
      }
      if (party?.can('skip') != true) {
        error = '一起听中：无切歌权限';
        notifyListeners();
        return;
      }
      party?.control('prev');
      return;
    }
    if (player.position > const Duration(seconds: 3)) {
      await player.seek(Duration.zero);
      if (inParty && partyIsHost) {
        party?.control('seek', {'position': 0.0});
      }
      return;
    }
    queueIndex = (queueIndex - 1 + queue.length) % queue.length;
    await _playCurrent();
    if (inParty && !partyApplying && partyIsHost) _partyBroadcastQueueIfAllowed();
  }

  Future<void> seek(Duration d) async {
    if (inParty && !partyApplying && !partyIsHost && !(party?.can('seek') == true)) {
      error = '一起听中：无拖动进度权限';
      notifyListeners();
      return;
    }
    await player.seek(d);
    if (inParty && !partyApplying && (partyIsHost || party?.can('seek') == true)) {
      party?.control('seek', {'position': d.inMilliseconds / 1000.0});
    }
  }

  // ---- Sleep timer + fade-out (A7) ----
  void setSleepTimer(int minutes) {
    _sleepTimer?.cancel();
    _fadeTimer?.cancel();
    _fadingOut = false;
    if (minutes <= 0) {
      cancelSleepTimer();
      return;
    }
    sleepUntil = DateTime.now().add(Duration(minutes: minutes));
    sleepMinutesLeft = minutes;
    // restore effective volume when starting a new timer
    player.setVolume(_effectiveVolume);
    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      final left = sleepUntil!.difference(DateTime.now());
      final sec = left.inSeconds;
      if (sec <= 0) {
        await _finishSleep();
        return;
      }
      // Last N seconds: linear fade to 0
      if (sec <= sleepFadeSeconds) {
        if (!_fadingOut) {
          _fadingOut = true;
        }
        final vol = _effectiveVolume * (sec / sleepFadeSeconds);
        await player.setVolume(vol.clamp(0.0, 1.0));
      }
      sleepMinutesLeft = (sec / 60).ceil().clamp(0, minutes);
      notifyListeners();
    });
    notifyListeners();
  }

  Future<void> _finishSleep() async {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _fadeTimer?.cancel();
    sleepUntil = null;
    sleepMinutesLeft = null;
    _fadingOut = false;
    await player.pause();
    await player.setVolume(_effectiveVolume);
    notifyListeners();
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _fadeTimer?.cancel();
    _fadeTimer = null;
    sleepUntil = null;
    sleepMinutesLeft = null;
    _fadingOut = false;
    player.setVolume(_effectiveVolume);
    notifyListeners();
  }

  @override
  void dispose() {
    _heartbeat?.cancel();
    _progressTimer?.cancel();
    _sleepTimer?.cancel();
    _fadeTimer?.cancel();
    _stopKaraokePoll();
    unawaited(purgeKaraokeSession(silent: true));
    unawaited(party?.dispose() ?? Future<void>.value());
    unawaited(purgeOnlineSessionCache());
    equalizer.release();
    if (_handler == null) {
      _fallbackPlayer.dispose();
    }
    super.dispose();
  }
}
