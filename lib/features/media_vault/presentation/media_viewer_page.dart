import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:video_player/video_player.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../app/import_actions.dart';
import '../domain/media_item.dart';
import 'media_cubit.dart';
import 'vault_thumbnail.dart';

/// Full-screen secure viewer. Swipe between items, pinch to zoom, tap to
/// hide the controls.
class MediaViewerPage extends StatefulWidget {
  const MediaViewerPage({
    super.key,
    required this.ids,
    required this.initialIndex,
  });

  final List<String> ids;
  final int initialIndex;

  @override
  State<MediaViewerPage> createState() => _MediaViewerPageState();
}

class _MediaViewerPageState extends State<MediaViewerPage> {
  late final PageController _pages = PageController(
    initialPage: widget.initialIndex,
  );
  late int _index = widget.initialIndex;
  bool _chrome = true;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  List<MediaItem> _visible(List<MediaItem> all) {
    final byId = {for (final m in all) m.id: m};
    return [
      for (final id in widget.ids)
        if (byId[id] != null) byId[id]!,
    ];
  }

  Future<void> _delete(MediaItem item, int remaining) async {
    final media = context.read<MediaCubit>();
    final navigator = Navigator.of(context);
    if (!await confirmDelete(context, what: 'this ${item.type.name}')) return;
    await media.delete({item.id});
    if (remaining <= 1) navigator.pop();
  }

  Future<void> _export(MediaItem item) => exportMedia(context, [item]);

  void _showInfo(MediaItem item) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              _InfoRow('Type', item.mimeType),
              _InfoRow('Added', formatDate(item.createdAt)),
              _InfoRow('Size', formatBytes(item.sizeBytes)),
              if (item.width != null)
                _InfoRow('Dimensions', '${item.width} × ${item.height}'),
              const _InfoRow('Storage', 'Encrypted, only on this phone'),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _visible(context.watch<MediaCubit>().state.items);
    if (items.isEmpty) {
      return const Scaffold(backgroundColor: Colors.black);
    }
    final index = _index.clamp(0, items.length - 1);
    final current = items[index];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        extendBodyBehindAppBar: true,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: _Fade(
            visible: _chrome,
            child: AppBar(
              backgroundColor: Colors.black45,
              foregroundColor: Colors.white,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(current.title, style: const TextStyle(fontSize: 16)),
                  Text(
                    formatDate(current.createdAt),
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  tooltip: 'Details',
                  icon: const Icon(Icons.info_outline_rounded),
                  onPressed: () => _showInfo(current),
                ),
              ],
            ),
          ),
        ),
        body: GestureDetector(
          onTap: () => setState(() => _chrome = !_chrome),
          child: PageView.builder(
            controller: _pages,
            itemCount: items.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) => _MediaPage(item: items[i]),
          ),
        ),
        bottomNavigationBar: _Fade(
          visible: _chrome,
          child: Container(
            color: Colors.black45,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _ViewerAction(
                      icon: current.favorite
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      label: 'Favourite',
                      onTap: () =>
                          context.read<MediaCubit>().toggleFavorite(current.id),
                    ),
                    _ViewerAction(
                      icon: Icons.ios_share_rounded,
                      label: 'Export',
                      onTap: () => _export(current),
                    ),
                    _ViewerAction(
                      icon: Icons.delete_outline_rounded,
                      label: 'Delete',
                      onTap: () => _delete(current, items.length),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MediaPage extends StatelessWidget {
  const _MediaPage({required this.item});

  final MediaItem item;

  @override
  Widget build(BuildContext context) =>
      item.isVideo ? _VideoPage(item: item) : _PhotoPage(item: item);
}

/// Decrypts the full photo into memory; the thumbnail shows meanwhile.
class _PhotoPage extends StatefulWidget {
  const _PhotoPage({required this.item});

  final MediaItem item;

  @override
  State<_PhotoPage> createState() => _PhotoPageState();
}

class _PhotoPageState extends State<_PhotoPage> {
  late final Future<Uint8List> _original = context.read<MediaCubit>().original(
    widget.item.id,
  );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _original,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _ViewerMessage(
            icon: Icons.broken_image_outlined,
            text: "This photo couldn't be opened.",
          );
        }
        final bytes = snapshot.data;
        return InteractiveViewer(
          maxScale: 5,
          child: Center(
            child: AspectRatio(
              aspectRatio: widget.item.aspectRatio,
              child: bytes == null
                  ? VaultThumbnail(item: widget.item, borderRadius: 0)
                  : Image.memory(
                      bytes,
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                      errorBuilder: (_, _, _) => const _ViewerMessage(
                        icon: Icons.broken_image_outlined,
                        text:
                            "This format can't be shown here. Export it "
                            'to open it in another app.',
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }
}

/// Video players need a file, so the video is decrypted into the vault's
/// temp folder and deleted when the page closes (and on lock, at the
/// latest).
class _VideoPage extends StatefulWidget {
  const _VideoPage({required this.item});

  final MediaItem item;

  @override
  State<_VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<_VideoPage> {
  VideoPlayerController? _controller;
  File? _file;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    try {
      final file = await context.read<MediaCubit>().openVideo(widget.item.id);
      if (!mounted) {
        await file.delete();
        return;
      }
      _file = file;
      final controller = VideoPlayerController.file(file);
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);
    } on Exception {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _file?.delete().catchError((_) => _file!);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (_failed) {
      return const _ViewerMessage(
        icon: Icons.videocam_off_outlined,
        text:
            "This video can't be played here. Export it to open it in "
            'another app.',
      );
    }
    if (controller == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Center(
      child: AspectRatio(
        aspectRatio: controller.value.aspectRatio,
        child: Stack(
          alignment: Alignment.center,
          children: [
            VideoPlayer(controller),
            ValueListenableBuilder<VideoPlayerValue>(
              valueListenable: controller,
              builder: (context, value, _) => AnimatedOpacity(
                opacity: value.isPlaying ? 0 : 1,
                duration: const Duration(milliseconds: 200),
                child: IconButton.filled(
                  iconSize: 44,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black45,
                    foregroundColor: Colors.white,
                  ),
                  tooltip: value.isPlaying ? 'Pause' : 'Play',
                  icon: Icon(
                    value.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                  ),
                  onPressed: () =>
                      value.isPlaying ? controller.pause() : controller.play(),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: VideoProgressIndicator(controller, allowScrubbing: true),
            ),
          ],
        ),
      ),
    );
  }
}

class _ViewerMessage extends StatelessWidget {
  const _ViewerMessage({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white70, size: 48),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

class _Fade extends StatelessWidget {
  const _Fade({required this.visible, required this.child});

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 200),
        child: child,
      ),
    );
  }
}

class _ViewerAction extends StatelessWidget {
  const _ViewerAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 36,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, a) =>
                  ScaleTransition(scale: a, child: child),
              child: Icon(icon, key: ValueKey(icon), color: Colors.white),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
