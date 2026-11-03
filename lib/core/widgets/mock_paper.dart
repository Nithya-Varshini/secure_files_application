import 'dart:math' as math;

import 'package:flutter/material.dart';

enum PaperTone { original, mono, enhanced }

/// A stylised sheet of paper standing in for scanned or PDF pages until real
/// rendering exists.
class MockPaper extends StatelessWidget {
  const MockPaper({
    super.key,
    required this.seed,
    this.tone = PaperTone.original,
    this.compact = false,
  });

  final int seed;
  final PaperTone tone;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final random = math.Random(seed);
    final (paper, ink) = switch (tone) {
      PaperTone.original => (const Color(0xFFF4EFE4), const Color(0xFF9A948A)),
      PaperTone.mono => (Colors.white, const Color(0xFF222222)),
      PaperTone.enhanced => (const Color(0xFFFDFDFD), const Color(0xFF4A4A4A)),
    };
    final lines = compact ? 6 : 14;

    return Container(
      decoration: BoxDecoration(
        color: paper,
        borderRadius: BorderRadius.circular(compact ? 4 : 8),
        boxShadow: compact
            ? null
            : const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 16,
                  offset: Offset(0, 6),
                ),
              ],
      ),
      padding: EdgeInsets.all(compact ? 6 : 20),
      child: ClipRect(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FractionallySizedBox(
                widthFactor: 0.55,
                child: Container(height: compact ? 3 : 10, color: ink),
              ),
              SizedBox(height: compact ? 4 : 16),
              for (var i = 0; i < lines; i++)
                Padding(
                  padding: EdgeInsets.only(bottom: compact ? 3 : 9),
                  child: FractionallySizedBox(
                    widthFactor: 0.55 + random.nextDouble() * 0.45,
                    child: Container(
                      height: compact ? 2 : 6,
                      decoration: BoxDecoration(
                        color: ink.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
