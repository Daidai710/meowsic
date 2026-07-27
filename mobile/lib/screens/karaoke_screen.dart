import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/hub_state.dart';
import '../util/haptics.dart';
/// Independent K 歌 mode: pick songs → serial Spleeter pipeline → play.
/// Session stem cache is wiped when leaving mode / app background.
class KaraokeScreen extends StatefulWidget {
  const KaraokeScreen({super.key});

  @override
  State<KaraokeScreen> createState() => _KaraokeScreenState();
}

class _KaraokeScreenState extends State<KaraokeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final hub = context.read<HubState>();
      if (!hub.karaokeMode) {
        hub.enterKaraokeMode();
      }
    });
  }

  Future<void> _pickSongs(HubState hub) async {
    final picked = await showModalBottomSheet<List<Song>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _SongPickSheet(hub: hub),
    );
    if (picked == null || picked.isEmpty || !mounted) return;
    MeowsicHaptics.medium();
    final msg = await hub.karaokeAddSongs(picked, append: true);
    if (!mounted) return;
    if (msg != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
      );
    }
  }

  Future<void> _addCurrentQueue(HubState hub) async {
    if (hub.queue.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('播放队列为空')),
      );
      return;
    }
    MeowsicHaptics.medium();
    final msg = await hub.karaokeAddSongs(hub.queue, append: true);
    if (!mounted) return;
    if (msg != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
      );
    }
  }

  Future<void> _exit(HubState hub) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退出 K 歌模式？'),
        content: const Text('将取消流水线，并删除本会话在电脑上的伴奏缓存。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('退出并清缓存')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await hub.exitKaraokeMode(purgeCache: true);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final hub = context.watch<HubState>();
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('K 歌模式'),
        actions: [
          TextButton(
            onPressed: () => _exit(hub),
            child: const Text('退出'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Material(
              color: cs.primaryContainer.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.mic_external_on_rounded, color: cs.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '流水线分轨 · EQ 兜底',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      hub.karaokeStatusHint.isEmpty
                          ? '选歌后按顺序用电脑 Spleeter 去人声；关 App / 进后台会清缓存。'
                          : hub.karaokeStatusHint,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.75),
                        height: 1.35,
                      ),
                    ),
                    if (hub.karaokePipe.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: hub.karaokePipe.isEmpty
                              ? 0
                              : hub.karaokeReadyCount / hub.karaokePipe.length,
                          minHeight: 6,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '进度 ${hub.karaokeReadyCount}/${hub.karaokePipe.length}'
                        '${hub.karaokeRunningCount > 0 ? ' · 正在分离' : ''}',
                        style: theme.textTheme.labelMedium?.copyWith(color: cs.primary),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        ActionChip(
                          avatar: const Icon(Icons.tune, size: 16),
                          label: Text('EQ 深度 ${hub.karaokeDepthLabel}'),
                          onPressed: () => _pickDepth(context, hub),
                        ),
                        if (hub.karaokeUsingStem)
                          Chip(
                            avatar: Icon(Icons.check_circle, size: 16, color: cs.primary),
                            label: const Text('AI 伴奏中'),
                          )
                        else if (hub.karaokeMode)
                          const Chip(
                            avatar: Icon(Icons.equalizer, size: 16),
                            label: Text('EQ 弱人声'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: hub.offlineMode || !hub.connected
                        ? null
                        : () => _pickSongs(hub),
                    icon: const Icon(Icons.playlist_add),
                    label: const Text('从曲库选歌'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: hub.queue.isEmpty ? null : () => _addCurrentQueue(hub),
                    icon: const Icon(Icons.queue_music),
                    label: const Text('导入播放队列'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: hub.karaokePipe.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        hub.offlineMode || !hub.connected
                            ? '请先连接电脑 Music Hub\n（Spleeter 在 D:\\声音分离 运行）'
                            : '还没有 K 歌曲目\n点「从曲库选歌」加入流水线',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.55),
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: hub.karaokePipe.length,
                    itemBuilder: (context, i) {
                      final item = hub.karaokePipe[i];
                      final playing = hub.current?.id == item.song.id && hub.karaokeMode;
                      return Dismissible(
                        key: ValueKey('k-${item.song.id}-$i'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: Colors.red.shade800,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 16),
                          child: const Icon(Icons.delete),
                        ),
                        onDismissed: (_) => hub.karaokeRemoveAt(i),
                        child: ListTile(
                          leading: _stateIcon(item, cs),
                          title: Text(
                            item.song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            _subtitle(item),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: item.isError
                                  ? Colors.orangeAccent
                                  : cs.onSurface.withValues(alpha: 0.65),
                              fontSize: 12,
                            ),
                          ),
                          trailing: IconButton(
                            tooltip: '播放',
                            icon: Icon(
                              playing ? Icons.equalizer : Icons.play_arrow_rounded,
                              color: playing ? cs.primary : null,
                            ),
                            onPressed: () {
                              MeowsicHaptics.light();
                              hub.karaokePlayFrom(i);
                            },
                          ),
                          onTap: () {
                            MeowsicHaptics.light();
                            hub.karaokePlayFrom(i);
                          },
                        ),
                      );
                    },
                  ),
          ),
          if (hub.karaokePipe.isNotEmpty)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: FilledButton.icon(
                  onPressed: () {
                    MeowsicHaptics.medium();
                    hub.karaokePlayFrom(0);
                  },
                  icon: const Icon(Icons.play_circle_filled),
                  label: Text(
                    hub.karaokeReadyCount > 0
                        ? '从第一首开始唱（${hub.karaokeReadyCount} 首已就绪）'
                        : '先唱起来（EQ 兜底，就绪后自动切伴奏）',
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _stateIcon(KaraokePipeItem item, ColorScheme cs) {
    switch (item.state) {
      case KaraokePipeState.ready:
        return CircleAvatar(
          backgroundColor: cs.primary.withValues(alpha: 0.2),
          child: Icon(Icons.check, color: cs.primary, size: 20),
        );
      case KaraokePipeState.running:
        return const SizedBox(
          width: 40,
          height: 40,
          child: Padding(
            padding: EdgeInsets.all(10),
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        );
      case KaraokePipeState.error:
        return CircleAvatar(
          backgroundColor: Colors.orange.withValues(alpha: 0.2),
          child: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
        );
      case KaraokePipeState.queued:
        return CircleAvatar(
          backgroundColor: cs.surfaceContainerHighest,
          child: Icon(Icons.hourglass_empty, color: cs.onSurfaceVariant, size: 20),
        );
    }
  }

  String _subtitle(KaraokePipeItem item) {
    final artist = item.song.artist;
    final st = switch (item.state) {
      KaraokePipeState.ready => '可唱 · AI 伴奏${item.engine != null ? ' (${item.engine})' : ''}',
      KaraokePipeState.running => item.message ?? '分离中…',
      KaraokePipeState.error => '失败 · EQ 兜底可唱 · ${item.error ?? ''}',
      KaraokePipeState.queued => item.message ?? '排队等待',
    };
    return '$artist\n$st';
  }

  Future<void> _pickDepth(BuildContext context, HubState hub) async {
    final picked = await showModalBottomSheet<KaraokeDepth>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text('EQ 弱人声深度（伴奏未就绪时）'),
            ),
            for (final d in KaraokeDepth.values)
              ListTile(
                leading: Icon(
                  d == hub.karaokeDepth ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: d == hub.karaokeDepth ? Theme.of(ctx).colorScheme.primary : null,
                ),
                title: Text({
                  KaraokeDepth.light: '浅 — 略压人声',
                  KaraokeDepth.medium: '中 — 默认',
                  KaraokeDepth.deep: '深 — 尽量压中频',
                }[d]!),
                selected: d == hub.karaokeDepth,
                onTap: () => Navigator.pop(ctx, d),
              ),
          ],
        ),
      ),
    );
    if (picked != null) await hub.setKaraokeDepth(picked);
  }
}

class _SongPickSheet extends StatefulWidget {
  const _SongPickSheet({required this.hub});
  final HubState hub;

  @override
  State<_SongPickSheet> createState() => _SongPickSheetState();
}

class _SongPickSheetState extends State<_SongPickSheet> {
  final _q = TextEditingController();
  final _selected = <int>{};

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  List<Song> get _list {
    final all = widget.hub.librarySongs.isNotEmpty
        ? widget.hub.librarySongs
        : widget.hub.songs;
    final q = _q.text.trim().toLowerCase();
    final hubOnly = all.where((s) => !s.isLocal && !s.isOnline).toList();
    if (q.isEmpty) return hubOnly;
    return hubOnly
        .where(
          (s) =>
              s.title.toLowerCase().contains(q) ||
              s.artist.toLowerCase().contains(q) ||
              s.album.toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final list = _list;
    final h = MediaQuery.of(context).size.height * 0.75;
    return SizedBox(
      height: h,
      child: Column(
        children: [
          const ListTile(
            title: Text('选择要唱的歌'),
            subtitle: Text('将按顺序进入 Spleeter 流水线'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _q,
              decoration: const InputDecoration(
                hintText: '筛选…',
                prefixIcon: Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: list.length,
              itemBuilder: (context, i) {
                final s = list[i];
                final on = _selected.contains(s.id);
                return CheckboxListTile(
                  value: on,
                  onChanged: (v) {
                    setState(() {
                      if (v == true) {
                        _selected.add(s.id);
                      } else {
                        _selected.remove(s.id);
                      }
                    });
                  },
                  title: Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(s.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: FilledButton(
                onPressed: _selected.isEmpty
                    ? null
                    : () {
                        final map = {for (final s in list) s.id: s};
                        // also resolve from full library
                        final full = widget.hub.librarySongs.isNotEmpty
                            ? widget.hub.librarySongs
                            : widget.hub.songs;
                        for (final s in full) {
                          map[s.id] = s;
                        }
                        final out = <Song>[
                          for (final id in _selected)
                            if (map[id] != null) map[id]!,
                        ];
                        Navigator.pop(context, out);
                      },
                child: Text('加入流水线（${_selected.length}）'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
