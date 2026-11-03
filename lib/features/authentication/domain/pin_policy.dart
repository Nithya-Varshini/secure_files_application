/// Rejects PINs that attackers try first.
///
/// A 6-digit PIN has 10^6 combinations, but people cluster on a few hundred
/// of them; blocking the obvious ones raises the real cost of guessing.
abstract final class PinPolicy {
  static const length = 6;

  static const _common = {
    '123456',
    '654321',
    '123123',
    '121212',
    '112233',
    '159753',
    '147258',
    '246810',
    '102030',
    '696969',
  };

  /// Returns a user-facing reason if [pin] is too easy to guess, else null.
  static String? weaknessReason(String pin) {
    if (pin.length != length || int.tryParse(pin) == null) {
      return 'Use exactly $length digits.';
    }
    if (pin.split('').toSet().length == 1) {
      return 'Avoid repeating one digit.';
    }
    if (_isSequence(pin, 1) || _isSequence(pin, -1)) {
      return 'Avoid counting up or down.';
    }
    if (_common.contains(pin)) {
      return 'That PIN is among the most guessed. Try another.';
    }
    return null;
  }

  static bool _isSequence(String pin, int step) {
    for (var i = 1; i < pin.length; i++) {
      final previous = int.parse(pin[i - 1]);
      final current = int.parse(pin[i]);
      if ((previous + step) % 10 != current) return false;
    }
    return true;
  }
}
