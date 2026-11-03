import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../crypto/stream_cipher.dart';
import '../crypto/vault_crypto.dart';
import '../security/vault_key.dart';
import 'vault_paths.dart';

/// Reference to one encrypted file, kept inside the encrypted index.
class StoredBlob {
  const StoredBlob({
    required this.id,
    required this.wrappedKey,
    required this.size,
  });

  /// Random file name; reveals nothing about the content.
  final String id;

  /// The file's own key, sealed with the master key.
  final String wrappedKey;

  /// Plaintext size in bytes.
  final int size;

  Map<String, Object> toJson() => {'id': id, 'key': wrappedKey, 'size': size};

  factory StoredBlob.fromJson(Map<String, Object?> json) => StoredBlob(
    id: json['id']! as String,
    wrappedKey: json['key']! as String,
    size: json['size']! as int,
  );
}

/// Stores file contents, each encrypted with its own random key (DEK).
///
/// Per-file keys mean a nonce collision across files is impossible, and
/// deleting an item makes it unreadable even if the bytes linger on flash:
/// its key disappears with the index record (crypto-shredding).
class BlobStore {
  BlobStore(this._paths, this._key);

  final VaultPaths _paths;
  final VaultKey _key;

  File _file(String id) => File('${_paths.blobs.path}/$id.bin');

  static String newId() =>
      VaultCrypto.randomBytes(16)
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();

  List<int> _contentAad(String id) => VaultCrypto.label('vault:blob:$id:v1');
  List<int> _keyAad(String id) => VaultCrypto.label('vault:dek:$id:v1');

  Future<StoredBlob> put(Stream<List<int>> source) async {
    await _paths.blobs.create(recursive: true);
    final id = newId();
    final dek = VaultCrypto.newKey();
    try {
      final size = await VaultStreamCipher.encryptToFile(
        source: source,
        destination: _file(id),
        key: dek,
        associatedData: _contentAad(id),
      );
      final wrapped = await VaultCrypto.seal(
        dek.bytes,
        _key.master,
        aad: _keyAad(id),
      );
      return StoredBlob(id: id, wrappedKey: base64Encode(wrapped), size: size);
    } finally {
      dek.destroy();
    }
  }

  Future<StoredBlob> putBytes(List<int> bytes) => put(Stream.value(bytes));

  Future<SecretKeyData> _unwrap(StoredBlob blob) async => SecretKeyData(
    await VaultCrypto.open(
      base64Decode(blob.wrappedKey),
      _key.master,
      aad: _keyAad(blob.id),
    ),
  );

  Stream<Uint8List> read(StoredBlob blob) async* {
    final dek = await _unwrap(blob);
    try {
      yield* VaultStreamCipher.decryptFile(
        _file(blob.id),
        key: dek,
        associatedData: _contentAad(blob.id),
      );
    } finally {
      dek.destroy();
    }
  }

  Future<Uint8List> readBytes(StoredBlob blob) async {
    final out = BytesBuilder(copy: false);
    await for (final chunk in read(blob)) {
      out.add(chunk);
    }
    return out.takeBytes();
  }

  /// Decrypts into the temp directory for players that need a real file.
  /// The caller deletes it; the whole directory is wiped on lock anyway.
  /// If decryption fails midway, the partial file is removed.
  Future<File> decryptToTemp(StoredBlob blob, {String extension = ''}) async {
    await _paths.temp.create(recursive: true);
    final file = File('${_paths.temp.path}/${newId()}$extension');
    final sink = file.openWrite();
    try {
      await sink.addStream(read(blob));
      await sink.close();
      return file;
    } catch (_) {
      await sink.close().catchError((_) {});
      if (await file.exists()) await file.delete();
      rethrow;
    }
  }

  Future<void> delete(StoredBlob blob) async {
    final file = _file(blob.id);
    if (await file.exists()) await file.delete();
  }
}
