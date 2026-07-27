/// Listening scenes: combine EQ curve + optional speed / volume soft trim.
class ScenePreset {
  const ScenePreset({
    required this.id,
    required this.label,
    required this.description,
    required this.eqPreset,
    this.speed = 1.0,
    this.volume = 1.0,
  });

  final String id;
  final String label;
  final String description;
  /// Maps to Android EQ preset name
  final String eqPreset;
  final double speed;
  final double volume;
}

const scenePresets = <ScenePreset>[
  ScenePreset(
    id: 'default',
    label: '默认',
    description: '不额外染色，按当前均衡器设置',
    eqPreset: 'normal',
    speed: 1.0,
    volume: 1.0,
  ),
  ScenePreset(
    id: 'cinematic',
    label: 'Cinematic',
    description: '电影感：低频厚实、中高频开阔',
    eqPreset: 'cinematic',
    speed: 1.0,
    volume: 0.95,
  ),
  ScenePreset(
    id: 'lofi',
    label: 'Lo-fi',
    description: '柔和滚降高音，略慢一点更松弛',
    eqPreset: 'lofi',
    speed: 0.95,
    volume: 0.9,
  ),
  ScenePreset(
    id: 'sad_ballad',
    label: 'Sad Ballad',
    description: '人声与中频靠前，适合抒情慢歌',
    eqPreset: 'sad_ballad',
    speed: 0.98,
    volume: 0.92,
  ),
  ScenePreset(
    id: 'night_drive',
    label: 'Night Drive',
    description: '低音推进 + 高音轮廓，适合夜驾',
    eqPreset: 'electronic',
    speed: 1.0,
    volume: 0.95,
  ),
  ScenePreset(
    id: 'focus',
    label: 'Focus',
    description: '削弱低频轰鸣，中高频干净，利于专注',
    eqPreset: 'podcast',
    speed: 1.0,
    volume: 0.85,
  ),
  ScenePreset(
    id: 'party',
    label: 'Party',
    description: '舞曲感，低音与空气感更足',
    eqPreset: 'dance',
    speed: 1.0,
    volume: 1.0,
  ),
  ScenePreset(
    id: 'acoustic_cafe',
    label: 'Acoustic Café',
    description: '原声温暖，中频自然',
    eqPreset: 'acoustic',
    speed: 1.0,
    volume: 0.9,
  ),
  ScenePreset(
    id: 'hiphop_street',
    label: 'Hip-Hop',
    description: '重低频与节奏感',
    eqPreset: 'hiphop',
    speed: 1.0,
    volume: 0.95,
  ),
  ScenePreset(
    id: 'bright_pop',
    label: 'Bright Pop',
    description: '流行曲明亮贴耳',
    eqPreset: 'pop',
    speed: 1.0,
    volume: 0.95,
  ),
];
