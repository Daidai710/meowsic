import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/hub_state.dart';

class BrokenScreen extends StatefulWidget {
  const BrokenScreen({super.key});

  @override
  State<BrokenScreen> createState() => _BrokenScreenState();
}

class _BrokenScreenState extends State<BrokenScreen> {
  List<Song> _list = [];
  bool _loading = true;
  final _busy = <int>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _list = await context.read<HubState>().loadBroken();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _fix(Song s) async {
    setState(() => _busy.add(s.id));
    try {
      final msg = await context.read<HubState>().fixBrokenSong(s.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        await _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('失败: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy.remove(s.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('异常歌曲修复'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _list.isEmpty
              ? const Center(child: Text('没有 tag_ok=0 的异常歌曲'))
              : ListView.builder(
                  itemCount: _list.length,
                  itemBuilder: (ctx, i) {
                    final s = _list[i];
                    final busy = _busy.contains(s.id);
                    return ListTile(
                      title: Text(s.title),
                      subtitle: Text('${s.artist} · ${s.format}'),
                      trailing: busy
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                          : FilledButton(
                              onPressed: () => _fix(s),
                              child: const Text('转码修复'),
                            ),
                    );
                  },
                ),
    );
  }
}
