import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/hub_state.dart';

/// Full-screen custom equalizer band sliders (Android only after playback starts).
class CustomEqScreen extends StatelessWidget {
  const CustomEqScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final hub = context.watch<HubState>();
    final eq = hub.equalizer;

    return Scaffold(
      appBar: AppBar(
        title: const Text('自定义均衡器'),
        actions: [
          TextButton(
            onPressed: eq.available
                ? () async {
                    await hub.setEqPreset('normal');
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('已重置为平坦')),
                      );
                    }
                  }
                : null,
            child: const Text('重置'),
          ),
        ],
      ),
      body: !eq.available
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  '请先在 Android 上播放一首歌曲以初始化系统均衡器，再返回此页调节。',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : eq.bands.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  children: [
                    Text(
                      '拖动各频段增益（单位 mB，约 100mB = 1dB）。当前：自定义',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white54),
                    ),
                    const SizedBox(height: 16),
                    ...eq.bands.map((band) {
                      final min = band.minMb.toDouble();
                      final max = band.maxMb.toDouble();
                      final level = band.levelMb.toDouble().clamp(min, max);
                      final db = (band.levelMb / 100).toStringAsFixed(1);
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    band.label,
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${db}dB',
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.primary,
                                      fontFeatures: const [FontFeature.tabularFigures()],
                                    ),
                                  ),
                                ],
                              ),
                              Slider(
                                value: level,
                                min: min,
                                max: max,
                                divisions: ((max - min) / 50).round().clamp(1, 80),
                                label: '${db}dB',
                                onChanged: (v) {
                                  hub.setEqBand(band.index, v.round());
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
    );
  }
}
