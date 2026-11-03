import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/di.dart';
import '../../../app/routes.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/buttons.dart';
import '../../files/presentation/files_cubit.dart';
import '../data/scan_camera.dart';
import '../domain/scan_page.dart';
import '../domain/scan_pdf.dart';

/// Capture pages, review them, and save one encrypted PDF. Pages stay in
/// memory; the camera's temporary JPEG is deleted as soon as it is read.
class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final ScanCamera _camera = getIt<ScanCamera>();
  final List<ScanPage> _pages = [];
  late final AnimationController _flash = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );
  final _reviewController = PageController();
  bool _cameraReady = false;
  String? _cameraError;
  bool _reviewing = false;
  bool _capturing = false;
  bool _saving = false;
  bool _torch = false;
  int _current = 0;
  int _nextId = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _camera.stop();
    _flash.dispose();
    _reviewController.dispose();
    super.dispose();
  }

  // Release the camera while the app is in the background.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _camera.stop();
      if (mounted) setState(() => _cameraReady = false);
    } else if (state == AppLifecycleState.resumed && !_reviewing) {
      _startCamera();
    }
  }

  Future<void> _startCamera() async {
    setState(() => _cameraError = null);
    try {
      await _camera.start();
      if (mounted) setState(() => _cameraReady = true);
    } on CameraUnavailableException catch (e) {
      if (mounted) {
        setState(
          () => _cameraError = e.reason == 'CameraAccessDenied'
              ? 'Camera access is off. Allow it in Settings to scan.'
              : "The camera couldn't start.",
        );
      }
    }
  }

  Future<void> _capture() async {
    if (_capturing || !_cameraReady) return;
    setState(() => _capturing = true);
    HapticFeedback.mediumImpact();
    _flash.forward(from: 0);
    try {
      final jpeg = await _camera.capture();
      if (mounted) {
        setState(() => _pages.add(ScanPage(id: _nextId++, jpeg: jpeg)));
      }
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("That photo didn't work. Try again.")),
        );
      }
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  void _openReview() {
    setState(() {
      _reviewing = true;
      _current = 0;
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
    final files = context.read<FilesCubit>();
    try {
      final pdf = await ScanPdf.build(_pages);
      await files.addScan(name: name, pdf: pdf);
      if (!mounted) return;
      context.go(Routes.files);
      messenger.showSnackBar(
        SnackBar(content: Text('"$name.pdf" encrypted and saved to Scans')),
      );
    } on Exception {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        const SnackBar(content: Text("The PDF couldn't be created.")),
      );
    }
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
    final scheme = Theme.of(context).colorScheme;
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
              onPressed: _cameraReady
                  ? () {
                      setState(() => _torch = !_torch);
                      _camera.setTorch(_torch);
                    }
                  : null,
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_cameraError != null)
                    _CameraError(message: _cameraError!, onRetry: _startCamera)
                  else if (!_cameraReady)
                    const Center(child: CircularProgressIndicator())
                  else
                    Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: _camera.buildPreview(),
                      ),
                    ),
                  if (_cameraReady)
                    Padding(
                      padding: const EdgeInsets.all(28),
                      child: CustomPaint(
                        painter: _ViewfinderPainter(scheme.primary),
                      ),
                    ),
                  if (_cameraReady)
                    const Positioned(
                      top: 8,
                      left: 0,
                      right: 0,
                      child: Center(child: _HintChip()),
                    ),
                  IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _flash,
                      builder: (context, _) => ColoredBox(
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
                      onTap: _pages.isEmpty ? null : _openReview,
                    ),
                    _ShutterButton(
                      enabled: _cameraReady && !_capturing,
                      onPressed: _capture,
                    ),
                    SizedBox(
                      width: 64,
                      child: TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _pages.isEmpty ? null : _openReview,
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
          onPressed: () {
            setState(() => _reviewing = false);
            _startCamera();
          },
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
                  padding: const EdgeInsets.fromLTRB(32, 16, 32, 8),
                  child: Center(
                    child: AnimatedRotation(
                      turns: _pages[i].quarterTurns / 4,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      child: _PageImage(page: _pages[i]),
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
                  onPressed: () {
                    setState(() => _reviewing = false);
                    _startCamera();
                  },
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
                    child: _PageImage(page: _pages[i], thumbnail: true),
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
}

/// Shows a page with its filter previewed live via a colour matrix; the
/// saved PDF applies the same filter for real with the image library.
class _PageImage extends StatelessWidget {
  const _PageImage({required this.page, this.thumbnail = false});

  final ScanPage page;
  final bool thumbnail;

  static const _grey = <double>[
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0, 0, 0, 1, 0,
  ];

  static List<double> _contrast(double c, double offset) => [
    c, 0, 0, 0, offset, //
    0, c, 0, 0, offset,
    0, 0, c, 0, offset,
    0, 0, 0, 1, 0,
  ];

  @override
  Widget build(BuildContext context) {
    Widget image = Image.memory(
      page.jpeg,
      fit: BoxFit.contain,
      cacheWidth: thumbnail ? 120 : null,
      gaplessPlayback: true,
    );
    switch (page.filter) {
      case ScanFilter.original:
        break;
      case ScanFilter.blackWhite:
        image = ColorFiltered(
          colorFilter: ColorFilter.matrix(_contrast(1.6, -60)),
          child: ColorFiltered(
            colorFilter: const ColorFilter.matrix(_grey),
            child: image,
          ),
        );
      case ScanFilter.enhanced:
        image = ColorFiltered(
          colorFilter: ColorFilter.matrix(_contrast(1.2, -10)),
          child: image,
        );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(thumbnail ? 4 : 8),
      child: image,
    );
  }
}

class _CameraError extends StatelessWidget {
  const _CameraError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.no_photography_outlined,
              color: Colors.white70,
              size: 56,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: onRetry,
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
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
      child: const Text(
        'Fit the page inside the corners',
        style: TextStyle(color: Colors.white, fontSize: 13),
      ),
    );
  }
}

class _ShutterButton extends StatefulWidget {
  const _ShutterButton({required this.enabled, required this.onPressed});

  final bool enabled;
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
      enabled: widget.enabled,
      label: 'Capture page',
      child: GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) {
          setState(() => _down = false);
          if (widget.enabled) widget.onPressed();
        },
        child: AnimatedOpacity(
          opacity: widget.enabled ? 1 : 0.4,
          duration: const Duration(milliseconds: 150),
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
    final scheme = Theme.of(context).colorScheme;
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
                      child: _PageImage(page: pages.last, thumbnail: true),
                    ),
                    Positioned(
                      right: -6,
                      top: -6,
                      child: CircleAvatar(
                        radius: 11,
                        backgroundColor: scheme.primary,
                        child: Text(
                          '${pages.length}',
                          style: TextStyle(
                            fontSize: 11,
                            color: scheme.onPrimary,
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
      [const Offset(0, length), Offset.zero, const Offset(length, 0)],
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
