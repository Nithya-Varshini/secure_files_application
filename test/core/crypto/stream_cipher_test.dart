import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_files_application/core/crypto/stream_cipher.dart';
import 'package:secure_files_application/core/crypto/vault_crypto.dart';

void main() {
  const segment = VaultStreamCipher.segmentSize;
  const encSegment = segment + VaultCrypto.macLength;
  const header = VaultStreamCipher.headerLength;
  final ad = VaultCrypto.label('item:abc');
  late Directory dir;

  setUp(() async => dir = await Directory.systemTemp.createTemp('vault_test'));
  tearDown(() => dir.delete(recursive: true));

  Uint8List data(int length) =>
      Uint8List.fromList(List.generate(length, (i) => (i * 31 + 7) % 256));

  Future<File> encrypt(Uint8List plain, {int chunk = 10000}) async {
    final file = File('${dir.path}/blob.bin');
    final key = VaultCrypto.newKey();
    // Feed odd-sized chunks to exercise the segment buffering.
    final source = Stream.fromIterable([
      for (var i = 0; i < plain.length; i += chunk)
        plain.sublist(i, (i + chunk).clamp(0, plain.length).toInt()),
    ]);
    await VaultStreamCipher.encryptToFile(
      source: source,
      destination: file,
      key: key,
      associatedData: ad,
    );
    _keys[file.path] = key;
    return file;
  }

  Future<Uint8List> decrypt(File file, {List<int>? associatedData}) =>
      VaultStreamCipher.decryptFileToBytes(
        file,
        key: _keys[file.path]!,
        associatedData: associatedData ?? ad,
      );

  for (final size in [
    0,
    1,
    segment - 1,
    segment,
    segment + 1,
    3 * segment + 5,
  ]) {
    test('round-trips $size bytes', () async {
      final plain = data(size);
      final file = await encrypt(plain);
      expect(await decrypt(file), plain);
      expect(await File('${file.path}.part').exists(), isFalse);
    });
  }

  test('in-memory variant matches the file format', () async {
    final key = VaultCrypto.newKey();
    final plain = data(segment * 2 + 3);
    final sealed = await VaultStreamCipher.encryptBytes(
      plain,
      key: key,
      associatedData: ad,
    );
    expect(
      await VaultStreamCipher.decryptBytes(
        sealed,
        key: key,
        associatedData: ad,
      ),
      plain,
    );
  });

  test('ciphertext does not contain the plaintext', () async {
    final plain = Uint8List.fromList(List.filled(5000, 0x41)); // "AAAA…"
    final file = await encrypt(plain);
    final bytes = await file.readAsBytes();
    expect(String.fromCharCodes(bytes).contains('AAAAAAAA'), isFalse);
  });

  group('tampering is detected', () {
    Future<void> expectRejected(File file, {List<int>? associatedData}) =>
        expectLater(
          decrypt(file, associatedData: associatedData),
          throwsA(isA<CryptoFailure>()),
        );

    test('a flipped bit in the body', () async {
      final file = await encrypt(data(segment * 2));
      final bytes = await file.readAsBytes();
      bytes[header + 100] ^= 1;
      await file.writeAsBytes(bytes);
      await expectRejected(file);
    });

    test('truncation that drops the final segment', () async {
      final file = await encrypt(data(segment * 3));
      final bytes = await file.readAsBytes();
      await file.writeAsBytes(bytes.sublist(0, header + 2 * encSegment));
      await expectRejected(file);
    });

    test('truncation inside a segment', () async {
      final file = await encrypt(data(segment + 500));
      final bytes = await file.readAsBytes();
      await file.writeAsBytes(bytes.sublist(0, bytes.length - 10));
      await expectRejected(file);
    });

    test('reordered segments', () async {
      final file = await encrypt(data(segment * 3));
      final b = await file.readAsBytes();
      final s0 = b.sublist(header, header + encSegment);
      final s1 = b.sublist(header + encSegment, header + 2 * encSegment);
      final swapped = [
        ...b.sublist(0, header),
        ...s1,
        ...s0,
        ...b.sublist(header + 2 * encSegment),
      ];
      await file.writeAsBytes(swapped);
      await expectRejected(file);
    });

    test('appended data', () async {
      final file = await encrypt(data(1000));
      final bytes = await file.readAsBytes();
      await file.writeAsBytes([...bytes, ...List.filled(40, 0)]);
      await expectRejected(file);
    });

    test('a file moved to another item (wrong associated data)', () async {
      final file = await encrypt(data(1000));
      await expectRejected(
        file,
        associatedData: VaultCrypto.label('item:other'),
      );
    });

    test('a changed format version', () async {
      final file = await encrypt(data(1000));
      final bytes = await file.readAsBytes();
      bytes[3] = 2;
      await file.writeAsBytes(bytes);
      await expectRejected(file);
    });

    test('a file that is not a vault file', () async {
      final file = File('${dir.path}/random.bin');
      await file.writeAsBytes(VaultCrypto.randomBytes(200));
      _keys[file.path] = VaultCrypto.newKey();
      await expectRejected(file);
    });
  });
}

final _keys = <String, SecretKeyData>{};
