import 'dart:typed_data';

import '../../../core/platform/pickers.dart';
import 'vault_file.dart';

abstract interface class FilesRepository {
  Future<List<VaultFile>> loadAll();

  /// Encrypts documents chosen through the Storage Access Framework.
  Future<List<VaultFile>> import(List<PickedFile> files, {String folder});

  /// Stores a PDF produced in memory by the scanner; it never touches disk
  /// unencrypted.
  Future<VaultFile> addPdf({required String name, required Uint8List bytes});

  /// The decrypted content, in memory.
  Future<Uint8List> read(String id);

  Future<VaultFile> rename(String id, String name);

  Future<VaultFile> move(String id, String folder);

  Future<void> delete(String id);
}
