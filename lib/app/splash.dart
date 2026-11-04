import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Cold-start splash drawn over the app: the two arches of the Kwam icon draw
/// themselves, a soft glow blooms behind them, the name fades in, then the
/// whole splash fades away to reveal the app (normally the lock screen).
///
/// It sits above the router, so navigation and the auth guard are untouched,
/// and it never shows again while the process lives. The native splash before
/// it uses the same [background] with no icon, so the hand-off has no jump.
class SplashOverlay extends StatefulWidget {
  const SplashOverlay({super.key, required this.child});

  final Widget child;

  /// Same as `@color/splash_background` on Android.
  static const background = Color(0xFF0B0820);

  @override
  State<SplashOverlay> createState() => _SplashOverlayState();
}

class _SplashOverlayState extends State<SplashOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _done = true);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller.isAnimating || _done) return;
    // Respect "remove animations": show the finished mark briefly instead.
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller
        ..value = 0.8
        ..animateTo(1, duration: const Duration(milliseconds: 400));
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_done) return widget.child;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        AbsorbPointer(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => _SplashFrame(t: _controller.value),
          ),
        ),
      ],
    );
  }
}

/// One frame of the splash at progress [t] (0..1 over 2.2 s).
class _SplashFrame extends StatelessWidget {
  const _SplashFrame({required this.t});

  final double t;

  /// Progress of the sub-animation that runs from [start] to [end] (in t).
  double _phase(double start, double end, [Curve curve = Curves.linear]) =>
      curve.transform(((t - start) / (end - start)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    final outer = _phase(0.0, 0.36, Curves.easeInOutCubic);
    final inner = _phase(0.12, 0.46, Curves.easeInOutCubic);
    final glow = _phase(0.36, 0.62, Curves.easeOut);
    final word = _phase(0.44, 0.66, Curves.easeOutCubic);
    final exit = _phase(0.84, 1.0, Curves.easeIn);
    final shortest = MediaQuery.sizeOf(context).shortestSide;
    final markSize = math.min(shortest * 0.42, 190.0);

    return Opacity(
      opacity: 1 - exit,
      child: ColoredBox(
        color: SplashOverlay.background,
        child: Center(
          child: Transform.scale(
            // A gentle settle while drawing, then a slight lift as it leaves.
            scale: 0.94 + 0.06 * Curves.easeOut.transform(outer) + 0.04 * exit,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox.square(
                  dimension: markSize,
                  child: CustomPaint(
                    painter: _ArchesPainter(
                      outer: outer,
                      inner: inner,
                      glow: glow,
                    ),
                  ),
                ),
                SizedBox(height: markSize * 0.16),
                Opacity(
                  opacity: word,
                  child: Transform.translate(
                    offset: Offset(0, 12 * (1 - word)),
                    child: ShaderMask(
                      shaderCallback: (rect) => const LinearGradient(
                        colors: [Color(0xFFE9E3FF), Color(0xFFA9B4FF)],
                      ).createShader(rect),
                      child: Text(
                        'Kwam',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: markSize * 0.2,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2 + 6 * (1 - word),
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
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

/// Draws the arches as stroked paths so they can be "drawn" by trimming:
/// up the left leg, over the top, down the right leg. Geometry and colours
/// follow the launcher icon (tool/generate_icon.dart), in its 108-unit space.
class _ArchesPainter extends CustomPainter {
  _ArchesPainter({
    required this.outer,
    required this.inner,
    required this.glow,
  });

  final double outer, inner, glow;

  // Visible window of the 108-unit icon canvas.
  static const _from = 28.0, _span = 52.0;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / _span;
    canvas
      ..save()
      ..scale(s)
      ..translate(-_from, -_from);

    if (glow > 0) {
      const centre = Offset(54, 60);
      canvas.drawCircle(
        centre,
        30,
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFF6D4FE0).withValues(alpha: 0.45 * glow),
              const Color(0x006D4FE0),
            ],
          ).createShader(Rect.fromCircle(center: centre, radius: 30)),
      );
    }

    _arch(
      canvas,
      centre: const Offset(54, 55.24),
      radius: 18.85,
      width: 7.5,
      bottom: 75.36,
      progress: outer,
      colors: const [Color(0xFFA48AF2), Color(0xFF6A47D6), Color(0xFF3F4AB8)],
    );
    _arch(
      canvas,
      centre: const Offset(54, 58.9),
      radius: 9.28,
      width: 5.76,
      bottom: 75.36,
      progress: inner,
      colors: const [Color(0xFF4A2CA6), Color(0xFF5B45CF), Color(0xFF7E8DF0)],
    );
    canvas.restore();
  }

  void _arch(
    Canvas canvas, {
    required Offset centre,
    required double radius,
    required double width,
    required double bottom,
    required double progress,
    required List<Color> colors,
  }) {
    if (progress <= 0) return;
    final path = Path()
      ..moveTo(centre.dx - radius, bottom)
      ..lineTo(centre.dx - radius, centre.dy)
      ..arcTo(
        Rect.fromCircle(center: centre, radius: radius),
        math.pi,
        math.pi,
        false,
      )
      ..lineTo(centre.dx + radius, bottom);
    final metric = path.computeMetrics().first;
    final bounds = Rect.fromLTRB(
      centre.dx - radius - width,
      centre.dy - radius - width,
      centre.dx + radius + width,
      bottom,
    );
    canvas.drawPath(
      metric.extractPath(0, metric.length * progress),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.butt
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ).createShader(bounds),
    );
  }

  @override
  bool shouldRepaint(_ArchesPainter old) =>
      old.outer != outer || old.inner != inner || old.glow != glow;
}
