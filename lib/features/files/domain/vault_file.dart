import 'package:equatable/equatable.dart';

enum FileKind { pdf, document, spreadsheet, image, text, archive, other }

abstract final class VaultFolders {
  static const unsorted = 'Unsorted';
  static const scans = 'Scans';
  static const all = [
    'Identity',
    'Finance',
    'Work',
    'Medical',
    scans,
    unsorted,
  ];
}

class VaultFile extends Equatable {
  const VaultFile({
    required this.id,
    required this.name,
    required this.kind,
    required this.mimeType,
    required this.folder,
    required this.sizeBytes,
    required this.modifiedAt,
  });

  final String id;
  final String name;
  final FileKind kind;
  final String mimeType;
  final String folder;
  final int sizeBytes;
  final DateTime modifiedAt;

  static FileKind kindFor(String mimeType, String name) {
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    if (mimeType == 'application/pdf' || ext == 'pdf') return FileKind.pdf;
    if (mimeType.startsWith('image/')) return FileKind.image;
    if (const {'doc', 'docx', 'odt', 'rtf', 'pages'}.contains(ext)) {
      return FileKind.document;
    }
    if (const {'xls', 'xlsx', 'ods', 'csv', 'numbers'}.contains(ext)) {
      return FileKind.spreadsheet;
    }
    if (const {'zip', 'rar', '7z', 'tar', 'gz'}.contains(ext)) {
      return FileKind.archive;
    }
    if (mimeType.startsWith('text/') || const {'txt', 'md'}.contains(ext)) {
      return FileKind.text;
    }
    return FileKind.other;
  }

  VaultFile copyWith({String? name, String? folder, DateTime? modifiedAt}) =>
      VaultFile(
        id: id,
        name: name ?? this.name,
        kind: kind,
        mimeType: mimeType,
        folder: folder ?? this.folder,
        sizeBytes: sizeBytes,
        modifiedAt: modifiedAt ?? this.modifiedAt,
      );

  @override
  List<Object?> get props => [
    id,
    name,
    kind,
    mimeType,
    folder,
    sizeBytes,
    modifiedAt,
  ];
}
