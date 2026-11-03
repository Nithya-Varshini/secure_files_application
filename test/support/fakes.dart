import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:secure_files_application/core/crypto/vault_crypto.dart';
import 'package:secure_files_application/core/platform/biometric_auth.dart';
import 'package:secure_files_application/core/platform/hardware_keystore.dart';

/// Stands in for the Android Keystore: each alias gets a random key that
/// lives only in this object, just as a hardware key never leaves the chip.
class FakeKeystore implements HardwareKeystore {
  final _keys = <String, SecretKeyData>{};
  final _invalidated = <String>{};

  Iterable<String> get aliases => _keys.keys;

  void invalidate(String alias) => _invalidated.add(alias);

  @override
  bool get isAvailable => true;

  @override
  Future<Uint8List> wrap(
    String alias,
    Uint8List data, {
    bool requireUserAuth = false,
  }) {
    final key = _keys.putIfAbsent(alias, VaultCrypto.newKey);
    return VaultCrypto.seal(data, key, aad: VaultCrypto.label(alias));
  }

  @override
  Future<Uint8List> unwrap(String alias, Uint8List data) async {
    if (_invalidated.contains(alias)) throw const KeyInvalidatedException();
    final key = _keys[alias];
    if (key == null) throw const KeystoreException('MISSING');
    try {
      return await VaultCrypto.open(data, key, aad: VaultCrypto.label(alias));
    } on CryptoFailure {
      throw const KeystoreException('BAD_DATA');
    }
  }

  @override
  Future<void> delete(String alias) async {
    _keys.remove(alias);
    _invalidated.remove(alias);
  }
}

class FakeBiometrics implements BiometricAuth {
  bool accept = true;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<bool> authenticate(String reason) async => accept;
}
