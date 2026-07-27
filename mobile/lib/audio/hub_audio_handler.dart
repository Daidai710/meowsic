import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

/// System media notification + lock-screen / headset controls (A5+).
class HubAudioHandler extends BaseAudioHandler with SeekHandler {
  HubAudioHandler() {
    _player.playbackEventStream.listen((event) {
      _broadcastState(event);
    });
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        onCompleted?.call();
      }
      // Re-broadcast when processing state changes (loading → ready).
      _broadcastState(_player.playbackEvent);
    });
    _player.playingStream.listen((_) {
      _broadcastState(_player.playbackEvent);
    });
  }

  final AudioPlayer _player = AudioPlayer();
  AudioPlayer get player => _player;

  Future<void> Function()? onPlay;
  Future<void> Function()? onPause;
  Future<void> Function()? onSkipNext;
  Future<void> Function()? onSkipPrevious;
  void Function()? onCompleted;

  Future<void> setMedia({
    required String id,
    required String title,
    required String artist,
    required String album,
    String? artUri,
    Duration? duration,
  }) async {
    mediaItem.add(
      MediaItem(
        id: id,
        title: title.isEmpty ? 'Music Hub' : title,
        artist: artist.isEmpty ? '未知艺人' : artist,
        album: album,
        artUri: artUri != null ? Uri.tryParse(artUri) : null,
        duration: duration,
        playable: true,
      ),
    );
    // Force notification refresh with current transport state.
    _broadcastState(_player.playbackEvent);
  }

  @override
  Future<void> play() async {
    if (onPlay != null) {
      await onPlay!();
    } else {
      await _player.play();
    }
    _broadcastState(_player.playbackEvent);
  }

  @override
  Future<void> pause() async {
    if (onPause != null) {
      await onPause!();
    } else {
      await _player.pause();
    }
    _broadcastState(_player.playbackEvent);
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
    _broadcastState(_player.playbackEvent);
  }

  @override
  Future<void> seek(Duration position) async {
    await _player.seek(position);
    _broadcastState(_player.playbackEvent);
  }

  @override
  Future<void> skipToNext() async {
    if (onSkipNext != null) await onSkipNext!();
  }

  @override
  Future<void> skipToPrevious() async {
    if (onSkipPrevious != null) await onSkipPrevious!();
  }

  void _broadcastState(PlaybackEvent event) {
    final playing = _player.playing;
    final proc = _player.processingState;
    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
          MediaControl.stop,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
          MediaAction.skipToNext,
          MediaAction.skipToPrevious,
          MediaAction.play,
          MediaAction.pause,
          MediaAction.stop,
        },
        // Compact notification shows prev / play-pause / next
        androidCompactActionIndices: const [0, 1, 2],
        processingState: const {
          ProcessingState.idle: AudioProcessingState.idle,
          ProcessingState.loading: AudioProcessingState.loading,
          ProcessingState.buffering: AudioProcessingState.buffering,
          ProcessingState.ready: AudioProcessingState.ready,
          ProcessingState.completed: AudioProcessingState.completed,
        }[proc]!,
        playing: playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: event.currentIndex,
      ),
    );
  }
}

Future<HubAudioHandler> initHubAudioHandler() async {
  return AudioService.init(
    builder: () => HubAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.musichub.music_hub_app.channel.audio',
      androidNotificationChannelName: 'Music Hub 播放',
      androidNotificationChannelDescription: '显示当前歌曲与切歌 / 暂停控件',
      androidNotificationIcon: 'drawable/ic_stat_music',
      // Keep service in foreground while paused so media controls stay visible
      // after leaving the app (also avoids Android 12+ FGS restart limits).
      androidNotificationOngoing: false,
      androidStopForegroundOnPause: false,
      androidShowNotificationBadge: true,
      androidNotificationClickStartsActivity: true,
      fastForwardInterval: Duration(seconds: 10),
      rewindInterval: Duration(seconds: 10),
      preloadArtwork: true,
    ),
  );
}
