import '../domain/files_repository.dart';
import '../domain/vault_file.dart';

/// PREVIEW ONLY: sample documents kept in memory.
class FakeFilesRepository implements FilesRepository {
  FakeFilesRepository() : _files = _seed();

  final List<VaultFile> _files;
  int _counter = 0;

  static List<VaultFile> _seed() {
    final now = DateTime.now();
    VaultFile f(
      String id,
      String name,
      FileKind kind,
      String folder,
      int kb,
      int daysAgo, {
      int pages = 1,
    }) => VaultFile(
      id: id,
      name: name,
      kind: kind,
      folder: folder,
      sizeBytes: kb * 1024,
      modifiedAt: now.subtract(Duration(days: daysAgo, hours: daysAgo * 3)),
      pageCount: pages,
    );

    return [
      f('f1', 'Passport.pdf', FileKind.pdf, 'Identity', 2400, 2, pages: 2),
      f('f2', 'Driving licence.jpg', FileKind.image, 'Identity', 1800, 40),
      f(
        'f3',
        'Tax return 2025.pdf',
        FileKind.pdf,
        'Finance',
        5100,
        12,
        pages: 9,
      ),
      f('f4', 'Bank statements.xlsx', FileKind.spreadsheet, 'Finance', 640, 5),
      f('f5', 'Employment contract.docx', FileKind.document, 'Work', 380, 90),
      f('f6', 'Offer letter.pdf', FileKind.pdf, 'Work', 720, 120, pages: 3),
      f(
        'f7',
        'Vaccination record.pdf',
        FileKind.pdf,
        'Medical',
        950,
        30,
        pages: 2,
      ),
      f(
        'f8',
        'Insurance policy.pdf',
        FileKind.pdf,
        'Medical',
        3300,
        60,
        pages: 14,
      ),
      f('f9', 'Wi-Fi and router codes.txt', FileKind.text, 'Personal', 2, 7),
      f('f10', 'Property papers.zip', FileKind.archive, 'Finance', 12800, 200),
    ];
  }

  @override
  Future<List<VaultFile>> loadAll() async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    return List.unmodifiable(_files);
  }

  @override
  Future<List<VaultFile>> importFromPicker() async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    final n = ++_counter;
    final file = VaultFile(
      id: 'import-file-$n-${DateTime.now().microsecondsSinceEpoch}',
      name: 'Imported document $n.pdf',
      kind: FileKind.pdf,
      folder: 'Work',
      sizeBytes: 820 * 1024,
      modifiedAt: DateTime.now(),
      pageCount: 2,
    );
    _files.insert(0, file);
    return [file];
  }

  @override
  Future<VaultFile> addScan({
    required String name,
    required int pageCount,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final file = VaultFile(
      id: 'scan-${DateTime.now().microsecondsSinceEpoch}',
      name: name.endsWith('.pdf') ? name : '$name.pdf',
      kind: FileKind.pdf,
      folder: 'Scans',
      sizeBytes: pageCount * 410 * 1024,
      modifiedAt: DateTime.now(),
      pageCount: pageCount,
    );
    _files.insert(0, file);
    return file;
  }

  @override
  Future<VaultFile> rename(String id, String name) async {
    final index = _files.indexWhere((f) => f.id == id);
    final renamed = _files[index].copyWith(
      name: name,
      modifiedAt: DateTime.now(),
    );
    _files[index] = renamed;
    return renamed;
  }

  @override
  Future<void> delete(String id) async => _files.removeWhere((f) => f.id == id);
}
