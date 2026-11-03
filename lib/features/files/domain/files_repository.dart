import 'vault_file.dart';

abstract interface class FilesRepository {
  Future<List<VaultFile>> loadAll();

  /// Imports documents chosen through the Storage Access Framework.
  Future<List<VaultFile>> importFromPicker();

  /// Stores a scanned PDF, encrypted immediately after it is generated.
  Future<VaultFile> addScan({required String name, required int pageCount});

  Future<VaultFile> rename(String id, String name);

  Future<void> delete(String id);
}
