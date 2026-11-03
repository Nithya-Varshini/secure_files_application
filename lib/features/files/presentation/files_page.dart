import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/import_actions.dart';
import '../../../app/routes.dart';
import '../../../core/state/load_status.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/skeleton.dart';
import '../domain/vault_file.dart';
import 'file_kind_style.dart';
import 'files_cubit.dart';

enum _Sort {
  date('Date modified'),
  name('Name'),
  size('Size');

  const _Sort(this.label);
  final String label;
}

class FilesPage extends StatefulWidget {
  const FilesPage({super.key});

  @override
  State<FilesPage> createState() => _FilesPageState();
}

class _FilesPageState extends State<FilesPage> {
  final _search = TextEditingController();
  String? _folder;
  _Sort _sort = _Sort.date;
  bool _searching = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<VaultFile> _visible(List<VaultFile> files) {
    final query = _search.text.trim().toLowerCase();
    final list = files
        .where((f) => _folder == null || f.folder == _folder)
        .where((f) => query.isEmpty || f.name.toLowerCase().contains(query))
        .toList();
    switch (_sort) {
      case _Sort.date:
        list.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
      case _Sort.name:
        list.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
      case _Sort.size:
        list.sort((a, b) => b.sizeBytes.compareTo(a.sizeBytes));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<FilesCubit>().state;
    final visible = _visible(state.files);
    final folders = {...VaultFolders.all, ...state.files.map((f) => f.folder)};

    return Scaffold(
      appBar: AppBar(
        title: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _searching
              ? TextField(
                  key: const ValueKey('search'),
                  controller: _search,
                  autofocus: true,
                  enableIMEPersonalizedLearning: false,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Search files',
                    filled: false,
                    border: InputBorder.none,
                  ),
                )
              : const Text('Files', key: ValueKey('title')),
        ),
        actions: [
          IconButton(
            tooltip: _searching ? 'Close search' : 'Search',
            icon: Icon(_searching ? Icons.close_rounded : Icons.search_rounded),
            onPressed: () => setState(() {
              _searching = !_searching;
              if (!_searching) _search.clear();
            }),
          ),
          PopupMenuButton<_Sort>(
            tooltip: 'Sort',
            icon: const Icon(Icons.sort_rounded),
            onSelected: (s) => setState(() => _sort = s),
            itemBuilder: (context) => [
              for (final s in _Sort.values)
                CheckedPopupMenuItem(
                  value: s,
                  checked: s == _sort,
                  child: Text(s.label),
                ),
            ],
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SizedBox(
              height: 104,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                children: [
                  _FolderCard(
                    name: 'All files',
                    count: state.files.length,
                    selected: _folder == null,
                    onTap: () => setState(() => _folder = null),
                  ),
                  for (final folder in folders)
                    _FolderCard(
                      name: folder,
                      count: state.files
                          .where((f) => f.folder == folder)
                          .length,
                      selected: _folder == folder,
                      onTap: () => setState(() => _folder = folder),
                    ),
                ],
              ),
            ),
          ),
          if (state.status != LoadStatus.ready)
            const SliverToBoxAdapter(child: _ListSkeleton())
          else if (visible.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: Icons.folder_open_rounded,
                title: _search.text.isEmpty ? 'No files here' : 'No matches',
                message: _search.text.isEmpty
                    ? 'Add IDs, certificates and contracts to keep them private.'
                    : 'Try a different name.',
              ),
            )
          else
            SliverList.builder(
              itemCount: visible.length,
              itemBuilder: (context, i) => _FileTile(file: visible[i]),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 96)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        // Tabs stay mounted together, so each FAB needs its own hero tag.
        heroTag: 'files-fab',
        onPressed: () => showImportSheet(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add'),
      ),
    );
  }
}

class _FolderCard extends StatelessWidget {
  const _FolderCard({
    required this.name,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 124,
        decoration: BoxDecoration(
          color: selected
              ? scheme.primaryContainer
              : scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? scheme.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(
                    selected ? Icons.folder_open_rounded : Icons.folder_rounded,
                    color: scheme.primary,
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        count == 1 ? '1 file' : '$count files',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _FileAction { rename, export, delete }

class _FileTile extends StatelessWidget {
  const _FileTile({required this.file});

  final VaultFile file;

  Future<void> _onAction(BuildContext context, _FileAction action) async {
    final cubit = context.read<FilesCubit>();
    switch (action) {
      case _FileAction.rename:
        final name = await _askForName(context, file.name);
        if (name != null && name.isNotEmpty) await cubit.rename(file.id, name);
      case _FileAction.export:
        if (await confirmExport(context, itemName: '"${file.name}"') &&
            context.mounted) {
          showPreviewNotice(
            context,
            'Preview: export arrives with the file module.',
          );
        }
      case _FileAction.delete:
        if (await confirmDelete(context, what: '"${file.name}"')) {
          await cubit.delete(file.id);
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.only(left: 20, right: 8),
      leading: FileKindBadge(kind: file.kind),
      title: Text(file.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${file.kind.label} · ${formatBytes(file.sizeBytes)} · '
        '${formatRelative(file.modifiedAt)}',
        style: TextStyle(color: scheme.onSurfaceVariant),
      ),
      trailing: PopupMenuButton<_FileAction>(
        tooltip: 'More',
        onSelected: (a) => _onAction(context, a),
        itemBuilder: (context) => const [
          PopupMenuItem(value: _FileAction.rename, child: Text('Rename')),
          PopupMenuItem(value: _FileAction.export, child: Text('Export')),
          PopupMenuItem(value: _FileAction.delete, child: Text('Delete')),
        ],
      ),
      onTap: () => context.push(Routes.file(file.id)),
    );
  }
}

Future<String?> _askForName(BuildContext context, String current) {
  final controller = TextEditingController(text: current);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Rename file'),
      content: TextField(
        controller: controller,
        autofocus: true,
        enableIMEPersonalizedLearning: false,
        onSubmitted: (v) => Navigator.pop(context, v.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          child: const Text('Rename'),
        ),
      ],
    ),
  ).whenComplete(controller.dispose);
}

class _ListSkeleton extends StatelessWidget {
  const _ListSkeleton();

  @override
  Widget build(BuildContext context) {
    return Pulse(
      child: Column(
        children: [
          for (var i = 0; i < 6; i++)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  SizedBox.square(dimension: 44, child: SkeletonBox()),
                  SizedBox(width: 16),
                  Expanded(child: SkeletonBox(height: 36)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
