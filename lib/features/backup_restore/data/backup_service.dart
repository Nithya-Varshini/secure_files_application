import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../../../core/crypto/stream_cipher.dart';
import '../../../core/crypto/vault_crypto.dart';
import '../../../core/security/vault_key.dart';
import '../../../core/storage/blob_store.dart';
import '../../../core/storage/vault_paths.dart';
import '../../authentication/domain/auth_repository.dart';

class BackupFormatException implements Exception {
  const BackupFormatException(this.message);

  final String message;
}

/// Encrypted, portable backups that open with the recovery phrase alone.
///
/// ```text
/// "VBAK" | version (1) | salt length (2) | recovery salt
///        | wrap length (2) | recovery envelope (master key, sealed)
///        | payload: VaultStreamCipher(HKDF(master, "backup"),
///                                     associated data = everything above)
/// payload plaintext = entries of  name length (2) | name | size (8) | bytes
///                     ending with name length 0
/// ```
///
/// The entries are the vault's already-encrypted index and blob files, so
/// the backup is encrypted twice. The header is authenticated by every
/// payload segment, so it cannot be swapped or edited. Nothing in it
/// depends on this phone's Keystore, so a new phone can open it.
class BackupService {
  BackupService(this._paths, this._key, this._auth);

  static const _magic = [0x56, 0x42, 0x41, 0x4B]; // "VBAK"
  static const _version = 1;
  static final _validName = RegExp(r'^(index|blobs)/[a-z0-9]{1,64}\.bin$');

  final VaultPaths _paths;
  final VaultKey _key;
  final AuthRepository _auth;

  static Future<SecretKeyData> _backupKey(SecretKey master) =>
      VaultCrypto.subkey(master, 'vault:backup:v1');

  // --- Create --------------------------------------------------------------

  /// Writes a backup into the temp folder (wiped on lock) and returns it.
  Future<File> create() async {
    final envelope = _auth.recoveryEnvelope;
    if (envelope == null) throw const VaultLockedException();
    final header = _header(envelope.salt, envelope.wrap);
    final key = await _backupKey(_key.master);
    await _paths.temp.create(recursive: true);
    final out = File('${_paths.temp.path}/${BlobStore.newId()}.vbak');
    final payload = File('${out.path}.payload');
    try {
      await VaultStreamCipher.encryptToFile(
        source: _archive(),
        destination: payload,
        key: key,
        associatedData: header,
      );
      final sink = out.openWrite()..add(header);
      await sink.addStream(payload.openRead());
      await sink.close();
      return out;
    } finally {
      key.destroy();
      if (await payload.exists()) await payload.delete();
    }
  }

  Uint8List _header(List<int> salt, List<int> wrap) {
    final b = BytesBuilder()
      ..add(_magic)
      ..addByte(_version)
      ..add(_u16(salt.length))
      ..add(salt)
      ..add(_u16(wrap.length))
      ..add(wrap);
    return b.takeBytes();
  }

  Stream<List<int>> _archive() async* {
    for (final (folder, dir) in [
      ('index', _paths.index),
      ('blobs', _paths.blobs),
    ]) {
      if (!await dir.exists()) continue;
      await for (final entity in dir.list()) {
        if (entity is! File) continue;
        final file = entity.uri.pathSegments.last;
        final name = '$folder/$file';
        if (!_validName.hasMatch(name)) continue; // skips *.part, *.tmp
        final nameBytes = utf8.encode(name);
        yield [
          ..._u16(nameBytes.length),
          ...nameBytes,
          ..._u64(await entity.length()),
        ];
        yield* entity.openRead();
      }
    }
    yield _u16(0);
  }

  // --- Restore -------------------------------------------------------------

  /// Restores [backup] onto a phone that has no vault yet. Returns false if
  /// the phrase does not open it. Throws [BackupFormatException] if the
  /// file is not a valid, untampered backup. Nothing is written until the
  /// whole backup has decrypted and verified.
  Future<bool> restore({
    required Uint8List backup,
    required List<String> words,
    required String newPin,
  }) async {
    final parsed = _parse(backup);
    final master = await _auth.openRecoveryEnvelope(
      words: words,
      salt: parsed.salt,
      wrap: parsed.wrap,
    );
    if (master == null) return false;

    final key = await _backupKey(master);
    final Uint8List archive;
    try {
      archive = await VaultStreamCipher.decryptBytes(
        Uint8List.sublistView(backup, parsed.headerLength),
        key: key,
        associatedData: Uint8List.sublistView(backup, 0, parsed.headerLength),
      );
    } on CryptoFailure {
      throw const BackupFormatException(
        'The backup is damaged or was altered.',
      );
    } finally {
      key.destroy();
    }

    final entries = _entries(archive);
    await _paths.wipeVault();
    await _paths.ensure();
    for (final (name, bytes) in entries) {
      await VaultPaths.writeAtomic(File('${_paths.root.path}/$name'), bytes);
    }
    await _auth.adoptRestoredVault(
      master: master,
      recoverySalt: parsed.salt,
      recoveryWrap: parsed.wrap,
      pin: newPin,
    );
    return true;
  }

  ({List<int> salt, List<int> wrap, int headerLength}) _parse(Uint8List b) {
    var o = 0;
    int take(int n) {
      if (o + n > b.length) {
        throw const BackupFormatException('This is not a vault backup.');
      }
      final start = o;
      o += n;
      return start;
    }

    final m = take(4);
    for (var i = 0; i < 4; i++) {
      if (b[m + i] != _magic[i]) {
        throw const BackupFormatException('This is not a vault backup.');
      }
    }
    if (b[take(1)] != _version) {
      throw const BackupFormatException('This backup needs a newer app.');
    }
    final saltLength = _readU16(b, take(2));
    final salt = b.sublist(take(saltLength), o);
    final wrapLength = _readU16(b, take(2));
    final wrap = b.sublist(take(wrapLength), o);
    return (salt: salt, wrap: wrap, headerLength: o);
  }

  /// Parses the decrypted archive. Every name must match the vault's own
  /// layout, so a crafted backup cannot write outside the vault folder
  /// ("../" path traversal).
  List<(String, Uint8List)> _entries(Uint8List a) {
    final out = <(String, Uint8List)>[];
    var o = 0;
    Never bad() => throw const BackupFormatException('The backup is damaged.');
    while (true) {
      if (o + 2 > a.length) bad();
      final nameLength = _readU16(a, o);
      o += 2;
      if (nameLength == 0) break;
      if (o + nameLength + 8 > a.length) bad();
      final name = utf8.decode(a.sublist(o, o + nameLength));
      o += nameLength;
      if (!_validName.hasMatch(name)) bad();
      final size = ByteData.sublistView(a, o, o + 8).getUint64(0);
      o += 8;
      if (size > a.length - o) bad();
      out.add((name, Uint8List.sublistView(a, o, o + size)));
      o += size;
    }
    return out;
  }

  static List<int> _u16(int v) =>
      (ByteData(2)..setUint16(0, v)).buffer.asUint8List();

  static List<int> _u64(int v) =>
      (ByteData(8)..setUint64(0, v)).buffer.asUint8List();

  static int _readU16(Uint8List b, int offset) =>
      ByteData.sublistView(b, offset, offset + 2).getUint16(0);
}
