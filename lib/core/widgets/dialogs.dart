import 'package:flutter/material.dart';

/// Every export leaves the vault, so the user must confirm it explicitly
/// (threat model L12: once shared, the copy is out of our control).
Future<bool> confirmExport(
  BuildContext context, {
  required String itemName,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.lock_open_rounded),
      title: const Text('Export a readable copy?'),
      content: Text(
        '$itemName will be decrypted and saved outside the vault. '
        'Any app that can open that location will be able to read it.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton.tonal(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Export'),
        ),
      ],
    ),
  );
  return result ?? false;
}

Future<bool> confirmDelete(BuildContext context, {required String what}) async {
  final scheme = Theme.of(context).colorScheme;
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: Icon(Icons.delete_outline_rounded, color: scheme.error),
      title: Text('Delete $what?'),
      content: const Text(
        'It will be removed from your vault. This cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: scheme.error,
            foregroundColor: scheme.onError,
          ),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  return result ?? false;
}

void showPreviewNotice(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
