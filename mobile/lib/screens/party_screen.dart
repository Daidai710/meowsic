import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../api/party_client.dart';
import '../state/hub_state.dart';
import '../widgets/cat_decor.dart';

/// 一起听：同步房间 + 共用曲库各自听（设备管理）
class PartyScreen extends StatefulWidget {
  const PartyScreen({super.key});

  @override
  State<PartyScreen> createState() => _PartyScreenState();
}

class _PartyScreenState extends State<PartyScreen> {
  /// 0 = 同步听，1 = 各自听（同曲库）
  int _mode = 0;
  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  String? _selectedMember;
  Map<String, bool> _permDraft = {
    'skip': true,
    'play_pause': false,
    'seek': false,
    'scene': true,
    'queue': false,
  };
  Map<String, dynamic> _meta = {};
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final hub = context.read<HubState>();
      _nameCtrl.text = '手机';
      await hub.refreshDevices();
      final c = PartyClient(baseUrl: hub.baseUrl, authToken: hub.authToken);
      final m = await c.fetchMeta();
      if (!mounted) return;
      setState(() {
        _meta = m;
        final d = m['default_mod_perms'];
        if (d is Map) {
          _permDraft = {
            for (final k in PartyClient.permLabels.keys) k: d[k] == true,
          };
        }
        if (hub.inParty) _mode = 0;
      });
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  String _joinUrl(HubState hub, String code) {
    final base = hub.baseUrl.replaceAll(RegExp(r'/$'), '');
    return '$base/?party=${Uri.encodeComponent(code)}';
  }

  String _qrUrl(HubState hub, String code) {
    final join = _joinUrl(hub, code);
    final base = hub.baseUrl.replaceAll(RegExp(r'/$'), '');
    return '$base/api/qr.png?url=${Uri.encodeQueryComponent(join)}&t=${DateTime.now().millisecondsSinceEpoch ~/ 30000}';
  }

  @override
  Widget build(BuildContext context) {
    final hub = context.watch<HubState>();
    final party = hub.party;
    final inRoom = hub.inParty;
    final room = party?.room;
    final you = party?.you;
    final members = (room?['members'] is List) ? room!['members'] as List : const [];
    final labels = <String, String>{
      ...PartyClient.permLabels,
      if (_meta['perm_labels'] is Map)
        for (final e in (_meta['perm_labels'] as Map).entries) '${e.key}': '${e.value}',
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('一起听'),
        actions: [
          if (_mode == 1)
            IconButton(
              tooltip: '刷新设备',
              onPressed: () => hub.refreshDevices(),
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('同步听'), icon: Icon(Icons.sync, size: 18)),
              ButtonSegment(value: 1, label: Text('各自听'), icon: Icon(Icons.library_music_outlined, size: 18)),
            ],
            selected: {_mode},
            onSelectionChanged: (s) => setState(() => _mode = s.first),
          ),
          const SizedBox(height: 12),
          Text(
            _mode == 0
                ? '同步听：多人同一进度；房主主控，可授予管理员切歌/场景等权限。'
                : '各自听：共用同一电脑曲库，每人独立点歌播放；可查看在线设备并踢人。不同步进度。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white60, height: 1.35),
          ),
          const SizedBox(height: 16),
          if (_mode == 0) ..._buildSyncMode(context, hub, inRoom, room, you, members, labels),
          if (_mode == 1) ..._buildSoloMode(context, hub),
          const SizedBox(height: 24),
          Text('跨网', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            '同 Wi‑Fi 填局域网地址即可。不同网络请用 Tailscale / 隧道访问 Hub，再同步听或各自听。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white54, height: 1.4),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSyncMode(
    BuildContext context,
    HubState hub,
    bool inRoom,
    Map<String, dynamic>? room,
    Map<String, dynamic>? you,
    List members,
    Map<String, String> labels,
  ) {
    return [
      TextField(
        controller: _nameCtrl,
        decoration: const InputDecoration(
          labelText: '本机显示名',
          border: OutlineInputBorder(),
        ),
      ),
      if (!inRoom) ...[
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _busy
              ? null
              : () async {
                  setState(() => _busy = true);
                  final err = await hub.partyCreate(displayName: _nameCtrl.text.trim());
                  setState(() => _busy = false);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(err ?? '房间已创建：${hub.party?.code}')),
                  );
                },
          icon: const Icon(Icons.add_circle_outline),
          label: const Text('创建同步房间'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _codeCtrl,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: '房间码',
            border: OutlineInputBorder(),
            hintText: '6 位',
          ),
          inputFormatters: [LengthLimitingTextInputFormatter(8)],
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _busy
              ? null
              : () async {
                  setState(() => _busy = true);
                  final err = await hub.partyJoin(_codeCtrl.text, displayName: _nameCtrl.text.trim());
                  setState(() => _busy = false);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(err ?? '已加入 ${hub.party?.code}')),
                  );
                },
          icon: const Icon(Icons.login),
          label: const Text('加入房间'),
        ),
      ],
      if (inRoom && room != null) ...[
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '房间 ${room['code']}',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: 3),
                      ),
                    ),
                    IconButton(
                      tooltip: '复制房间码',
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: '${room['code']}'));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('已复制房间码')),
                          );
                        }
                      },
                      icon: const Icon(Icons.pin_outlined),
                    ),
                  ],
                ),
                Text(
                  _roleLine(you, room),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70),
                ),
                if (hub.partyError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(hub.partyError!, style: const TextStyle(color: Colors.orangeAccent)),
                  ),
                const SizedBox(height: 12),
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      _qrUrl(hub, '${room['code']}'),
                      width: 200,
                      height: 200,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const SizedBox(
                        height: 80,
                        child: Center(child: Text('二维码加载失败\n请确认 Hub 已装 qrcode', textAlign: TextAlign.center)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SelectableText(
                  _joinUrl(hub, '${room['code']}'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.primary),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: () async {
                        final url = _joinUrl(hub, '${room['code']}');
                        await Clipboard.setData(ClipboardData(text: url));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('已复制邀请链接')),
                          );
                        }
                      },
                      icon: const Icon(Icons.link),
                      label: const Text('复制邀请链接'),
                    ),
                    OutlinedButton(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: '${room['code']}'));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('已复制房间码')),
                          );
                        }
                      },
                      child: const Text('复制房间码'),
                    ),
                    OutlinedButton(onPressed: () => hub.partyLeave(), child: const Text('离开房间')),
                  ],
                ),
                const SizedBox(height: 12),
                Text(_trackLine(hub, room), style: Theme.of(context).textTheme.bodyMedium),
                Text(_permLine(you, labels), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white54)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text('房间成员', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ...members.map((raw) {
          final m = Map<String, dynamic>.from(raw as Map);
          final id = '${m['device_id']}';
          final name = '${m['name'] ?? '设备'}';
          final role = '${m['role'] ?? 'guest'}';
          final isMe = id == hub.deviceId;
          final selected = _selectedMember == id;
          return Card(
            color: selected ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15) : null,
            child: ListTile(
              selected: selected,
              onTap: () => setState(() => _selectedMember = id),
              title: Text('$name${isMe ? '（我）' : ''}'),
              subtitle: Text(m['online'] == false ? '离线' : '在线'),
              trailing: MeowsicRoleBadge(role: role),
            ),
          );
        }),
        if (you?['role'] == 'host') ...[
          const SizedBox(height: 16),
          Text('授予管理员权限', style: Theme.of(context).textTheme.titleMedium),
          Text(
            '点选成员后勾选权限。也可踢出成员。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white54),
          ),
          ...PartyClient.permLabels.keys.map((k) {
            return CheckboxListTile(
              dense: true,
              value: _permDraft[k] == true,
              onChanged: (v) => setState(() => _permDraft[k] = v == true),
              title: Text(labels[k] ?? k),
            );
          }),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: _selectedMember == null || _selectedMember == hub.deviceId
                    ? null
                    : () {
                        hub.partySetRole(_selectedMember!, 'mod', Map<String, bool>.from(_permDraft));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('已设为管理员')),
                        );
                      },
                child: const Text('设为管理员'),
              ),
              OutlinedButton(
                onPressed: _selectedMember == null || _selectedMember == hub.deviceId
                    ? null
                    : () => hub.partySetRole(_selectedMember!, 'guest', {}),
                child: const Text('降为听众'),
              ),
              OutlinedButton(
                onPressed: _selectedMember == null || _selectedMember == hub.deviceId
                    ? null
                    : () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (c) => AlertDialog(
                            title: const Text('转让房主？'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('取消')),
                              FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('转让')),
                            ],
                          ),
                        );
                        if (ok == true) hub.partyTransferHost(_selectedMember!);
                      },
                child: const Text('转让房主'),
              ),
              TextButton(
                onPressed: _selectedMember == null || _selectedMember == hub.deviceId
                    ? null
                    : () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (c) => AlertDialog(
                            title: const Text('踢出房间成员？'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('取消')),
                              FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('踢出')),
                            ],
                          ),
                        );
                        if (ok == true) {
                          hub.partyKick(_selectedMember!);
                          setState(() => _selectedMember = null);
                        }
                      },
                child: const Text('踢出'),
              ),
            ],
          ),
        ],
      ],
    ];
  }

  List<Widget> _buildSoloMode(BuildContext context, HubState hub) {
    final devices = hub.devices;
    return [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('当前 Hub', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              SelectableText(hub.baseUrl, style: TextStyle(color: Theme.of(context).colorScheme.primary)),
              const SizedBox(height: 8),
              Text(
                '所有连上此地址的设备共享同一曲库，各自搜索、点歌、建歌单，互不影响进度。',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white60),
              ),
              if (hub.inParty) ...[
                const SizedBox(height: 10),
                Text(
                  '你仍在同步房间 ${hub.party?.code}。若只要各自听，可先离开房间。',
                  style: const TextStyle(color: Colors.orangeAccent, fontSize: 12),
                ),
                TextButton(onPressed: () => hub.partyLeave(), child: const Text('离开同步房间')),
              ],
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      Text('在线设备', style: Theme.of(context).textTheme.titleMedium),
      Text(
        '心跳上报的设备；可踢下线（对方需重连）。同步房间内踢人请到「同步听」。',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white54),
      ),
      const SizedBox(height: 8),
      if (devices.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: Text('暂无设备记录\n连接并播放后会自动上报', textAlign: TextAlign.center)),
        )
      else
        ...devices.map((d) {
          final id = '${d['device_id'] ?? ''}';
          final name = '${d['name'] ?? 'Device'}';
          final platform = '${d['platform'] ?? ''}';
          final online = d['online'] == 1 || d['online'] == true;
          final kicked = d['kicked'] == 1 || d['kicked'] == true;
          final isMe = id == hub.deviceId;
          return Card(
            child: ListTile(
              leading: Icon(
                online ? Icons.smartphone : Icons.phonelink_off,
                color: kicked
                    ? Colors.redAccent
                    : online
                        ? Colors.greenAccent
                        : Colors.white38,
              ),
              title: Text('$name${isMe ? '（本机）' : ''}'),
              subtitle: Text('$platform\n${d['last_seen'] ?? ''}'),
              isThreeLine: true,
              trailing: isMe
                  ? CatPawIcon(size: 22, color: Theme.of(context).colorScheme.primary)
                  : (kicked
                      ? const Text('已踢', style: TextStyle(color: Colors.redAccent))
                      : TextButton(
                          onPressed: () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (c) => AlertDialog(
                                title: const Text('踢下线？'),
                                content: Text('确定踢掉 $name？对方需重新连接。'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('取消')),
                                  FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('踢下线')),
                                ],
                              ),
                            );
                            if (ok == true) await hub.kickDevice(id);
                          },
                          child: const Text('踢下线'),
                        )),
            ),
          );
        }),
    ];
  }

  String _roleLine(Map<String, dynamic>? you, Map<String, dynamic> room) {
    final role = you?['role']?.toString() ?? 'guest';
    final label = role == 'host' ? '房主' : role == 'mod' ? '管理员' : '听众';
    return '你是$label · 在线 ${room['online_count'] ?? '?'} / ${room['member_count'] ?? '?'}';
  }

  String _trackLine(HubState hub, Map<String, dynamic> room) {
    final st = room['state'];
    if (st is! Map) return '当前曲目：—';
    final id = st['song_id'];
    if (id == null) return '当前曲目：—';
    final song = hub.current;
    if (song != null && song.id == id) {
      return '当前曲目：${song.title} — ${song.artist}';
    }
    return '当前曲目：#$id';
  }

  String _permLine(Map<String, dynamic>? you, Map<String, String> labels) {
    final role = you?['role']?.toString() ?? 'guest';
    if (role == 'host') return '权限：全部（房主）';
    if (role != 'mod') return '权限：仅跟随播放';
    final perms = you?['perms'];
    if (perms is! Map) return '权限：无';
    final on = perms.entries.where((e) => e.value == true).map((e) => labels['${e.key}'] ?? '${e.key}').toList();
    return on.isEmpty ? '权限：无（仅跟随）' : '权限：${on.join('、')}';
  }
}
