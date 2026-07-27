import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/hub_state.dart';
import '../widgets/song_tile.dart';

/// A3: artists / albums browse
class BrowseScreen extends StatefulWidget {
  const BrowseScreen({super.key});

  @override
  State<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends State<BrowseScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<Map<String, dynamic>> _artists = [];
  List<Map<String, dynamic>> _albums = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final api = context.read<HubState>().api;
    setState(() => _loading = true);
    try {
      _artists = await api.artists();
      _albums = await api.albums();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('浏览'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [Tab(text: '艺人'), Tab(text: '专辑')],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabs,
              children: [
                ListView.builder(
                  itemCount: _artists.length,
                  itemBuilder: (ctx, i) {
                    final a = _artists[i];
                    final name = (a['artist'] ?? 'Unknown') as String;
                    final count = a['count'] ?? 0;
                    return ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person)),
                      title: Text(name),
                      subtitle: Text('$count 首'),
                      onTap: () => _openSongs(artist: name, title: name),
                    );
                  },
                ),
                ListView.builder(
                  itemCount: _albums.length,
                  itemBuilder: (ctx, i) {
                    final a = _albums[i];
                    final album = (a['album'] ?? 'Unknown') as String;
                    final artist = (a['artist'] ?? '') as String;
                    final count = a['count'] ?? 0;
                    return ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.album)),
                      title: Text(album),
                      subtitle: Text('$artist · $count 首'),
                      onTap: () => _openSongs(album: album, artist: artist, title: album),
                    );
                  },
                ),
              ],
            ),
    );
  }

  Future<void> _openSongs({String? artist, String? album, required String title}) async {
    final hub = context.read<HubState>();
    final songs = await hub.api.allSongs(artist: artist, album: album);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _SongListPage(title: title, songs: songs),
      ),
    );
  }
}

class _SongListPage extends StatelessWidget {
  const _SongListPage({required this.title, required this.songs});
  final String title;
  final List songs; // List<Song>

  @override
  Widget build(BuildContext context) {
    final hub = context.watch<HubState>();
    final list = List<Song>.from(songs);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView.builder(
        itemCount: list.length,
        itemBuilder: (ctx, i) {
          final s = list[i];
          return SongTile(
            song: s,
            baseUrl: hub.baseUrl,
            playing: hub.current?.id == s.id,
            onTap: () => hub.playList(list, i),
            onPlayNext: () => hub.playNext(s),
            onAddToQueue: () => hub.addToQueueEnd(s),
          );
        },
      ),
    );
  }
}
