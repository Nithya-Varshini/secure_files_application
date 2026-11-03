import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_files_application/core/crypto/vault_crypto.dart';

void main() {
  final aad = VaultCrypto.label('test:v1');

  group('seal / open', () {
    test('round-trips', () async {
      final key = VaultCrypto.newKey();
      final sealed = await VaultCrypto.seal(
        utf8.encode('hello'),
        key,
        aad: aad,
      );
      final opened = await VaultCrypto.open(sealed, key, aad: aad);
      expect(utf8.decode(opened), 'hello');
    });

    test('never repeats a nonce for the same plaintext', () async {
      final key = VaultCrypto.newKey();
      final a = await VaultCrypto.seal([1, 2, 3], key, aad: aad);
      final b = await VaultCrypto.seal([1, 2, 3], key, aad: aad);
      expect(a.sublist(0, 12), isNot(equals(b.sublist(0, 12))));
      expect(a, isNot(equals(b)));
    });

    test('detects a single flipped bit anywhere', () async {
      final key = VaultCrypto.newKey();
      final sealed = await VaultCrypto.seal(
        utf8.encode('secret'),
        key,
        aad: aad,
      );
      for (var i = 0; i < sealed.length; i++) {
        final tampered = [...sealed]..[i] ^= 0x01;
        await expectLater(
          VaultCrypto.open(tampered, key, aad: aad),
          throwsA(isA<CryptoFailure>()),
          reason: 'byte $i',
        );
      }
    });

    test('rejects the wrong key', () async {
      final sealed = await VaultCrypto.seal(
        [9],
        VaultCrypto.newKey(),
        aad: aad,
      );
      await expectLater(
        VaultCrypto.open(sealed, VaultCrypto.newKey(), aad: aad),
        throwsA(isA<CryptoFailure>()),
      );
    });

    test('rejects a ciphertext replayed in another context (AAD)', () async {
      final key = VaultCrypto.newKey();
      final sealed = await VaultCrypto.seal([9], key, aad: aad);
      await expectLater(
        VaultCrypto.open(sealed, key, aad: VaultCrypto.label('other:v1')),
        throwsA(isA<CryptoFailure>()),
      );
    });

    test('rejects input shorter than nonce + tag', () async {
      await expectLater(
        VaultCrypto.open([1, 2, 3], VaultCrypto.newKey(), aad: aad),
        throwsA(isA<CryptoFailure>()),
      );
    });
  });

  group('key derivation', () {
    test('Argon2id is deterministic for the same PIN and salt', () async {
      final salt = VaultCrypto.randomBytes(16);
      final a = await VaultCrypto.derivePinKey(
        '482915',
        salt,
        KdfParams.testing,
      );
      final b = await VaultCrypto.derivePinKey(
        '482915',
        salt,
        KdfParams.testing,
      );
      expect(await a.extractBytes(), await b.extractBytes());
    });

    test('a different PIN or salt gives a different key', () async {
      final salt = VaultCrypto.randomBytes(16);
      final base = await VaultCrypto.derivePinKey(
        '482915',
        salt,
        KdfParams.testing,
      );
      final otherPin = await VaultCrypto.derivePinKey(
        '482916',
        salt,
        KdfParams.testing,
      );
      final otherSalt = await VaultCrypto.derivePinKey(
        '482915',
        VaultCrypto.randomBytes(16),
        KdfParams.testing,
      );
      final bytes = await base.extractBytes();
      expect(await otherPin.extractBytes(), isNot(equals(bytes)));
      expect(await otherSalt.extractBytes(), isNot(equals(bytes)));
    });

    test('HKDF gives independent keys per purpose', () async {
      final master = VaultCrypto.newKey();
      final index = await VaultCrypto.subkey(master, 'index');
      final backup = await VaultCrypto.subkey(master, 'backup');
      expect(await index.extractBytes(), hasLength(32));
      expect(
        await index.extractBytes(),
        isNot(equals(await backup.extractBytes())),
      );
    });

    test('KDF parameters survive a JSON round trip', () {
      final json = KdfParams.recommended.toJson();
      final back = KdfParams.fromJson(json);
      expect(back.memoryKiB, 19456);
      expect(back.iterations, 2);
    });

    test('destroyed keys can no longer be used', () async {
      final key = VaultCrypto.newKey()..destroy();
      expect(key.isDestroyed, isTrue);
      await expectLater(
        VaultCrypto.seal([1], key, aad: aad),
        throwsA(anything),
      );
    });
  });

  test('random bytes are not constant', () {
    final a = VaultCrypto.randomBytes(32);
    final b = VaultCrypto.randomBytes(32);
    expect(a, isNot(equals(b)));
    expect(SecretKeyData(a).bytes, hasLength(32));
  });
}
