import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/hub_state.dart';
import '../util/haptics.dart';
import '../widgets/cat_decor.dart';
import 'karaoke_screen.dart';
import 'lyrics_sheet.dart';
import 'queue_screen.dart';

class NowPlayingScreen extends StatelessWidget {
  const NowPlayingScreen({super.key});

  String _t(Duration d) {
    final s = d.inSeconds;
    final m = s ~/ 60;
    final r = s % 60;
    return '$m:${r.toString().padLeft(2, '0')}';
  }

  IconData _loopIcon(LoopMode m) {
    switch (m) {
      case LoopMode.off:
        return Icons.repeat;
      case LoopMode.all:
        return Icons.repeat_on;
      case LoopMode.one:
        return Icons.repeat_one_on;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hub = context.watch<HubState>();
    final song = hub.current;
    if (song == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('未播放')),
      );
    }
    final cover = song.absoluteCoverUrl(hub.baseUrl);
    final pos = hub.player.position;
    final dur = hub.player.duration ?? Duration.zero;
    final maxMs = dur.inMilliseconds <= 0 ? 1.0 : dur.inMilliseconds.toDouble();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CatPawIcon(size: 18, color: cs.primary),
            const SizedBox(width: 8),
            const Text('正在播放'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '歌词',
            icon: const Icon(Icons.lyrics_outlined),
            onPressed: () => showLyricsSheet(context),
          ),
          IconButton(
            tooltip: '播放队列',
            icon: const Icon(Icons.queue_music),
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const QueueScreen()));
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final coverMax = (constraints.maxHeight * 0.38).clamp(160.0, 320.0);
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight - 16),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: coverMax, maxHeight: coverMax),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: cover != null
                            ? Image.network(
                                cover,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => _coverPh(),
                              )
                            : _coverPh(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    song.title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${song.artist} · ${song.album}',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 16),
                  Slider(
                    value: pos.inMilliseconds.clamp(0, maxMs.toInt()).toDouble(),
                    max: maxMs,
                    onChangeStart: (_) => MeowsicHaptics.selection(),
                    onChanged: (v) => hub.seek(Duration(milliseconds: v.round())),
                    onChangeEnd: (_) => MeowsicHaptics.light(),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_t(pos), style: const TextStyle(color: Colors.white54, fontSize: 12)),
                        Text(_t(dur), style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Primary transport — roomy and never crowded
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        iconSize: 28,
                        color: hub.shuffle ? cs.primary : null,
                        tooltip: '随机',
                        icon: const Icon(Icons.shuffle),
                        onPressed: () {
                          MeowsicHaptics.selection();
                          hub.toggleShuffle();
                        },
                      ),
                      IconButton(
                        iconSize: 42,
                        tooltip: '上一首',
                        icon: const Icon(Icons.skip_previous),
                        onPressed: () {
                          MeowsicHaptics.light();
                          hub.prev();
                        },
                      ),
                      IconButton(
                        iconSize: 68,
                        color: cs.primary,
                        tooltip: hub.player.playing ? '暂停' : '播放',
                        icon: Icon(
                          hub.player.playing ? Icons.pause_circle_filled : Icons.play_circle_filled,
                        ),
                        onPressed: () {
                          MeowsicHaptics.medium();
                          hub.togglePlay();
                        },
                      ),
                      IconButton(
                        iconSize: 42,
                        tooltip: '下一首',
                        icon: const Icon(Icons.skip_next),
                        onPressed: () {
                          MeowsicHaptics.light();
                          hub.next();
                        },
                      ),
                      IconButton(
                        iconSize: 28,
                        color: hub.loopMode == LoopMode.off ? null : cs.primary,
                        icon: Icon(_loopIcon(hub.loopMode)),
                        tooltip: hub.loopModeLabel,
                        onPressed: () {
                          MeowsicHaptics.selection();
                          _pickLoopMode(context, hub);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '队列 ${hub.queueIndex + 1}/${hub.queue.length}'
                    '${hub.shuffle ? ' · 随机' : ''}'
                    ' · ${hub.loopModeLabel}'
                    ' · ${hub.speed}x'
                    '${hub.isSleeping ? ' · 睡眠${hub.sleepMinutesLeft}分${hub.isFadingOut ? '(淡出)' : ''}' : ''}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                  const SizedBox(height: 14),
                  // Up next — reduces “will it skip?” anxiety after manual skip
                  if (hub.queue.length > 1 && hub.queueIndex + 1 < hub.queue.length)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        '下一首 · ${hub.queue[hub.queueIndex + 1].title}',
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: cs.primary.withValues(alpha: 0.85),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  if (song.isOnline && song.onlinePreviewOnly)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        '联网试听约 30 秒 · 关闭 App 后自动清除缓存',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.orangeAccent.withValues(alpha: 0.9), fontSize: 12),
                      ),
                    ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      ActionChip(
                        avatar: Icon(
                          hub.karaokeMode ? Icons.mic_external_on : Icons.mic_rounded,
                          size: 18,
                          color: hub.karaokeMode ? cs.primary : null,
                        ),
                        label: Text(
                          hub.karaokeMode
                              ? (hub.karaokeUsingStem
                                  ? 'K 歌·AI'
                                  : 'K 歌·${hub.karaokeReadyCount}/${hub.karaokePipe.length}')
                              : 'K 歌模式',
                        ),
                        onPressed: () {
                          MeowsicHaptics.selection();
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const KaraokeScreen()),
                          );
                        },
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.speed, size: 18),
                        label: Text('${hub.speed}x'),
                        onPressed: () => _pickSpeed(context, hub),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.bedtime, size: 18),
                        label: Text(
                          hub.isSleeping
                              ? (hub.isFadingOut ? '淡出中…' : '取消睡眠')
                              : '睡眠定时',
                        ),
                        onPressed: () {
                          if (hub.isSleeping) {
                            hub.cancelSleepTimer();
                          } else {
                            _pickSleep(context, hub);
                          }
                        },
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.queue_music, size: 18),
                        label: const Text('队列'),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const QueueScreen()),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _pickSleep(BuildContext context, HubState hub) async {
    final m = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('睡眠定时（到时暂停）')),
            for (final n in [15, 30, 45, 60, 90])
              ListTile(
                title: Text('$n 分钟'),
                onTap: () => Navigator.pop(ctx, n),
              ),
            ListTile(
              leading: const Icon(Icons.edit_calendar_outlined),
              title: const Text('自定义时长…'),
              onTap: () => Navigator.pop(ctx, -1),
            ),
          ],
        ),
      ),
    );
    if (m == null) return;
    if (m == -1) {
      if (!context.mounted) return;
      final custom = await _promptCustomSleepMinutes(context);
      if (custom != null) hub.setSleepTimer(custom);
      return;
    }
    hub.setSleepTimer(m);
  }

  Future<int?> _promptCustomSleepMinutes(BuildContext context) async {
    final controller = TextEditingController(text: '25');
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('自定义睡眠时长'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: '分钟',
            hintText: '1～480',
            suffixText: '分钟',
          ),
          onSubmitted: (v) {
            final n = int.tryParse(v.trim());
            if (n != null && n >= 1 && n <= 480) Navigator.pop(ctx, n);
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              final n = int.tryParse(controller.text.trim());
              if (n == null || n < 1 || n > 480) return;
              Navigator.pop(ctx, n);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _pickLoopMode(BuildContext context, HubState hub) async {
    final mode = await showModalBottomSheet<LoopMode>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('选择循环模式')),
            for (final item in HubState.loopModeChoices)
              ListTile(
                title: Text(item.$2),
                subtitle: Text(item.$3),
                trailing: hub.loopMode == item.$1 ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(ctx, item.$1),
              ),
          ],
        ),
      ),
    );
    if (mode != null) await hub.setLoopMode(mode);
  }

  Future<void> _pickSpeed(BuildContext context, HubState hub) async {
    final v = await showModalBottomSheet<double>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('选择播放速度')),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final s in HubState.speedOptions)
                    ListTile(
                      title: Text('${s}x'),
                      trailing: (hub.speed - s).abs() < 0.001 ? const Icon(Icons.check) : null,
                      onTap: () => Navigator.pop(ctx, s),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (v != null) await hub.setSpeed(v);
  }

  Widget _coverPh() => Container(
        color: const Color(0xFF2A3142),
        child: const Center(child: Icon(Icons.music_note, size: 80)),
      );
}
