import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/mock_paper.dart';
import '../domain/vault_file.dart';
import 'file_kind_style.dart';
import 'files_cubit.dart';

class FilePreviewPage extends StatefulWidget {
  const FilePreviewPage({super.key, required this.fileId});

  final String fileId;

  @override
  State<FilePreviewPage> createState() => _FilePreviewPageState();
}

class _FilePreviewPageState extends State<FilePreviewPage> {
  int _page = 0;

  Future<void> _delete(VaultFile file) async {
    final cubit = context.read<FilesCubit>();
    if (!await confirmDelete(context, what: '"${file.name}"')) return;
    if (!mounted) return;
    context.pop();
    await cubit.delete(file.id);
  }

  Future<void> _export(VaultFile file) async {
    if (await confirmExport(context, itemName: '"${file.name}"') && mounted) {
      showPreviewNotice(
        context,
        'Preview: export arrives with the file module.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final file = context.select((FilesCubit c) => c.state.byId(widget.fileId));
    if (file == null) {
      return Scaffold(appBar: AppBar());
    }
    final paged = file.kind == FileKind.pdf || file.kind == FileKind.document;

    return Scaffold(
      appBar: AppBar(
        title: Text(file.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Export',
            icon: const Icon(Icons.ios_share_rounded),
            onPressed: () => _export(file),
          ),
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () => _delete(file),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Container(
            height: 380,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(24),
            ),
            child: paged
                ? Column(
                    children: [
                      Expanded(
                        child: PageView.builder(
                          itemCount: file.pageCount,
                          onPageChanged: (i) => setState(() => _page = i),
                          itemBuilder: (context, i) => Padding(
                            padding: const EdgeInsets.fromLTRB(40, 24, 40, 8),
                            child: Center(
                              child: AspectRatio(
                                aspectRatio: 0.72,
                                child: MockPaper(
                                  seed: file.id.hashCode + i,
                                  tone: PaperTone.enhanced,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Text(
                          'Page ${_page + 1} of ${file.pageCount}',
                          style: theme.textTheme.labelMedium,
                        ),
                      ),
                    ],
                  )
                : Center(child: FileKindBadge(kind: file.kind, size: 120)),
          ),
          const SizedBox(height: 24),
          Text(
            file.name,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  _Detail(Icons.category_outlined, 'Type', file.kind.label),
                  _Detail(
                    Icons.straighten_rounded,
                    'Size',
                    formatBytes(file.sizeBytes),
                  ),
                  _Detail(Icons.folder_outlined, 'Folder', file.folder),
                  _Detail(
                    Icons.schedule_rounded,
                    'Modified',
                    formatDate(file.modifiedAt),
                  ),
                  const _Detail(
                    Icons.phone_android_rounded,
                    'Stored',
                    'Only on this phone',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail(this.icon, this.label, this.value);

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      dense: true,
      leading: Icon(icon, color: scheme.onSurfaceVariant),
      title: Text(label, style: TextStyle(color: scheme.onSurfaceVariant)),
      trailing: Text(value, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}
