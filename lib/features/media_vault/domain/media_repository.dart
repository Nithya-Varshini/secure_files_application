import 'dart:io';
import 'dart:typed_data';

import '../../../core/platform/pickers.dart';
import 'media_item.dart';

abstract interface class MediaRepository {
  Future<List<MediaItem>> loadAll();

  /// Encrypts each picked file (plus a thumbnail for photos) into the vault.
  Future<List<MediaItem>> import(List<PickedFile> files);

  /// Small decrypted preview, or null if none exists (e.g. videos).
  Future<Uint8List?> thumbnail(String id);

  /// The full decrypted photo, kept in memory only.
  Future<Uint8List> original(String id);

  /// Video players need a real file: decrypts into the temp folder, which
  /// is wiped on lock. The caller deletes it when done.
  Future<File> openVideo(String id);

  Future<void> delete(Set<String> ids);

  Future<void> setFavorite(String id, {required bool favorite});
}
