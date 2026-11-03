import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/widgets.dart';
import 'package:image/image.dart' as img;
import 'package:secure_files_application/core/crypto/vault_crypto.dart';
import 'package:secure_files_application/core/platform/biometric_auth.dart';
import 'package:secure_files_application/core/platform/hardware_keystore.dart';
import 'package:secure_files_application/core/platform/pickers.dart';
import 'package:secure_files_application/features/scanner/data/scan_camera.dart';

/// Stands in for the Android Keystore: each alias gets a random key that
/// lives only in this object, just as a hardware key never leaves the chip.
class FakeKeystore implements HardwareKeystore {
  final _keys = <String, SecretKeyData>{};
  final _invalidated = <String>{};

  Iterable<String> get aliases => _keys.keys;

  void invalidate(String alias) => _invalidated.add(alias);

  @override
  bool get isAvailable => true;

  @override
  Future<Uint8List> wrap(
    String alias,
    Uint8List data, {
    bool requireUserAuth = false,
  }) {
    final key = _keys.putIfAbsent(alias, VaultCrypto.newKey);
    return VaultCrypto.seal(data, key, aad: VaultCrypto.label(alias));
  }

  @override
  Future<Uint8List> unwrap(String alias, Uint8List data) async {
    if (_invalidated.contains(alias)) throw const KeyInvalidatedException();
    final key = _keys[alias];
    if (key == null) throw const KeystoreException('MISSING');
    try {
      return await VaultCrypto.open(data, key, aad: VaultCrypto.label(alias));
    } on CryptoFailure {
      throw const KeystoreException('BAD_DATA');
    }
  }

  @override
  Future<void> delete(String alias) async {
    _keys.remove(alias);
    _invalidated.remove(alias);
  }
}

class FakeBiometrics implements BiometricAuth {
  bool accept = true;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<bool> authenticate(String reason) async => accept;
}

/// Returns a fixed set of "picked" photos instead of opening the system UI.
class FakeMediaPicker implements MediaPicker {
  @override
  Future<List<PickedFile>> pickPhotosAndVideos() async => [
    for (var i = 0; i < 3; i++)
      PickedFile(
        name: 'Holiday ${i + 1}.jpg',
        open: () => Stream.value(sampleJpeg(hue: i * 90)),
      ),
  ];
}

class FakeDocumentPicker implements DocumentPicker {
  final saved = <String>[];

  @override
  Future<List<PickedFile>> pickDocuments() async => [
    PickedFile(
      name: 'Wi-Fi codes.txt',
      open: () => Stream.value('Router: 7741-ALPHA'.codeUnits),
    ),
  ];

  @override
  Future<bool> saveCopy({
    required String name,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    saved.add(name);
    return true;
  }
}

/// A camera that "photographs" a generated page.
class FakeScanCamera implements ScanCamera {
  @override
  Future<void> start() async {}

  @override
  Future<Uint8List> capture() async => sampleJpeg(hue: 40);

  @override
  Future<void> setTorch(bool on) async {}

  @override
  Future<void> stop() async {}

  @override
  Widget buildPreview() => const ColoredBox(color: Color(0xFF444444));
}

Uint8List sampleJpeg({int hue = 0}) {
  final image = img.Image(width: 120, height: 160)
    ..clear(img.ColorRgb8(200, (hue * 2) % 255, (hue * 3) % 255));
  return img.encodeJpg(image);
}
