import 'package:flutter_test/flutter_test.dart';
import 'package:secure_files_application/features/authentication/domain/recovery_phrase.dart';

void main() {
  // Official BIP39 test vector: 128 zero bits of entropy.
  const zeroVector = [
    'abandon', 'abandon', 'abandon', 'abandon', 'abandon', 'abandon', //
    'abandon', 'abandon', 'abandon', 'abandon', 'abandon', 'about',
  ];

  test('generates 12 words with a valid checksum', () {
    final phrase = RecoveryPhrase.generate();
    expect(phrase, hasLength(12));
    expect(RecoveryPhrase.isValid(phrase), isTrue);
  });

  test('two phrases are different', () {
    expect(RecoveryPhrase.generate(), isNot(equals(RecoveryPhrase.generate())));
  });

  test('matches the BIP39 reference vector', () {
    expect(RecoveryPhrase.entropyOf(zeroVector), List.filled(16, 0));
  });

  test('a wrong last word fails the checksum', () {
    final broken = [...zeroVector]..[11] = 'abandon';
    expect(RecoveryPhrase.isValid(broken), isFalse);
  });

  test('unknown words and wrong lengths are rejected', () {
    expect(RecoveryPhrase.isValid([...zeroVector]..[3] = 'notaword'), isFalse);
    expect(RecoveryPhrase.isValid(zeroVector.sublist(0, 11)), isFalse);
  });

  test('normalise tolerates case and extra whitespace', () {
    expect(RecoveryPhrase.normalise('  Abandon   ABOUT\nzoo '), [
      'abandon',
      'about',
      'zoo',
    ]);
  });
}
