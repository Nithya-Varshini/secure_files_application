import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'scan_page.dart';

/// Turns captured pages into a PDF entirely in memory, on a background
/// isolate so the UI stays smooth. The result is encrypted straight away by
/// the caller; no intermediate image or PDF is ever written to disk.
abstract final class ScanPdf {
  /// Long side of each page image; enough for print-quality A4.
  static const maxSide = 2000;

  static Future<Uint8List> build(List<ScanPage> pages) {
    final input = [
      for (final p in pages) (p.jpeg, p.quarterTurns, p.filter.index),
    ];
    return Isolate.run(() => _build(input));
  }

  static Future<Uint8List> _build(List<(Uint8List, int, int)> pages) async {
    final doc = pw.Document();
    for (final (bytes, turns, filterIndex) in pages) {
      final jpeg = processPage(bytes, turns, ScanFilter.values[filterIndex]);
      final image = pw.MemoryImage(jpeg);
      final landscape = (image.width ?? 1) > (image.height ?? 1);
      doc.addPage(
        pw.Page(
          pageFormat: landscape ? PdfPageFormat.a4.landscape : PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (_) =>
              pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain)),
        ),
      );
    }
    return doc.save();
  }

  /// Applies orientation, rotation, size limit and filter to one page.
  static Uint8List processPage(Uint8List jpeg, int turns, ScanFilter filter) {
    var image = img.decodeImage(jpeg);
    if (image == null) throw const FormatException('Unreadable page');
    image = img.bakeOrientation(image);
    if (turns % 4 != 0) image = img.copyRotate(image, angle: 90 * (turns % 4));
    final longSide = image.width > image.height ? image.width : image.height;
    if (longSide > maxSide) {
      image = image.width >= image.height
          ? img.copyResize(image, width: maxSide)
          : img.copyResize(image, height: maxSide);
    }
    switch (filter) {
      case ScanFilter.original:
        break;
      case ScanFilter.blackWhite:
        image = img.contrast(img.grayscale(image), contrast: 160);
      case ScanFilter.enhanced:
        image = img.adjustColor(image, contrast: 1.2, brightness: 1.05);
    }
    return img.encodeJpg(image, quality: 85);
  }
}
