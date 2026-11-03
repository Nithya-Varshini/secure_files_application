import 'package:equatable/equatable.dart';

enum ScanFilter { original, blackWhite, enhanced }

class ScanPage extends Equatable {
  const ScanPage({
    required this.id,
    required this.seed,
    this.quarterTurns = 0,
    this.filter = ScanFilter.enhanced,
  });

  final int id;
  final int seed;
  final int quarterTurns;
  final ScanFilter filter;

  ScanPage copyWith({int? quarterTurns, ScanFilter? filter}) => ScanPage(
    id: id,
    seed: seed,
    quarterTurns: quarterTurns ?? this.quarterTurns,
    filter: filter ?? this.filter,
  );

  @override
  List<Object?> get props => [id, seed, quarterTurns, filter];
}
