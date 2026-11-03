import '../domain/auth_repository.dart';
import '../domain/recovery_phrase.dart';

/// PREVIEW ONLY. Keeps the PIN and phrase in plain memory so the UI can be
/// exercised end to end. Never ship this: a real vault stores only wrapped
/// key material and derives keys with Argon2id (decisions D4-D6).
class InMemoryAuthRepository implements AuthRepository {
  String? _pin;
  List<String>? _phrase;

  @override
  bool get hasVault => _pin != null;

  @override
  Future<void> createVault({
    required String pin,
    required List<String> recoveryPhrase,
  }) async {
    _pin = pin;
    _phrase = List.unmodifiable(recoveryPhrase);
  }

  @override
  Future<bool> verifyPin(String pin) async {
    // Simulates the deliberate cost of Argon2id key derivation.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return pin == _pin;
  }

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
  Future<void> changePin(String newPin) async => _pin = newPin;

  @override
  Future<void> deleteVault() async {
    _pin = null;
    _phrase = null;
  }
}
