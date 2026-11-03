import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/import_actions.dart';
import '../../../core/state/load_status.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/gradient_thumb.dart';
import '../../../core/widgets/skeleton.dart';
import '../domain/media_item.dart';
import 'media_cubit.dart';
import 'media_style.dart';
import 'media_viewer_page.dart';

enum _Filter {
  all('All'),
  photos('Photos'),
  videos('Videos'),
  favourites('Favourites');

  const _Filter(this.label);
  final String label;

  bool matches(MediaItem m) => switch (this) {
    _Filter.all => true,
    _Filter.photos => !m.isVideo,
    _Filter.videos => m.isVideo,
    _Filter.favourites => m.favorite,
  };
}

class GalleryPage extends StatefulWidget {
  const GalleryPage({super.key});

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  _Filter _filter = _Filter.all;
  final Set<String> _selected = {};

  bool get _selecting => _selected.isNotEmpty;

  void _toggle(String id) => setState(() {
    if (!_selected.remove(id)) _selected.add(id);
  });

  Future<void> _deleteSelected() async {
    final count = _selected.length;
    final media = context.read<MediaCubit>();
    final messenger = ScaffoldMessenger.of(context);
    if (!await confirmDelete(context, what: '$count items')) return;
    await media.delete({..._selected});
    setState(_selected.clear);
    messenger.showSnackBar(SnackBar(content: Text('$count items deleted')));
  }

  Future<void> _exportSelected() async {
    final count = _selected.length;
    if (!await confirmExport(context, itemName: '$count items')) return;
    if (!mounted) return;
    showPreviewNotice(
      context,
      'Preview: export arrives with the media module.',
    );
    setState(_selected.clear);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MediaCubit>().state;
    final items = state.items.where(_filter.matches).toList();

    return PopScope(
      canPop: !_selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(_selected.clear);
      },
      child: Scaffold(
        appBar: _selecting
            ? AppBar(
                leading: IconButton(
                  tooltip: 'Cancel selection',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => setState(_selected.clear),
                ),
                title: Text('${_selected.length} selected'),
                actions: [
                  IconButton(
                    tooltip: 'Export',
                    icon: const Icon(Icons.ios_share_rounded),
                    onPressed: _exportSelected,
                  ),
                  IconButton(
                    tooltip: 'Delete',
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: _deleteSelected,
                  ),
                ],
              )
            : AppBar(title: const Text('Gallery')),
        body: Column(
          children: [
            SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final f in _Filter.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(f.label),
                        selected: _filter == f,
                        onSelected: (_) => setState(() => _filter = f),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: switch (state.status) {
                  LoadStatus.ready when items.isEmpty => EmptyState(
                    key: const ValueKey('empty'),
                    icon: Icons.photo_library_outlined,
                    title: _filter == _Filter.all
                        ? 'No photos yet'
                        : 'Nothing here',
                    message: _filter == _Filter.favourites
                        ? 'Tap the heart on any photo to see it here.'
                        : 'Import photos and videos to keep them private.',
                  ),
                  LoadStatus.ready => GridView.builder(
                    key: ValueKey(_filter),
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 4,
                          crossAxisSpacing: 4,
                        ),
                    itemCount: items.length,
                    itemBuilder: (context, i) => _MediaTile(
                      item: items[i],
                      index: i,
                      ids: [for (final m in items) m.id],
                      selecting: _selecting,
                      selected: _selected.contains(items[i].id),
                      onToggle: () => _toggle(items[i].id),
                    ),
                  ),
                  _ => const _GridSkeleton(),
                },
              ),
            ),
          ],
        ),
        floatingActionButton: AnimatedScale(
          scale: _selecting ? 0 : 1,
          duration: const Duration(milliseconds: 200),
          child: FloatingActionButton.extended(
            onPressed: () => runImport(context, ImportSource.photos),
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: const Text('Import'),
          ),
        ),
      ),
    );
  }
}

class _MediaTile extends StatelessWidget {
  const _MediaTile({
    required this.item,
    required this.index,
    required this.ids,
    required this.selecting,
    required this.selected,
    required this.onToggle,
  });

  final MediaItem item;
  final int index;
  final List<String> ids;
  final bool selecting;
  final bool selected;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Staggered entrance: each tile fades in slightly after the previous.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 250 + (index.clamp(0, 15) * 35)),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.scale(scale: 0.92 + 0.08 * t, child: child),
      ),
      child: OpenContainer(
        tappable: false,
        closedElevation: 0,
        openElevation: 0,
        closedColor: Colors.transparent,
        openColor: Colors.black,
        middleColor: Colors.black,
        closedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        transitionDuration: const Duration(milliseconds: 450),
        openBuilder: (context, _) =>
            MediaViewerPage(ids: ids, initialIndex: index),
        closedBuilder: (context, open) => GestureDetector(
          onTap: selecting ? onToggle : open,
          onLongPress: onToggle,
          child: AnimatedScale(
            scale: selected ? 0.86 : 1,
            duration: const Duration(milliseconds: 180),
            child: Stack(
              fit: StackFit.expand,
              children: [
                GradientThumb(
                  seed: item.seed,
                  icon: item.subject.icon,
                  borderRadius: 10,
                ),
                if (item.isVideo)
                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: _VideoBadge(duration: item.duration!),
                  ),
                if (item.favorite)
                  const Positioned(
                    left: 6,
                    top: 6,
                    child: Icon(
                      Icons.favorite_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                if (selecting)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected ? scheme.primary : Colors.black26,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: selected
                          ? Icon(
                              Icons.check_rounded,
                              size: 14,
                              color: scheme.onPrimary,
                            )
                          : null,
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

class _VideoBadge extends StatelessWidget {
  const _VideoBadge({required this.duration});

  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.play_arrow_rounded, size: 14, color: Colors.white),
          Text(
            formatDuration(duration),
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _GridSkeleton extends StatelessWidget {
  const _GridSkeleton();

  @override
  Widget build(BuildContext context) {
    return Pulse(
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
        ),
        itemCount: 15,
        itemBuilder: (context, _) => const SkeletonBox(radius: 10),
      ),
    );
  }
}
