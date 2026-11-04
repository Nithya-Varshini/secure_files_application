// Generates every launcher-icon asset from the artwork in
// assets/branding/kwam_icon_source.png, so the adaptive icon, the legacy PNGs
// and the Play Store icon all match.
//
//   dart run tool/generate_icon.dart
//
// Android crops every launcher icon with its own mask (circle, squircle,
// rounded square) and shows only the central 72 of the 108 x 108 dp canvas.
// So the source's own rounded tile and rim are dropped: the artwork inside it
// (arches, glow, floor light) is cropped, scaled so the arches stay inside
// the 66 dp safe circle, and set on a blurred extension of its own background.
import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

const _source = 'assets/branding/kwam_icon_source.png';
const _res = 'android/app/src/main/res';

// Square crop of the source around the arches (source pixels).
const _cropX = 157, _cropY = 80, _cropSize = 700;

// Master canvas: 108 dp at 10 px/dp. The crop fills the central 56 dp.
const _master = 1080;
const _artSize = 560;
const _feather = 70; // px of soft blend between art and extended background

void main() {
  final source = img.decodePng(File(_source).readAsBytesSync())!;
  final art = img.copyCrop(
    source,
    x: _cropX,
    y: _cropY,
    width: _cropSize,
    height: _cropSize,
  );
  final master = _compose(art);

  // Adaptive icon (Android 8+): the artwork is the background layer.
  const adaptive = {
    'mdpi': 108,
    'hdpi': 162,
    'xhdpi': 216,
    'xxhdpi': 324,
    'xxxhdpi': 432,
  };
  adaptive.forEach(
    (dpi, px) => _save(
      '$_res/mipmap-$dpi/ic_launcher_background.png',
      _resize(master, px),
    ),
  );

  // Legacy icon (Android 7): the same central 72 dp, rounded square.
  final visible = img.copyCrop(
    master,
    x: _master ~/ 6,
    y: _master ~/ 6,
    width: _master * 2 ~/ 3,
    height: _master * 2 ~/ 3,
  );
  const legacy = {
    'mdpi': 48,
    'hdpi': 72,
    'xhdpi': 96,
    'xxhdpi': 144,
    'xxxhdpi': 192,
  };
  legacy.forEach(
    (dpi, px) => _save(
      '$_res/mipmap-$dpi/ic_launcher.png',
      _roundCorners(_resize(visible, px)),
    ),
  );

  // Play Store listing icon: full square, Play applies its own mask.
  _save('assets/branding/play_store_icon_512.png', _resize(visible, 512));

  _writeXml();
  stdout.writeln('Icons generated.');
}

/// Sharp artwork centred on the canvas. Outside it, the artwork's own blurred
/// edge colours are extended outwards (edge clamp), so the dark background
/// and the floor light continue to the canvas edge without a seam.
img.Image _compose(img.Image art) {
  final sharp = _resize(art, _artSize);
  final soft = img.gaussianBlur(_resize(art, 140), radius: 6);
  final out = img.Image(width: _master, height: _master);
  const offset = (_master - _artSize) ~/ 2;
  for (var y = 0; y < _master; y++) {
    for (var x = 0; x < _master; x++) {
      final ax = x - offset, ay = y - offset;
      final b = soft.getPixel(
        (ax * 140 ~/ _artSize).clamp(0, 139),
        (ay * 140 ~/ _artSize).clamp(0, 139),
      );
      var r = b.r.toDouble(), g = b.g.toDouble(), bl = b.b.toDouble();
      if (ax >= 0 && ay >= 0 && ax < _artSize && ay < _artSize) {
        final edge = math.min(
          math.min(ax, _artSize - 1 - ax),
          math.min(ay, _artSize - 1 - ay),
        );
        final t = (edge / _feather).clamp(0.0, 1.0);
        final a = t * t * (3 - 2 * t); // smoothstep
        final s = sharp.getPixel(ax, ay);
        r += (s.r - r) * a;
        g += (s.g - g) * a;
        bl += (s.b - bl) * a;
      }
      out.setPixelRgb(x, y, r.round(), g.round(), bl.round());
    }
  }
  return out;
}

img.Image _resize(img.Image image, int size) => img.copyResize(
  image,
  width: size,
  height: size,
  interpolation: img.Interpolation.average,
);

img.Image _roundCorners(img.Image image) {
  final size = image.width;
  final out = img.Image(width: size, height: size, numChannels: 4);
  final r = size * 0.22, half = size / 2;
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final qx = (x + 0.5 - half).abs() - (half - r);
      final qy = (y + 0.5 - half).abs() - (half - r);
      final outside = math.sqrt(
        math.pow(math.max(qx, 0), 2) + math.pow(math.max(qy, 0), 2),
      );
      final d = outside + math.min(math.max(qx, qy), 0) - r;
      final p = image.getPixel(x, y);
      out.setPixelRgba(
        x,
        y,
        p.r,
        p.g,
        p.b,
        ((0.5 - d).clamp(0.0, 1.0) * 255).round(),
      );
    }
  }
  return out;
}

void _save(String path, img.Image image) => File(path)
  ..createSync(recursive: true)
  ..writeAsBytesSync(img.encodePng(image));

/// Arch outline for the Android 13+ themed (monochrome) icon, traced from the
/// artwork: a half ring over (cx, cy) with straight legs down to [bottom].
String _arch(double cx, double cy, double r, double width, double bottom) {
  String f(double v) => v.toStringAsFixed(2);
  final ro = r + width / 2, ri = r - width / 2;
  return 'M${f(cx - ro)},${f(bottom)}L${f(cx - ro)},${f(cy)}'
      'A${f(ro)},${f(ro)} 0 0,1 ${f(cx + ro)},${f(cy)}'
      'L${f(cx + ro)},${f(bottom)}L${f(cx + ri)},${f(bottom)}'
      'L${f(cx + ri)},${f(cy)}'
      'A${f(ri)},${f(ri)} 0 0,0 ${f(cx - ri)},${f(cy)}'
      'L${f(cx - ri)},${f(bottom)}Z';
}

void _writeXml() {
  const header =
      '<?xml version="1.0" encoding="utf-8"?>\n'
      '<!-- Generated by tool/generate_icon.dart. Do not edit. -->\n';
  File('$_res/drawable/ic_launcher_monochrome.xml').writeAsStringSync(
    '$header'
    '<vector xmlns:android="http://schemas.android.com/apk/res/android"\n'
    '    android:width="108dp" android:height="108dp"\n'
    '    android:viewportWidth="108" android:viewportHeight="108">\n'
    '    <path android:fillColor="#FFFFFFFF"\n'
    '        android:pathData="${_arch(54, 54.7, 18.8, 7.6, 74.6)}" />\n'
    '    <path android:fillColor="#FFFFFFFF"\n'
    '        android:pathData="${_arch(54, 58.2, 9.3, 5.8, 74.6)}" />\n'
    '</vector>\n',
  );
  File('$_res/mipmap-anydpi-v26/ic_launcher.xml')
    ..createSync(recursive: true)
    ..writeAsStringSync(
      '$header'
      '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
      '    <background android:drawable="@mipmap/ic_launcher_background" />\n'
      '    <foreground android:drawable="@android:color/transparent" />\n'
      '    <!-- Android 13+ themed icons -->\n'
      '    <monochrome android:drawable="@drawable/ic_launcher_monochrome" />\n'
      '</adaptive-icon>\n',
    );
}
