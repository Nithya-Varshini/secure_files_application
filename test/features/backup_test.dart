import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:secure_files_application/core/crypto/stream_cipher.dart';
import 'package:secure_files_application/core/crypto/vault_crypto.dart';
import 'package:secure_files_application/core/security/vault_key.dart';
import 'package:secure_files_application/core/storage/encrypted_index.dart';
import 'package:secure_files_application/core/storage/vault_paths.dart';
import 'package:secure_files_application/features/authentication/data/local_auth_repository.dart';
import 'package:secure_files_application/features/authentication/domain/recovery_phrase.dart';
import 'package:secure_files_application/features/backup_restore/data/backup_service.dart';
import 'package:secure_files_application/features/notes/data/local_notes_repository.dart';
import 'package:secure_files_application/features/notes/domain/note.dart';

import '../support/fakes.dart';

/// One simulated phone: its own folder, Keystore and keys.
class _Device {
  _Device(Directory base, String name)
    : paths = VaultPaths(
        root: Directory('${base.path}/$name/vault'),
        temp: Directory('${base.path}/$name/cache/tmp'),
      );

  final VaultPaths paths;
  final key = VaultKey();
  final keystore = FakeKeystore();

  late final auth = LocalAuthRepository(
    paths: paths,
    key: key,
    keystore: keystore,
    biometrics: FakeBiometrics(),
    kdf: KdfParams.testing,
  );
  late final backups = BackupService(paths, key, auth);
  late final notes = LocalNotesRepository(EncryptedIndex(paths, key));
}

void main() {
  late Directory base;
  late List<String> phrase;

  setUp(() async {
    base = await Directory.systemTemp.createTemp('vault_backup');
    phrase = RecoveryPhrase.generate();
  });

  tearDown(() => base.delete(recursive: true));

  Future<Uint8List> backupFromOldPhone() async {
    final old = _Device(base, 'old');
    await old.auth.createVault(pin: '482915', recoveryPhrase: phrase);
    await old.notes.save(
      Note(
        id: 'n1',
        title: 'Locker',
        body: 'Code 4417',
        updatedAt: DateTime(2026),
      ),
    );
    final file = await old.backups.create();
    final bytes = await file.readAsBytes();
    expect(String.fromCharCodes(bytes).contains('4417'), isFalse);
    return bytes;
  }

  test('restores on a new phone with the phrase alone', () async {
    final backup = await backupFromOldPhone();
    final phone = _Device(base, 'new');
    await phone.auth.init();

    final ok = await phone.backups.restore(
      backup: backup,
      words: phrase,
      newPin: '305718',
    );
    expect(ok, isTrue);
    expect((await phone.notes.loadAll()).single.body, 'Code 4417');

    // The new PIN works on the new phone; recovery still works too.
    phone.auth.lock();
    expect(await phone.auth.unlockWithPin('305718'), isTrue);
    expect(await phone.auth.verifyRecoveryPhrase(phrase), isTrue);
  });

  test('a wrong phrase opens nothing and writes nothing', () async {
    final backup = await backupFromOldPhone();
    final phone = _Device(base, 'new');
    final ok = await phone.backups.restore(
      backup: backup,
      words: RecoveryPhrase.generate(),
      newPin: '305718',
    );
    expect(ok, isFalse);
    expect(await phone.paths.header.exists(), isFalse);
  });

  test('any altered byte is rejected', () async {
    final backup = await backupFromOldPhone();
    for (final at in [2, 10, backup.length ~/ 2, backup.length - 1]) {
      final tampered = Uint8List.fromList(backup)..[at] ^= 1;
      final phone = _Device(base, 'tamper$at');
      // Depending on the byte, the header no longer parses, the recovery
      // envelope no longer opens, or a payload segment fails its tag.
      try {
        final ok = await phone.backups.restore(
          backup: tampered,
          words: phrase,
          newPin: '305718',
        );
        expect(ok, isFalse, reason: 'byte $at');
      } on BackupFormatException {
        // Rejected outright: also fine.
      }
      expect(await phone.paths.header.exists(), isFalse);
    }
  });

  test('a random file is not mistaken for a backup', () async {
    final phone = _Device(base, 'new');
    await expectLater(
      phone.backups.restore(
        backup: VaultCrypto.randomBytes(300),
        words: phrase,
        newPin: '305718',
      ),
      throwsA(isA<BackupFormatException>()),
    );
  });

  test(
    'a crafted backup cannot write outside the vault (path traversal)',
    () async {
      // Build a validly encrypted backup whose archive names "../evil.bin".
      final old = _Device(base, 'old');
      await old.auth.createVault(pin: '482915', recoveryPhrase: phrase);
      final env = old.auth.recoveryEnvelope!;
      final header = BytesBuilder()
        ..add('VBAK'.codeUnits)
        ..addByte(1)
        ..add([0, env.salt.length])
        ..add(env.salt)
        ..add([0, env.wrap.length])
        ..add(env.wrap);
      final headerBytes = header.takeBytes();
      final name = utf8.encode('../evil.bin');
      final archive = [
        0, name.length, ...name,
        0, 0, 0, 0, 0, 0, 0, 1, 42, //
        0, 0,
      ];
      final key = await VaultCrypto.subkey(old.key.master, 'vault:backup:v1');
      final payload = await VaultStreamCipher.encryptBytes(
        archive,
        key: key,
        associatedData: headerBytes,
      );
      final crafted = Uint8List.fromList([...headerBytes, ...payload]);

      final phone = _Device(base, 'new');
      await expectLater(
        phone.backups.restore(backup: crafted, words: phrase, newPin: '305718'),
        throwsA(isA<BackupFormatException>()),
      );
      expect(
        await File('${phone.paths.root.parent.path}/evil.bin').exists(),
        isFalse,
      );
    },
  );
}
