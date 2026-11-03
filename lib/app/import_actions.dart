import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:mime/mime.dart';

import '../core/platform/pickers.dart';
import '../core/widgets/dialogs.dart';
import '../features/files/domain/vault_file.dart';
import '../features/files/presentation/files_cubit.dart';
import '../features/media_vault/domain/media_item.dart';
import '../features/media_vault/presentation/media_cubit.dart';
import 'di.dart';
import 'routes.dart';

enum ImportSource { photos, files, scan, note }

/// Bottom sheet listing every way to add something to the vault.
Future<void> showImportSheet(BuildContext context) async {
  final source = await showModalBottomSheet<ImportSource>(
    context: context,
    builder: (context) => const _ImportSheet(),
  );
  if (source != null && context.mounted) await runImport(context, source);
}

Future<void> runImport(BuildContext context, ImportSource source) async {
  final messenger = ScaffoldMessenger.of(context);
  switch (source) {
    case ImportSource.photos:
      final media = context.read<MediaCubit>();
      _showProgress(messenger, 'Encrypting…');
      final (added, picked) = await media.importFromPicker();
      messenger.hideCurrentSnackBar();
      if (picked == 0 || !context.mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(_summary(added, picked))));
      if (added > 0) await _remindAboutOriginals(context, added);
    case ImportSource.files:
      final files = context.read<FilesCubit>();
      _showProgress(messenger, 'Encrypting…');
      final (added, picked) = await files.importFromPicker();
      messenger.hideCurrentSnackBar();
      if (picked == 0) return;
      messenger.showSnackBar(SnackBar(content: Text(_summary(added, picked))));
    case ImportSource.scan:
      context.push(Routes.scanner);
    case ImportSource.note:
      context.push(Routes.newNote);
  }
}

void _showProgress(ScaffoldMessengerState messenger, String text) =>
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(minutes: 5),
        content: Row(
          children: [
            const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 16),
            Text(text),
          ],
        ),
      ),
    );

String _summary(int added, int picked) {
  final noun = added == 1 ? 'item' : 'items';
  final base = '$added $noun encrypted and added';
  return added == picked ? base : '$base. ${picked - added} could not be read.';
}

/// Importing copies a photo; the original still sits in the gallery and may
/// already be in a cloud backup (threat model L1). The Photo Picker grants
/// read access only, so the app cannot delete originals itself.
Future<void> _remindAboutOriginals(BuildContext context, int count) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.photo_library_outlined),
      title: const Text('Originals are still in your gallery'),
      content: Text(
        'The vault keeps an encrypted copy of ${count == 1 ? 'this item' : 'these $count items'}. '
        'The originals stay in your gallery, and may already be backed up to '
        'a cloud service. Delete them in your Gallery or Photos app so they '
        'live only in the vault.',
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Got it'),
        ),
      ],
    ),
  );
}

/// Decrypts and hands copies to the system "save as" dialog, after a
/// warning that they leave the vault (threat model L12).
Future<void> exportMedia(BuildContext context, List<MediaItem> items) async {
  if (items.isEmpty) return;
  final label = items.length == 1
      ? '"${items.first.title}"'
      : '${items.length} items';
  if (!await confirmExport(context, itemName: label) || !context.mounted) {
    return;
  }
  final media = context.read<MediaCubit>();
  final messenger = ScaffoldMessenger.of(context);
  var saved = 0;
  for (final item in items) {
    final bytes = await media.original(item.id);
    final ext = extensionFromMime(item.mimeType);
    final ok = await getIt<DocumentPicker>().saveCopy(
      name: ext == null ? item.title : '${item.title}.$ext',
      bytes: bytes,
      mimeType: item.mimeType,
    );
    if (ok) saved++;
  }
  if (saved > 0) {
    messenger.showSnackBar(
      SnackBar(content: Text('$saved exported outside the vault')),
    );
  }
}

Future<void> exportFile(BuildContext context, VaultFile file) async {
  if (!await confirmExport(context, itemName: '"${file.name}"') ||
      !context.mounted) {
    return;
  }
  final files = context.read<FilesCubit>();
  final messenger = ScaffoldMessenger.of(context);
  final ok = await getIt<DocumentPicker>().saveCopy(
    name: file.name,
    bytes: await files.read(file.id),
    mimeType: file.mimeType,
  );
  if (ok) {
    messenger.showSnackBar(
      SnackBar(content: Text('"${file.name}" exported outside the vault')),
    );
  }
}

class _ImportSheet extends StatelessWidget {
  const _ImportSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Text(
                'Add to vault',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                'Everything is encrypted as it is added.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const _SheetOption(
              source: ImportSource.photos,
              icon: Icons.photo_library_outlined,
              title: 'Photos & videos',
              subtitle: 'Choose from your gallery',
            ),
            const _SheetOption(
              source: ImportSource.files,
              icon: Icons.upload_file_outlined,
              title: 'Documents',
              subtitle: 'PDFs, office files and more',
            ),
            const _SheetOption(
              source: ImportSource.scan,
              icon: Icons.document_scanner_outlined,
              title: 'Scan a document',
              subtitle: 'Camera to encrypted PDF',
            ),
            const _SheetOption(
              source: ImportSource.note,
              icon: Icons.edit_note_outlined,
              title: 'Write a note',
              subtitle: 'Private text, encrypted',
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetOption extends StatelessWidget {
  const _SheetOption({
    required this.source,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final ImportSource source;
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: scheme.secondaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: scheme.onSecondaryContainer),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      onTap: () => Navigator.pop(context, source),
    );
  }
}
