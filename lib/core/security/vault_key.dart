import 'package:cryptography/cryptography.dart';

import '../crypto/vault_crypto.dart';

class VaultLockedException implements Exception {
  const VaultLockedException();
}

/// Holds the master key in memory only while the vault is unlocked.
///
/// Locking destroys (zeroes) the key bytes we control. Dart's garbage
/// collector may still hold copies we cannot reach; that residual risk is
/// recorded in the threat model (L14).
class VaultKey {
  SecretKeyData? _master;
  SecretKeyData? _index;

  bool get isUnlocked => _master != null;

  SecretKeyData get master => _master ?? (throw const VaultLockedException());

  /// Separate key for the metadata index, derived with HKDF so that the
  /// master key itself never encrypts bulk data.
  SecretKeyData get indexKey => _index ?? (throw const VaultLockedException());

  Future<void> unlock(SecretKeyData master) async {
    lock();
    _master = master;
    _index = await VaultCrypto.subkey(master, 'vault:index:v1');
  }

  void lock() {
    _master?.destroy();
    _index?.destroy();
    _master = null;
    _index = null;
  }
}
