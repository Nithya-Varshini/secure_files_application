import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Cold-start splash drawn over the app: light falls in from the top-left and
/// the two arches of the Kwam icon zoom in one after the other, then the
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
    final light = _phase(0.0, 0.5, Curves.easeOut);
    // The inner arch follows the outer one, which reads as depth.
    final outer = _phase(0.0, 0.45, Curves.easeOutCubic);
    final inner = _phase(0.1, 0.55, Curves.easeOutCubic);
    final exit = _phase(0.82, 1.0, Curves.easeInCubic);
    final shortest = MediaQuery.sizeOf(context).shortestSide;
    final markSize = math.min(shortest * 0.42, 190.0);

    return Opacity(
      opacity: 1 - exit,
      child: ColoredBox(
        color: SplashOverlay.background,
        child: DecoratedBox(
          decoration: BoxDecoration(
            // Light falling in from the top-left corner, as on the icon.
            gradient: RadialGradient(
              center: const Alignment(-1.1, -1.1),
              radius: 1.4,
              colors: [
                const Color(0xFF6D4FE0).withValues(alpha: 0.55 * light),
                const Color(0xFF3B2A8F).withValues(alpha: 0.2 * light),
                const Color(0x003B2A8F),
              ],
              stops: const [0, 0.4, 1],
            ),
          ),
          child: Center(
            child: Transform.scale(
              // On the way out the mark keeps zooming towards the viewer.
              scale: 1 + 0.25 * exit,
              child: SizedBox.square(
                dimension: markSize,
                child: CustomPaint(
                  painter: _ArchesPainter(outer: outer, inner: inner),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Draws the two arches, each zooming in from 55 % to full size while it
/// fades in. Geometry and colours follow the launcher icon
/// (tool/generate_icon.dart), in its 108-unit space, lit from the top-left.
class _ArchesPainter extends CustomPainter {
  _ArchesPainter({required this.outer, required this.inner});

  /// Entrance progress of each arch, 0..1.
  final double outer, inner;

  // Visible window of the 108-unit icon canvas, and the zoom centre.
  static const _from = 28.0, _span = 52.0;
  static const _centre = Offset(54, 54);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / _span;
    canvas
      ..save()
      ..scale(s)
      ..translate(-_from, -_from);
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
    final bounds = Rect.fromLTRB(
      centre.dx - radius - width,
      centre.dy - radius - width,
      centre.dx + radius + width,
      bottom,
    );
    final zoom = 0.55 + 0.45 * progress;
    canvas
      ..save()
      ..translate(_centre.dx, _centre.dy)
      ..scale(zoom)
      ..translate(-_centre.dx, -_centre.dy);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.butt
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            for (final c in colors)
              c.withValues(alpha: math.min(1, progress * 1.6)),
          ],
        ).createShader(bounds),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ArchesPainter old) =>
      old.outer != outer || old.inner != inner;
}
