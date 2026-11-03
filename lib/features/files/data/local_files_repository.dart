import 'dart:io';
import 'dart:typed_data';

import '../../../core/platform/pickers.dart';
import '../../../core/storage/blob_store.dart';
import '../../../core/storage/encrypted_index.dart';
import '../domain/files_repository.dart';
import '../domain/vault_file.dart';

class LocalFilesRepository implements FilesRepository {
  LocalFilesRepository(this._index, this._blobs);

  static const _collection = 'files';

  final EncryptedIndex _index;
  final BlobStore _blobs;

  Future<List<_Record>> _records() async =>
      (await _index.read(_collection)).map(_Record.fromJson).toList();

  Future<void> _save(List<_Record> records) =>
      _index.write(_collection, [for (final r in records) r.toJson()]);

  @override
  Future<List<VaultFile>> loadAll() async => [
    for (final r in await _records()) r.file,
  ];

  @override
  Future<List<VaultFile>> import(
    List<PickedFile> files, {
    String folder = VaultFolders.unsorted,
  }) async {
    final records = await _records();
    final added = <VaultFile>[];
    for (final picked in files) {
      try {
        final blob = await _blobs.put(picked.open());
        final mime = picked.resolvedMimeType;
        final file = VaultFile(
          id: BlobStore.newId(),
          name: picked.name,
          kind: VaultFile.kindFor(mime, picked.name),
          mimeType: mime,
          folder: folder,
          sizeBytes: blob.size,
          modifiedAt: DateTime.now(),
        );
        records.insert(0, _Record(file, blob));
        added.add(file);
        await _save(records);
      } on FileSystemException {
        continue;
      } finally {
        await picked.discardPluginCopy();
      }
    }
    return added;
  }

  @override
  Future<VaultFile> addPdf({
    required String name,
    required Uint8List bytes,
  }) async {
    final blob = await _blobs.putBytes(bytes);
    final file = VaultFile(
      id: BlobStore.newId(),
      name: name.toLowerCase().endsWith('.pdf') ? name : '$name.pdf',
      kind: FileKind.pdf,
      mimeType: 'application/pdf',
      folder: VaultFolders.scans,
      sizeBytes: blob.size,
      modifiedAt: DateTime.now(),
    );
    await _save([_Record(file, blob), ...await _records()]);
    return file;
  }

  @override
  Future<Uint8List> read(String id) async {
    final record = (await _records()).firstWhere((r) => r.file.id == id);
    return _blobs.readBytes(record.blob);
  }

  Future<VaultFile> _update(
    String id,
    VaultFile Function(VaultFile) change,
  ) async {
    final records = await _records();
    final i = records.indexWhere((r) => r.file.id == id);
    final updated = change(records[i].file);
    records[i] = _Record(updated, records[i].blob);
    await _save(records);
    return updated;
  }

  @override
  Future<VaultFile> rename(String id, String name) =>
      _update(id, (f) => f.copyWith(name: name, modifiedAt: DateTime.now()));

  @override
  Future<VaultFile> move(String id, String folder) =>
      _update(id, (f) => f.copyWith(folder: folder));

  @override
  Future<void> delete(String id) async {
    final records = await _records();
    final i = records.indexWhere((r) => r.file.id == id);
    if (i == -1) return;
    final removed = records.removeAt(i);
    await _save(records);
    await _blobs.delete(removed.blob);
  }
}

class _Record {
  const _Record(this.file, this.blob);

  final VaultFile file;
  final StoredBlob blob;

  Map<String, Object?> toJson() => {
    'id': file.id,
    'name': file.name,
    'kind': file.kind.name,
    'mime': file.mimeType,
    'folder': file.folder,
    'size': file.sizeBytes,
    'modified': file.modifiedAt.millisecondsSinceEpoch,
    'blob': blob.toJson(),
  };

  factory _Record.fromJson(Map<String, Object?> j) => _Record(
    VaultFile(
      id: j['id']! as String,
      name: j['name']! as String,
      kind: FileKind.values.byName(j['kind']! as String),
      mimeType: j['mime']! as String,
      folder: j['folder']! as String,
      sizeBytes: j['size']! as int,
      modifiedAt: DateTime.fromMillisecondsSinceEpoch(j['modified']! as int),
    ),
    StoredBlob.fromJson((j['blob']! as Map).cast()),
  );
}
