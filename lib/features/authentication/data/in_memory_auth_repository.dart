import '../domain/auth_repository.dart';
import '../domain/recovery_phrase.dart';

/// TEST DOUBLE ONLY: keeps the PIN in plain memory so session logic can be
/// unit-tested without cryptography or disk. The app uses
/// LocalAuthRepository.
class InMemoryAuthRepository implements AuthRepository {
  String? _pin;
  List<String>? _phrase;
  bool _unlocked = false;
  bool _biometrics = false;
  LockoutState _lockout = const LockoutState();

  bool get isUnlocked => _unlocked;

  @override
  bool get hasVault => _pin != null;

  @override
  bool get biometricsEnrolled => _biometrics;

  @override
  Future<bool> biometricsAvailable() async => true;

  @override
  Future<void> createVault({
    required String pin,
    required List<String> recoveryPhrase,
  }) async {
    _pin = pin;
    _phrase = List.unmodifiable(recoveryPhrase);
    _unlocked = true;
  }

  @override
  Future<bool> unlockWithPin(String pin) async =>
      _unlocked = hasVault && pin == _pin;

  @override
  Future<bool> unlockWithBiometrics() async => _unlocked = _biometrics;

  @override
  Future<bool> verifyPin(String pin) async => pin == _pin;

  @override
  Future<bool> verifyRecoveryPhrase(List<String> words) async {
    final phrase = _phrase;
    if (phrase == null || words.length != RecoveryPhrase.wordCount) {
      return false;
    }
    for (var i = 0; i < phrase.length; i++) {
      if (phrase[i] != words[i]) return false;
    }
    return true;
  }

  @override
  Future<bool> recover({
    required List<String> words,
    required String newPin,
  }) async {
    if (!await verifyRecoveryPhrase(words)) return false;
    _pin = newPin;
    return _unlocked = true;
  }

  @override
  Future<void> changePin(String newPin) async => _pin = newPin;

  @override
  Future<bool> enableBiometrics() async => _biometrics = true;

  @override
  Future<void> disableBiometrics() async => _biometrics = false;

  @override
  void lock() => _unlocked = false;

  @override
  Future<void> deleteVault() async {
    _pin = null;
    _phrase = null;
    _unlocked = false;
    _biometrics = false;
  }

  @override
  Future<LockoutState> readLockout() async => _lockout;

  @override
  Future<void> writeLockout(LockoutState state) async => _lockout = state;
}
