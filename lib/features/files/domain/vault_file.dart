import 'package:equatable/equatable.dart';

enum FileKind { pdf, document, spreadsheet, image, text, archive }

abstract final class VaultFolders {
  static const all = ['Identity', 'Finance', 'Work', 'Medical', 'Scans'];
}

class VaultFile extends Equatable {
  const VaultFile({
    required this.id,
    required this.name,
    required this.kind,
    required this.folder,
    required this.sizeBytes,
    required this.modifiedAt,
    this.pageCount = 1,
  });

  final String id;
  final String name;
  final FileKind kind;
  final String folder;
  final int sizeBytes;
  final DateTime modifiedAt;
  final int pageCount;

  VaultFile copyWith({String? name, String? folder, DateTime? modifiedAt}) =>
      VaultFile(
        id: id,
        name: name ?? this.name,
        kind: kind,
        folder: folder ?? this.folder,
        sizeBytes: sizeBytes,
        modifiedAt: modifiedAt ?? this.modifiedAt,
        pageCount: pageCount,
      );

  @override
  List<Object?> get props => [
    id,
    name,
    kind,
    folder,
    sizeBytes,
    modifiedAt,
    pageCount,
  ];
}
