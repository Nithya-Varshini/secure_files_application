import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:secure_files_application/features/authentication/domain/recovery_phrase.dart';

void main() {
  test('demo word list has 128 unique words (7 bits each)', () {
    expect(RecoveryPhrase.demoWordListSize, 128);
  });

  test('generates 12 distinct words', () {
    final phrase = RecoveryPhrase.generate(random: Random(1));
    expect(phrase, hasLength(12));
    expect(phrase.toSet(), hasLength(12));
  });

  test('normalise tolerates case and extra whitespace', () {
    expect(RecoveryPhrase.normalise('  Apple   RIVER\nmint '), [
      'apple',
      'river',
      'mint',
    ]);
  });
}
