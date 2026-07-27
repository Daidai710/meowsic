import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/hub_state.dart';
import '../widgets/song_tile.dart';

class RecentScreen extends StatefulWidget {
  const RecentScreen({super.key});

  @override
  State<RecentScreen> createState() => _RecentScreenState();
}

class _RecentScreenState extends State<RecentScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HubState>().refreshRecent();
    });
  }

  @override
  Widget build(BuildContext context) {
    final hub = context.watch<HubState>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('最近播放'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => hub.refreshRecent(),
          ),
        ],
      ),
      body: hub.recent.isEmpty
          ? const Center(child: Text('暂无播放记录\n听几首歌后再来看', textAlign: TextAlign.center))
          : ListView.builder(
              itemCount: hub.recent.length,
              itemBuilder: (context, i) {
                final s = hub.recent[i];
                return SongTile(
                  song: s,
                  baseUrl: hub.baseUrl,
                  playing: hub.current?.id == s.id,
                  // 最近列表是临时视图：点歌插播，不替换整队为「最近」
                  onTap: () => hub.playNow(s),
                  onPlayNext: () {
                    hub.playNext(s);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('已设为下一首播放'), duration: Duration(seconds: 1)),
                    );
                  },
                  onAddToQueue: () {
                    hub.addToQueueEnd(s);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('已加到队列末尾'), duration: Duration(seconds: 1)),
                    );
                  },
                );
              },
            ),
    );
  }
}
