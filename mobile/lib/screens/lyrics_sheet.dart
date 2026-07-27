import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/hub_state.dart';

Future<void> showLyricsSheet(BuildContext context) async {
  final hub = context.read<HubState>();
  final song = hub.current;
  if (song == null) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('未播放')));
    return;
  }
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _LyricsBody(songId: song.id, title: song.title),
  );
}

class _LyricsBody extends StatefulWidget {
  const _LyricsBody({required this.songId, required this.title});
  final int songId;
  final String title;

  @override
  State<_LyricsBody> createState() => _LyricsBodyState();
}

class _LyricsBodyState extends State<_LyricsBody> {
  LyricsData? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final hub = context.read<HubState>();
    final d = await hub.loadLyrics(widget.songId);
    if (mounted) setState(() {
      _data = d;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hub = context.watch<HubState>();
    final pos = hub.player.position.inMilliseconds / 1000.0;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (ctx, scroll) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.title, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
              if (_data?.source != null)
                Text('来源: ${_data!.source}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 12),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : (_data == null || _data!.isEmpty)
                        ? const Center(child: Text('暂无歌词\n可在歌曲同目录放 .lrc 文件', textAlign: TextAlign.center))
                        : ListView.builder(
                            controller: scroll,
                            itemCount: _data!.lines.length,
                            itemBuilder: (c, i) {
                              final line = _data!.lines[i];
                              final nextT = i + 1 < _data!.lines.length ? _data!.lines[i + 1].t : null;
                              final active = line.t != null &&
                                  pos >= line.t! &&
                                  (nextT == null || pos < nextT);
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                child: Text(
                                  line.line,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: active ? 18 : 15,
                                    fontWeight: active ? FontWeight.bold : FontWeight.normal,
                                    color: active ? Theme.of(context).colorScheme.primary : Colors.white70,
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
}
