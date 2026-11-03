import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Toggles Android's FLAG_SECURE: blocks screenshots, screen recording and
/// the recent-apps thumbnail. It does not stop accessibility services or a
/// camera pointed at the screen (threat model L8, L9).
abstract final class SecureWindow {
  static const _channel = MethodChannel('vault/window');

  static Future<void> setSecure(bool enabled) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    await _channel.invokeMethod<void>('setSecure', {'enabled': enabled});
  }
}
