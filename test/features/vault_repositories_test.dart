import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:secure_files_application/core/crypto/vault_crypto.dart';
import 'package:secure_files_application/core/platform/pickers.dart';
import 'package:secure_files_application/core/platform/thumbnailer.dart';
import 'package:secure_files_application/core/security/vault_key.dart';
import 'package:secure_files_application/core/storage/blob_store.dart';
import 'package:secure_files_application/core/storage/encrypted_index.dart';
import 'package:secure_files_application/core/storage/vault_paths.dart';
import 'package:secure_files_application/features/files/data/local_files_repository.dart';
import 'package:secure_files_application/features/files/domain/vault_file.dart';
import 'package:secure_files_application/features/media_vault/data/local_media_repository.dart';
import 'package:secure_files_application/features/media_vault/domain/media_item.dart';
import 'package:secure_files_application/features/notes/data/local_notes_repository.dart';
import 'package:secure_files_application/features/notes/domain/note.dart';
import 'package:secure_files_application/features/scanner/domain/scan_page.dart';
import 'package:secure_files_application/features/scanner/domain/scan_pdf.dart';

class _FakeThumbnailer implements Thumbnailer {
  @override
  Future<Thumbnail?> make(Uint8List bytes) async =>
      Thumbnail(png: Uint8List.fromList([1, 2, 3]), width: 40, height: 30);
}

Uint8List _jpeg({int width = 60, int height = 80}) => img.encodeJpg(
  img.Image(width: width, height: height)..clear(img.ColorRgb8(240, 240, 240)),
);

PickedFile _picked(String name, List<int> bytes, {File? copy}) =>
    PickedFile(name: name, open: () => Stream.value(bytes), pluginCopy: copy);

void main() {
  late Directory dir;
  late VaultPaths paths;
  late VaultKey key;
  late EncryptedIndex index;
  late BlobStore blobs;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('vault_repos');
    paths = VaultPaths(
      root: Directory('${dir.path}/vault'),
      temp: Directory('${dir.path}/cache/tmp'),
    );
    await paths.ensure();
    key = VaultKey();
    await key.unlock(VaultCrypto.newKey());
    index = EncryptedIndex(paths, key);
    blobs = BlobStore(paths, key);
  });

  tearDown(() => dir.delete(recursive: true));

  Future<String> allVaultBytesAsText() async {
    final buffer = StringBuffer();
    await for (final f in paths.root.list(recursive: true)) {
      if (f is File) buffer.write(String.fromCharCodes(await f.readAsBytes()));
    }
    return buffer.toString();
  }

  group('media', () {
    test('imports photos with thumbnails and videos without', () async {
      final repo = LocalMediaRepository(index, blobs, _FakeThumbnailer());
      final added = await repo.import([
        _picked('beach.jpg', _jpeg()),
        _picked('clip.mp4', [0, 1, 2, 3]),
      ]);
      expect(added.map((m) => m.type), [MediaType.photo, MediaType.video]);
      expect(added.first.title, 'beach');
      expect(added.first.hasThumbnail, isTrue);
      expect(added.last.hasThumbnail, isFalse);
      expect(await repo.thumbnail(added.first.id), [1, 2, 3]);
      expect(await repo.original(added.first.id), _jpeg());
    });

    test('nothing readable lands on disk: not names, not content', () async {
      final repo = LocalMediaRepository(index, blobs, _FakeThumbnailer());
      await repo.import([_picked('PassportScan.txt', 'TOP SECRET'.codeUnits)]);
      final disk = await allVaultBytesAsText();
      expect(disk.contains('PassportScan'), isFalse);
      expect(disk.contains('TOP SECRET'), isFalse);
    });

    test("the picker plugin's plaintext copy is deleted", () async {
      final copy = File('${paths.cache.path}/picked.jpg');
      await copy.parent.create(recursive: true);
      await copy.writeAsBytes(_jpeg());
      final repo = LocalMediaRepository(index, blobs, _FakeThumbnailer());
      await repo.import([_picked('picked.jpg', _jpeg(), copy: copy)]);
      expect(await copy.exists(), isFalse);
    });

    test('favourites and deletion persist', () async {
      final repo = LocalMediaRepository(index, blobs, _FakeThumbnailer());
      final added = await repo.import([
        _picked('a.jpg', _jpeg()),
        _picked('b.jpg', _jpeg()),
      ]);
      await repo.setFavorite(added.first.id, favorite: true);
      await repo.delete({added.last.id});
      final fresh = LocalMediaRepository(index, blobs, _FakeThumbnailer());
      final items = await fresh.loadAll();
      expect(items, hasLength(1));
      expect(items.single.favorite, isTrue);
      // Two blobs (photo + thumbnail) remain for the surviving item.
      expect(await paths.blobs.list().length, 2);
    });

    test('videos decrypt to the temp folder only', () async {
      final repo = LocalMediaRepository(index, blobs, _FakeThumbnailer());
      final added = await repo.import([
        _picked('clip.mp4', [9, 8, 7]),
      ]);
      final file = await repo.openVideo(added.single.id);
      expect(file.path.startsWith(paths.temp.path), isTrue);
      expect(file.path.endsWith('.mp4'), isTrue);
      expect(await file.readAsBytes(), [9, 8, 7]);
    });
  });

  group('files', () {
    test('import, kinds, read back, rename, move, delete', () async {
      final repo = LocalFilesRepository(index, blobs);
      final added = await repo.import([
        _picked('Contract.pdf', '%PDF-1.4 test'.codeUnits),
        _picked('notes.txt', 'hello'.codeUnits),
        _picked('budget.xlsx', [1, 2]),
      ]);
      expect(added.map((f) => f.kind), [
        FileKind.pdf,
        FileKind.text,
        FileKind.spreadsheet,
      ]);
      expect(added.first.folder, VaultFolders.unsorted);
      expect(await repo.read(added[1].id), 'hello'.codeUnits);

      await repo.rename(added[1].id, 'renamed.txt');
      await repo.move(added[1].id, 'Work');
      await repo.delete(added[2].id);

      final files = await LocalFilesRepository(index, blobs).loadAll();
      final renamed = files.firstWhere((f) => f.id == added[1].id);
      expect(files, hasLength(2));
      expect(renamed.name, 'renamed.txt');
      expect(renamed.folder, 'Work');
    });

    test('scanned PDFs go to Scans with a .pdf name', () async {
      final repo = LocalFilesRepository(index, blobs);
      final file = await repo.addPdf(
        name: 'Scan 3 Nov',
        bytes: Uint8List.fromList('%PDF'.codeUnits),
      );
      expect(file.name, 'Scan 3 Nov.pdf');
      expect(file.folder, VaultFolders.scans);
    });
  });

  test('notes persist encrypted', () async {
    final repo = LocalNotesRepository(index);
    await repo.save(
      Note(
        id: 'n1',
        title: 'Locker',
        body: 'Code 4417',
        updatedAt: DateTime(2026),
      ),
    );
    final notes = await LocalNotesRepository(index).loadAll();
    expect(notes.single.body, 'Code 4417');
    expect((await allVaultBytesAsText()).contains('4417'), isFalse);
  });

  group('scanner PDF', () {
    test('builds a multi-page PDF in memory', () async {
      final pdf = await ScanPdf.build([
        ScanPage(id: 0, jpeg: _jpeg()),
        ScanPage(id: 1, jpeg: _jpeg(), filter: ScanFilter.blackWhite),
      ]);
      expect(String.fromCharCodes(pdf.sublist(0, 5)), '%PDF-');
      expect(
        RegExp(r'/Type\s*/Page\b').allMatches(String.fromCharCodes(pdf)).length,
        2,
      );
    });

    test('rotation swaps the page orientation', () {
      final rotated = ScanPdf.processPage(_jpeg(), 1, ScanFilter.original);
      final image = img.decodeJpg(rotated)!;
      expect(image.width, 80);
      expect(image.height, 60);
    });

    test('very large captures are scaled down', () {
      final big = _jpeg(width: 4000, height: 3000);
      final out = img.decodeJpg(
        ScanPdf.processPage(big, 0, ScanFilter.enhanced),
      )!;
      expect(out.width, ScanPdf.maxSide);
    });
  });

  test('plugin leftovers in the cache are wiped', () async {
    await paths.cache.create(recursive: true);
    final pdf = File('${paths.cache.path}/abc.pdf');
    final rendered = Directory('${paths.cache.path}/pdf_renderer_cache');
    final unrelated = File('${paths.cache.path}/keep.txt');
    await pdf.writeAsString('x');
    await rendered.create();
    await unrelated.writeAsString('x');
    await paths.wipeTemp();
    expect(await pdf.exists(), isFalse);
    expect(await rendered.exists(), isFalse);
    expect(await unrelated.exists(), isTrue);
  });
}
