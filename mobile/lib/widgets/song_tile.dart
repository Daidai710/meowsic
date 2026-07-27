import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/ui_theme.dart';
import '../util/haptics.dart';
import 'cat_decor.dart';

class SongTile extends StatelessWidget {
  const SongTile({
    super.key,
    required this.song,
    required this.baseUrl,
    required this.onTap,
    this.playing = false,
    this.onAddPlaylist,
    this.onPlayNext,
    this.onAddToQueue,
  });

  final Song song;
  final String baseUrl;
  final VoidCallback onTap;
  final bool playing;
  final VoidCallback? onAddPlaylist;
  final VoidCallback? onPlayNext;
  final VoidCallback? onAddToQueue;

  String _fmt(double? sec) {
    if (sec == null || sec.isNaN) return '';
    final s = sec.floor();
    final m = s ~/ 60;
    final r = s % 60;
    return '$m:${r.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final cover = song.absoluteCoverUrl(baseUrl);
    final hasMenu =
        onPlayNext != null || onAddToQueue != null || onAddPlaylist != null;
    final compact = context.watch<UiTheme>().compactMode;
    final coverSize = compact ? 42.0 : 50.0;
    final cs = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;

    final tile = ListTile(
      dense: compact,
      visualDensity:
          compact ? VisualDensity.compact : VisualDensity.standard,
      contentPadding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 0 : 2,
      ),
      selected: playing,
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: coverSize,
              height: coverSize,
              child: cover != null
                  ? Image.network(
                      cover,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _coverPh(cs),
                    )
                  : _coverPh(cs),
            ),
          ),
          if (playing)
            Positioned(
              right: -3,
              bottom: -3,
              child: CatPawIcon(size: 14, color: cs.primary, opacity: 0.95),
            ),
        ],
      ),
      title: Text(
        song.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: playing ? FontWeight.w700 : FontWeight.w600,
          color: playing && isLight ? const Color(0xFF3D2418) : null,
        ),
      ),
      subtitle: Text(
        '${song.artist} · ${_fmt(song.duration)}'
        '${song.tagOk ? '' : ' · 异常格式'}'
        '${song.isOnline ? (song.onlinePreviewOnly ? ' · 联网试听' : ' · 联网') : ''}'
        '${song.isLocal ? ' · 本机' : ''}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: (playing && isLight
                  ? const Color(0xFF5C3A28)
                  : cs.onSurface)
              .withValues(alpha: 0.65),
        ),
      ),
      trailing: hasMenu
          ? PopupMenuButton<String>(
              icon: Icon(
                Icons.more_horiz_rounded,
                color: cs.onSurface.withValues(alpha: 0.55),
              ),
              onSelected: (v) {
                MeowsicHaptics.selection();
                if (v == 'next') onPlayNext?.call();
                if (v == 'end') onAddToQueue?.call();
                if (v == 'pl') onAddPlaylist?.call();
              },
              itemBuilder: (ctx) => [
                if (onPlayNext != null)
                  const PopupMenuItem(value: 'next', child: Text('下一首播放')),
                if (onAddToQueue != null)
                  const PopupMenuItem(value: 'end', child: Text('加到队列末尾')),
                if (onAddPlaylist != null)
                  const PopupMenuItem(value: 'pl', child: Text('加入歌单')),
              ],
            )
          : Text(
              song.isOnline ? '试听' : song.format.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: cs.primary.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w600,
                  ),
            ),
      onTap: () {
        MeowsicHaptics.light();
        onTap();
      },
      onLongPress: onPlayNext == null
          ? null
          : () {
              MeowsicHaptics.medium();
              onPlayNext!();
            },
    );

    // Peach cream card row (01/06 selected highlight)
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 2 : 4,
      ),
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: playing
                ? LinearGradient(
                    colors: [
                      cs.primary.withValues(alpha: isLight ? 0.32 : 0.28),
                      cs.primary.withValues(alpha: isLight ? 0.12 : 0.14),
                    ],
                  )
                : null,
            color: playing
                ? null
                : cs.surface.withValues(alpha: isLight ? 0.72 : 0.42),
            border: Border.all(
              color: playing
                  ? cs.primary.withValues(alpha: 0.45)
                  : cs.onSurface.withValues(alpha: 0.05),
            ),
            boxShadow: playing
                ? [
                    BoxShadow(
                      color: cs.primary.withValues(alpha: 0.14),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: tile,
        ),
      ),
    );
  }

  Widget _coverPh(ColorScheme cs) => ColoredBox(
        color: cs.primary.withValues(alpha: 0.12),
        child: Icon(Icons.music_note_rounded, size: 22, color: cs.primary),
      );
}
