import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/hub_state.dart';
import '../widgets/song_tile.dart';

class QueueScreen extends StatefulWidget {
  const QueueScreen({super.key});

  @override
  State<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends State<QueueScreen> {
  final _scroll = ScrollController();
  static const _tileExtent = 72.0;
  int? _lastLocatedIndex;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToCurrent(int index, int total) {
    if (index < 0 || total <= 0 || !_scroll.hasClients) return;
    if (_lastLocatedIndex == index) return;
    _lastLocatedIndex = index;
    final max = _scroll.position.maxScrollExtent;
    final target = (index * _tileExtent - 80).clamp(0.0, max);
    _scroll.animateTo(
      target,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final hub = context.watch<HubState>();
    // After shuffle → order restore, keep current track in view.
    if (hub.queue.isNotEmpty && hub.queueIndex >= 0) {
      final idx = hub.queueIndex;
      final n = hub.queue.length;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _scrollToCurrent(idx, n);
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          hub.queue.isEmpty
              ? '播放队列'
              : '播放队列 (${hub.queueIndex + 1}/${hub.queue.length})',
        ),
        actions: [
          if (hub.queue.length > 1)
            IconButton(
              tooltip: '打乱队列顺序',
              onPressed: () {
                hub.shuffleQueueOrder(keepCurrentFirst: true);
                _lastLocatedIndex = null;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已打乱队列（当前曲置顶）'), duration: Duration(seconds: 1)),
                );
              },
              icon: const Icon(Icons.swap_vert),
            ),
          if (hub.queue.isNotEmpty)
            TextButton(
              onPressed: hub.clearQueueKeepCurrent,
              child: const Text('只留当前'),
            ),
        ],
      ),
      body: hub.queue.isEmpty
          ? const Center(child: Text('队列为空\n点一首歌开始播放', textAlign: TextAlign.center))
          : ListView.builder(
              controller: _scroll,
              itemCount: hub.queue.length,
              itemExtent: _tileExtent,
              itemBuilder: (context, i) {
                final s = hub.queue[i];
                final isCur = i == hub.queueIndex;
                return Dismissible(
                  key: ValueKey('q-${s.id}-$i'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red.shade800,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 16),
                    child: const Icon(Icons.delete),
                  ),
                  onDismissed: (_) => hub.removeFromQueue(i),
                  child: SongTile(
                    song: s,
                    baseUrl: hub.baseUrl,
                    playing: isCur,
                    onTap: () => hub.playQueueIndex(i),
                  ),
                );
              },
            ),
    );
  }
}
