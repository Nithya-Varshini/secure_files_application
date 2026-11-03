import 'package:flutter/services.dart';

/// The key was destroyed by the OS, e.g. after new fingerprints were
/// enrolled (setInvalidatedByBiometricEnrollment). Data wrapped with it is
/// unrecoverable through that path; the user must fall back to the PIN.
class KeyInvalidatedException implements Exception {
  const KeyInvalidatedException();
}

class KeystoreException implements Exception {
  const KeystoreException(this.code);

  final String code;

  @override
  String toString() => 'KeystoreException($code)';
}

/// Wraps small secrets with non-exportable keys held in secure hardware
/// (Android Keystore: TEE, or StrongBox where available). The key material
/// never enters app memory, so copying the app's files to another machine
/// gains an attacker nothing: decryption only works on this device.
abstract interface class HardwareKeystore {
  bool get isAvailable;

  /// [requireUserAuth] creates a key usable only for a few seconds after a
  /// strong biometric authentication (used for biometric unlock).
  Future<Uint8List> wrap(
    String alias,
    Uint8List data, {
    bool requireUserAuth = false,
  });

  Future<Uint8List> unwrap(String alias, Uint8List data);

  Future<void> delete(String alias);
}

class AndroidHardwareKeystore implements HardwareKeystore {
  static const _channel = MethodChannel('vault/keystore');

  @override
  bool get isAvailable => true;

  @override
  Future<Uint8List> wrap(
    String alias,
    Uint8List data, {
    bool requireUserAuth = false,
  }) => _call('wrap', {
    'alias': alias,
    'data': data,
    'requireAuth': requireUserAuth,
  });

  @override
  Future<Uint8List> unwrap(String alias, Uint8List data) =>
      _call('unwrap', {'alias': alias, 'data': data});

  @override
  Future<void> delete(String alias) async {
    await _channel.invokeMethod<void>('delete', {'alias': alias});
  }

  Future<Uint8List> _call(String method, Map<String, Object> args) async {
    try {
      final result = await _channel.invokeMethod<Uint8List>(method, args);
      return result!;
    } on PlatformException catch (e) {
      if (e.code == 'KEY_INVALIDATED') throw const KeyInvalidatedException();
      throw KeystoreException(e.code);
    }
  }
}

/// Platforms without a hardware keystore (desktop test runs). Reports
/// itself unavailable so callers skip the hardware layer and never enable
/// features, such as biometric unlock, that depend on it.
class UnavailableHardwareKeystore implements HardwareKeystore {
  const UnavailableHardwareKeystore();

  @override
  bool get isAvailable => false;

  @override
  Future<Uint8List> wrap(
    String alias,
    Uint8List data, {
    bool requireUserAuth = false,
  }) => throw UnsupportedError('No hardware keystore');

  @override
  Future<Uint8List> unwrap(String alias, Uint8List data) =>
      throw UnsupportedError('No hardware keystore');

  @override
  Future<void> delete(String alias) async {}
}
