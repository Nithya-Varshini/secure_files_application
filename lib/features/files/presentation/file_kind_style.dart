import 'package:flutter/material.dart';

import '../domain/vault_file.dart';

extension FileKindStyle on FileKind {
  String get label => switch (this) {
    FileKind.pdf => 'PDF',
    FileKind.document => 'Document',
    FileKind.spreadsheet => 'Spreadsheet',
    FileKind.image => 'Image',
    FileKind.text => 'Text',
    FileKind.archive => 'Archive',
  };

  IconData get icon => switch (this) {
    FileKind.pdf => Icons.picture_as_pdf_rounded,
    FileKind.document => Icons.article_rounded,
    FileKind.spreadsheet => Icons.table_chart_rounded,
    FileKind.image => Icons.image_rounded,
    FileKind.text => Icons.notes_rounded,
    FileKind.archive => Icons.folder_zip_rounded,
  };

  Color get color => switch (this) {
    FileKind.pdf => const Color(0xFFE5484D),
    FileKind.document => const Color(0xFF3B82F6),
    FileKind.spreadsheet => const Color(0xFF16A34A),
    FileKind.image => const Color(0xFF8B5CF6),
    FileKind.text => const Color(0xFF64748B),
    FileKind.archive => const Color(0xFFD97706),
  };
}

class FileKindBadge extends StatelessWidget {
  const FileKindBadge({super.key, required this.kind, this.size = 44});

  final FileKind kind;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: kind.color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Icon(kind.icon, color: kind.color, size: size * 0.5),
    );
  }
}
