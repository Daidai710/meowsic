import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../state/ui_theme.dart';

/// Full-page accent color editor: palette, HSV, RGB sliders, Hex input.
class ColorPickerScreen extends StatefulWidget {
  const ColorPickerScreen({super.key});

  @override
  State<ColorPickerScreen> createState() => _ColorPickerScreenState();
}

class _ColorPickerScreenState extends State<ColorPickerScreen> {
  late HSVColor _hsv;
  late TextEditingController _hexCtrl;
  late TextEditingController _rCtrl;
  late TextEditingController _gCtrl;
  late TextEditingController _bCtrl;
  bool _syncingText = false;

  @override
  void initState() {
    super.initState();
    final ui = context.read<UiTheme>();
    final c = ui.useCustomAccent ? ui.customAccent : ui.style.accent;
    _hsv = HSVColor.fromColor(c);
    _hexCtrl = TextEditingController(text: UiTheme.colorToHex(c).substring(1));
    _rCtrl = TextEditingController(text: '${UiTheme.channel(c, 'r')}');
    _gCtrl = TextEditingController(text: '${UiTheme.channel(c, 'g')}');
    _bCtrl = TextEditingController(text: '${UiTheme.channel(c, 'b')}');
  }

  @override
  void dispose() {
    _hexCtrl.dispose();
    _rCtrl.dispose();
    _gCtrl.dispose();
    _bCtrl.dispose();
    super.dispose();
  }

  Color get _color => _hsv.toColor();

  void _applyFromHsv(HSVColor hsv, {bool persist = true}) {
    setState(() => _hsv = hsv);
    _syncTextFromColor(_color);
    if (persist) {
      context.read<UiTheme>().setCustomAccent(_color, enable: true);
    }
  }

  void _syncTextFromColor(Color c) {
    _syncingText = true;
    _hexCtrl.text = UiTheme.colorToHex(c).substring(1);
    _rCtrl.text = '${UiTheme.channel(c, 'r')}';
    _gCtrl.text = '${UiTheme.channel(c, 'g')}';
    _bCtrl.text = '${UiTheme.channel(c, 'b')}';
    _syncingText = false;
  }

  void _applyFromRgb(int r, int g, int b) {
    final c = Color.fromARGB(255, r.clamp(0, 255), g.clamp(0, 255), b.clamp(0, 255));
    _applyFromHsv(HSVColor.fromColor(c));
  }

  Future<void> _applyHex() async {
    final ok = await context.read<UiTheme>().setCustomAccentHex('#${_hexCtrl.text}');
    if (!mounted) return;
    if (ok) {
      final c = context.read<UiTheme>().customAccent;
      setState(() => _hsv = HSVColor.fromColor(c));
      _syncTextFromColor(c);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已应用 ${UiTheme.colorToHex(c)}'), duration: const Duration(seconds: 1)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hex 无效，请用 RRGGBB 或 RGB，如 6C9EFF')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui = context.watch<UiTheme>();
    final c = _color;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('自定义主色'),
        actions: [
          if (ui.useCustomAccent)
            TextButton(
              onPressed: () async {
                await ui.clearCustomAccent();
                if (!mounted) return;
                final back = ui.style.accent;
                setState(() => _hsv = HSVColor.fromColor(back));
                _syncTextFromColor(back);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已恢复当前风格默认色')),
                );
              },
              child: const Text('恢复默认'),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // Live preview
          Container(
            height: 88,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [c, Color.lerp(c, Colors.black, 0.35)!],
              ),
              border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white54, width: 2),
                    boxShadow: [
                      BoxShadow(color: c.withValues(alpha: 0.5), blurRadius: 12),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        UiTheme.colorToHex(c),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                          color: Colors.white,
                          shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                        ),
                      ),
                      Text(
                        'RGB(${UiTheme.channel(c, 'r')}, ${UiTheme.channel(c, 'g')}, ${UiTheme.channel(c, 'b')})'
                        '${ui.useCustomAccent ? ' · 自定义中' : ' · 未启用自定义'}',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Text('色盘快选', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final p in accentPalette)
                GestureDetector(
                  onTap: () => _applyFromHsv(HSVColor.fromColor(p)),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: p,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: (UiTheme.channel(c, 'r') == UiTheme.channel(p, 'r') &&
                                UiTheme.channel(c, 'g') == UiTheme.channel(p, 'g') &&
                                UiTheme.channel(c, 'b') == UiTheme.channel(p, 'b'))
                            ? theme.colorScheme.onSurface
                            : Colors.white24,
                        width: 2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 22),

          Text('色相 / 饱和 / 明度', style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          // Hue rainbow slider
          _labeledSlider(
            label: 'H 色相 ${_hsv.hue.round()}°',
            value: _hsv.hue,
            min: 0,
            max: 360,
            activeColor: HSVColor.fromAHSV(1, _hsv.hue, 1, 1).toColor(),
            onChanged: (v) => _applyFromHsv(_hsv.withHue(v)),
          ),
          _labeledSlider(
            label: 'S 饱和 ${(_hsv.saturation * 100).round()}%',
            value: _hsv.saturation,
            min: 0,
            max: 1,
            activeColor: c,
            onChanged: (v) => _applyFromHsv(_hsv.withSaturation(v)),
          ),
          _labeledSlider(
            label: 'V 明度 ${(_hsv.value * 100).round()}%',
            value: _hsv.value,
            min: 0.05,
            max: 1,
            activeColor: c,
            onChanged: (v) => _applyFromHsv(_hsv.withValue(v)),
          ),

          // SV square picker
          const SizedBox(height: 8),
          Text('平面选色（饱和×明度）', style: theme.textTheme.bodySmall),
          const SizedBox(height: 6),
          AspectRatio(
            aspectRatio: 1.4,
            child: LayoutBuilder(
              builder: (context, box) {
                return GestureDetector(
                  onPanDown: (d) => _pickSv(d.localPosition, box.biggest),
                  onPanUpdate: (d) => _pickSv(d.localPosition, box.biggest),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CustomPaint(
                      painter: _SvPainter(hue: _hsv.hue),
                      child: Stack(
                        children: [
                          Positioned(
                            left: (_hsv.saturation * box.maxWidth) - 8,
                            top: ((1 - _hsv.value) * box.maxHeight) - 8,
                            child: Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: c,
                                border: Border.all(color: Colors.white, width: 2),
                                boxShadow: const [
                                  BoxShadow(blurRadius: 4, color: Colors.black45),
                                ],
                              ),
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
          const SizedBox(height: 22),

          Text('RGB 色号', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          _rgbSlider(
            label: 'R',
            value: UiTheme.channel(c, 'r').toDouble(),
            color: Colors.redAccent,
            controller: _rCtrl,
            onSlider: (v) => _applyFromRgb(
              v.round(),
              UiTheme.channel(c, 'g'),
              UiTheme.channel(c, 'b'),
            ),
            onSubmit: () {
              final r = int.tryParse(_rCtrl.text) ?? UiTheme.channel(c, 'r');
              _applyFromRgb(r, UiTheme.channel(c, 'g'), UiTheme.channel(c, 'b'));
            },
          ),
          _rgbSlider(
            label: 'G',
            value: UiTheme.channel(c, 'g').toDouble(),
            color: Colors.greenAccent,
            controller: _gCtrl,
            onSlider: (v) => _applyFromRgb(
              UiTheme.channel(c, 'r'),
              v.round(),
              UiTheme.channel(c, 'b'),
            ),
            onSubmit: () {
              final g = int.tryParse(_gCtrl.text) ?? UiTheme.channel(c, 'g');
              _applyFromRgb(UiTheme.channel(c, 'r'), g, UiTheme.channel(c, 'b'));
            },
          ),
          _rgbSlider(
            label: 'B',
            value: UiTheme.channel(c, 'b').toDouble(),
            color: Colors.lightBlueAccent,
            controller: _bCtrl,
            onSlider: (v) => _applyFromRgb(
              UiTheme.channel(c, 'r'),
              UiTheme.channel(c, 'g'),
              v.round(),
            ),
            onSubmit: () {
              final b = int.tryParse(_bCtrl.text) ?? UiTheme.channel(c, 'b');
              _applyFromRgb(UiTheme.channel(c, 'r'), UiTheme.channel(c, 'g'), b);
            },
          ),
          const SizedBox(height: 18),

          Text('Hex 色号', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('#', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(width: 6),
              Expanded(
                child: TextField(
                  controller: _hexCtrl,
                  decoration: const InputDecoration(
                    hintText: '6C9EFF',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9a-fA-F]')),
                    LengthLimitingTextInputFormatter(8),
                  ],
                  textCapitalization: TextCapitalization.characters,
                  onSubmitted: (_) => _applyHex(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(onPressed: _applyHex, child: const Text('应用')),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '说明：自定义主色会覆盖当前风格的强调色（按钮、进度、光晕等），'
            '背景风格预设仍保留。可点右上角「恢复默认」。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }

  void _pickSv(Offset local, Size size) {
    final s = (local.dx / size.width).clamp(0.0, 1.0);
    final v = (1 - local.dy / size.height).clamp(0.05, 1.0);
    _applyFromHsv(_hsv.withSaturation(s).withValue(v));
  }

  Widget _labeledSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required Color activeColor,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12)),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          activeColor: activeColor,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _rgbSlider({
    required String label,
    required double value,
    required Color color,
    required TextEditingController controller,
    required ValueChanged<double> onSlider,
    required VoidCallback onSubmit,
  }) {
    return Row(
      children: [
        SizedBox(width: 18, child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold))),
        Expanded(
          child: Slider(
            value: value.clamp(0, 255),
            min: 0,
            max: 255,
            divisions: 255,
            activeColor: color,
            onChanged: onSlider,
          ),
        ),
        SizedBox(
          width: 52,
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            ),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(3),
            ],
            onChanged: (_) {
              if (_syncingText) return;
            },
            onSubmitted: (_) => onSubmit(),
            onEditingComplete: onSubmit,
          ),
        ),
      ],
    );
  }
}

class _SvPainter extends CustomPainter {
  _SvPainter({required this.hue});
  final double hue;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final hueColor = HSVColor.fromAHSV(1, hue, 1, 1).toColor();
    // White → pure hue (saturation)
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          colors: [Colors.white, hueColor],
        ).createShader(rect),
    );
    // Transparent → black (value)
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _SvPainter oldDelegate) => oldDelegate.hue != hue;
}
