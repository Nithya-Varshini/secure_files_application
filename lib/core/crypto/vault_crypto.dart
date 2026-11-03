import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Any decryption or authentication failure. Deliberately carries no detail
/// that could act as an oracle: wrong key, wrong context and tampering all
/// look the same to the caller.
class CryptoFailure implements Exception {
  const CryptoFailure(this.message);

  final String message;

  @override
  String toString() => 'CryptoFailure: $message';
}

/// Argon2id cost parameters. Stored next to the salt so they can be raised
/// later without breaking existing vaults.
class KdfParams {
  const KdfParams({
    required this.memoryKiB,
    required this.iterations,
    required this.parallelism,
  });

  /// OWASP's minimum recommendation for Argon2id: 19 MiB, 2 passes, 1 lane.
  static const recommended = KdfParams(
    memoryKiB: 19456,
    iterations: 2,
    parallelism: 1,
  );

  /// Cheap parameters for automated tests only. Never use in production.
  static const testing = KdfParams(
    memoryKiB: 64,
    iterations: 1,
    parallelism: 1,
  );

  final int memoryKiB;
  final int iterations;
  final int parallelism;

  Map<String, Object> toJson() => {
    'alg': 'argon2id',
    'm': memoryKiB,
    't': iterations,
    'p': parallelism,
  };

  factory KdfParams.fromJson(Map<String, Object?> json) {
    if (json['alg'] != 'argon2id') throw const CryptoFailure('Unknown KDF');
    return KdfParams(
      memoryKiB: json['m']! as int,
      iterations: json['t']! as int,
      parallelism: json['p']! as int,
    );
  }
}

/// The vault's cryptographic primitives, built only from vetted algorithms:
/// AES-256-GCM (authenticated encryption), Argon2id (PIN stretching) and
/// HKDF-SHA256 (key separation). Nothing here is home-made cryptography.
abstract final class VaultCrypto {
  static const keyLength = 32;
  static const nonceLength = 12;
  static const macLength = 16;

  static final _aead = AesGcm.with256bits();
  static final _random = Random.secure();

  /// Bytes from the operating system's CSPRNG.
  static Uint8List randomBytes(int length) {
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = _random.nextInt(256);
    }
    return bytes;
  }

  static SecretKeyData newKey() => SecretKeyData(randomBytes(keyLength));

  static List<int> label(String text) => utf8.encode(text);

  /// Encrypts small values (wrapped keys, the metadata index).
  ///
  /// Output: `nonce (12) | ciphertext | tag (16)`. The random 96-bit nonce is
  /// safe for roughly 2^32 messages per key, far beyond what one vault key
  /// seals. [aad] binds the ciphertext to its purpose, so a blob sealed for
  /// one context cannot be replayed in another.
  static Future<Uint8List> seal(
    List<int> plaintext,
    SecretKey key, {
    required List<int> aad,
  }) async {
    final box = await _aead.encrypt(
      plaintext,
      secretKey: key,
      nonce: randomBytes(nonceLength),
      aad: aad,
    );
    return box.concatenation();
  }

  static Future<Uint8List> open(
    List<int> sealed,
    SecretKey key, {
    required List<int> aad,
  }) async {
    if (sealed.length < nonceLength + macLength) {
      throw const CryptoFailure('Ciphertext too short');
    }
    final box = SecretBox.fromConcatenation(
      sealed,
      nonceLength: nonceLength,
      macLength: macLength,
    );
    try {
      return Uint8List.fromList(
        await _aead.decrypt(box, secretKey: key, aad: aad),
      );
    } on SecretBoxAuthenticationError {
      throw const CryptoFailure('Authentication failed');
    }
  }

  /// Stretches a low-entropy PIN into a key-encryption key.
  static Future<SecretKeyData> derivePinKey(
    String pin,
    List<int> salt,
    KdfParams params,
  ) async {
    final kdf = Argon2id(
      parallelism: params.parallelism,
      memory: params.memoryKiB,
      iterations: params.iterations,
      hashLength: keyLength,
    );
    final key = await kdf.deriveKey(
      secretKey: SecretKey(utf8.encode(pin)),
      nonce: salt,
    );
    return SecretKeyData(await key.extractBytes());
  }

  /// Derives an independent key for one purpose from a high-entropy key.
  /// High-entropy inputs need no slow KDF; HKDF only separates contexts.
  static Future<SecretKeyData> subkey(
    SecretKey inputKey,
    String info, {
    List<int> salt = const [],
  }) {
    return Hkdf(
      hmac: Hmac.sha256(),
      outputLength: keyLength,
    ).deriveKey(secretKey: inputKey, nonce: salt, info: label(info));
  }

  /// Raw AES-GCM with a caller-built nonce; used by [VaultStreamCipher].
  static Future<Uint8List> encryptWithNonce(
    List<int> plaintext,
    SecretKey key, {
    required List<int> nonce,
    required List<int> aad,
  }) async {
    final box = await _aead.encrypt(
      plaintext,
      secretKey: key,
      nonce: nonce,
      aad: aad,
    );
    return box.concatenation(nonce: false);
  }

  static Future<Uint8List> decryptWithNonce(
    List<int> cipherTextAndTag,
    SecretKey key, {
    required List<int> nonce,
    required List<int> aad,
  }) async {
    if (cipherTextAndTag.length < macLength) {
      throw const CryptoFailure('Segment too short');
    }
    final split = cipherTextAndTag.length - macLength;
    final box = SecretBox(
      cipherTextAndTag.sublist(0, split),
      nonce: nonce,
      mac: Mac(cipherTextAndTag.sublist(split)),
    );
    try {
      return Uint8List.fromList(
        await _aead.decrypt(box, secretKey: key, aad: aad),
      );
    } on SecretBoxAuthenticationError {
      throw const CryptoFailure('Authentication failed');
    }
  }
}
