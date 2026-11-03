import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

class Thumbnail {
  const Thumbnail({
    required this.png,
    required this.width,
    required this.height,
  });

  final Uint8List png;

  /// Dimensions of the original image.
  final int width;
  final int height;
}

abstract interface class Thumbnailer {
  /// Returns null if the format cannot be decoded (e.g. HEIC on some
  /// devices); the item is still stored, just without a preview.
  Future<Thumbnail?> make(Uint8List imageBytes);
}

/// Decodes with Flutter's image codecs, entirely in memory. Reads the
/// dimensions from the header first so a 12 MP photo is decoded straight
/// to thumbnail size instead of full resolution.
class FlutterThumbnailer implements Thumbnailer {
  const FlutterThumbnailer({this.maxSide = 480});

  final int maxSide;

  @override
  Future<Thumbnail?> make(Uint8List imageBytes) async {
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    try {
      buffer = await ui.ImmutableBuffer.fromUint8List(imageBytes);
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      final w = descriptor.width;
      final h = descriptor.height;
      final scale = math.min(1.0, maxSide / math.max(w, h));
      final codec = await descriptor.instantiateCodec(
        targetWidth: math.max(1, (w * scale).round()),
        targetHeight: math.max(1, (h * scale).round()),
      );
      final frame = await codec.getNextFrame();
      final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      frame.image.dispose();
      codec.dispose();
      if (data == null) return null;
      return Thumbnail(png: data.buffer.asUint8List(), width: w, height: h);
    } on Exception {
      return null;
    } finally {
      descriptor?.dispose();
      buffer?.dispose();
    }
  }
}
