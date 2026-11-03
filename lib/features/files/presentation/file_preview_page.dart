import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pdfx/pdfx.dart';

import '../../../app/di.dart';
import '../../../app/import_actions.dart';
import '../../../core/storage/vault_paths.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/dialogs.dart';
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
  late final Future<Uint8List> _content = context.read<FilesCubit>().read(
    widget.fileId,
  );

  @override
  void dispose() {
    // pdfx renders through files in the cache; remove them now rather
    // than waiting for the next lock (threat model L7).
    getIt<VaultPaths>().wipePluginLeftovers();
    super.dispose();
  }

  Future<void> _delete(VaultFile file) async {
    final cubit = context.read<FilesCubit>();
    if (!await confirmDelete(context, what: '"${file.name}"')) return;
    if (!mounted) return;
    context.pop();
    await cubit.delete(file.id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final file = context.select((FilesCubit c) => c.state.byId(widget.fileId));
    if (file == null) return Scaffold(appBar: AppBar());

    return Scaffold(
      appBar: AppBar(
        title: Text(file.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Export',
            icon: const Icon(Icons.ios_share_rounded),
            onPressed: () => exportFile(context, file),
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
            height: 440,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(24),
            ),
            child: FutureBuilder<Uint8List>(
              future: _content,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const _NoPreview(
                    text: "This file couldn't be decrypted.",
                  );
                }
                final bytes = snapshot.data;
                if (bytes == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                return _Preview(file: file, bytes: bytes);
              },
            ),
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
                    Icons.lock_outline_rounded,
                    'Stored',
                    'Encrypted, only on this phone',
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

class _Preview extends StatelessWidget {
  const _Preview({required this.file, required this.bytes});

  final VaultFile file;
  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    switch (file.kind) {
      case FileKind.image:
        return InteractiveViewer(
          maxScale: 5,
          child: Image.memory(
            bytes,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const _NoPreview(
              text: "This image format can't be shown here.",
            ),
          ),
        );
      case FileKind.pdf:
        return _PdfPreview(bytes: bytes);
      case FileKind.text:
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Text(
            utf8.decode(bytes, allowMalformed: true),
            style: const TextStyle(fontFamily: 'monospace', height: 1.4),
          ),
        );
      case FileKind.document:
      case FileKind.spreadsheet:
      case FileKind.archive:
      case FileKind.other:
        return _NoPreview(
          icon: file.kind,
          text:
              'No preview for this type. Export it to open it in '
              'another app.',
        );
    }
  }
}

class _PdfPreview extends StatefulWidget {
  const _PdfPreview({required this.bytes});

  final Uint8List bytes;

  @override
  State<_PdfPreview> createState() => _PdfPreviewState();
}

class _PdfPreviewState extends State<_PdfPreview> {
  late final _controller = PdfControllerPinch(
    document: PdfDocument.openData(widget.bytes),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PdfViewPinch(
      controller: _controller,
      builders: PdfViewPinchBuilders<DefaultBuilderOptions>(
        options: const DefaultBuilderOptions(),
        errorBuilder: (_, _) =>
            const _NoPreview(text: "This PDF couldn't be displayed."),
      ),
    );
  }
}

class _NoPreview extends StatelessWidget {
  const _NoPreview({required this.text, this.icon});

  final String text;
  final FileKind? icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FileKindBadge(kind: icon ?? FileKind.other, size: 96),
            const SizedBox(height: 16),
            Text(text, textAlign: TextAlign.center),
          ],
        ),
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
