import 'dart:convert';
import 'dart:io';

import '../crypto/vault_crypto.dart';
import '../security/vault_key.dart';
import 'vault_paths.dart';

/// Encrypted metadata: one sealed JSON document per collection (media,
/// files, notes). Names, titles, folders, sizes and dates never touch disk
/// in plaintext.
///
/// For R1's expected scale (hundreds to a few thousand items) rewriting one
/// small sealed document per change is simpler and safer than a database;
/// moving to SQLCipher is the planned path if the index outgrows that.
class EncryptedIndex {
  EncryptedIndex(this._paths, this._key);

  final VaultPaths _paths;
  final VaultKey _key;
  final _queues = <String, Future<void>>{};

  File _file(String name) => File('${_paths.index.path}/$name.bin');

  List<int> _aad(String name) => VaultCrypto.label('vault:index:$name:v1');

  Future<List<Map<String, Object?>>> read(String name) async {
    final file = _file(name);
    if (!await file.exists()) return [];
    final clear = await VaultCrypto.open(
      await file.readAsBytes(),
      _key.indexKey,
      aad: _aad(name),
    );
    return (jsonDecode(utf8.decode(clear)) as List)
        .cast<Map<String, Object?>>();
  }

  /// Writes are serialised per collection so two quick edits cannot
  /// interleave and lose one another.
  Future<void> write(String name, List<Map<String, Object?>> records) {
    final previous = _queues[name] ?? Future<void>.value();
    final next = previous.then((_) async {
      final sealed = await VaultCrypto.seal(
        utf8.encode(jsonEncode(records)),
        _key.indexKey,
        aad: _aad(name),
      );
      await VaultPaths.writeAtomic(_file(name), sealed);
    });
    _queues[name] = next.catchError((_) {});
    return next;
  }
}
