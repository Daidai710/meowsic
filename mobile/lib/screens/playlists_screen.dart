import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/hub_state.dart';
import '../widgets/song_tile.dart';

class PlaylistsScreen extends StatefulWidget {
  const PlaylistsScreen({super.key});

  @override
  State<PlaylistsScreen> createState() => _PlaylistsScreenState();
}

class _PlaylistsScreenState extends State<PlaylistsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HubState>().refreshPlaylists();
    });
  }

  Future<void> _create() async {
    final nameCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新建歌单'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: '歌单名'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('创建')),
        ],
      ),
    );
    if (ok == true && nameCtrl.text.trim().isNotEmpty && mounted) {
      await context.read<HubState>().createPlaylist(nameCtrl.text.trim());
    }
  }

  Future<void> _openPlaylist(Playlist p) async {
    final hub = context.read<HubState>();
    final songs = await hub.loadPlaylistSongs(p.id);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlaylistDetailPage(playlist: p, songs: songs),
      ),
    );
    hub.refreshPlaylists();
  }

  @override
  Widget build(BuildContext context) {
    final hub = context.watch<HubState>();
    if (hub.offlineMode) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.55),
              ),
              const SizedBox(height: 12),
              const Text('离线模式无电脑歌单', textAlign: TextAlign.center),
              const SizedBox(height: 6),
              Text(
                '歌单存在电脑服务器上；请先连接后使用。\n本机歌曲在「曲库 → 本机」里听。',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white54),
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      children: [
        ListTile(
          title: const Text('我的歌单'),
          trailing: IconButton(
            icon: const Icon(Icons.add),
            onPressed: _create,
          ),
        ),
        Expanded(
          child: hub.playlists.isEmpty
              ? const Center(child: Text('还没有歌单'))
              : ListView.builder(
                  itemCount: hub.playlists.length,
                  itemBuilder: (context, i) {
                    final p = hub.playlists[i];
                    return ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.queue_music)),
                      title: Text(p.name),
                      subtitle: Text('${p.songCount} 首'),
                      onTap: () => _openPlaylist(p),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class PlaylistDetailPage extends StatelessWidget {
  const PlaylistDetailPage({super.key, required this.playlist, required this.songs});

  final Playlist playlist;
  final List<Song> songs;

  @override
  Widget build(BuildContext context) {
    final hub = context.watch<HubState>();
    return Scaffold(
      appBar: AppBar(
        title: Text(playlist.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.shuffle),
            onPressed: songs.isEmpty ? null : () => hub.playShuffleAll(songs),
          ),
        ],
      ),
      body: songs.isEmpty
          ? const Center(child: Text('空歌单'))
          : ListView.builder(
              itemCount: songs.length,
              itemBuilder: (context, i) {
                final s = songs[i];
                return SongTile(
                  song: s,
                  baseUrl: hub.baseUrl,
                  playing: hub.current?.id == s.id,
                  onTap: () => hub.playList(songs, i),
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
