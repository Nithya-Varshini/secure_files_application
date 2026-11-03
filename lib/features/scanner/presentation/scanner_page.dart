import 'dart:math';

import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/mock_paper.dart';
import '../../files/presentation/files_cubit.dart';
import '../domain/scan_page.dart';

/// Capture pages, review them, and save one encrypted PDF.
///
/// PREVIEW: the viewfinder is simulated; CameraX replaces it in Module E.
/// Pages never touch the public gallery (threat model L7).
class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage>
    with TickerProviderStateMixin {
  final _random = Random();
  final List<ScanPage> _pages = [];
  late final AnimationController _flash = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );
  late final AnimationController _scanLine = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat(reverse: true);
  final _reviewController = PageController();
  bool _reviewing = false;
  bool _saving = false;
  bool _torch = false;
  int _current = 0;
  int _nextId = 0;

  @override
  void dispose() {
    _flash.dispose();
    _scanLine.dispose();
    _reviewController.dispose();
    super.dispose();
  }

  void _capture() {
    HapticFeedback.mediumImpact();
    _flash.forward(from: 0);
    setState(() {
      _pages.add(ScanPage(id: _nextId++, seed: _random.nextInt(1 << 20)));
    });
  }

  void _updateCurrent(ScanPage Function(ScanPage) change) =>
      setState(() => _pages[_current] = change(_pages[_current]));

  void _removeCurrent() {
    setState(() {
      _pages.removeAt(_current);
      if (_pages.isEmpty) {
        _reviewing = false;
        _current = 0;
      } else {
        _current = _current.clamp(0, _pages.length - 1);
      }
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final name = 'Scan ${formatDate(DateTime.now())}';
    final messenger = ScaffoldMessenger.of(context);
    await context.read<FilesCubit>().addScan(
      name: name,
      pageCount: _pages.length,
    );
    if (!mounted) return;
    context.go(Routes.files);
    messenger.showSnackBar(
      SnackBar(content: Text('"$name.pdf" encrypted and saved to Scans')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PageTransitionSwitcher(
      duration: const Duration(milliseconds: 450),
      transitionBuilder: (child, animation, secondary) => SharedAxisTransition(
        animation: animation,
        secondaryAnimation: secondary,
        transitionType: SharedAxisTransitionType.horizontal,
        child: child,
      ),
      child: _reviewing ? _buildReview(context) : _buildCapture(context),
    );
  }

  Widget _buildCapture(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      key: const ValueKey('capture'),
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF0B0B0F),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          title: const Text('Scan document'),
          actions: [
            IconButton(
              tooltip: _torch ? 'Torch off' : 'Torch on',
              icon: Icon(
                _torch ? Icons.flash_on_rounded : Icons.flash_off_rounded,
              ),
              onPressed: () => setState(() => _torch = !_torch),
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(36),
                      child: AspectRatio(
                        aspectRatio: 0.72,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Transform.rotate(
                              angle: -0.03,
                              child: Opacity(
                                opacity: 0.85,
                                child: MockPaper(seed: _nextId * 31 + 7),
                              ),
                            ),
                            CustomPaint(
                              painter: _ViewfinderPainter(
                                Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            AnimatedBuilder(
                              animation: _scanLine,
                              builder: (context, _) => Align(
                                alignment: Alignment(
                                  0,
                                  -1 + 2 * _scanLine.value,
                                ),
                                child: Container(
                                  height: 2,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    boxShadow: [
                                      BoxShadow(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                        blurRadius: 12,
                                      ),
                                    ],
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primaryContainer,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Positioned(
                    top: 8,
                    left: 0,
                    right: 0,
                    child: Center(child: _HintChip()),
                  ),
                  IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _flash,
                      builder: (context, _) => Container(
                        color: Colors.white.withValues(
                          alpha: _flash.isAnimating ? 1 - _flash.value : 0,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _PagesThumb(
                      pages: _pages,
                      onTap: _pages.isEmpty
                          ? null
                          : () => setState(() => _reviewing = true),
                    ),
                    _ShutterButton(onPressed: _capture),
                    SizedBox(
                      width: 64,
                      child: TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _pages.isEmpty
                            ? null
                            : () => setState(() => _reviewing = true),
                        child: const Text('Done'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReview(BuildContext context) {
    final theme = Theme.of(context);
    final page = _pages[_current.clamp(0, _pages.length - 1)];
    return Scaffold(
      key: const ValueKey('review'),
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back to camera',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => setState(() => _reviewing = false),
        ),
        title: Text(
          _pages.length == 1
              ? 'Review 1 page'
              : 'Review ${_pages.length} pages',
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _reviewController,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _current = i),
                itemBuilder: (context, i) => Padding(
                  padding: const EdgeInsets.fromLTRB(40, 16, 40, 8),
                  child: Center(
                    child: AnimatedRotation(
                      turns: _pages[i].quarterTurns / 4,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      child: AspectRatio(
                        aspectRatio: 0.72,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: MockPaper(
                            key: ValueKey(_pages[i].filter),
                            seed: _pages[i].seed,
                            tone: _toneFor(_pages[i].filter),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Text(
              'Page ${_current + 1} of ${_pages.length}',
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: 12),
            SegmentedButton<ScanFilter>(
              segments: const [
                ButtonSegment(
                  value: ScanFilter.original,
                  label: Text('Original'),
                ),
                ButtonSegment(value: ScanFilter.blackWhite, label: Text('B&W')),
                ButtonSegment(
                  value: ScanFilter.enhanced,
                  label: Text('Enhance'),
                ),
              ],
              selected: {page.filter},
              onSelectionChanged: (s) =>
                  _updateCurrent((p) => p.copyWith(filter: s.first)),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.filledTonal(
                  tooltip: 'Rotate',
                  icon: const Icon(Icons.rotate_right_rounded),
                  onPressed: () => _updateCurrent(
                    (p) => p.copyWith(quarterTurns: p.quarterTurns + 1),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton.filledTonal(
                  tooltip: 'Add a page',
                  icon: const Icon(Icons.add_a_photo_outlined),
                  onPressed: () => setState(() => _reviewing = false),
                ),
                const SizedBox(width: 12),
                IconButton.filledTonal(
                  tooltip: 'Remove this page',
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: _removeCurrent,
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 76,
              child: ReorderableListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _pages.length,
                // onReorderItem already adjusts newIndex for the removed item.
                onReorderItem: (oldIndex, newIndex) => setState(() {
                  _pages.insert(newIndex, _pages.removeAt(oldIndex));
                }),
                itemBuilder: (context, i) => GestureDetector(
                  key: ValueKey(_pages[i].id),
                  onTap: () => _reviewController.animateToPage(
                    i,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 50,
                    margin: const EdgeInsets.all(4),
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: i == _current
                            ? theme.colorScheme.primary
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: MockPaper(
                      seed: _pages[i].seed,
                      tone: _toneFor(_pages[i].filter),
                      compact: true,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: PrimaryButton(
                label: _saving ? 'Encrypting…' : 'Save as encrypted PDF',
                icon: Icons.lock_outline_rounded,
                onPressed: _saving ? null : _save,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static PaperTone _toneFor(ScanFilter filter) => switch (filter) {
    ScanFilter.original => PaperTone.original,
    ScanFilter.blackWhite => PaperTone.mono,
    ScanFilter.enhanced => PaperTone.enhanced,
  };
}

class _HintChip extends StatelessWidget {
  const _HintChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: Color(0xFF4ADE80)),
          SizedBox(width: 8),
          Text(
            'Edges found. Hold steady',
            style: TextStyle(color: Colors.white, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _ShutterButton extends StatefulWidget {
  const _ShutterButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_ShutterButton> createState() => _ShutterButtonState();
}

class _ShutterButtonState extends State<_ShutterButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Capture page',
      child: GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) {
          setState(() => _down = false);
          widget.onPressed();
        },
        child: AnimatedScale(
          scale: _down ? 0.88 : 1,
          duration: const Duration(milliseconds: 120),
          child: Container(
            width: 78,
            height: 78,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white70, width: 4),
            ),
            child: const DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PagesThumb extends StatelessWidget {
  const _PagesThumb({required this.pages, required this.onTap});

  final List<ScanPage> pages;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 72,
      child: pages.isEmpty
          ? null
          : GestureDetector(
              onTap: onTap,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, a) =>
                    ScaleTransition(scale: a, child: child),
                child: Stack(
                  key: ValueKey(pages.length),
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: MockPaper(seed: pages.last.seed, compact: true),
                    ),
                    Positioned(
                      right: -6,
                      top: -6,
                      child: CircleAvatar(
                        radius: 11,
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        child: Text(
                          '${pages.length}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.onPrimary,
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

class _ViewfinderPainter extends CustomPainter {
  _ViewfinderPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const length = 28.0;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final w = size.width;
    final h = size.height;
    final corners = [
      [Offset(0, length), Offset.zero, const Offset(length, 0)],
      [Offset(w - length, 0), Offset(w, 0), Offset(w, length)],
      [Offset(w, h - length), Offset(w, h), Offset(w - length, h)],
      [Offset(length, h), Offset(0, h), Offset(0, h - length)],
    ];
    for (final c in corners) {
      canvas.drawPath(
        Path()
          ..moveTo(c[0].dx, c[0].dy)
          ..lineTo(c[1].dx, c[1].dy)
          ..lineTo(c[2].dx, c[2].dy),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ViewfinderPainter oldDelegate) =>
      oldDelegate.color != color;
}
