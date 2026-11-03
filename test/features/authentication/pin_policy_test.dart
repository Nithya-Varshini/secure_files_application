import 'package:flutter_test/flutter_test.dart';
import 'package:secure_files_application/features/authentication/domain/pin_policy.dart';

void main() {
  group('PinPolicy.weaknessReason', () {
    test('accepts an unremarkable 6-digit PIN', () {
      expect(PinPolicy.weaknessReason('482915'), isNull);
    });

    test('rejects wrong length or non-digits', () {
      expect(PinPolicy.weaknessReason('1234'), isNotNull);
      expect(PinPolicy.weaknessReason('12a456'), isNotNull);
    });

    test('rejects a repeated digit', () {
      expect(PinPolicy.weaknessReason('777777'), isNotNull);
    });

    test('rejects ascending and descending runs, including wrap-around', () {
      expect(PinPolicy.weaknessReason('345678'), isNotNull);
      expect(PinPolicy.weaknessReason('987654'), isNotNull);
      expect(PinPolicy.weaknessReason('789012'), isNotNull);
    });

    test('rejects commonly guessed PINs', () {
      expect(PinPolicy.weaknessReason('121212'), isNotNull);
      expect(PinPolicy.weaknessReason('112233'), isNotNull);
    });
  });
}
