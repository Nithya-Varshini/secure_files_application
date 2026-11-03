import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../features/files/presentation/files_cubit.dart';
import '../features/media_vault/presentation/media_cubit.dart';
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
      final count = await context.read<MediaCubit>().importFromPicker();
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('$count photos encrypted and added')),
      );
      await _offerToRemoveOriginals(context, count);
    case ImportSource.files:
      final count = await context.read<FilesCubit>().importFromPicker();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            count == 1 ? '1 file encrypted and added' : '$count files added',
          ),
        ),
      );
    case ImportSource.scan:
      context.push(Routes.scanner);
    case ImportSource.note:
      context.push(Routes.newNote);
  }
}

/// Importing copies a photo; the original still sits in the gallery and may
/// already be in a cloud backup (threat model L1).
Future<void> _offerToRemoveOriginals(BuildContext context, int count) async {
  final remove = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.photo_library_outlined),
      title: const Text('Remove the originals?'),
      content: Text(
        'The $count photos are still in your phone gallery, and may already be '
        'backed up to a cloud service. Remove them so they live only in your '
        'vault.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Keep'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Remove originals'),
        ),
      ],
    ),
  );
  if ((remove ?? false) && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Preview: Android will ask you to confirm the removal.'),
      ),
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
