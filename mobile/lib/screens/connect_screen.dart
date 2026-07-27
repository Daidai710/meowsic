import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../state/hub_state.dart';
import '../util/hub_url.dart';
import '../util/lan_discovery.dart';
import '../util/haptics.dart';
import '../widgets/cat_decor.dart';
import 'qr_scan_screen.dart';

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key, this.onConnected});

  final VoidCallback? onConnected;

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  final _ctrl = TextEditingController(text: 'http://192.168.0.8:8787');
  final _pwCtrl = TextEditingController();
  bool _busy = false;
  bool _scanning = false;
  List<String> _discovered = [];

  @override
  void initState() {
    super.initState();
    final hub = context.read<HubState>();
    if (hub.baseUrl.isNotEmpty) {
      _ctrl.text = hub.baseUrl;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  Future<void> _connect([String? overrideUrl]) async {
    final raw = (overrideUrl ?? _ctrl.text).trim();
    final url = extractHubUrl(raw) ?? raw;
    _ctrl.text = url;
    setState(() => _busy = true);
    final pw = _pwCtrl.text.trim();
    MeowsicHaptics.medium();
    final ok = await context.read<HubState>().connect(url, password: pw.isEmpty ? null : pw);
    setState(() => _busy = false);
    if (!mounted) return;
    if (ok) {
      MeowsicHaptics.medium();
      // Cat atmosphere: paw-step celebration (UI chrome; themes only recolor)
      if (mounted) {
        await showMeowsicConnectCelebration(context);
      }
      if (!mounted) return;
      widget.onConnected?.call();
      final hub = context.read<HubState>();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              CatPawIcon(size: 18, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(child: Text('已连接 $url')),
            ],
          ),
        ),
      );
      if (hub.pendingResume?.song != null) {
        final resume = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('继续播放？'),
            content: Text(
              '发现其他设备进度：\n${hub.pendingResume!.song!.title}\n'
              '约 ${hub.pendingResume!.position.toStringAsFixed(0)} 秒处',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('忽略')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('继续')),
            ],
          ),
        );
        if (resume == true) {
          await hub.resumePending();
        } else {
          hub.dismissResume();
        }
      }
    } else {
      final err = context.read<HubState>().connectionHint ?? context.read<HubState>().error ?? '连接失败';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  Future<void> _scanQr() async {
    final url = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const QrScanScreen()),
    );
    if (url == null || !mounted) return;
    _ctrl.text = url;
    await _connect(url);
  }

  Future<void> _discover() async {
    setState(() {
      _scanning = true;
      _discovered = [];
    });
    try {
      final list = await discoverMusicHubs();
      setState(() => _discovered = list);
      if (list.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('未发现服务器，请确认同一 Wi‑Fi 且服务已启动')),
        );
      }
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('剪贴板为空')));
      return;
    }
    final url = extractHubUrl(text);
    if (url == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('无法识别地址：$text')));
      return;
    }
    _ctrl.text = url;
    setState(() {});
    await _connect(url);
  }

  @override
  Widget build(BuildContext context) {
    final hub = context.watch<HubState>();
    final theme = Theme.of(context);
    final onMuted = theme.colorScheme.onSurface.withValues(alpha: 0.65);
    final onFaint = theme.colorScheme.onSurface.withValues(alpha: 0.48);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 12),
            MeowsicPanel(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
              child: Column(
                children: [
                  const MeowsicBrandMark(size: 108),
                  const SizedBox(height: 10),
                  Text(
                    'meowsic',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '喵～ 戴上耳机，连接笔记本曲库',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(color: onMuted),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '同一 Wi‑Fi · 私人音乐库',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(color: onFaint),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              onPressed: _busy ? null : _scanQr,
              icon: const Icon(Icons.qr_code_scanner, size: 28),
              label: const Text('扫码连接'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: (_busy || _scanning) ? null : _discover,
              icon: _scanning
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.radar),
              label: Text(_scanning ? '正在扫描局域网…' : '自动发现服务器'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _busy ? null : _paste,
              icon: const Icon(Icons.content_paste),
              label: const Text('粘贴链接并连接'),
            ),
            const SizedBox(height: 10),
            FilledButton.tonalIcon(
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              onPressed: _busy
                  ? null
                  : () async {
                      MeowsicHaptics.medium();
                      setState(() => _busy = true);
                      final hub = context.read<HubState>();
                      final messenger = ScaffoldMessenger.of(context);
                      await hub.enterOfflineMode();
                      if (!mounted) return;
                      setState(() => _busy = false);
                      final n = hub.localSongs.length;
                      widget.onConnected?.call();
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            n > 0
                                ? '离线模式 · 本机已有 $n 首（可再扫描）'
                                : '离线模式 · 点曲库「扫描本机」导入音频',
                          ),
                        ),
                      );
                    },
              icon: const Icon(Icons.phone_android),
              label: Text(
                hub.localSongs.isEmpty ? '离线听本机' : '离线听本机（${hub.localSongs.length} 首）',
              ),
            ),
            if (_discovered.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('发现的服务器', style: Theme.of(context).textTheme.titleSmall),
              ..._discovered.map(
                (u) => ListTile(
                  leading: const Icon(Icons.dns),
                  title: Text(u),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    _ctrl.text = u;
                    _connect(u);
                  },
                ),
              ),
            ],
            const SizedBox(height: 24),
            TextField(
              controller: _ctrl,
              decoration: const InputDecoration(
                labelText: '服务器地址',
                hintText: 'http://192.168.x.x:8787',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.dns_outlined),
              ),
              keyboardType: TextInputType.url,
              onSubmitted: (_) => _connect(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pwCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: '访问密码（若服务器启用）',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: _busy ? null : () => _connect(),
              icon: _busy
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.link),
              label: Text(_busy ? '连接中…' : '连接'),
            ),
            if (hub.connectionHint != null && !hub.connected) ...[
              const SizedBox(height: 16),
              Card(
                color: theme.colorScheme.primary.withValues(alpha: 0.14),
                child: ListTile(
                  leading: Icon(Icons.info_outline, color: theme.colorScheme.primary),
                  title: const Text('连接提示'),
                  subtitle: Text(hub.connectionHint!),
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
