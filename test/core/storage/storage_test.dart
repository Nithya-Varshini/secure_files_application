import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:secure_files_application/core/crypto/vault_crypto.dart';
import 'package:secure_files_application/core/security/vault_key.dart';
import 'package:secure_files_application/core/storage/blob_store.dart';
import 'package:secure_files_application/core/storage/encrypted_index.dart';
import 'package:secure_files_application/core/storage/vault_paths.dart';

void main() {
  late Directory dir;
  late VaultPaths paths;
  late VaultKey key;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('vault_storage');
    paths = VaultPaths(
      root: Directory('${dir.path}/vault'),
      temp: Directory('${dir.path}/tmp'),
    );
    await paths.ensure();
    key = VaultKey();
    await key.unlock(VaultCrypto.newKey());
  });

  tearDown(() => dir.delete(recursive: true));

  group('EncryptedIndex', () {
    test('round-trips records and stores no plaintext', () async {
      final index = EncryptedIndex(paths, key);
      await index.write('notes', [
        {'id': 'n1', 'title': 'Bank PIN reminder'},
      ]);
      expect(await index.read('notes'), [
        {'id': 'n1', 'title': 'Bank PIN reminder'},
      ]);
      final raw = await File('${paths.index.path}/notes.bin').readAsBytes();
      expect(String.fromCharCodes(raw).contains('Bank'), isFalse);
    });

    test('a missing collection reads as empty', () async {
      expect(await EncryptedIndex(paths, key).read('media'), isEmpty);
    });

    test(
      'a collection file renamed to another collection is rejected',
      () async {
        final index = EncryptedIndex(paths, key);
        await index.write('notes', [
          {'id': 'n1'},
        ]);
        await File('${paths.index.path}/notes.bin')
            .copy('${paths.index.path}/files.bin');
        await expectLater(index.read('files'), throwsA(isA<CryptoFailure>()));
      },
    );

    test('rapid writes keep the last one', () async {
      final index = EncryptedIndex(paths, key);
      await Future.wait([
        for (var i = 0; i < 10; i++)
          index.write('notes', [
            {'n': i},
          ]),
      ]);
      expect(await index.read('notes'), [
        {'n': 9},
      ]);
    });

    test('reading while locked fails', () async {
      final index = EncryptedIndex(paths, key);
      await index.write('notes', []);
      key.lock();
      await expectLater(
        index.read('notes'),
        throwsA(isA<VaultLockedException>()),
      );
    });
  });

  group('BlobStore', () {
    Uint8List data(int n) =>
        Uint8List.fromList(List.generate(n, (i) => (i * 7) % 256));

    test('round-trips a file larger than one segment', () async {
      final store = BlobStore(paths, key);
      final plain = data(200000);
      final blob = await store.putBytes(plain);
      expect(blob.size, plain.length);
      expect(await store.readBytes(blob), plain);
    });

    test('each file gets its own key', () async {
      final store = BlobStore(paths, key);
      final a = await store.putBytes([1, 2, 3]);
      final b = await store.putBytes([1, 2, 3]);
      expect(a.wrappedKey, isNot(b.wrappedKey));
      expect(a.id, isNot(b.id));
    });

    test('a key cannot be used for another blob (cut-and-paste)', () async {
      final store = BlobStore(paths, key);
      final a = await store.putBytes([1, 2, 3]);
      final b = await store.putBytes([4, 5, 6]);
      final swapped = StoredBlob(id: b.id, wrappedKey: a.wrappedKey, size: 3);
      await expectLater(
        store.readBytes(swapped),
        throwsA(isA<CryptoFailure>()),
      );
    });

    test('blobs cannot be opened under another master key', () async {
      final blob = await BlobStore(paths, key).putBytes([1, 2, 3]);
      final other = VaultKey();
      await other.unlock(VaultCrypto.newKey());
      await expectLater(
        BlobStore(paths, other).readBytes(blob),
        throwsA(isA<CryptoFailure>()),
      );
    });

    test(
      'temp decryption lands in the temp folder and wipe clears it',
      () async {
        final store = BlobStore(paths, key);
        final blob = await store.putBytes(data(1000));
        final file = await store.decryptToTemp(blob, extension: '.mp4');
        expect(file.path.startsWith(paths.temp.path), isTrue);
        expect(await file.readAsBytes(), data(1000));
        await paths.wipeTemp();
        expect(await file.exists(), isFalse);
      },
    );

    test('delete removes the encrypted file', () async {
      final store = BlobStore(paths, key);
      final blob = await store.putBytes([1]);
      await store.delete(blob);
      expect(
        await File('${paths.blobs.path}/${blob.id}.bin').exists(),
        isFalse,
      );
    });
  });
}
