import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/gradient_thumb.dart';
import '../domain/media_item.dart';
import 'media_cubit.dart';
import 'media_style.dart';

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

  Future<void> _export(MediaItem item) async {
    if (!await confirmExport(context, itemName: '"${item.title}"')) return;
    if (mounted) {
      showPreviewNotice(
        context,
        'Preview: export arrives with the media module.',
      );
    }
  }

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
              _InfoRow('Type', item.isVideo ? 'Video' : 'Photo'),
              _InfoRow('Album', item.album),
              _InfoRow('Added', formatDate(item.createdAt)),
              _InfoRow('Size', formatBytes(item.sizeBytes)),
              if (item.duration != null)
                _InfoRow('Length', formatDuration(item.duration!)),
              const _InfoRow('Storage', 'Only on this phone'),
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
  Widget build(BuildContext context) {
    final portrait = item.subject == MediaSubject.portrait;
    return InteractiveViewer(
      maxScale: 4,
      child: Center(
        child: AspectRatio(
          aspectRatio: portrait ? 3 / 4 : 4 / 3,
          child: Stack(
            fit: StackFit.expand,
            children: [
              GradientThumb(
                seed: item.seed,
                icon: item.isVideo ? null : item.subject.icon,
                borderRadius: 0,
                iconSize: 72,
              ),
              if (item.isVideo)
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                      color: Colors.black45,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      size: 44,
                      color: Colors.white,
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
