import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:secure_files_application/core/crypto/vault_crypto.dart';
import 'package:secure_files_application/core/platform/hardware_keystore.dart';
import 'package:secure_files_application/core/security/vault_key.dart';
import 'package:secure_files_application/core/storage/vault_paths.dart';
import 'package:secure_files_application/features/authentication/data/local_auth_repository.dart';
import 'package:secure_files_application/features/authentication/domain/auth_repository.dart';
import 'package:secure_files_application/features/authentication/domain/recovery_phrase.dart';

import '../../support/fakes.dart';

void main() {
  const pin = '482915';
  late Directory dir;
  late VaultPaths paths;
  late VaultKey key;
  late FakeKeystore keystore;
  late FakeBiometrics biometrics;
  late List<String> phrase;

  LocalAuthRepository repo({HardwareKeystore? hw}) => LocalAuthRepository(
    paths: paths,
    key: key,
    keystore: hw ?? keystore,
    biometrics: biometrics,
    kdf: KdfParams.testing,
  );

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('vault_auth');
    paths = VaultPaths(
      root: Directory('${dir.path}/vault'),
      temp: Directory('${dir.path}/tmp'),
    );
    key = VaultKey();
    keystore = FakeKeystore();
    biometrics = FakeBiometrics();
    phrase = RecoveryPhrase.generate();
  });

  tearDown(() => dir.delete(recursive: true));

  test('create, lock, unlock with the right PIN only', () async {
    final auth = repo();
    await auth.createVault(pin: pin, recoveryPhrase: phrase);
    expect(key.isUnlocked, isTrue);
    final master = key.master.bytes.toList();

    auth.lock();
    expect(key.isUnlocked, isFalse);
    expect(await auth.unlockWithPin('000000'), isFalse);
    expect(key.isUnlocked, isFalse);
    expect(await auth.unlockWithPin(pin), isTrue);
    expect(key.master.bytes, master);
  });

  test('a restarted app reads the header and unlocks', () async {
    await repo().createVault(pin: pin, recoveryPhrase: phrase);
    key.lock();
    final again = repo();
    await again.init();
    expect(again.hasVault, isTrue);
    expect(await again.unlockWithPin(pin), isTrue);
  });

  test('the header on disk holds no PIN, phrase or raw key', () async {
    await repo().createVault(pin: pin, recoveryPhrase: phrase);
    final master = base64Encode(key.master.bytes);
    final text = await paths.header.readAsString();
    expect(text.contains(pin), isFalse);
    expect(text.contains(phrase.first), isFalse);
    expect(text.contains(master), isFalse);
  });

  test('without the device key, a copied header cannot be opened', () async {
    await repo().createVault(pin: pin, recoveryPhrase: phrase);
    key.lock();
    // An attacker copies the files to another phone: different Keystore.
    final elsewhere = repo(hw: FakeKeystore());
    await elsewhere.init();
    expect(await elsewhere.unlockWithPin(pin), isFalse);
  });

  test(
    'recovery phrase sets a new PIN and keeps the same master key',
    () async {
      final auth = repo();
      await auth.createVault(pin: pin, recoveryPhrase: phrase);
      final master = key.master.bytes.toList();
      auth.lock();

      expect(
        await auth.verifyRecoveryPhrase(RecoveryPhrase.generate()),
        isFalse,
      );
      expect(await auth.recover(words: phrase, newPin: '305718'), isTrue);
      expect(key.master.bytes, master);
      auth.lock();
      expect(await auth.unlockWithPin(pin), isFalse);
      expect(await auth.unlockWithPin('305718'), isTrue);
    },
  );

  test('changing the PIN keeps recovery working', () async {
    final auth = repo();
    await auth.createVault(pin: pin, recoveryPhrase: phrase);
    await auth.changePin('305718');
    auth.lock();
    expect(await auth.unlockWithPin('305718'), isTrue);
    auth.lock();
    expect(await auth.verifyRecoveryPhrase(phrase), isTrue);
  });

  test('a tampered header is rejected, not crashed on', () async {
    await repo().createVault(pin: pin, recoveryPhrase: phrase);
    key.lock();
    final json = (jsonDecode(await paths.header.readAsString()) as Map)
        .cast<String, Object?>();
    final wrap = base64Decode(json['pinWrap']! as String);
    wrap[wrap.length - 1] ^= 1;
    json['pinWrap'] = base64Encode(wrap);
    await paths.header.writeAsString(jsonEncode(json));
    final auth = repo();
    await auth.init();
    expect(await auth.unlockWithPin(pin), isFalse);
  });

  group('biometrics', () {
    test('enable, then unlock with a fingerprint', () async {
      final auth = repo();
      await auth.createVault(pin: pin, recoveryPhrase: phrase);
      expect(await auth.enableBiometrics(), isTrue);
      auth.lock();
      expect(await auth.unlockWithBiometrics(), isTrue);
      expect(key.isUnlocked, isTrue);
    });

    test('a cancelled prompt leaves the vault locked', () async {
      final auth = repo();
      await auth.createVault(pin: pin, recoveryPhrase: phrase);
      await auth.enableBiometrics();
      auth.lock();
      biometrics.accept = false;
      expect(await auth.unlockWithBiometrics(), isFalse);
      expect(key.isUnlocked, isFalse);
    });

    test('new fingerprints invalidate the key and switch it off', () async {
      final auth = repo();
      await auth.createVault(pin: pin, recoveryPhrase: phrase);
      await auth.enableBiometrics();
      auth.lock();
      keystore.invalidate(LocalAuthRepository.biometricAlias);
      await expectLater(
        auth.unlockWithBiometrics(),
        throwsA(isA<BiometricsInvalidatedException>()),
      );
      expect(auth.biometricsEnrolled, isFalse);
      expect(await auth.unlockWithPin(pin), isTrue);
    });

    test('never offered without a hardware keystore', () async {
      final auth = repo(hw: const UnavailableHardwareKeystore());
      await auth.createVault(pin: pin, recoveryPhrase: phrase);
      expect(await auth.biometricsAvailable(), isFalse);
      expect(await auth.enableBiometrics(), isFalse);
    });
  });

  test('lockout state survives a restart', () async {
    final auth = repo();
    await auth.createVault(pin: pin, recoveryPhrase: phrase);
    final until = DateTime(2030);
    await auth.writeLockout(
      LockoutState(failedAttempts: 6, lockedOutUntil: until),
    );
    final read = await repo().readLockout();
    expect(read.failedAttempts, 6);
    expect(read.lockedOutUntil, until);
  });

  test('deleting the vault removes files and keys', () async {
    final auth = repo();
    await auth.createVault(pin: pin, recoveryPhrase: phrase);
    await auth.deleteVault();
    expect(auth.hasVault, isFalse);
    expect(await paths.root.exists(), isFalse);
    expect(keystore.aliases, isEmpty);
  });

  test('keystore wraps are unreadable without the fake hardware key', () async {
    final wrapped = await keystore.wrap('a', Uint8List.fromList([1, 2, 3]));
    await expectLater(
      FakeKeystore().unwrap('a', wrapped),
      throwsA(isA<KeystoreException>()),
    );
  });
}
