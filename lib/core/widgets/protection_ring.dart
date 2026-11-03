import 'package:flutter/material.dart';

/// Animated "x of y protections on" ring.
class ProtectionRing extends StatelessWidget {
  const ProtectionRing({
    super.key,
    required this.done,
    required this.total,
    this.size = 64,
    this.strokeWidth = 7,
    this.color,
    this.trackColor,
    this.label,
  });

  final int done;
  final int total;
  final double size;
  final double strokeWidth;
  final Color? color;
  final Color? trackColor;
  final Widget? label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ratio = total == 0 ? 0.0 : done / total;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: ratio),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) => SizedBox.square(
        dimension: size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CircularProgressIndicator(
              value: value,
              strokeWidth: strokeWidth,
              strokeCap: StrokeCap.round,
              color: color ?? scheme.primary,
              backgroundColor: trackColor ?? scheme.surfaceContainerHighest,
            ),
            Center(
              child:
                  label ??
                  Text(
                    '$done/$total',
                    style: Theme.of(context).textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
