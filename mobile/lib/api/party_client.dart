import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

/// Listen-together WebSocket + REST client.
class PartyClient {
  PartyClient({required this.baseUrl, this.authToken});

  String baseUrl;
  String? authToken;

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _hostTick;
  bool _closed = true;

  String? code;
  Map<String, dynamic>? room;
  Map<String, dynamic>? you;

  void Function(Map<String, dynamic> room, Map<String, dynamic>? you)? onState;
  void Function(String message)? onError;
  void Function(String message)? onKicked;
  void Function()? onLeft;
  Map<String, dynamic>? Function()? hostTickProvider;

  static const permLabels = <String, String>{
    'skip': '切歌 / 点歌',
    'play_pause': '播放 / 暂停',
    'seek': '拖动进度',
    'scene': '房间场景 / EQ',
    'queue': '改队列',
  };

  bool get isInRoom => code != null && room != null;

  bool get isHost => you?['role'] == 'host';

  bool get isMod => you?['role'] == 'mod';

  Map<String, bool> get perms {
    final raw = you?['perms'];
    if (raw is Map) {
      return raw.map((k, v) => MapEntry('$k', v == true));
    }
    return {};
  }

  bool can(String action) {
    if (you == null) return false;
    if (you!['role'] == 'host') return true;
    if (you!['role'] != 'mod') return false;
    const map = {
      'play': 'play_pause',
      'pause': 'play_pause',
      'toggle': 'play_pause',
      'seek': 'seek',
      'next': 'skip',
      'prev': 'skip',
      'set_song': 'skip',
      'set_queue': 'queue',
      'queue_add': 'queue',
      'set_scene': 'scene',
      'set_speed': 'scene',
    };
    final key = map[action];
    if (key == null) return false;
    return perms[key] == true;
  }

  Uri _u(String path) {
    final b = baseUrl.replaceAll(RegExp(r'/$'), '');
    return Uri.parse('$b$path');
  }

  Map<String, String> get _headers {
    final h = <String, String>{'Content-Type': 'application/json'};
    if (authToken != null && authToken!.isNotEmpty) {
      h['x-music-hub-token'] = authToken!;
    }
    return h;
  }

  Future<Map<String, dynamic>> fetchMeta() async {
    final r = await http.get(_u('/api/party/meta'), headers: _headers).timeout(const Duration(seconds: 10));
    if (r.statusCode >= 400) return {'perm_keys': permLabels.keys.toList(), 'default_mod_perms': {}};
    return jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> create({
    required String deviceId,
    required String name,
    String platform = 'flutter',
  }) async {
    final r = await http
        .post(
          _u('/api/party/create'),
          headers: _headers,
          body: jsonEncode({'device_id': deviceId, 'name': name, 'platform': platform}),
        )
        .timeout(const Duration(seconds: 12));
    final j = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    if (r.statusCode >= 400) {
      throw Exception(j['detail']?.toString() ?? '创建房间失败');
    }
    room = j['room'] as Map<String, dynamic>?;
    code = room?['code']?.toString();
    await _connectWs(deviceId);
    return room!;
  }

  Future<Map<String, dynamic>> join({
    required String roomCode,
    required String deviceId,
    required String name,
    String platform = 'flutter',
  }) async {
    final r = await http
        .post(
          _u('/api/party/join'),
          headers: _headers,
          body: jsonEncode({
            'code': roomCode.trim().toUpperCase(),
            'device_id': deviceId,
            'name': name,
            'platform': platform,
          }),
        )
        .timeout(const Duration(seconds: 12));
    final j = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    if (r.statusCode >= 400) {
      throw Exception(j['detail']?.toString() ?? '加入失败');
    }
    room = j['room'] as Map<String, dynamic>?;
    code = room?['code']?.toString();
    await _connectWs(deviceId);
    return room!;
  }

  Future<void> _connectWs(String deviceId) async {
    await disposeSocketOnly();
    _closed = false;
    final b = baseUrl.replaceAll(RegExp(r'/$'), '');
    final wsBase = b.replaceFirst(RegExp(r'^http'), 'ws');
    final q = <String, String>{'device_id': deviceId};
    if (authToken != null && authToken!.isNotEmpty) q['token'] = authToken!;
    final uri = Uri.parse('$wsBase/ws/party/$code').replace(queryParameters: q);
    final ch = WebSocketChannel.connect(uri);
    _channel = ch;
    final ready = Completer<void>();
    _sub = ch.stream.listen(
      (raw) {
        try {
          final msg = jsonDecode(raw as String) as Map<String, dynamic>;
          _onMessage(msg);
          if (msg['type'] == 'hello' && !ready.isCompleted) ready.complete();
        } catch (_) {}
      },
      onError: (_) {
        if (!ready.isCompleted) ready.completeError(Exception('WebSocket 失败'));
      },
      onDone: () {
        _stopHostTick();
        if (!_closed && code != null) {
          Future<void>.delayed(const Duration(seconds: 2), () {
            if (!_closed && code != null) {
              _connectWs(deviceId).catchError((_) {});
            }
          });
        }
      },
    );
    await ready.future.timeout(const Duration(seconds: 8));
  }

  void _onMessage(Map<String, dynamic> msg) {
    final type = msg['type']?.toString();
    if (type == 'hello' || type == 'state') {
      if (msg['room'] is Map) room = Map<String, dynamic>.from(msg['room'] as Map);
      if (msg['you'] is Map) {
        you = Map<String, dynamic>.from(msg['you'] as Map);
      } else {
        _refreshYou();
      }
      if (isHost) {
        _startHostTick();
      } else {
        _stopHostTick();
      }
      onState?.call(room ?? {}, you);
    } else if (type == 'error') {
      onError?.call(msg['message']?.toString() ?? '错误');
    } else if (type == 'kicked') {
      _closed = true;
      code = null;
      room = null;
      you = null;
      onKicked?.call(msg['message']?.toString() ?? '已移出房间');
    }
  }

  void _refreshYou() {
    final members = room?['members'];
    if (members is! List || you == null) return;
    // keep you from last hello if member list updated
    final id = you!['device_id'];
    for (final m in members) {
      if (m is Map && m['device_id'] == id) {
        you = Map<String, dynamic>.from(m);
        return;
      }
    }
  }

  void send(Map<String, dynamic> obj) {
    final ch = _channel;
    if (ch == null) return;
    ch.sink.add(jsonEncode(obj));
  }

  void control(String action, [Map<String, dynamic>? extra]) {
    send({'type': 'control', 'action': action, ...?extra});
  }

  void setRole(String targetId, String role, Map<String, bool> perms) {
    send({'type': 'set_role', 'target_id': targetId, 'role': role, 'perms': perms});
  }

  void kick(String targetId) {
    send({'type': 'kick', 'target_id': targetId});
  }

  void transferHost(String targetId) {
    send({'type': 'transfer_host', 'target_id': targetId});
  }

  void leave() {
    _closed = true;
    _stopHostTick();
    send({'type': 'leave'});
    disposeSocketOnly();
    code = null;
    room = null;
    you = null;
    onLeft?.call();
  }

  void _startHostTick() {
    _hostTick?.cancel();
    _hostTick = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!isHost) return;
      final tick = hostTickProvider?.call();
      if (tick == null) return;
      control('host_tick', tick);
    });
  }

  void _stopHostTick() {
    _hostTick?.cancel();
    _hostTick = null;
  }

  Future<void> disposeSocketOnly() async {
    await _sub?.cancel();
    _sub = null;
    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;
  }

  Future<void> dispose() async {
    _closed = true;
    _stopHostTick();
    await disposeSocketOnly();
  }
}
