import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../audio/equalizer_service.dart';
import '../audio/scene_presets.dart';
import '../state/hub_state.dart';
import '../state/ui_theme.dart';
import '../util/haptics.dart';
import '../widgets/cat_decor.dart';
import '../widgets/mini_player.dart';
import 'broken_screen.dart';
import 'browse_screen.dart';
import 'color_picker_screen.dart';
import 'connect_screen.dart';
import 'custom_eq_screen.dart';
import 'karaoke_screen.dart';
import 'library_screen.dart';
import 'party_screen.dart';
import 'playlists_screen.dart';
import 'queue_screen.dart';
import 'recent_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;
  /// AppBar 功能条展开：浏览 / 最近 / 队列 / 扫描…
  bool _toolsOpen = false;

  void _closeTools() {
    if (_toolsOpen) setState(() => _toolsOpen = false);
  }

  Future<void> _openTool(Future<void> Function() action) async {
    MeowsicHaptics.selection();
    _closeTools();
    await action();
  }

  @override
  Widget build(BuildContext context) {
    final hub = context.watch<HubState>();
    if (!hub.sessionActive) {
      return ConnectScreen(onConnected: () => setState(() => _tab = 0));
    }

    final pages = [
      const LibraryScreen(),
      const PlaylistsScreen(),
      _SettingsTab(
        onDisconnect: () {
          if (hub.offlineMode) {
            hub.leaveOfflineToConnect();
          } else {
            hub.disconnect();
          }
        },
      ),
    ];

    final titles = ['曲库', '歌单', '设置'];
    final theme = Theme.of(context);
    final offline = hub.offlineMode;

    final toolItems = <_AppToolItem>[
      if (!offline)
        _AppToolItem(
          icon: Icons.album_outlined,
          label: '浏览',
          subtitle: '艺人 / 专辑',
          onTap: () => _openTool(() async {
            await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BrowseScreen()));
          }),
        ),
      if (!offline)
        _AppToolItem(
          icon: Icons.history,
          label: '最近播放',
          subtitle: '听过的歌',
          onTap: () => _openTool(() async {
            await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RecentScreen()));
          }),
        ),
      _AppToolItem(
        icon: Icons.queue_music,
        label: '播放队列',
        subtitle: '当前列表',
        onTap: () => _openTool(() async {
          await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const QueueScreen()));
        }),
      ),
      if (!offline)
        _AppToolItem(
          icon: Icons.groups_2_outlined,
          label: '一起听',
          subtitle: hub.inParty ? '房间 ${hub.party?.code ?? ''}' : '同步 / 各自听',
          onTap: () => _openTool(() async {
            await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PartyScreen()));
          }),
        ),
      if (!offline)
        _AppToolItem(
          icon: Icons.mic_external_on_rounded,
          label: 'K 歌',
          subtitle: hub.karaokeMode
              ? '${hub.karaokeReadyCount}/${hub.karaokePipe.length} 就绪'
              : '流水线分轨 · EQ 兜底',
          onTap: () => _openTool(() async {
            await Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const KaraokeScreen()),
            );
          }),
        ),
      if (_tab == 0 && !offline)
        _AppToolItem(
          icon: Icons.radar,
          label: '扫描曲库',
          subtitle: hub.loading ? '扫描中…' : '电脑重扫目录',
          enabled: !hub.loading,
          onTap: () => _openTool(() async {
            await hub.scanLibrary();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('扫描完成，共 ${hub.songs.length} 首')),
              );
            }
          }),
        ),
      if (_tab == 0 && offline)
        _AppToolItem(
          icon: Icons.phone_android,
          label: '扫描本机',
          subtitle: hub.scanningLocal ? '扫描中…' : '导入手机音频',
          enabled: !hub.scanningLocal,
          onTap: () => _openTool(() async {
            final err = await hub.scanLocalLibrary();
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  err ?? '本机扫描完成，共 ${hub.localSongs.length} 首',
                ),
              ),
            );
          }),
        ),
    ];

    final primary = theme.colorScheme.primary;
    final isLight = theme.brightness == Brightness.light;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: MeowsicAppBarTitle(pageTitle: titles[_tab]),
        actions: [
          IconButton(
            tooltip: _toolsOpen ? '收起功能' : '更多功能',
            onPressed: () {
              MeowsicHaptics.selection();
              setState(() => _toolsOpen = !_toolsOpen);
            },
            icon: AnimatedRotation(
              turns: _toolsOpen ? 0.125 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(_toolsOpen ? Icons.close : Icons.apps_rounded),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(_toolsOpen ? 72 : 0),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _toolsOpen
                ? SizedBox(
                    height: 72,
                    width: double.infinity,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                      itemCount: toolItems.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        final item = toolItems[i];
                        return _ToolChip(
                          item: item,
                          accent: primary,
                        );
                      },
                    ),
                  )
                : const SizedBox(width: double.infinity, height: 0),
          ),
        ),
      ),
      body: Column(
        children: [
          if (offline)
            Material(
              color: primary.withValues(alpha: isLight ? 0.18 : 0.35),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.phone_android, size: 16, color: primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '离线模式 · 仅本机曲库，不连电脑',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        MeowsicHaptics.selection();
                        hub.leaveOfflineToConnect();
                      },
                      child: const Text('连电脑'),
                    ),
                  ],
                ),
              ),
            ),
          if (!offline && (hub.connectionHint != null || hub.reconnecting))
            Material(
              color: hub.reconnecting
                  ? Colors.orange.withValues(alpha: isLight ? 0.22 : 0.55)
                  : theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: isLight ? 0.9 : 0.85),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    if (hub.reconnecting)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    if (hub.reconnecting) const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        hub.connectionHint ?? '连接异常',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final ok = await hub.softPing(force: true);
                        if (!ok) await hub.connect(hub.baseUrl);
                      },
                      child: const Text('重连'),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: Stack(
              children: [
                pages[_tab],
                const CatPawWatermark(),
              ],
            ),
          ),
        ],
      ),
      // Floating mini-player sits above the nav bar (not buried in list body).
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MiniPlayer(),
          NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (i) {
              MeowsicHaptics.selection();
              setState(() {
                _tab = i;
                _toolsOpen = false;
              });
            },
            destinations: [
              NavigationDestination(
                icon: CatPawIcon(size: 22, color: primary, opacity: 0.55),
                selectedIcon: CatPawIcon(size: 24, color: primary, opacity: 1),
                label: '曲库',
              ),
              NavigationDestination(
                icon: Icon(Icons.queue_music_outlined, color: primary.withValues(alpha: 0.55)),
                selectedIcon: Icon(Icons.queue_music_rounded, color: primary),
                label: '歌单',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined, color: primary.withValues(alpha: 0.55)),
                selectedIcon: Icon(Icons.settings_rounded, color: primary),
                label: '设置',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AppToolItem {
  const _AppToolItem({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  final bool enabled;
}

class _ToolChip extends StatelessWidget {
  const _ToolChip({required this.item, required this.accent});

  final _AppToolItem item;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final on = item.enabled;
    final cs = Theme.of(context).colorScheme;
    final muted = cs.onSurface.withValues(alpha: on ? 0.58 : 0.32);
    return Material(
      color: on
          ? accent.withValues(alpha: 0.16)
          : cs.onSurface.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: on ? item.onTap : null,
        child: Container(
          constraints: const BoxConstraints(minWidth: 108),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(item.icon, size: 22, color: on ? accent : muted),
              const SizedBox(width: 8),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: on ? cs.onSurface : muted,
                    ),
                  ),
                  Text(
                    item.subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: muted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsTab extends StatelessWidget {
  const _SettingsTab({required this.onDisconnect});
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    final hub = context.watch<HubState>();
    final ui = context.watch<UiTheme>();
    final s = hub.status;
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
      children: [
        _sectionHeader(
          context,
          '连接',
          hub.offlineMode ? '当前离线，仅使用本机曲库' : '与电脑上的 Music Hub 服务通信',
        ),
        if (hub.offlineMode)
          _infoTile(
            icon: Icons.phone_android,
            iconColor: Colors.tealAccent,
            title: '离线模式',
            subtitle: '本机 ${hub.localSongs.length} 首\n不依赖电脑与 Wi‑Fi',
            hint: '可随时点下方「连接电脑」进入扫码/局域网连接。',
          )
        else ...[
          _infoTile(
            icon: Icons.dns,
            title: '服务器地址',
            subtitle: hub.baseUrl,
            hint: '曲库、封面、歌词都从这台机器读取；换 Wi‑Fi 后可能要重连。',
          ),
          if (s != null)
            _infoTile(
              icon: hub.reconnecting ? Icons.cloud_off : Icons.cloud_done,
              iconColor: hub.reconnecting ? Colors.orange : Colors.greenAccent,
              title: hub.reconnecting ? '连接不稳定' : '已连接',
              subtitle: '${s.songCount} 首 · FFmpeg ${s.ffmpeg ? '可用' : '无'}\n${s.libraryPath}',
              hint: 'FFmpeg 用于异常音频转码与部分修复。',
            ),
          if (hub.pendingResume?.song != null)
            ListTile(
              leading: const Icon(Icons.history_toggle_off),
              title: const Text('继续其他设备进度'),
              subtitle: Text('${hub.pendingResume!.song!.title}\n可从上次暂停位置接着听'),
              isThreeLine: true,
              trailing: TextButton(onPressed: hub.resumePending, child: const Text('继续')),
            ),
        ],

        if (!hub.offlineMode) _sectionHeader(context, '一起听', '同步进度或仅共用曲库'),
        if (!hub.offlineMode)
        ListTile(
          leading: Icon(
            Icons.groups_2_outlined,
            color: hub.inParty ? Theme.of(context).colorScheme.primary : null,
          ),
          title: const Text('一起听'),
          subtitle: Text(
            hub.inParty
                ? '同步房间 ${hub.party?.code ?? ''} · ${hub.partyIsHost ? '房主' : '已加入'}'
                : '同步听 / 各自听 · 设备管理 · 房间码与邀请链接',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PartyScreen()));
          },
        ),

        _sectionHeader(context, '播放', '循环、速度、睡眠'),
        ListTile(
          leading: const Icon(Icons.repeat),
          title: const Text('循环模式'),
          subtitle: Text('${hub.loopModeLabel}\n${hub.loopModeDescription}'),
          isThreeLine: true,
          trailing: const Icon(Icons.arrow_drop_down),
          onTap: () => _pickLoopMode(context, hub),
        ),
        ListTile(
          leading: const Icon(Icons.speed),
          title: const Text('播放速度'),
          subtitle: Text(
            '${hub.speed}x\n'
            '拖慢适合抒情 / 学习，加快适合播客赶进度。点击从列表选择。',
          ),
          isThreeLine: true,
          trailing: const Icon(Icons.arrow_drop_down),
          onTap: () => _pickSpeed(context, hub),
        ),
        ListTile(
          leading: const Icon(Icons.bedtime),
          title: const Text('睡眠定时'),
          subtitle: Text(
            hub.isSleeping
                ? '剩余约 ${hub.sleepMinutesLeft} 分钟${hub.isFadingOut ? ' · 正在淡出' : ' · 结束前30秒淡出'}'
                : '未开启 · 到时前 30 秒自动渐弱后暂停',
          ),
          trailing: hub.isSleeping
              ? TextButton(onPressed: hub.cancelSleepTimer, child: const Text('取消'))
              : const Icon(Icons.arrow_drop_down),
          onTap: () async {
            if (hub.isSleeping) {
              hub.cancelSleepTimer();
              return;
            }
            final m = await showModalBottomSheet<int>(
              context: context,
              showDragHandle: true,
              builder: (ctx) => SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: SleepingCatArt(size: 88),
                    ),
                    const ListTile(
                      title: Text('睡眠定时'),
                      subtitle: Text('到时前 30 秒渐弱后暂停，适合睡前听歌。喵～'),
                    ),
                    for (final n in [15, 30, 45, 60, 90])
                      ListTile(
                        leading: CatPawIcon(
                          size: 18,
                          color: Theme.of(ctx).colorScheme.primary.withValues(alpha: 0.75),
                        ),
                        title: Text('$n 分钟'),
                        onTap: () {
                          MeowsicHaptics.selection();
                          Navigator.pop(ctx, n);
                        },
                      ),
                    ListTile(
                      leading: CatPawIcon(
                        size: 18,
                        color: Theme.of(ctx).colorScheme.primary.withValues(alpha: 0.75),
                      ),
                      title: const Text('自定义时长…'),
                      subtitle: const Text('1～480 分钟'),
                      onTap: () {
                        MeowsicHaptics.selection();
                        Navigator.pop(ctx, -1);
                      },
                    ),
                    const SizedBox(height: 8),
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
          },
        ),

        _sectionHeader(context, '听感', '场景优先；EQ 仅 Android'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Text(
            '当前：${hub.currentScene.label} — ${hub.currentScene.description}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ),
        SizedBox(
          height: 118,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            itemCount: scenePresets.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final scene = scenePresets[i];
              final selected = hub.currentSceneId == scene.id;
              return SizedBox(
                width: 148,
                child: Material(
                  color: selected
                      ? theme.colorScheme.primaryContainer.withValues(alpha: 0.85)
                      : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () async {
                      MeowsicHaptics.selection();
                      await hub.applyScene(scene);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('已应用场景：${scene.label}'),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      }
                    },
                    child: Stack(
                      children: [
                        if (selected)
                          Positioned(
                            right: 6,
                            top: 6,
                            child: CatPawIcon(size: 16, color: theme.colorScheme.primary, opacity: 0.95),
                          ),
                        Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  scene.label,
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (selected)
                                Icon(Icons.check_circle, size: 16, color: theme.colorScheme.primary),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Expanded(
                            child: Text(
                              scene.description,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.58),
                                height: 1.25,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        _sectionHeader(context, '均衡器', 'Android 系统 EQ；需先播放歌曲初始化'),
        ListTile(
          leading: const Icon(Icons.equalizer),
          title: const Text('均衡器预设'),
          subtitle: Text(
            hub.equalizer.available
                ? '${EqualizerService.presets[hub.equalizer.currentPreset] ?? hub.equalizer.currentPreset}\n'
                    '${EqualizerService.presetHints[hub.equalizer.currentPreset] ?? '选择曲线快速改变音色'}'
                : '播放歌曲后可用（仅 Android）\n非 Android 或未开始播放时无法调用系统 EQ',
          ),
          isThreeLine: true,
          trailing: const Icon(Icons.arrow_drop_down),
          onTap: () => _pickEqPreset(context, hub),
        ),
        ListTile(
          leading: const Icon(Icons.tune),
          title: const Text('自定义 EQ'),
          subtitle: const Text('按频段滑块精细调节增益，结果保存为「自定义」'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CustomEqScreen()),
            );
          },
        ),


        _sectionHeader(context, '外观', '可换配色 / 壁纸 / 主色；猫耳壳与爪印始终保留'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Text(
            '当前：${ui.style.label} — ${ui.style.description}'
            '${ui.useCustomAccent ? ' · 主色 ${ui.accentHex}' : ''}\n'
            '默认 Meowsic 奶油 = 01 暖橘 + 06 品牌壳。换风格只改颜色，不移除猫元素与外观设置。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ),
        SizedBox(
          height: 118,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            itemCount: uiStylePresets.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final preset = uiStylePresets[i];
              return StylePreviewChip(
                preset: preset,
                selected: ui.styleId == preset.id,
                onTap: () async {
                  MeowsicHaptics.selection();
                  await ui.setStyle(preset.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('已切换配色：${preset.label}'),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  }
                },
              );
            },
          ),
        ),
        ListTile(
          leading: CircleAvatar(
            backgroundColor: ui.effectiveAccent,
            radius: 14,
            child: const Icon(Icons.colorize, size: 16, color: Colors.white),
          ),
          title: const Text('自定义主色'),
          subtitle: Text(ui.useCustomAccent ? '${ui.accentHex} · 覆盖强调色' : '色盘 / Hex / RGB'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ColorPickerScreen()),
            );
          },
        ),
        if (ui.useCustomAccent)
          ListTile(
            leading: const Icon(Icons.format_color_reset_outlined),
            title: const Text('清除自定义主色'),
            onTap: () async {
              await ui.clearCustomAccent();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已恢复风格默认主色')),
                );
              }
            },
          ),
        ExpansionTile(
          leading: const Icon(Icons.tune),
          title: const Text('外观高级'),
          subtitle: const Text('封面取色、字体、紧凑列表、背景图'),
          children: [
            SwitchListTile(
              secondary: const Icon(Icons.album_outlined),
              title: const Text('封面取色主题'),
              value: ui.coverThemeEnabled,
              onChanged: ui.setCoverThemeEnabled,
            ),
            ListTile(
              leading: const Icon(Icons.format_size),
              title: Text('字体大小 ${(ui.textScale * 100).round()}%'),
              subtitle: Slider(
                value: ui.textScale,
                min: 0.85,
                max: 1.3,
                divisions: 9,
                onChanged: ui.setTextScale,
              ),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.density_small),
              title: const Text('紧凑列表'),
              value: ui.compactMode,
              onChanged: ui.setCompactMode,
            ),
            ListTile(
              leading: const Icon(Icons.wallpaper),
              title: const Text('导入背景图'),
              onTap: () async {
                final ok = await ui.pickWallpaper();
                if (context.mounted && ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已导入并应用')),
                  );
                }
              },
            ),
            if (ui.wallpaperGallery.isNotEmpty)
              SizedBox(
                height: 88,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: ui.wallpaperGallery.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final path = ui.wallpaperGallery[i];
                    final selected = ui.wallpaperPath == path;
                    return GestureDetector(
                      onTap: () => ui.useWallpaper(path),
                      onLongPress: () => _wallpaperActions(context, ui, path),
                      child: Container(
                        width: 72,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: selected ? theme.colorScheme.primary : Colors.white24,
                            width: selected ? 2.5 : 1,
                          ),
                          image: DecorationImage(
                            image: FileImage(File(path)),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            if (ui.wallpaperPath != null) ...[
              ListTile(
                leading: const Icon(Icons.fit_screen),
                title: const Text('贴合方式'),
                subtitle: Text(ui.fitLabel),
                onTap: () => _pickFit(context, ui),
              ),
              ListTile(
                leading: const Icon(Icons.brightness_medium),
                title: Text('图片暗化 ${(ui.dim * 100).round()}%'),
                subtitle: Slider(
                  value: ui.dim,
                  min: 0.15,
                  max: 0.85,
                  onChanged: ui.setDim,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.hide_image_outlined),
                title: const Text('停用当前背景'),
                onTap: () async { await ui.clearWallpaper(); },
              ),
            ],
          ],
        ),

        _sectionHeader(context, '高级', '较少使用的维护项'),
        ExpansionTile(
          leading: const Icon(Icons.build_circle_outlined),
          title: const Text('高级选项'),
          subtitle: const Text('响度、软刷新、曲库只读、修复'),
          children: [
            SwitchListTile(
              secondary: const Icon(Icons.graphic_eq),
              title: const Text('响度匹配'),
              value: hub.loudnessMatch,
              onChanged: hub.setLoudnessMatch,
            ),
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('软刷新当前流'),
              trailing: const Icon(Icons.refresh),
              onTap: () async {
                await hub.softRefreshStream();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已软刷新播放流')),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder_copy_outlined),
              title: const Text('曲库目录（只读）'),
              subtitle: Text(
                (hub.libraryPaths.isNotEmpty
                        ? hub.libraryPaths.join('\n')
                        : (hub.status?.libraryPath ?? '未知')) +
                    '\n修改路径请在电脑 Web「设置 → 音乐目录」',
              ),
              isThreeLine: true,
              trailing: IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () async {
                  await hub.refreshLibraries();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('共 ${hub.libraryPaths.length} 个目录')),
                    );
                  }
                },
              ),
            ),
            ListTile(
              leading: const Icon(Icons.healing_outlined),
              title: const Text('异常歌曲修复'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BrokenScreen()));
              },
            ),
          ],
        ),

        const SizedBox(height: 12),
        if (hub.offlineMode) ...[
          FilledButton.tonalIcon(
            onPressed: onDisconnect,
            icon: const Icon(Icons.link),
            label: const Text('连接电脑服务器'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              final err = await hub.scanLocalLibrary();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(err ?? '本机扫描完成，共 ${hub.localSongs.length} 首')),
                );
              }
            },
            icon: const Icon(Icons.phone_android),
            label: const Text('重新扫描本机'),
          ),
        ] else ...[
          FilledButton.tonalIcon(
            onPressed: () async {
              final soft = await hub.softPing(force: true);
              if (!soft) {
                await hub.connect(hub.baseUrl);
              } else {
                await hub.refreshLibrary();
              }
            },
            icon: const Icon(Icons.refresh),
            label: const Text('重新连接 / 刷新状态'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onDisconnect,
            icon: const Icon(Icons.link_off),
            label: const Text('更换服务器'),
          ),
        ],
        const SizedBox(height: 20),
        Text(
          hub.offlineMode
              ? 'meowsic · 离线模式只听本机音频；需要电脑曲库时点「连接电脑」。 喵～'
              : 'meowsic · 曲库与扫描在电脑端；播放控制、场景、外观在本机。\n'
                  '一起听可同步进度，或仅共用曲库各自听。 喵～',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _sectionHeader(BuildContext context, String title, String hint) {
    final on = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            hint,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: on.withValues(alpha: 0.45),
                ),
          ),
        ],
      ),
    );
  }

  Widget _infoTile({
    required IconData icon,
    required String title,
    required String subtitle,
    String? hint,
    Color? iconColor,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(title),
      subtitle: Text(
        hint == null ? subtitle : '$subtitle\n$hint',
      ),
      isThreeLine: hint != null || subtitle.contains('\n'),
    );
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
            const ListTile(
              title: Text('选择循环模式'),
              subtitle: Text('控制队列结束后是否继续播放'),
            ),
            for (final item in HubState.loopModeChoices)
              ListTile(
                leading: Icon(
                  item.$1 == LoopMode.off
                      ? Icons.repeat
                      : item.$1 == LoopMode.one
                          ? Icons.repeat_one
                          : Icons.repeat_on,
                  color: hub.loopMode == item.$1
                      ? Theme.of(ctx).colorScheme.primary
                      : null,
                ),
                title: Text(item.$2),
                subtitle: Text(item.$3),
                trailing: hub.loopMode == item.$1 ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(ctx, item.$1),
              ),
            const SizedBox(height: 8),
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
            const ListTile(
              title: Text('选择播放速度'),
              subtitle: Text('影响当前及之后曲目的倍速'),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final s in HubState.speedOptions)
                    ListTile(
                      title: Text('${s}x'),
                      subtitle: Text(_speedHint(s)),
                      trailing: (hub.speed - s).abs() < 0.001
                          ? const Icon(Icons.check)
                          : null,
                      onTap: () => Navigator.pop(ctx, s),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (v != null) await hub.setSpeed(v);
  }

  String _speedHint(double s) {
    if (s < 0.9) return '明显变慢，适合精听歌词';
    if (s < 1.0) return '略慢，场景/氛围向';
    if (s == 1.0) return '原速';
    if (s <= 1.25) return '略快';
    if (s <= 1.5) return '明显加快';
    return '极快，适合过内容';
  }

  Future<void> _pickEqPreset(BuildContext context, HubState hub) async {
    final name = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        final entries = EqualizerService.presets.entries
            .where((e) => e.key != 'custom')
            .toList();
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.92,
          builder: (ctx, scroll) => Column(
            children: [
              const ListTile(
                title: Text('选择均衡器预设'),
                subtitle: Text('基于 Android 系统 Equalizer；精细调节请用「自定义 EQ」'),
              ),
              Expanded(
                child: ListView(
                  controller: scroll,
                  children: [
                    ...entries.map(
                      (e) => ListTile(
                        title: Text(e.value),
                        subtitle: Text(EqualizerService.presetHints[e.key] ?? ''),
                        trailing: hub.equalizer.currentPreset == e.key
                            ? const Icon(Icons.check)
                            : null,
                        onTap: () => Navigator.pop(ctx, e.key),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.tune),
                      title: const Text('打开自定义 EQ…'),
                      onTap: () {
                        Navigator.pop(ctx);
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const CustomEqScreen()),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
    if (name != null) await hub.setEqPreset(name);
  }

  Future<void> _wallpaperActions(BuildContext context, UiTheme ui, String path) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('背景缓存'), subtitle: Text('长按菜单')),
            ListTile(
              leading: const Icon(Icons.check_circle_outline),
              title: const Text('使用这张'),
              onTap: () => Navigator.pop(ctx, 'use'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
              title: const Text('从缓存删除'),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (action == 'use') {
      await ui.useWallpaper(path);
    } else if (action == 'delete') {
      await ui.deleteWallpaperFromGallery(path);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已从缓存删除')),
        );
      }
    }
  }

  Future<void> _pickFit(BuildContext context, UiTheme ui) async {
    final options = <(BoxFit, String, String)>[
      (BoxFit.cover, '铺满裁切', '填满屏幕，多余部分裁掉（推荐）'),
      (BoxFit.contain, '完整显示', '完整显示图片，可能留黑边'),
      (BoxFit.fill, '拉伸填满', '强制拉伸，可能变形'),
      (BoxFit.fitWidth, '适应宽度', '按宽度对齐'),
      (BoxFit.fitHeight, '适应高度', '按高度对齐'),
    ];
    final fit = await showModalBottomSheet<BoxFit>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text('背景贴合方式'),
              subtitle: Text('图片如何适配不同屏幕比例'),
            ),
            for (final o in options)
              ListTile(
                title: Text(o.$2),
                subtitle: Text(o.$3),
                trailing: ui.fit == o.$1 ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(ctx, o.$1),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (fit != null) await ui.setFit(fit);
  }
}
