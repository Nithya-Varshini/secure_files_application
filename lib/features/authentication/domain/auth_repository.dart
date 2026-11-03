/// Everything the app needs from the vault's key-management layer.
///
/// The UI only talks to this interface. Module A/B replaces the in-memory
/// demo with the Kotlin crypto core (Argon2id + Keystore-wrapped master key),
/// without touching a single screen.
abstract interface class AuthRepository {
  bool get hasVault;

  Future<void> createVault({
    required String pin,
    required List<String> recoveryPhrase,
  });

  Future<bool> verifyPin(String pin);

  Future<bool> verifyRecoveryPhrase(List<String> words);

  Future<void> changePin(String newPin);

  Future<void> deleteVault();
}
