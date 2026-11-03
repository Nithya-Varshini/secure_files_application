/// Failed-attempt counter, persisted so that killing and restarting the app
/// does not reset the wait.
class LockoutState {
  const LockoutState({this.failedAttempts = 0, this.lockedOutUntil});

  final int failedAttempts;
  final DateTime? lockedOutUntil;

  Map<String, Object?> toJson() => {
    'failed': failedAttempts,
    'until': lockedOutUntil?.millisecondsSinceEpoch,
  };

  factory LockoutState.fromJson(Map<String, Object?> json) => LockoutState(
    failedAttempts: json['failed'] as int? ?? 0,
    lockedOutUntil: json['until'] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(json['until']! as int),
  );
}

/// The biometric key was invalidated (new fingerprints enrolled). Biometric
/// unlock has been switched off; the user must use the PIN.
class BiometricsInvalidatedException implements Exception {
  const BiometricsInvalidatedException();
}

/// Everything the app needs from the vault's key-management layer. Screens
/// and cubits talk only to this interface.
abstract interface class AuthRepository {
  bool get hasVault;

  bool get biometricsEnrolled;

  Future<bool> biometricsAvailable();

  /// Creates the vault and leaves it unlocked.
  Future<void> createVault({
    required String pin,
    required List<String> recoveryPhrase,
  });

  /// Unlocks on success; false for a wrong PIN.
  Future<bool> unlockWithPin(String pin);

  /// Unlocks on success; false if the user cancelled.
  /// Throws [BiometricsInvalidatedException] if the key was invalidated.
  Future<bool> unlockWithBiometrics();

  /// Checks a PIN without changing the lock state.
  Future<bool> verifyPin(String pin);

  Future<bool> verifyRecoveryPhrase(List<String> words);

  /// Sets a new PIN using the recovery phrase and unlocks.
  Future<bool> recover({required List<String> words, required String newPin});

  /// Requires the vault to be unlocked.
  Future<void> changePin(String newPin);

  /// Requires the vault to be unlocked. Returns false if the user cancelled.
  Future<bool> enableBiometrics();

  Future<void> disableBiometrics();

  /// Destroys the in-memory keys.
  void lock();

  Future<void> deleteVault();

  Future<LockoutState> readLockout();

  Future<void> writeLockout(LockoutState state);
}
