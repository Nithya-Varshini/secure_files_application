import 'package:flutter/material.dart';

/// Placeholder artwork for sample media: a gradient derived from [seed].
/// Real decrypted thumbnails replace this in the media module.
class GradientThumb extends StatelessWidget {
  const GradientThumb({
    super.key,
    required this.seed,
    this.icon,
    this.borderRadius = 16,
    this.iconSize = 28,
  });

  final int seed;
  final IconData? icon;
  final double borderRadius;
  final double iconSize;

  static List<Color> colorsFor(int seed) {
    final hue = (seed * 47) % 360;
    return [
      HSLColor.fromAHSL(1, hue.toDouble(), 0.55, 0.62).toColor(),
      HSLColor.fromAHSL(1, ((hue + 40) % 360).toDouble(), 0.6, 0.42).toColor(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colorsFor(seed),
        ),
      ),
      child: SizedBox.expand(
        child: icon == null
            ? null
            : Icon(
                icon,
                size: iconSize,
                color: Colors.white.withValues(alpha: 0.85),
              ),
      ),
    );
  }
}
