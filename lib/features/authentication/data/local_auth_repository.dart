import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../../../core/crypto/vault_crypto.dart';
import '../../../core/platform/biometric_auth.dart';
import '../../../core/platform/hardware_keystore.dart';
import '../../../core/security/vault_key.dart';
import '../../../core/storage/vault_paths.dart';
import '../domain/auth_repository.dart';
import '../domain/recovery_phrase.dart';

/// On-disk key header. Contains only wrapped (encrypted) key material.
///
/// ```text
/// master key (random 256-bit)
///  ├─ pinWrap      = AES-GCM(Argon2id(PIN, pinSalt), master)
///  │                 then, on Android, wrapped again by a Keystore key
///  ├─ recoveryWrap = AES-GCM(HKDF(phrase entropy, recoverySalt), master)
///  └─ bioWrap      = Keystore key that needs a fresh biometric check
/// ```
class VaultHeader {
  const VaultHeader({
    required this.kdf,
    required this.pinSalt,
    required this.pinWrap,
    required this.hardwareBound,
    required this.recoverySalt,
    required this.recoveryWrap,
    this.bioWrap,
  });

  static const version = 1;

  final KdfParams kdf;
  final List<int> pinSalt;
  final List<int> pinWrap;
  final bool hardwareBound;
  final List<int> recoverySalt;
  final List<int> recoveryWrap;
  final List<int>? bioWrap;

  VaultHeader copyWith({
    KdfParams? kdf,
    List<int>? pinSalt,
    List<int>? pinWrap,
    bool? hardwareBound,
    List<int>? bioWrap,
    bool clearBio = false,
  }) => VaultHeader(
    kdf: kdf ?? this.kdf,
    pinSalt: pinSalt ?? this.pinSalt,
    pinWrap: pinWrap ?? this.pinWrap,
    hardwareBound: hardwareBound ?? this.hardwareBound,
    recoverySalt: recoverySalt,
    recoveryWrap: recoveryWrap,
    bioWrap: clearBio ? null : (bioWrap ?? this.bioWrap),
  );

  Map<String, Object?> toJson() => {
    'v': version,
    'kdf': kdf.toJson(),
    'pinSalt': base64Encode(pinSalt),
    'pinWrap': base64Encode(pinWrap),
    'hw': hardwareBound,
    'recoverySalt': base64Encode(recoverySalt),
    'recoveryWrap': base64Encode(recoveryWrap),
    if (bioWrap != null) 'bioWrap': base64Encode(bioWrap!),
  };

  factory VaultHeader.fromJson(Map<String, Object?> json) {
    if (json['v'] != version) throw const CryptoFailure('Unsupported header');
    List<int> b(String key) => base64Decode(json[key]! as String);
    return VaultHeader(
      kdf: KdfParams.fromJson((json['kdf']! as Map).cast<String, Object?>()),
      pinSalt: b('pinSalt'),
      pinWrap: b('pinWrap'),
      hardwareBound: json['hw']! as bool,
      recoverySalt: b('recoverySalt'),
      recoveryWrap: b('recoveryWrap'),
      bioWrap: json['bioWrap'] == null ? null : b('bioWrap'),
    );
  }
}

class LocalAuthRepository implements AuthRepository {
  // Private named parameters: callers still write `paths:`, `key:` etc.
  LocalAuthRepository({
    required this._paths,
    required this._key,
    required this._keystore,
    required this._biometrics,
    this._kdf = KdfParams.recommended,
  });

  static const deviceAlias = 'vault.device';
  static const biometricAlias = 'vault.biometric';

  static final _pinAad = VaultCrypto.label('vault:pin-wrap:v1');
  static final _recoveryAad = VaultCrypto.label('vault:recovery-wrap:v1');

  final VaultPaths _paths;
  final VaultKey _key;
  final HardwareKeystore _keystore;
  final BiometricAuth _biometrics;
  final KdfParams _kdf;
  VaultHeader? _header;

  /// Reads the header from disk. Call once at start-up.
  Future<void> init() async {
    final file = _paths.header;
    _header = await file.exists()
        ? VaultHeader.fromJson(
            (jsonDecode(await file.readAsString()) as Map)
                .cast<String, Object?>(),
          )
        : null;
  }

  @override
  bool get hasVault => _header != null;

  @override
  bool get biometricsEnrolled => _header?.bioWrap != null;

  @override
  Future<bool> biometricsAvailable() async =>
      _keystore.isAvailable && await _biometrics.isAvailable();

  Future<void> _save(VaultHeader header) async {
    await VaultPaths.writeAtomic(
      _paths.header,
      utf8.encode(jsonEncode(header.toJson())),
    );
    _header = header;
  }

  // --- PIN layer -----------------------------------------------------------

  Future<({List<int> salt, List<int> wrap, bool hw})> _wrapForPin(
    SecretKeyData master,
    String pin,
  ) async {
    final salt = VaultCrypto.randomBytes(16);
    final kek = await VaultCrypto.derivePinKey(pin, salt, _kdf);
    Uint8List wrap = await VaultCrypto.seal(master.bytes, kek, aad: _pinAad);
    kek.destroy();
    // Second layer: a non-exportable hardware key. Without this device the
    // wrapped key cannot even be tested against PIN guesses (D6).
    final hw = _keystore.isAvailable;
    if (hw) wrap = await _keystore.wrap(deviceAlias, wrap);
    return (salt: salt, wrap: wrap, hw: hw);
  }

  Future<SecretKeyData?> _openWithPin(String pin) async {
    final header = _header;
    if (header == null) return null;
    try {
      var wrap = Uint8List.fromList(header.pinWrap);
      if (header.hardwareBound) {
        wrap = await _keystore.unwrap(deviceAlias, wrap);
      }
      final kek = await VaultCrypto.derivePinKey(
        pin,
        header.pinSalt,
        header.kdf,
      );
      try {
        return SecretKeyData(await VaultCrypto.open(wrap, kek, aad: _pinAad));
      } finally {
        kek.destroy();
      }
    } on CryptoFailure {
      return null;
    } on KeystoreException {
      // The device key is gone (e.g. app data partly restored elsewhere).
      // The PIN can no longer open the vault; the recovery phrase still can.
      return null;
    }
  }

  // --- Recovery layer ------------------------------------------------------

  Future<SecretKeyData?> _recoveryKey(
    List<String> words,
    List<int> salt,
  ) async {
    final entropy = RecoveryPhrase.entropyOf(words);
    if (entropy == null) return null;
    return VaultCrypto.subkey(
      SecretKeyData(entropy),
      'vault:recovery:v1',
      salt: salt,
    );
  }

  Future<SecretKeyData?> _openWithPhrase(List<String> words) async {
    final header = _header;
    if (header == null) return null;
    final kek = await _recoveryKey(words, header.recoverySalt);
    if (kek == null) return null;
    try {
      return SecretKeyData(
        await VaultCrypto.open(header.recoveryWrap, kek, aad: _recoveryAad),
      );
    } on CryptoFailure {
      return null;
    } finally {
      kek.destroy();
    }
  }

  // --- AuthRepository ------------------------------------------------------

  @override
  Future<void> createVault({
    required String pin,
    required List<String> recoveryPhrase,
  }) async {
    await _paths.ensure();
    final master = VaultCrypto.newKey();
    final pinLayer = await _wrapForPin(master, pin);
    final recoverySalt = VaultCrypto.randomBytes(16);
    final recoveryKek = await _recoveryKey(recoveryPhrase, recoverySalt);
    if (recoveryKek == null) throw ArgumentError('Invalid recovery phrase');
    final recoveryWrap = await VaultCrypto.seal(
      master.bytes,
      recoveryKek,
      aad: _recoveryAad,
    );
    recoveryKek.destroy();

    await _save(
      VaultHeader(
        kdf: _kdf,
        pinSalt: pinLayer.salt,
        pinWrap: pinLayer.wrap,
        hardwareBound: pinLayer.hw,
        recoverySalt: recoverySalt,
        recoveryWrap: recoveryWrap,
      ),
    );
    await writeLockout(const LockoutState());
    await _key.unlock(master);
  }

  @override
  Future<bool> unlockWithPin(String pin) async {
    final master = await _openWithPin(pin);
    if (master == null) return false;
    await _key.unlock(master);
    return true;
  }

  @override
  Future<bool> verifyPin(String pin) async {
    final master = await _openWithPin(pin);
    master?.destroy();
    return master != null;
  }

  @override
  Future<bool> verifyRecoveryPhrase(List<String> words) async {
    final master = await _openWithPhrase(words);
    master?.destroy();
    return master != null;
  }

  @override
  Future<bool> recover({
    required List<String> words,
    required String newPin,
  }) async {
    final master = await _openWithPhrase(words);
    if (master == null) return false;
    final pinLayer = await _wrapForPin(master, newPin);
    await _save(
      _header!.copyWith(
        pinSalt: pinLayer.salt,
        pinWrap: pinLayer.wrap,
        hardwareBound: pinLayer.hw,
      ),
    );
    await _key.unlock(master);
    return true;
  }

  @override
  Future<void> changePin(String newPin) async {
    final pinLayer = await _wrapForPin(_key.master, newPin);
    await _save(
      _header!.copyWith(
        pinSalt: pinLayer.salt,
        pinWrap: pinLayer.wrap,
        hardwareBound: pinLayer.hw,
      ),
    );
  }

  @override
  Future<bool> enableBiometrics() async {
    if (!await biometricsAvailable()) return false;
    final master = _key.master;
    // The biometric key only works for a few seconds after a successful
    // check, so authenticate first, then wrap.
    if (!await _biometrics.authenticate('Turn on fingerprint unlock')) {
      return false;
    }
    await _keystore.delete(biometricAlias);
    final wrap = await _keystore.wrap(
      biometricAlias,
      Uint8List.fromList(master.bytes),
      requireUserAuth: true,
    );
    await _save(_header!.copyWith(bioWrap: wrap));
    return true;
  }

  @override
  Future<void> disableBiometrics() async {
    await _keystore.delete(biometricAlias);
    if (_header != null) await _save(_header!.copyWith(clearBio: true));
  }

  @override
  Future<bool> unlockWithBiometrics() async {
    final wrap = _header?.bioWrap;
    if (wrap == null) return false;
    if (!await _biometrics.authenticate('Unlock your vault')) return false;
    try {
      final master = await _keystore.unwrap(
        biometricAlias,
        Uint8List.fromList(wrap),
      );
      await _key.unlock(SecretKeyData(master));
      return true;
    } on KeyInvalidatedException {
      await disableBiometrics();
      throw const BiometricsInvalidatedException();
    }
  }

  @override
  void lock() => _key.lock();

  @override
  Future<void> deleteVault() async {
    _key.lock();
    await _keystore.delete(deviceAlias);
    await _keystore.delete(biometricAlias);
    await _paths.wipeVault();
    _header = null;
  }

  @override
  Future<LockoutState> readLockout() async {
    final file = _paths.lockout;
    if (!await file.exists()) return const LockoutState();
    try {
      return LockoutState.fromJson(
        (jsonDecode(await file.readAsString()) as Map).cast<String, Object?>(),
      );
    } on FormatException {
      return const LockoutState();
    }
  }

  @override
  Future<void> writeLockout(LockoutState state) => VaultPaths.writeAtomic(
    _paths.lockout,
    utf8.encode(jsonEncode(state.toJson())),
  );
}
