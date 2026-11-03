/// System pickers (Photo Picker, file chooser, camera) open in another
/// activity, which sends this app to the background. Without this guard,
/// "lock immediately" would lock the vault halfway through an import.
abstract final class AutoLockGuard {
  static int _depth = 0;

  static bool get suspended => _depth > 0;

  static Future<T> run<T>(Future<T> Function() action) async {
    _depth++;
    try {
      return await action();
    } finally {
      _depth--;
    }
  }
}
