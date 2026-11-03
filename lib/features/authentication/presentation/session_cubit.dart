import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/auth_repository.dart';

enum VaultStatus { noVault, locked, unlocked }

enum UnlockResult { success, wrongPin, lockedOut }

enum SecurityEventType {
  vaultCreated,
  unlocked,
  biometricUnlock,
  failedAttempt,
  lockedOut,
  locked,
  pinChanged,
  recovered,
}

class SecurityEvent extends Equatable {
  const SecurityEvent(this.type, this.at);

  final SecurityEventType type;
  final DateTime at;

  @override
  List<Object?> get props => [type, at];
}

class SessionState extends Equatable {
  const SessionState({
    this.status = VaultStatus.noVault,
    this.failedAttempts = 0,
    this.lockedOutUntil,
    this.recoveryVerified = false,
    this.events = const [],
  });

  final VaultStatus status;
  final int failedAttempts;
  final DateTime? lockedOutUntil;
  final bool recoveryVerified;
  final List<SecurityEvent> events;

  bool isLockedOut(DateTime now) =>
      lockedOutUntil != null && now.isBefore(lockedOutUntil!);

  SessionState copyWith({
    VaultStatus? status,
    int? failedAttempts,
    DateTime? lockedOutUntil,
    bool clearLockout = false,
    bool? recoveryVerified,
    List<SecurityEvent>? events,
  }) {
    return SessionState(
      status: status ?? this.status,
      failedAttempts: failedAttempts ?? this.failedAttempts,
      lockedOutUntil: clearLockout
          ? null
          : (lockedOutUntil ?? this.lockedOutUntil),
      recoveryVerified: recoveryVerified ?? this.recoveryVerified,
      events: events ?? this.events,
    );
  }

  @override
  List<Object?> get props => [
    status,
    failedAttempts,
    lockedOutUntil,
    recoveryVerified,
    events,
  ];
}

/// Single source of truth for "is the vault open?". The router redirects on
/// every change, and feature data is loaded or wiped in response.
class SessionCubit extends Cubit<SessionState> {
  SessionCubit(this._auth, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now,
      super(
        SessionState(
          status: _auth.hasVault ? VaultStatus.locked : VaultStatus.noVault,
        ),
      );

  /// Wrong PINs allowed before the first wait.
  static const freeAttempts = 5;

  /// First lockout length; doubles with each further failure, up to 16 min.
  static const baseLockout = Duration(seconds: 30);

  final AuthRepository _auth;
  final DateTime Function() _clock;

  int get attemptsLeft => math.max(0, freeAttempts - state.failedAttempts);

  Future<void> createVault({
    required String pin,
    required List<String> phrase,
  }) async {
    await _auth.createVault(pin: pin, recoveryPhrase: phrase);
    emit(
      SessionState(
        status: VaultStatus.unlocked,
        recoveryVerified: true,
        events: _log(SecurityEventType.vaultCreated),
      ),
    );
  }

  Future<UnlockResult> unlockWithPin(String pin) async {
    final now = _clock();
    if (state.isLockedOut(now)) return UnlockResult.lockedOut;

    if (await _auth.verifyPin(pin)) {
      emit(
        state.copyWith(
          status: VaultStatus.unlocked,
          failedAttempts: 0,
          clearLockout: true,
          events: _log(SecurityEventType.unlocked),
        ),
      );
      return UnlockResult.success;
    }

    final attempts = state.failedAttempts + 1;
    DateTime? until;
    if (attempts >= freeAttempts) {
      final multiplier = math.min(1 << (attempts - freeAttempts), 32);
      until = now.add(baseLockout * multiplier);
    }
    emit(
      state.copyWith(
        failedAttempts: attempts,
        lockedOutUntil: until,
        events: _log(
          until == null
              ? SecurityEventType.failedAttempt
              : SecurityEventType.lockedOut,
        ),
      ),
    );
    return until == null ? UnlockResult.wrongPin : UnlockResult.lockedOut;
  }

  /// PREVIEW: real biometrics unlock a Keystore key via BiometricPrompt.
  void unlockWithBiometric() {
    if (state.status != VaultStatus.locked) return;
    emit(
      state.copyWith(
        status: VaultStatus.unlocked,
        failedAttempts: 0,
        clearLockout: true,
        events: _log(SecurityEventType.biometricUnlock),
      ),
    );
  }

  void lock() {
    if (state.status != VaultStatus.unlocked) return;
    emit(
      state.copyWith(
        status: VaultStatus.locked,
        events: _log(SecurityEventType.locked),
      ),
    );
  }

  Future<bool> checkPin(String pin) => _auth.verifyPin(pin);

  Future<bool> checkRecoveryPhrase(List<String> words) =>
      _auth.verifyRecoveryPhrase(words);

  Future<bool> changePin({
    required String currentPin,
    required String newPin,
  }) async {
    if (!await _auth.verifyPin(currentPin)) return false;
    await _auth.changePin(newPin);
    emit(state.copyWith(events: _log(SecurityEventType.pinChanged)));
    return true;
  }

  Future<bool> recover({
    required List<String> words,
    required String newPin,
  }) async {
    if (!await _auth.verifyRecoveryPhrase(words)) return false;
    await _auth.changePin(newPin);
    emit(
      state.copyWith(
        status: VaultStatus.unlocked,
        failedAttempts: 0,
        clearLockout: true,
        events: _log(SecurityEventType.recovered),
      ),
    );
    return true;
  }

  Future<void> deleteVault() async {
    await _auth.deleteVault();
    emit(const SessionState());
  }

  List<SecurityEvent> _log(SecurityEventType type) =>
      [SecurityEvent(type, _clock()), ...state.events].take(50).toList();
}
