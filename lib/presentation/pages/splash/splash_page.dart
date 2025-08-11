import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key, this.duration = const Duration(milliseconds: 3200)});

  final Duration duration; // keep in sync with splashHoldProvider in main.dart

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  // Title animations
  late final Animation<double> _titleOpacity;
  late final Animation<Offset> _titleOffset;

  // Logo settle scale
  late final Animation<double> _logoScale;

  // Underline sweep (0..1)
  late final Animation<double> _lineProgress;

  // Iris reveal radius factor (0..1)
  late final Animation<double> _iris;

  // Ambient glow (0..1)
  late final Animation<double> _glow;

  // Grid, squares, dots
  late final Animation<double> _gridOpacity;
  late final Animation<double> _squaresProgress;
  late final Animation<double> _dotsProgress;

  late final List<Offset> _dotSeeds;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)..forward();

    const curve = Curves.easeOutCubic;
    // Title enters quickly
    _titleOpacity = CurvedAnimation(parent: _controller, curve: const Interval(0.06, 0.32, curve: curve));
    _titleOffset = Tween<Offset>(begin: const Offset(0, 0.10), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: const Interval(0.06, 0.32, curve: curve)));

    _logoScale = Tween<double>(begin: 0.95, end: 1.0)
        .animate(CurvedAnimation(parent: _controller, curve: const Interval(0.38, 0.62, curve: curve)));

    _lineProgress = CurvedAnimation(parent: _controller, curve: const Interval(0.42, 0.75, curve: curve));
    _iris = CurvedAnimation(parent: _controller, curve: const Interval(0.76, 1.0, curve: curve));
    _glow = CurvedAnimation(parent: _controller, curve: const Interval(0.00, 0.50, curve: Curves.easeOut));
    _gridOpacity = CurvedAnimation(parent: _controller, curve: const Interval(0.06, 0.32, curve: curve));
    _squaresProgress = CurvedAnimation(parent: _controller, curve: const Interval(0.20, 0.55, curve: curve));
    _dotsProgress = CurvedAnimation(parent: _controller, curve: const Interval(0.45, 0.75, curve: curve));

    final rnd = math.Random(9);
    _dotSeeds = List.generate(12, (_) => Offset(rnd.nextDouble(), rnd.nextDouble()));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Use container pair for guaranteed contrast across light/dark
    final bg = theme.colorScheme.primaryContainer;
    final fg = theme.colorScheme.onPrimaryContainer;
    final overlayStyle = ThemeData.estimateBrightnessForColor(bg) == Brightness.dark
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark;

    // reserved for potential future tweaks

    return Scaffold(
      backgroundColor: bg,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: overlayStyle,
        child: LayoutBuilder(builder: (context, constraints) {
          final width = constraints.maxWidth;
          final lineWidth = math.min(160.0, math.max(90.0, width * 0.42));

          return AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return Stack(children: [
          // Minimal grid background
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _GridPainter(opacity: _gridOpacity.value, isLight: theme.brightness == Brightness.light),
              ),
            ),
          ),
          // Ambient glow as overlay (doesn't affect layout)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _GlowPainter(
                  progress: _glow.value,
                  baseColor: theme.colorScheme.primary,
                  isLight: ThemeData.estimateBrightnessForColor(bg) == Brightness.light,
                ),
              ),
            ),
          ),
          // Center stack
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FadeTransition(
                  opacity: _titleOpacity,
                  child: SlideTransition(
                    position: _titleOffset,
                    child: ScaleTransition(
                      scale: _logoScale,
                      child: Builder(builder: (context) {
                        final w = constraints.maxWidth;
                        final fontSize = (w * 0.12).clamp(28.0, 40.0);
                        final ls = (fontSize / 12).clamp(2.0, 4.0);
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Concentric minimalist squares
                            SizedBox(
                              width: fontSize * 3.2,
                              height: fontSize * 3.2,
                              child: CustomPaint(
                                painter: _LogoSquaresPainter(
                                  progress: _squaresProgress.value,
                                  strokeColor: fg,
                                ),
                              ),
                            ),
                            const SizedBox(height: 28),
                            Text(
                              'IQRA',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: ls,
                                        color: fg,
                                        fontSize: fontSize,
                                      ) ??
                                      TextStyle(
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: ls,
                                        color: fg,
                                        fontSize: fontSize,
                                      ),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Underline sweep
                SizedBox(
                  height: 1,
                  width: lineWidth,
                  child: CustomPaint(
                    painter: _HairlinePainter(
                      progress: _lineProgress.value,
                      color: fg,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Floating dots
                SizedBox(
                  width: lineWidth,
                  height: 40,
                  child: CustomPaint(
                    painter: _DotsPainter(
                      progress: _dotsProgress.value,
                      seeds: _dotSeeds,
                      color: fg,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Iris reveal overlay
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _IrisPainter(progress: _iris.value, color: bg),
              ),
            ),
          ),
              ]);
            },
          );
        }),
      ),
    );
  }

}

class _IrisPainter extends CustomPainter {
  const _IrisPainter({required this.progress, required this.color});
  final double progress; // 0..1
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    // Draw a radial mask-like overlay that expands, then fades
    final paint = Paint()..color = color;
    final rect = Offset.zero & size;
    final radius = (size.longestSide * 0.9) * progress * 1.2;

    // Draw background then clear circle using destinationOut
    canvas.saveLayer(rect, Paint());
    canvas.drawRect(rect, paint);
    final clear = Paint()..blendMode = BlendMode.clear;
    canvas.drawCircle(size.center(Offset.zero), radius, clear);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _IrisPainter oldDelegate) => oldDelegate.progress != progress || oldDelegate.color != color;
}

class _GlowPainter extends CustomPainter {
  const _GlowPainter({required this.progress, required this.baseColor, required this.isLight});
  final double progress; // 0..1
  final Color baseColor;
  final bool isLight;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final center = size.center(Offset.zero);
    final radius = size.shortestSide * (0.40 + 0.25 * progress);
    HSLColor hsl = HSLColor.fromColor(baseColor);
    final inner = hsl.withLightness((isLight ? 0.66 : 0.48)).toColor().withValues(alpha: 0.35 * progress);
    final mid = hsl.withLightness((isLight ? 0.58 : 0.40)).toColor().withValues(alpha: 0.22 * progress);
    final outer = hsl.withLightness((isLight ? 0.50 : 0.32)).toColor().withValues(alpha: 0.0);
    final gradient = RadialGradient(colors: [inner, mid, outer], stops: const [0.0, 0.55, 1.0]);
    final paint = Paint()..shader = gradient.createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _GlowPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.baseColor != baseColor || oldDelegate.isLight != isLight;
}

class _HairlinePainter extends CustomPainter {
  const _HairlinePainter({required this.progress, required this.color});
  final double progress; // 0..1
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = progress.clamp(0.0, 1.0);
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final y = size.height / 2;
    canvas.drawLine(Offset(0, y), Offset(size.width * p, y), paint);
  }

  @override
  bool shouldRepaint(covariant _HairlinePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

class _GridPainter extends CustomPainter {
  const _GridPainter({required this.opacity, required this.isLight});
  final double opacity;
  final bool isLight;

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0) return;
    final color = (isLight ? const Color(0xFF000000) : const Color(0xFFFFFFFF)).withValues(alpha: 0.06 * opacity);
    final paint = Paint()..color = color;
    const step = 20.0;
    for (double x = 0; x <= size.width; x += step) {
      canvas.drawRect(Rect.fromLTWH(x, 0, 1, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) => oldDelegate.opacity != opacity || oldDelegate.isLight != isLight;
}

class _LogoSquaresPainter extends CustomPainter {
  const _LogoSquaresPainter({required this.progress, required this.strokeColor});
  final double progress; // 0..1
  final Color strokeColor;

  @override
  void paint(Canvas canvas, Size size) {
    final p = progress.clamp(0.0, 1.0);
    final center = size.center(Offset.zero);
    final stroke = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    // Draw 4 concentric squares with staggered alpha/scale
    for (int i = 0; i < 4; i++) {
      final tStart = i * 0.08;
      final t = ((p - tStart) / 0.32).clamp(0.0, 1.0);
      if (t <= 0) continue;
      final scale = 0.5 + 0.12 * i;
      final sizeEdge = size.shortestSide * scale * (0.9 + 0.1 * t);
      final rect = Rect.fromCenter(center: center, width: sizeEdge, height: sizeEdge);
      final alpha = (0.25 + 0.75 * t) * (1.0 - i * 0.08);
      canvas.drawRect(rect, stroke..color = strokeColor.withValues(alpha: alpha));
    }
  }

  @override
  bool shouldRepaint(covariant _LogoSquaresPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.strokeColor != strokeColor;
}

class _DotsPainter extends CustomPainter {
  const _DotsPainter({required this.progress, required this.seeds, required this.color});
  final double progress; // 0..1
  final List<Offset> seeds; // 0..1 normalized positions
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final paint = Paint()..color = color;
    for (int i = 0; i < seeds.length; i++) {
      final s = seeds[i];
      final appearT = (i / seeds.length) * 0.6;
      final t = ((progress - appearT) / 0.4).clamp(0.0, 1.0);
      if (t <= 0) continue;
      final x = s.dx * size.width;
      final y = s.dy * size.height;
      final r = 2.0 + 1.5 * t;
      final alpha = 0.2 + 0.6 * t;
      canvas.drawCircle(Offset(x, y - 6 * (1 - t)), r, paint..color = color.withValues(alpha: alpha));
    }
  }

  @override
  bool shouldRepaint(covariant _DotsPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.seeds != seeds || oldDelegate.color != color;
}
