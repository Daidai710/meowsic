import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Small decorative cat paw (vector). Color comes from theme accent when null.
class CatPawIcon extends StatelessWidget {
  const CatPawIcon({
    super.key,
    this.size = 22,
    this.color,
    this.opacity = 1,
  });

  final double size;
  final Color? color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final c = (color ?? Theme.of(context).colorScheme.primary).withValues(alpha: opacity);
    return CustomPaint(
      size: Size(size, size),
      painter: _CatPawPainter(c),
    );
  }
}

class _CatPawPainter extends CustomPainter {
  _CatPawPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final w = size.width;
    final h = size.height;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * 0.5, h * 0.62), width: w * 0.52, height: h * 0.42),
      p,
    );
    final toes = <Offset>[
      Offset(w * 0.22, h * 0.32),
      Offset(w * 0.40, h * 0.20),
      Offset(w * 0.60, h * 0.20),
      Offset(w * 0.78, h * 0.32),
    ];
    for (final o in toes) {
      canvas.drawOval(
        Rect.fromCenter(center: o, width: w * 0.20, height: h * 0.24),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CatPawPainter old) => old.color != color;
}

/// Simple cat-ear silhouette for host / VIP badges.
class CatEarIcon extends StatelessWidget {
  const CatEarIcon({super.key, this.size = 18, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return CustomPaint(
      size: Size(size, size),
      painter: _CatEarPainter(c),
    );
  }
}

class _CatEarPainter extends CustomPainter {
  _CatEarPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(size.width * 0.12, size.height * 0.88)
      ..lineTo(size.width * 0.28, size.height * 0.12)
      ..lineTo(size.width * 0.52, size.height * 0.72)
      ..close();
    final path2 = Path()
      ..moveTo(size.width * 0.48, size.height * 0.72)
      ..lineTo(size.width * 0.72, size.height * 0.12)
      ..lineTo(size.width * 0.88, size.height * 0.88)
      ..close();
    canvas.drawPath(path, p);
    canvas.drawPath(path2, p);
  }

  @override
  bool shouldRepaint(covariant _CatEarPainter old) => old.color != color;
}

/// Role badge: host = ears, mod/guest = paw.
class MeowsicRoleBadge extends StatelessWidget {
  const MeowsicRoleBadge({super.key, required this.role});

  /// host | mod | guest
  final String role;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isHost = role == 'host';
    final isMod = role == 'mod';
    final label = isHost ? '房主' : isMod ? '管理' : '听众';
    final bg = isHost
        ? cs.primary.withValues(alpha: 0.22)
        : isMod
            ? cs.tertiary.withValues(alpha: 0.2)
            : cs.surfaceContainerHighest.withValues(alpha: 0.7);
    final fg = isHost ? cs.primary : (isMod ? cs.tertiary : cs.onSurface.withValues(alpha: 0.7));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isHost)
            CatEarIcon(size: 14, color: fg)
          else
            CatPawIcon(size: 13, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
          ),
        ],
      ),
    );
  }
}

/// Soft floating paw trail.
class CatPawTrail extends StatelessWidget {
  const CatPawTrail({
    super.key,
    this.height = 40,
    this.opacity = 0.18,
  });

  final double height;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme.primary;
    return SizedBox(
      height: height,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < 5; i++) ...[
            if (i > 0) SizedBox(width: 10 + (i % 2) * 4.0),
            Transform.rotate(
              angle: (i.isEven ? -1 : 1) * 0.25,
              child: CatPawIcon(
                size: 14 + (i % 3) * 3.0,
                color: c,
                opacity: opacity * (0.55 + (i % 3) * 0.15),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Brand mark with asset icon (preview 06 mascot).
class MeowsicBrandMark extends StatelessWidget {
  const MeowsicBrandMark({super.key, this.size = 88, this.showPawTrail = true});

  final double size;
  final bool showPawTrail;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size * 0.28),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.28),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(size * 0.28),
            child: Image.asset(
              'assets/icons/meowsic_icon.png',
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, error, stack) => Icon(
                Icons.pets,
                size: size * 0.72,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ),
        if (showPawTrail) ...[
          const SizedBox(height: 6),
          const CatPawTrail(height: 28, opacity: 0.22),
        ],
      ],
    );
  }
}

/// Compact brand row for AppBar (icon + meowsic wordmark).
class MeowsicAppBarTitle extends StatelessWidget {
  const MeowsicAppBarTitle({super.key, required this.pageTitle});

  final String pageTitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.asset(
            'assets/icons/meowsic_icon.png',
            width: 32,
            height: 32,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => CatPawIcon(size: 22, color: primary),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                pageTitle,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'meowsic',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: primary.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Soft cream panel (06 glass shell) — recolors with surface/primary.
class MeowsicPanel extends StatelessWidget {
  const MeowsicPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.radius = 22,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: isLight ? 0.88 : 0.72),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: cs.primary.withValues(alpha: isLight ? 0.12 : 0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isLight ? 0.06 : 0.28),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Corner brand mascot (preview 06) — non-interactive, sits above content.
class MeowsicCornerMascot extends StatelessWidget {
  const MeowsicCornerMascot({
    super.key,
    this.size = 112,
    this.opacity = 0.92,
  });

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: Alignment.bottomRight,
        child: Padding(
          padding: const EdgeInsets.only(right: 2, bottom: 4),
          child: Opacity(
            opacity: opacity,
            child: Image.asset(
              'assets/icons/meowsic_icon.png',
              width: size,
              height: size,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
  }
}

/// Corner watermark paws (non-interactive). Always on — theme only recolors.
class CatPawWatermark extends StatelessWidget {
  const CatPawWatermark({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme.primary;
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            right: 12,
            top: 8,
            child: CatPawIcon(size: 28, color: c, opacity: 0.10),
          ),
          Positioned(
            right: 36,
            top: 36,
            child: Transform.rotate(
              angle: 0.4,
              child: CatPawIcon(size: 18, color: c, opacity: 0.08),
            ),
          ),
          Positioned(
            left: 10,
            bottom: 10,
            child: Transform.rotate(
              angle: -0.35,
              child: CatPawIcon(size: 22, color: c, opacity: 0.09),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sleeping cat illustration for sleep-timer sheet (vector, recolors with theme).
class SleepingCatArt extends StatelessWidget {
  const SleepingCatArt({super.key, this.size = 72});

  final double size;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme.primary;
    return CustomPaint(
      size: Size(size, size * 0.75),
      painter: _SleepingCatPainter(c),
    );
  }
}

class _SleepingCatPainter extends CustomPainter {
  _SleepingCatPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final body = Paint()..color = color.withValues(alpha: 0.85);
    final soft = Paint()..color = color.withValues(alpha: 0.35);
    final w = size.width;
    final h = size.height;
    // Body
    canvas.drawOval(Rect.fromLTWH(w * 0.12, h * 0.38, w * 0.62, h * 0.42), body);
    // Head
    canvas.drawCircle(Offset(w * 0.68, h * 0.42), w * 0.18, body);
    // Ear
    final ear = Path()
      ..moveTo(w * 0.58, h * 0.32)
      ..lineTo(w * 0.62, h * 0.12)
      ..lineTo(w * 0.72, h * 0.30)
      ..close();
    canvas.drawPath(ear, body);
    // Closed eye
    final eye = Paint()
      ..color = color.withValues(alpha: 0.55)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCenter(center: Offset(w * 0.72, h * 0.42), width: w * 0.08, height: h * 0.06),
      0.2,
      math.pi * 0.9,
      false,
      eye,
    );
    // Zzz
    final tp = TextPainter(
      text: TextSpan(
        text: 'z z',
        style: TextStyle(
          color: color.withValues(alpha: 0.7),
          fontSize: w * 0.12,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(w * 0.78, h * 0.08));
    // Soft pillow blob
    canvas.drawOval(Rect.fromLTWH(w * 0.08, h * 0.72, w * 0.84, h * 0.18), soft);
  }

  @override
  bool shouldRepaint(covariant _SleepingCatPainter old) => old.color != color;
}

/// QR viewfinder with paw corners (UI chrome — not color-theme dependent layout).
class QrPawViewfinder extends StatelessWidget {
  const QrPawViewfinder({super.key, this.size = 240});

  final double size;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme.primary;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          // Soft edge guide (no heavy rectangle)
          CustomPaint(
            size: Size(size, size),
            painter: _QrGuidePainter(c.withValues(alpha: 0.35)),
          ),
          Positioned(left: 4, top: 4, child: Transform.rotate(angle: -0.3, child: CatPawIcon(size: 26, color: c, opacity: 0.95))),
          Positioned(right: 4, top: 4, child: Transform.rotate(angle: 0.3, child: CatPawIcon(size: 26, color: c, opacity: 0.95))),
          Positioned(left: 4, bottom: 4, child: Transform.rotate(angle: 0.35, child: CatPawIcon(size: 26, color: c, opacity: 0.95))),
          Positioned(right: 4, bottom: 4, child: Transform.rotate(angle: -0.35, child: CatPawIcon(size: 26, color: c, opacity: 0.95))),
        ],
      ),
    );
  }
}

class _QrGuidePainter extends CustomPainter {
  _QrGuidePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final r = RRect.fromRectAndRadius(
      Rect.fromLTWH(18, 18, size.width - 36, size.height - 36),
      const Radius.circular(20),
    );
    canvas.drawRRect(r, p);
  }

  @override
  bool shouldRepaint(covariant _QrGuidePainter old) => old.color != color;
}

/// Brief “paw steps” celebration after successful connect.
Future<void> showMeowsicConnectCelebration(BuildContext context) async {
  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (ctx, a1, a2) {
      return const _PawStepDialog();
    },
  );
}

class _PawStepDialog extends StatefulWidget {
  const _PawStepDialog();

  @override
  State<_PawStepDialog> createState() => _PawStepDialogState();
}

class _PawStepDialogState extends State<_PawStepDialog> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..forward();

  @override
  void initState() {
    super.initState();
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Center(
      child: Material(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 22, 28, 20),
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '连接成功',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '喵～ 爪爪带你进曲库',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
                        ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 56,
                    width: 200,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        for (var i = 0; i < 4; i++)
                          _stepPaw(
                            index: i,
                            t: _c.value,
                            color: primary,
                          ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _stepPaw({required int index, required double t, required Color color}) {
    final start = index * 0.18;
    final local = ((t - start) / 0.35).clamp(0.0, 1.0);
    final appear = Curves.easeOut.transform(local);
    final x = -70.0 + index * 42.0;
    final y = (index.isEven ? -6.0 : 8.0) * (1 - appear) + math.sin(t * math.pi * 2 + index) * 2;
    return Positioned(
      left: 100 + x,
      top: 20 + y,
      child: Opacity(
        opacity: appear,
        child: Transform.rotate(
          angle: (index.isEven ? -1 : 1) * 0.28,
          child: Transform.scale(
            scale: 0.7 + 0.35 * appear,
            child: CatPawIcon(size: 26, color: color, opacity: 0.35 + 0.65 * appear),
          ),
        ),
      ),
    );
  }
}
