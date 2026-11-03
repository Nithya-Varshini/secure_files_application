import 'dart:typed_data';

enum ScanFilter { original, blackWhite, enhanced }

/// One captured page, held only in memory until it is saved as an
/// encrypted PDF.
class ScanPage {
  const ScanPage({
    required this.id,
    required this.jpeg,
    this.quarterTurns = 0,
    this.filter = ScanFilter.enhanced,
  });

  final int id;
  final Uint8List jpeg;
  final int quarterTurns;
  final ScanFilter filter;

  ScanPage copyWith({int? quarterTurns, ScanFilter? filter}) => ScanPage(
    id: id,
    jpeg: jpeg,
    quarterTurns: quarterTurns ?? this.quarterTurns,
    filter: filter ?? this.filter,
  );
}
