import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/models.dart';

class MusicHubApi {
  MusicHubApi(this.baseUrl, {this.token});

  /// e.g. http://192.168.0.8:8787  (no trailing slash)
  String baseUrl;
  String? token;

  Uri _u(String path, [Map<String, String>? query]) {
    final b = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final q = <String, String>{...?query};
    if (token != null && token!.isNotEmpty) q['token'] = token!;
    return Uri.parse('$b$path').replace(queryParameters: q.isEmpty ? null : q);
  }

  Map<String, String> get _headers {
    final h = <String, String>{'Content-Type': 'application/json'};
    if (token != null && token!.isNotEmpty) {
      h['X-Music-Hub-Token'] = token!;
    }
    return h;
  }

  Future<HubStatus> status() async {
    // Slightly longer timeout for flaky LAN / phone Doze wakeups.
    final r = await http.get(_u('/api/status'), headers: _headers).timeout(const Duration(seconds: 12));
    _ensureOk(r);
    return HubStatus.fromJson(jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>);
  }

  Future<String?> login(String password) async {
    final r = await http
        .post(
          _u('/api/auth/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'password': password}),
        )
        .timeout(const Duration(seconds: 10));
    _ensureOk(r);
    final j = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    if (j['ok'] == true) {
      final t = j['token'] as String?;
      token = t;
      return t;
    }
    return null;
  }

  Future<List<Song>> songs({
    String? q,
    String? artist,
    String? album,
    int? libraryIndex,
    String? library,
    int limit = 5000,
    int offset = 0,
  }) async {
    final query = <String, String>{
      'limit': '$limit',
      'offset': '$offset',
    };
    if (q != null && q.isNotEmpty) query['q'] = q;
    if (artist != null && artist.isNotEmpty) query['artist'] = artist;
    if (album != null && album.isNotEmpty) query['album'] = album;
    if (libraryIndex != null) query['library_index'] = '$libraryIndex';
    if (library != null && library.isNotEmpty) query['library'] = library;
    final r = await http.get(_u('/api/songs', query), headers: _headers).timeout(const Duration(seconds: 30));
    _ensureOk(r);
    final list = jsonDecode(utf8.decode(r.bodyBytes)) as List<dynamic>;
    return list.map((e) => Song.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Song>> allSongs({
    String? q,
    String? artist,
    String? album,
    int? libraryIndex,
    String? library,
  }) async {
    final all = <Song>[];
    var offset = 0;
    const page = 500;
    while (true) {
      final batch = await songs(
        q: q,
        artist: artist,
        album: album,
        libraryIndex: libraryIndex,
        library: library,
        limit: page,
        offset: offset,
      );
      all.addAll(batch);
      if (batch.length < page) break;
      offset += page;
      if (offset > 100000) break;
    }
    return all;
  }

  Future<List<Map<String, dynamic>>> artists() async {
    final r = await http.get(_u('/api/artists'), headers: _headers).timeout(const Duration(seconds: 15));
    _ensureOk(r);
    return (jsonDecode(utf8.decode(r.bodyBytes)) as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> albums({String? artist}) async {
    final q = artist == null ? null : {'artist': artist};
    final r = await http.get(_u('/api/albums', q), headers: _headers).timeout(const Duration(seconds: 15));
    _ensureOk(r);
    return (jsonDecode(utf8.decode(r.bodyBytes)) as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<List<Playlist>> playlists() async {
    final r = await http.get(_u('/api/playlists'), headers: _headers).timeout(const Duration(seconds: 10));
    _ensureOk(r);
    final list = jsonDecode(utf8.decode(r.bodyBytes)) as List<dynamic>;
    return list.map((e) => Playlist.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Song>> playlistSongs(int id) async {
    final r = await http.get(_u('/api/playlists/$id/songs'), headers: _headers).timeout(const Duration(seconds: 20));
    _ensureOk(r);
    final list = jsonDecode(utf8.decode(r.bodyBytes)) as List<dynamic>;
    return list.map((e) => Song.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Playlist> createPlaylist(String name) async {
    final r = await http
        .post(
          _u('/api/playlists'),
          headers: _headers,
          body: jsonEncode({'name': name}),
        )
        .timeout(const Duration(seconds: 10));
    _ensureOk(r);
    return Playlist.fromJson(jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>);
  }

  Future<void> addToPlaylist(int playlistId, List<int> songIds) async {
    final r = await http
        .post(
          _u('/api/playlists/$playlistId/songs'),
          headers: _headers,
          body: jsonEncode({'song_ids': songIds}),
        )
        .timeout(const Duration(seconds: 10));
    _ensureOk(r);
  }

  Future<void> removeFromPlaylist(int playlistId, int songId) async {
    final r = await http.delete(_u('/api/playlists/$playlistId/songs/$songId'), headers: _headers).timeout(const Duration(seconds: 10));
    _ensureOk(r);
  }

  Future<Map<String, dynamic>> scan() async {
    final r = await http.post(_u('/api/scan'), headers: _headers).timeout(const Duration(minutes: 5));
    _ensureOk(r);
    return jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
  }

  Future<List<String>> listLibraries() async {
    final r = await http.get(_u('/api/libraries'), headers: _headers).timeout(const Duration(seconds: 10));
    _ensureOk(r);
    final j = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    final paths = j['paths'];
    if (paths is List) return paths.map((e) => '$e').toList();
    return [];
  }

  Future<List<String>> addLibrary(String path) async {
    final r = await http
        .post(
          _u('/api/libraries'),
          headers: _headers,
          body: jsonEncode({'path': path}),
        )
        .timeout(const Duration(seconds: 15));
    _ensureOk(r);
    final j = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    final paths = j['paths'];
    if (paths is List) return paths.map((e) => '$e').toList();
    return [];
  }

  Future<List<String>> removeLibrary(String path) async {
    final r = await http
        .delete(
          _u('/api/libraries'),
          headers: _headers,
          body: jsonEncode({'path': path}),
        )
        .timeout(const Duration(seconds: 15));
    _ensureOk(r);
    final j = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    final paths = j['paths'];
    if (paths is List) return paths.map((e) => '$e').toList();
    return [];
  }

  Future<List<Song>> recent({int limit = 50}) async {
    final r = await http.get(_u('/api/recent', {'limit': '$limit'}), headers: _headers).timeout(const Duration(seconds: 15));
    _ensureOk(r);
    final list = jsonDecode(utf8.decode(r.bodyBytes)) as List<dynamic>;
    return list.map((e) => Song.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> recordPlay(int songId, {String? device}) async {
    final q = device == null ? null : {'device': device};
    final r = await http.post(_u('/api/recent/$songId', q), headers: _headers).timeout(const Duration(seconds: 8));
    _ensureOk(r);
  }

  Future<void> saveProgress({
    required String deviceId,
    required int songId,
    required double position,
  }) async {
    final r = await http
        .post(
          _u('/api/progress'),
          headers: _headers,
          body: jsonEncode({
            'device_id': deviceId,
            'song_id': songId,
            'position': position,
          }),
        )
        .timeout(const Duration(seconds: 8));
    _ensureOk(r);
  }

  Future<ResumeProgress> getProgress(String deviceId) async {
    final r = await http.get(_u('/api/progress/${Uri.encodeComponent(deviceId)}'), headers: _headers).timeout(const Duration(seconds: 8));
    _ensureOk(r);
    return ResumeProgress.fromJson(jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>);
  }

  Future<ResumeProgress> getProgressLatest({String? excludeDevice}) async {
    final q = excludeDevice == null ? null : {'exclude_device': excludeDevice};
    final r = await http.get(_u('/api/progress-latest', q), headers: _headers).timeout(const Duration(seconds: 8));
    _ensureOk(r);
    return ResumeProgress.fromJson(jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>);
  }

  Future<LyricsData> lyrics(int songId) async {
    final r = await http.get(_u('/api/lyrics/$songId'), headers: _headers).timeout(const Duration(seconds: 10));
    _ensureOk(r);
    return LyricsData.fromJson(jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>);
  }

  /// Karaoke engine probe (SpleeterGUI / ffmpeg).
  Future<Map<String, dynamic>> karaokeEngine() async {
    final r = await http
        .get(_u('/api/karaoke'), headers: _headers)
        .timeout(const Duration(seconds: 12));
    _ensureOk(r);
    return jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
  }

  /// Karaoke accompaniment status (Spleeter / cached stem).
  Future<Map<String, dynamic>> karaokeStatus(int songId) async {
    final r = await http
        .get(_u('/api/karaoke/$songId'), headers: _headers)
        .timeout(const Duration(seconds: 12));
    _ensureOk(r);
    return jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
  }

  /// Start / await accompaniment prepare job on the hub.
  Future<Map<String, dynamic>> karaokePrepare(int songId) async {
    final r = await http
        .post(_u('/api/karaoke/$songId/prepare'), headers: _headers)
        .timeout(const Duration(seconds: 30));
    _ensureOk(r);
    return jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
  }

  /// Serial K 歌 pipeline: set or append song_ids for this device.
  Future<Map<String, dynamic>> karaokePipelineSet({
    required String deviceId,
    required List<int> songIds,
    bool append = false,
  }) async {
    final r = await http
        .post(
          _u('/api/karaoke/pipeline'),
          headers: _headers,
          body: jsonEncode({
            'device_id': deviceId,
            'song_ids': songIds,
            'append': append,
          }),
        )
        .timeout(const Duration(seconds: 30));
    _ensureOk(r);
    return jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> karaokePipelineStatus(String deviceId) async {
    final r = await http
        .get(
          _u('/api/karaoke/pipeline', {'device_id': deviceId}),
          headers: _headers,
        )
        .timeout(const Duration(seconds: 12));
    _ensureOk(r);
    return jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
  }

  /// Cancel pipeline + delete session stem cache (default).
  Future<Map<String, dynamic>> karaokePipelineClear(
    String deviceId, {
    bool deleteFiles = true,
  }) async {
    final r = await http
        .delete(
          _u('/api/karaoke/pipeline', {
            'device_id': deviceId,
            'delete_files': deleteFiles ? 'true' : 'false',
          }),
          headers: _headers,
        )
        .timeout(const Duration(seconds: 20));
    _ensureOk(r);
    return jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
  }

  Future<List<Song>> brokenSongs({int limit = 200}) async {
    final r = await http.get(_u('/api/songs-broken', {'limit': '$limit'}), headers: _headers).timeout(const Duration(seconds: 15));
    _ensureOk(r);
    final list = jsonDecode(utf8.decode(r.bodyBytes)) as List<dynamic>;
    return list.map((e) => Song.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<String> fixSong(int songId) async {
    final r = await http.post(_u('/api/songs/$songId/fix'), headers: _headers).timeout(const Duration(minutes: 10));
    _ensureOk(r);
    final j = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    return (j['message'] ?? 'ok') as String;
  }

  Future<Map<String, dynamic>> deviceHeartbeat({
    required String deviceId,
    required String name,
    required String platform,
  }) async {
    final r = await http
        .post(
          _u('/api/devices/heartbeat'),
          headers: _headers,
          body: jsonEncode({
            'device_id': deviceId,
            'name': name,
            'platform': platform,
          }),
        )
        .timeout(const Duration(seconds: 12));
    _ensureOk(r);
    return jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> listDevices() async {
    final r = await http.get(_u('/api/devices'), headers: _headers).timeout(const Duration(seconds: 10));
    _ensureOk(r);
    return (jsonDecode(utf8.decode(r.bodyBytes)) as List<dynamic>).cast<Map<String, dynamic>>();
  }

  Future<void> kickDevice(String deviceId) async {
    final r = await http
        .post(_u('/api/devices/${Uri.encodeComponent(deviceId)}/kick'), headers: _headers)
        .timeout(const Duration(seconds: 10));
    _ensureOk(r);
  }

  void _ensureOk(http.Response r) {
    if (r.statusCode >= 200 && r.statusCode < 300) return;
    if (r.statusCode == 401) throw Exception('需要密码 / Unauthorized');
    throw Exception('HTTP ${r.statusCode}: ${r.body}');
  }
}
