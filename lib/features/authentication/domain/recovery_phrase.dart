import 'package:bip39_mnemonic/bip39_mnemonic.dart';

import '../../../core/crypto/vault_crypto.dart';

/// The 12-word recovery phrase, in standard BIP39 form: 128 bits of random
/// entropy plus a 4-bit checksum, written with the official 2048-word
/// English list (11 bits per word).
///
/// 2^128 possibilities cannot be brute-forced at any speed, so the phrase is
/// turned into a key with HKDF rather than a slow password KDF.
abstract final class RecoveryPhrase {
  static const wordCount = 12;

  static List<String> generate() =>
      Mnemonic(VaultCrypto.randomBytes(16), Language.english).words;

  static List<String> normalise(String input) => input
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();

  /// True if every word is in the list and the checksum matches, which
  /// catches most typos and swapped words before any key is tried.
  static bool isValid(List<String> words) => entropyOf(words) != null;

  static List<int>? entropyOf(List<String> words) {
    if (words.length != wordCount) return null;
    try {
      return Mnemonic.fromWords(words: words).entropy;
    } on Exception {
      return null;
    } on Error {
      return null;
    }
  }
}
