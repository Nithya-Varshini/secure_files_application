import 'package:local_auth/local_auth.dart';

/// Asks the OS to verify the user's fingerprint or face. A successful check
/// does not unlock anything by itself: it only makes the biometric-bound
/// Keystore key usable for a few seconds.
abstract interface class BiometricAuth {
  Future<bool> isAvailable();

  /// Returns false when the user cancels or the check fails.
  Future<bool> authenticate(String reason);
}

class LocalBiometricAuth implements BiometricAuth {
  final _auth = LocalAuthentication();

  @override
  Future<bool> isAvailable() async {
    try {
      final enrolled = await _auth.getAvailableBiometrics();
      return enrolled.contains(BiometricType.strong) ||
          enrolled.contains(BiometricType.fingerprint) ||
          enrolled.contains(BiometricType.face);
    } on Exception {
      return false;
    }
  }

  @override
  Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
      );
    } on LocalAuthException {
      return false;
    }
  }
}

class UnavailableBiometricAuth implements BiometricAuth {
  const UnavailableBiometricAuth();

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<bool> authenticate(String reason) async => false;
}
