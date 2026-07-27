import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/hub_state.dart';
import '../util/haptics.dart';
import '../widgets/cat_decor.dart';
import '../widgets/song_tile.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final _search = TextEditingController();
  final _listController = ScrollController();
  Timer? _searchDebounce;

  /// Fixed remote slots: 曲库 A/B/C
  static const int _slotCount = 3;

  /// Debounce for remote / 总曲库 server search.
  static const _remoteSearchDelay = Duration(milliseconds: 380);

  bool _sidebarExpanded = false;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _search.dispose();
    _listController.dispose();
    super.dispose();
  }

  Future<void> _scanLocal(HubState hub) async {
    MeowsicHaptics.medium();
    final err = await hub.scanLocalLibrary();
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('本机扫描完成，共 ${hub.localSongs.length} 首')),
      );
    }
  }

  Future<void> _onSongTap(HubState hub, Song s) async {
    MeowsicHaptics.light();
    final msg = await hub.playLibrarySong(s);
    if (!mounted || msg == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _clearSearch(HubState hub) async {
    _searchDebounce?.cancel();
    _search.clear();
    await hub.searchSongs('');
    if (!mounted) return;
    setState(() {});
  }

  /// UX5: 本机即时筛选；电脑曲库防抖后再搜。
  void _onSearchTextChanged(HubState hub, String raw) {
    setState(() {});
    final q = raw.trim();
    _searchDebounce?.cancel();
    if (hub.canInstantLocalSearch) {
      hub.searchSongs(q);
      return;
    }
    // Remote: debounce API; empty clears immediately.
    if (q.isEmpty) {
      hub.searchSongs('');
      return;
    }
    _searchDebounce = Timer(_remoteSearchDelay, () {
      if (!mounted) return;
      hub.searchSongs(q);
    });
  }

  Future<void> _quickPickLibrary(HubState hub) async {
    if (hub.offlineMode) {
      hub.selectLibrary(HubState.kLocalLibraryIndex);
      return;
    }
    final choice = await showModalBottomSheet<int?>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('快速切换曲库')),
            ListTile(
              leading: const Icon(Icons.library_music),
              title: Text(hub.libraryLabel(null)),
              subtitle: const Text('全部'),
              selected: hub.selectedLibraryIndex == null,
              onTap: () => Navigator.pop(ctx, -99), // sentinel for 总曲库
            ),
            ListTile(
              leading: const Icon(Icons.phone_android),
              title: Text(hub.libraryLabel(HubState.kLocalLibraryIndex)),
              subtitle: Text(hub.localSongs.isEmpty ? '点扫描' : '${hub.localSongs.length} 首'),
              selected: hub.selectedLibraryIndex == HubState.kLocalLibraryIndex,
              onTap: () => Navigator.pop(ctx, HubState.kLocalLibraryIndex),
            ),
            ListTile(
              leading: const Icon(Icons.unfold_more_rounded),
              title: const Text('展开全部曲库…'),
              onTap: () => Navigator.pop(ctx, -100),
            ),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == -100) {
      setState(() => _sidebarExpanded = true);
      return;
    }
    MeowsicHaptics.selection();
    if (choice == -99) {
      await hub.selectLibrary(null);
    } else {
      await hub.selectLibrary(choice);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hub = context.watch<HubState>();
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final isLocal = hub.selectedLibraryIndex == HubState.kLocalLibraryIndex;
    final filtering = hub.search.trim().isNotEmpty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _LibrarySidebar(
          expanded: _sidebarExpanded,
          onExpandedChanged: (v) => setState(() => _sidebarExpanded = v),
          selectedIndex: hub.selectedLibraryIndex,
          slotCount: hub.offlineMode ? 0 : _slotCount,
          libraryPaths: hub.libraryPaths,
          localCount: hub.localSongs.length,
          offlineMode: hub.offlineMode,
          labelFor: hub.libraryLabel,
          pathHint: hub.libraryPathHint,
          onSelect: (index) {
            MeowsicHaptics.selection();
            hub.selectLibrary(index);
            setState(() => _sidebarExpanded = false);
          },
          onLongPressCollapsed: () => _quickPickLibrary(hub),
        ),
        Expanded(
          child: Stack(
            children: [
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _search,
                            decoration: InputDecoration(
                              hintText: '搜索歌名 / 艺人 / 专辑',
                              prefixIcon: Icon(
                                Icons.search_rounded,
                                color: primary.withValues(alpha: 0.85),
                              ),
                              suffixIcon: _search.text.isEmpty
                                  ? null
                                  : IconButton(
                                      icon: const Icon(Icons.clear_rounded),
                                      onPressed: () => _clearSearch(hub),
                                    ),
                              isDense: true,
                            ),
                            onChanged: (v) => _onSearchTextChanged(hub, v),
                            onSubmitted: (v) {
                              _searchDebounce?.cancel();
                              hub.searchSongs(v.trim());
                            },
                          ),
                        ),
                        const SizedBox(width: 6),
                        IconButton.filledTonal(
                          tooltip: '联网搜索相关歌曲（会话缓存，关 App 清除）',
                          onPressed: hub.onlineSearching || _search.text.trim().isEmpty
                              ? null
                              : () async {
                                  MeowsicHaptics.medium();
                                  _searchDebounce?.cancel();
                                  await hub.searchSongs(_search.text.trim());
                                  await hub.searchOnline(_search.text.trim());
                                  if (!mounted) return;
                                  if (hub.onlineResults.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(hub.onlineSearchError ?? '联网未找到相关歌曲'),
                                      ),
                                    );
                                  }
                                },
                          icon: hub.onlineSearching
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.travel_explore),
                        ),
                      ],
                    ),
                  ),
                  // UX2: search filter ≠ queue
                  if (filtering)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                      child: Material(
                        color: primary.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Row(
                            children: [
                              Icon(Icons.filter_alt_outlined, size: 18, color: primary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '筛选中 · 显示 ${hub.songs.length} 首 · 点歌仍按完整曲库续播',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: primary.withValues(alpha: 0.95),
                                    height: 1.25,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () => _clearSearch(hub),
                                child: const Text('清除'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            hub.loading || hub.scanningLocal
                                ? (hub.scanningLocal ? '扫描本机…' : '加载中…')
                                : filtering
                                    ? '${hub.libraryLabel(hub.selectedLibraryIndex)} · 筛选 ${hub.songs.length} 首'
                                        '${hub.librarySongs.isNotEmpty ? ' / 曲库 ${hub.librarySongs.length}' : ''}'
                                        '${hub.shuffle ? ' · 随机' : ' · 顺序'}'
                                    : '${hub.libraryLabel(hub.selectedLibraryIndex)} · ${hub.songs.length} 首'
                                        '${hub.shuffle ? ' · 随机' : ' · 顺序'}',
                            style: theme.textTheme.bodySmall?.copyWith(color: Colors.white60),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          tooltip: '扫描本机音频',
                          onPressed: hub.scanningLocal ? null : () => _scanLocal(hub),
                          icon: hub.scanningLocal
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.phone_android),
                        ),
                        IconButton(
                          tooltip: hub.libraryOrderShuffled ? '恢复列表顺序' : '打乱列表顺序',
                          onPressed: hub.songs.length < 2
                              ? null
                              : () async {
                                  MeowsicHaptics.medium();
                                  if (hub.libraryOrderShuffled) {
                                    await hub.restoreLibraryOrder();
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('已恢复曲库列表顺序'),
                                        duration: Duration(seconds: 1),
                                      ),
                                    );
                                  } else {
                                    hub.shuffleLibraryOrder();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('已打乱曲库列表顺序'),
                                        duration: Duration(seconds: 1),
                                      ),
                                    );
                                  }
                                },
                          icon: Icon(
                            hub.libraryOrderShuffled
                                ? Icons.sort_by_alpha
                                : Icons.swap_vert,
                          ),
                        ),
                        IconButton(
                          tooltip: '随机播放',
                          onPressed: hub.songs.isEmpty
                              ? null
                              : () {
                                  MeowsicHaptics.medium();
                                  hub.playShuffleAll();
                                },
                          icon: const Icon(Icons.shuffle),
                        ),
                        IconButton(
                          tooltip: isLocal ? '刷新本机列表' : '刷新',
                          onPressed: hub.loading || hub.scanningLocal
                              ? null
                              : () {
                                  MeowsicHaptics.light();
                                  if (isLocal) {
                                    _scanLocal(hub);
                                  } else {
                                    hub.refreshLibrary();
                                  }
                                },
                          icon: const Icon(Icons.refresh),
                        ),
                      ],
                    ),
                  ),
                  if (hub.error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        hub.error!,
                        style: const TextStyle(color: Colors.orangeAccent, fontSize: 12),
                      ),
                    ),
                  Expanded(
                    child: (hub.loading || hub.scanningLocal) && hub.songs.isEmpty && hub.onlineResults.isEmpty
                        ? const Center(child: CircularProgressIndicator())
                        : hub.songs.isEmpty && hub.onlineResults.isEmpty && !hub.onlineSearching
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isLocal ? Icons.phone_android : Icons.pets,
                                      size: 48,
                                      color: primary.withValues(alpha: 0.55),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      _emptyTitle(hub),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _emptyHint(hub),
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.white54),
                                    ),
                                    if (isLocal || hub.localSongs.isEmpty) ...[
                                      const SizedBox(height: 16),
                                      FilledButton.tonalIcon(
                                        onPressed: hub.scanningLocal ? null : () => _scanLocal(hub),
                                        icon: const Icon(Icons.radar),
                                        label: const Text('扫描本机音频'),
                                      ),
                                    ],
                                    if (_search.text.trim().isNotEmpty) ...[
                                      const SizedBox(height: 12),
                                      FilledButton.icon(
                                        onPressed: hub.onlineSearching
                                            ? null
                                            : () => hub.searchOnline(_search.text.trim()),
                                        icon: const Icon(Icons.travel_explore),
                                        label: const Text('联网搜索相关歌曲'),
                                      ),
                                    ],
                                    if (hub.onlineSearchError != null) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        hub.onlineSearchError!,
                                        style: const TextStyle(color: Colors.orangeAccent, fontSize: 12),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                    const SizedBox(height: 12),
                                    const CatPawTrail(opacity: 0.2),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                controller: _listController,
                                itemCount: hub.songs.length +
                                    (hub.onlineResults.isNotEmpty || hub.onlineSearching
                                        ? 1 + hub.onlineResults.length
                                        : 0),
                                itemBuilder: (context, i) {
                                  // Local / hub results first
                                  if (i < hub.songs.length) {
                                    final s = hub.songs[i];
                                    return SongTile(
                                      song: s,
                                      baseUrl: hub.baseUrl,
                                      playing: hub.current?.id == s.id,
                                      onTap: () => _onSongTap(hub, s),
                                      onPlayNext: () {
                                        hub.playNext(s);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('已设为下一首播放'),
                                            duration: Duration(seconds: 1),
                                          ),
                                        );
                                      },
                                      onAddToQueue: () {
                                        hub.addToQueueEnd(s);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('已加到队列末尾'),
                                            duration: Duration(seconds: 1),
                                          ),
                                        );
                                      },
                                      onAddPlaylist: s.isLocal || s.isOnline
                                          ? null
                                          : () => _pickPlaylist(context, s),
                                    );
                                  }
                                  // Header + online results
                                  final oi = i - hub.songs.length;
                                  if (oi == 0) {
                                    return ListTile(
                                      dense: true,
                                      leading: Icon(Icons.travel_explore, color: primary, size: 22),
                                      title: Text(
                                        hub.onlineSearching
                                            ? '联网搜索中…'
                                            : '联网相关 · ${hub.onlineResults.length} 首（试听）',
                                        style: theme.textTheme.titleSmall?.copyWith(color: primary),
                                      ),
                                      subtitle: Text(
                                        hub.onlineSearchQuery.isEmpty
                                            ? '关闭 App 后自动清除缓存'
                                            : '「${hub.onlineSearchQuery}」· 关闭 App 后清除',
                                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.white54),
                                      ),
                                      trailing: hub.onlineResults.isEmpty
                                          ? null
                                          : IconButton(
                                              tooltip: '清除联网结果',
                                              icon: const Icon(Icons.close, size: 18),
                                              onPressed: () => hub.clearOnlineResults(keepCache: true),
                                            ),
                                    );
                                  }
                                  final s = hub.onlineResults[oi - 1];
                                  return SongTile(
                                    song: s,
                                    baseUrl: hub.baseUrl,
                                    playing: hub.current?.id == s.id,
                                    onTap: () async {
                                      MeowsicHaptics.light();
                                      await hub.playNow(s);
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('已插播联网试听'),
                                          duration: Duration(seconds: 1),
                                        ),
                                      );
                                    },
                                    onPlayNext: () {
                                      hub.playNext(s);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('已设为下一首播放'),
                                          duration: Duration(seconds: 1),
                                        ),
                                      );
                                    },
                                    onAddToQueue: () {
                                      hub.addToQueueEnd(s);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('已加到队列末尾'),
                                          duration: Duration(seconds: 1),
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                  ),
                ],
              ),
              // UX3: tap list area to collapse expanded sidebar
              if (_sidebarExpanded)
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _sidebarExpanded = false),
                    child: ColoredBox(
                      color: Colors.black.withValues(alpha: 0.28),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  String _emptyTitle(HubState hub) {
    final idx = hub.selectedLibraryIndex;
    if (idx == HubState.kLocalLibraryIndex) {
      return '本机还没有歌曲';
    }
    if (idx != null && idx >= 0 && idx >= hub.libraryPaths.length) {
      return '${hub.libraryLabel(idx)} 尚未配置';
    }
    return '还没有歌哦 喵～';
  }

  String _emptyHint(HubState hub) {
    final idx = hub.selectedLibraryIndex;
    if (idx == HubState.kLocalLibraryIndex) {
      return '点上方「扫描本机」授权后扫描手机里的音频';
    }
    if (idx != null && idx >= 0 && idx >= hub.libraryPaths.length) {
      return '请在电脑 Web「设置 → 音乐目录」添加第 ${idx + 1} 个文件夹';
    }
    if (idx != null && idx >= 0) {
      return '该目录下暂无歌曲，可在电脑端扫描曲库';
    }
    return '可连接电脑曲库，或扫描本机音频';
  }

  Future<void> _pickPlaylist(BuildContext context, Song song) async {
    final hub = context.read<HubState>();
    await hub.refreshPlaylists();
    if (!context.mounted) return;
    if (hub.playlists.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先创建歌单')),
      );
      return;
    }
    final id = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) => ListView(
        shrinkWrap: true,
        children: [
          const ListTile(title: Text('加入歌单')),
          ...hub.playlists.map(
            (p) => ListTile(
              title: Text(p.name),
              subtitle: Text('${p.songCount} 首'),
              onTap: () => Navigator.pop(ctx, p.id),
            ),
          ),
        ],
      ),
    );
    if (id != null) {
      await hub.addSongToPlaylist(id, song.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已加入歌单')),
        );
      }
    }
  }
}

/// Vertical rail: collapsed shows only current library; expand for A/B/C/本机.
class _LibrarySidebar extends StatelessWidget {
  const _LibrarySidebar({
    required this.expanded,
    required this.onExpandedChanged,
    required this.selectedIndex,
    required this.slotCount,
    required this.libraryPaths,
    required this.localCount,
    required this.offlineMode,
    required this.labelFor,
    required this.pathHint,
    required this.onSelect,
    required this.onLongPressCollapsed,
  });

  final bool expanded;
  final ValueChanged<bool> onExpandedChanged;
  final int? selectedIndex;
  final int slotCount;
  final List<String> libraryPaths;
  final int localCount;
  final bool offlineMode;
  final String Function(int? index) labelFor;
  final String Function(int index) pathHint;
  final ValueChanged<int?> onSelect;
  final VoidCallback onLongPressCollapsed;

  int? get _effectiveIndex {
    if (offlineMode) {
      return selectedIndex == HubState.kLocalLibraryIndex || selectedIndex == null
          ? HubState.kLocalLibraryIndex
          : selectedIndex;
    }
    return selectedIndex;
  }

  String _currentHint(int? index) {
    if (index == null) return '全部';
    if (index == HubState.kLocalLibraryIndex) {
      return localCount > 0 ? '$localCount 首' : '点扫描';
    }
    if (index >= 0 && index < libraryPaths.length) {
      return pathHint(index);
    }
    return '未配置';
  }

  IconData _currentIcon(int? index) {
    if (index == null) return Icons.library_music;
    if (index == HubState.kLocalLibraryIndex) return Icons.phone_android;
    if (index >= 0 && index < libraryPaths.length) return Icons.folder;
    return Icons.folder_off_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final idx = _effectiveIndex;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      width: 72,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        border: Border(
          right: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: SafeArea(
        right: false,
        child: expanded ? _buildExpanded(primary) : _buildCollapsed(primary, idx),
      ),
    );
  }

  Widget _buildCollapsed(Color primary, int? idx) {
    final label = offlineMode && (idx == null || idx == HubState.kLocalLibraryIndex)
        ? '本机'
        : labelFor(idx);
    // Entire strip is tappable to expand; long-press for quick switch.
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onExpandedChanged(true),
        onLongPress: onLongPressCollapsed,
        child: Column(
          children: [
            const SizedBox(height: 8),
            _SideBtn(
              label: label,
              hint: _currentHint(idx),
              icon: _currentIcon(idx),
              selected: true,
              primary: primary,
              onTap: () => onExpandedChanged(true),
              onLongPress: onLongPressCollapsed,
            ),
            const Spacer(),
            Icon(
              Icons.unfold_more_rounded,
              size: 18,
              color: primary.withValues(alpha: 0.75),
            ),
            const SizedBox(height: 2),
            Text(
              '切换',
              style: TextStyle(
                fontSize: 9,
                color: primary.withValues(alpha: 0.65),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '长按快捷',
              style: TextStyle(
                fontSize: 8,
                color: primary.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildExpanded(Color primary) {
    return Column(
      children: [
        const SizedBox(height: 4),
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => onExpandedChanged(false),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.unfold_less_rounded, size: 20, color: primary),
                  const SizedBox(height: 2),
                  Text(
                    '收起',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: primary.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 14),
          child: Divider(height: 1, color: Colors.white.withValues(alpha: 0.12)),
        ),
        if (offlineMode) ...[
          _SideBtn(
            label: '本机',
            hint: localCount > 0 ? '$localCount 首' : '点扫描',
            icon: Icons.phone_android,
            selected: true,
            primary: primary,
            onTap: () => onSelect(HubState.kLocalLibraryIndex),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
              child: Text(
                '离线',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  color: primary.withValues(alpha: 0.7),
                ),
              ),
            ),
          ),
        ] else ...[
          _SideBtn(
            label: labelFor(null),
            hint: '全部',
            icon: Icons.library_music,
            selected: selectedIndex == null,
            primary: primary,
            onTap: () => onSelect(null),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 14),
            child: Divider(height: 1, color: Colors.white.withValues(alpha: 0.12)),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 8),
              children: [
                for (var i = 0; i < slotCount; i++)
                  _SideBtn(
                    label: labelFor(i),
                    hint: i < libraryPaths.length ? pathHint(i) : '未配置',
                    icon: i < libraryPaths.length ? Icons.folder : Icons.folder_off_outlined,
                    selected: selectedIndex == i,
                    primary: primary,
                    dimmed: i >= libraryPaths.length,
                    onTap: () => onSelect(i),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 14),
                  child: Divider(height: 1, color: Colors.white.withValues(alpha: 0.12)),
                ),
                _SideBtn(
                  label: labelFor(HubState.kLocalLibraryIndex),
                  hint: localCount > 0 ? '$localCount 首' : '点扫描',
                  icon: Icons.phone_android,
                  selected: selectedIndex == HubState.kLocalLibraryIndex,
                  primary: primary,
                  dimmed: localCount == 0,
                  onTap: () => onSelect(HubState.kLocalLibraryIndex),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _SideBtn extends StatelessWidget {
  const _SideBtn({
    required this.label,
    required this.hint,
    required this.icon,
    required this.selected,
    required this.primary,
    required this.onTap,
    this.onLongPress,
    this.dimmed = false,
  });

  final String label;
  final String hint;
  final IconData icon;
  final bool selected;
  final Color primary;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final fg = selected
        ? primary
        : (dimmed ? Colors.white38 : Colors.white70);
    final bg = selected ? primary.withValues(alpha: 0.18) : Colors.transparent;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          onLongPress: onLongPress,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: selected
                  ? Border.all(color: primary.withValues(alpha: 0.55), width: 1.2)
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 22, color: fg),
                const SizedBox(height: 6),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: fg,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hint,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9,
                    color: fg.withValues(alpha: 0.75),
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
