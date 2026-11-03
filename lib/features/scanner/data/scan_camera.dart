import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../../core/security/auto_lock_guard.dart';

class CameraUnavailableException implements Exception {
  const CameraUnavailableException(this.reason);

  final String reason;
}

/// The camera as the scanner needs it. Swappable so the scan flow can be
/// tested on machines without a camera.
abstract interface class ScanCamera {
  /// Throws [CameraUnavailableException] if there is no camera or the user
  /// denied permission.
  Future<void> start();

  /// Returns the photo as JPEG bytes, in memory only.
  Future<Uint8List> capture();

  Future<void> setTorch(bool on);

  Future<void> stop();

  Widget buildPreview();
}

class DeviceScanCamera implements ScanCamera {
  CameraController? _controller;

  @override
  Future<void> start() async {
    if (_controller?.value.isInitialized ?? false) return;
    try {
      // The permission dialog briefly backgrounds the app.
      await AutoLockGuard.run(() async {
        final cameras = await availableCameras();
        if (cameras.isEmpty) {
          throw const CameraUnavailableException('No camera found');
        }
        final back = cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.back,
          orElse: () => cameras.first,
        );
        final controller = CameraController(
          back,
          ResolutionPreset.veryHigh,
          enableAudio: false,
          imageFormatGroup: ImageFormatGroup.jpeg,
        );
        await controller.initialize();
        await controller.setFlashMode(FlashMode.off);
        _controller = controller;
      });
    } on CameraException catch (e) {
      throw CameraUnavailableException(e.code);
    }
  }

  @override
  Future<Uint8List> capture() async {
    final controller = _controller;
    if (controller == null) throw const CameraUnavailableException('Stopped');
    final shot = await controller.takePicture();
    final bytes = await shot.readAsBytes();
    // The plugin writes the photo to the cache; remove the plaintext copy
    // immediately (threat model L7).
    final file = File(shot.path);
    if (await file.exists()) await file.delete();
    return bytes;
  }

  @override
  Future<void> setTorch(bool on) async =>
      _controller?.setFlashMode(on ? FlashMode.torch : FlashMode.off);

  @override
  Future<void> stop() async {
    final controller = _controller;
    _controller = null;
    await controller?.dispose();
  }

  @override
  Widget buildPreview() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox.shrink();
    }
    return CameraPreview(controller);
  }
}
