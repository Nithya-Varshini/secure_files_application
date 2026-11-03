import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';

import '../security/auto_lock_guard.dart';

/// A file the user chose with a system picker, not yet in the vault.
class PickedFile {
  PickedFile({
    required this.name,
    required this.open,
    this.mimeType,
    this.pluginCopy,
  });

  final String name;
  final Stream<List<int>> Function() open;
  final String? mimeType;

  /// Plaintext copy the picker plugin wrote into our cache. Deleted as soon
  /// as the encrypted version is stored (threat model L7).
  final File? pluginCopy;

  String get resolvedMimeType =>
      mimeType ?? lookupMimeType(name) ?? 'application/octet-stream';

  Future<Uint8List> readAll() async {
    final out = BytesBuilder(copy: false);
    await for (final chunk in open()) {
      out.add(chunk);
    }
    return out.takeBytes();
  }

  Future<void> discardPluginCopy() async {
    final copy = pluginCopy;
    if (copy != null && await copy.exists()) await copy.delete();
  }
}

abstract interface class MediaPicker {
  /// Android Photo Picker: the app sees only what the user selects and
  /// needs no storage permission.
  Future<List<PickedFile>> pickPhotosAndVideos();
}

abstract interface class DocumentPicker {
  /// Storage Access Framework document chooser.
  Future<List<PickedFile>> pickDocuments();

  /// Lets the user choose where a decrypted copy goes. Returns false if
  /// they cancelled.
  Future<bool> saveCopy({
    required String name,
    required Uint8List bytes,
    required String mimeType,
  });
}

class SystemMediaPicker implements MediaPicker {
  SystemMediaPicker(this._cacheRoot);

  final Directory _cacheRoot;
  final _picker = ImagePicker();

  @override
  Future<List<PickedFile>> pickPhotosAndVideos() async {
    final files = await AutoLockGuard.run(
      () => _picker.pickMultipleMedia(requestFullMetadata: false),
    );
    return [
      for (final f in files)
        PickedFile(
          name: f.name,
          open: f.openRead,
          mimeType: f.mimeType,
          pluginCopy: _isOurCopy(f.path) ? File(f.path) : null,
        ),
    ];
  }

  bool _isOurCopy(String path) => path.startsWith(_cacheRoot.path);
}

class SystemDocumentPicker implements DocumentPicker {
  SystemDocumentPicker(this._cacheRoot);

  final Directory _cacheRoot;

  @override
  Future<List<PickedFile>> pickDocuments() async {
    final files = await AutoLockGuard.run(() => FilePicker.pickFiles());
    return [
      for (final f in files)
        PickedFile(
          name: f.name,
          open: f.readAsByteStream,
          pluginCopy: f.path != null && f.path!.startsWith(_cacheRoot.path)
              ? File(f.path!)
              : null,
        ),
    ];
  }

  @override
  Future<bool> saveCopy({
    required String name,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    final uri = await AutoLockGuard.run(
      () =>
          FilePicker.saveFile(fileName: name, bytes: bytes, mimeType: mimeType),
    );
    return uri != null;
  }
}
