import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Where the vault lives. Everything is in app-private storage, which other
/// apps cannot read and which is excluded from Android backups.
class VaultPaths {
  VaultPaths({required this.root, required this.temp});

  /// Directory holding the vault (key header, encrypted index and blobs).
  final Directory root;

  /// Short-lived decrypted files (e.g. a video being played). Wiped when the
  /// vault locks and at every start (threat model L7).
  final Directory temp;

  static Future<VaultPaths> resolve() async {
    final support = await getApplicationSupportDirectory();
    final cache = await getTemporaryDirectory();
    return VaultPaths(
      root: Directory('${support.path}/vault'),
      temp: Directory('${cache.path}/vault_tmp'),
    );
  }

  File get header => File('${root.path}/vault.json');
  File get lockout => File('${root.path}/lockout.json');
  File get settings => File('${root.path}/settings.json');
  Directory get index => Directory('${root.path}/index');
  Directory get blobs => Directory('${root.path}/blobs');

  Future<void> ensure() async {
    await index.create(recursive: true);
    await blobs.create(recursive: true);
    await temp.create(recursive: true);
  }

  /// The app's cache directory; [temp] lives inside it.
  Directory get cache => temp.parent;

  Future<void> wipeTemp() async {
    if (await temp.exists()) await temp.delete(recursive: true);
    await temp.create(recursive: true);
    await wipePluginLeftovers();
  }

  /// Plugins that cannot work from memory leave plaintext in our cache:
  /// pdfx writes the PDF and rendered pages, file_picker and image_picker
  /// copy picked files. Everything is app-private, but it must not outlive
  /// its use (threat model L7).
  Future<void> wipePluginLeftovers() async {
    if (!await cache.exists()) return;
    await for (final entry in cache.list(followLinks: false)) {
      final name = entry.uri.pathSegments.where((s) => s.isNotEmpty).last;
      final isPluginDir =
          entry is Directory &&
          (name == 'pdf_renderer_cache' || name == 'file_picker');
      final isPluginFile =
          entry is File &&
          (name.endsWith('.pdf') ||
              name.startsWith('image_picker') ||
              name.startsWith('scaled_') ||
              name.startsWith('CAP'));
      try {
        if (isPluginDir) await entry.delete(recursive: true);
        if (isPluginFile) await entry.delete();
      } on FileSystemException {
        // Still in use (e.g. an open PDF); the next wipe removes it.
      }
    }
  }

  /// Removes every vault file. Without the keys the ciphertext would be
  /// useless anyway, but flash storage may keep old blocks: this is
  /// best-effort deletion, not a forensic guarantee.
  Future<void> wipeVault() async {
    if (await root.exists()) await root.delete(recursive: true);
    await wipeTemp();
  }

  /// Writes through a temporary file and a rename, so a crash leaves either
  /// the old or the new version, never half of each.
  static Future<void> writeAtomic(File file, List<int> bytes) async {
    await file.parent.create(recursive: true);
    final temp = File('${file.path}.tmp');
    await temp.writeAsBytes(bytes, flush: true);
    await temp.rename(file.path);
  }
}
