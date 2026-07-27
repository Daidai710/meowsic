import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../screens/now_playing_screen.dart';
import '../screens/queue_screen.dart';
import '../state/hub_state.dart';
import '../util/haptics.dart';
import 'cat_decor.dart';

/// Floating mini player above the bottom navigation — cream glass bar (01/06).
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final hub = context.watch<HubState>();
    final song = hub.current;
    if (song == null) return const SizedBox.shrink();

    final cover = song.absoluteCoverUrl(hub.baseUrl);
    final pos = hub.player.position;
    final dur = hub.player.duration ?? Duration.zero;
    final progress =
        dur.inMilliseconds == 0 ? 0.0 : pos.inMilliseconds / dur.inMilliseconds;
    final cs = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final titleColor = cs.onSurface;
    final subColor = cs.onSurface.withValues(alpha: 0.65);

    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: Material(
          elevation: 8,
          shadowColor: cs.primary.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(20),
          color: cs.surface.withValues(alpha: isLight ? 0.94 : 0.90),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: cs.primary.withValues(alpha: isLight ? 0.14 : 0.22),
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    minHeight: 3,
                    backgroundColor: cs.primary.withValues(alpha: 0.12),
                    color: cs.primary,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              MeowsicHaptics.light();
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const NowPlayingScreen(),
                                ),
                              );
                            },
                            child: Row(
                              children: [
                                Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: SizedBox(
                                        width: 48,
                                        height: 48,
                                        child: cover != null
                                            ? Image.network(
                                                cover,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, _, _) =>
                                                    _ph(cs),
                                              )
                                            : _ph(cs),
                                      ),
                                    ),
                                    Positioned(
                                      right: -4,
                                      bottom: -4,
                                      child: CatPawIcon(
                                        size: 15,
                                        color: cs.primary,
                                        opacity: 0.95,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        song.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                          color: titleColor,
                                        ),
                                      ),
                                      Text(
                                        _subtitle(hub, song.artist),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: subColor,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: '上一首',
                          icon: Icon(
                            Icons.skip_previous_rounded,
                            color: titleColor,
                          ),
                          onPressed: () {
                            MeowsicHaptics.light();
                            hub.prev();
                          },
                        ),
                        IconButton(
                          tooltip: hub.player.playing ? '暂停' : '播放',
                          iconSize: 44,
                          color: cs.primary,
                          icon: Icon(
                            hub.player.playing
                                ? Icons.pause_circle_filled_rounded
                                : Icons.play_circle_filled_rounded,
                          ),
                          onPressed: () {
                            MeowsicHaptics.medium();
                            hub.togglePlay();
                          },
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: '下一首',
                          icon: Icon(
                            Icons.skip_next_rounded,
                            color: titleColor,
                          ),
                          onPressed: () {
                            MeowsicHaptics.light();
                            hub.next();
                          },
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: hub.queue.isEmpty
                              ? '队列'
                              : '队列 ${hub.queueIndex + 1}/${hub.queue.length}',
                          icon: Icon(
                            Icons.queue_music_rounded,
                            size: 22,
                            color: subColor,
                          ),
                          onPressed: () {
                            MeowsicHaptics.light();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const QueueScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _subtitle(HubState hub, String artist) {
    final q = hub.queue.isEmpty
        ? ''
        : '${hub.queueIndex + 1}/${hub.queue.length}';
    if (hub.isSleeping) {
      final sleep = '睡眠 ${hub.sleepMinutesLeft} 分';
      return q.isEmpty ? '$sleep · $artist' : '$q · $sleep · $artist';
    }
    return q.isEmpty ? artist : '$q · $artist';
  }

  Widget _ph(ColorScheme cs) => ColoredBox(
        color: cs.primary.withValues(alpha: 0.14),
        child: Icon(Icons.music_note_rounded, size: 22, color: cs.primary),
      );
}
