import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'vault_crypto.dart';

/// Chunked authenticated encryption for files of any size.
///
/// Follows the STREAM construction (Hoang, Reyhanitabar, Rogaway, Vizár,
/// 2015), the same design behind Tink's AES-GCM-HKDF streaming AEAD:
///
/// ```text
/// header   = "VLT" | version (1) | nonce prefix (7, random)
/// segment  = AES-256-GCM(key,
///              nonce = prefix | segment index (4, big-endian) | last flag (1),
///              aad   = header | associated data)
/// ```
///
/// * The index in the nonce makes reordered or duplicated segments fail.
/// * The last-segment flag makes truncation fail: a cut file ends on a
///   segment that was not sealed as the last one.
/// * The header and associated data (for example the item id) are
///   authenticated in every segment, so a file cannot be swapped for another
///   item's file, nor downgraded to another format version.
///
/// Each file gets its own random key, so (key, nonce) pairs never repeat.
///
/// Segments are verified one by one while streaming. A consumer must treat
/// the whole output as invalid if the stream ends with an error.
abstract final class VaultStreamCipher {
  static const version = 1;
  static const segmentSize = 64 * 1024;
  static const _magic = [0x56, 0x4C, 0x54]; // "VLT"
  static const _prefixLength = 7;
  static const headerLength = 3 + 1 + _prefixLength;
  static const _encryptedSegment = segmentSize + VaultCrypto.macLength;
  static const _maxSegments = 0xFFFFFFFF;

  /// Encrypts [source] into [destination], replacing it atomically: the
  /// ciphertext is written to a temporary file and renamed only once
  /// complete, so a crash never leaves a half-written item.
  /// Returns the number of plaintext bytes.
  static Future<int> encryptToFile({
    required Stream<List<int>> source,
    required File destination,
    required SecretKey key,
    required List<int> associatedData,
  }) async {
    final temp = File('${destination.path}.part');
    final sink = temp.openWrite();
    try {
      final total = await _encrypt(source, sink, key, associatedData);
      await sink.flush();
      await sink.close();
      await temp.rename(destination.path);
      return total;
    } catch (_) {
      await sink.close().catchError((_) {});
      if (await temp.exists()) await temp.delete();
      rethrow;
    }
  }

  /// In-memory variant for small payloads such as thumbnails.
  static Future<Uint8List> encryptBytes(
    List<int> plaintext, {
    required SecretKey key,
    required List<int> associatedData,
  }) async {
    final out = _MemorySink();
    await _encrypt(Stream.value(plaintext), out, key, associatedData);
    return out.bytes.takeBytes();
  }

  static Future<int> _encrypt(
    Stream<List<int>> source,
    StreamSink<List<int>> sink,
    SecretKey key,
    List<int> associatedData,
  ) async {
    final prefix = VaultCrypto.randomBytes(_prefixLength);
    final header = [..._magic, version, ...prefix];
    final aad = [...header, ...associatedData];
    sink.add(header);

    var index = 0;
    var total = 0;
    final pending = BytesBuilder(copy: false);

    Future<void> emit(List<int> data, {required bool last}) async {
      if (index > _maxSegments) throw const CryptoFailure('File too large');
      sink.add(
        await VaultCrypto.encryptWithNonce(
          data,
          key,
          nonce: _nonce(prefix, index, last: last),
          aad: aad,
        ),
      );
      index++;
    }

    await for (final chunk in source) {
      total += chunk.length;
      pending.add(chunk);
      // Hold back at least one byte: a segment may only be sealed as
      // non-final once we know more data follows it.
      if (pending.length > segmentSize) {
        final data = pending.takeBytes();
        var offset = 0;
        while (data.length - offset > segmentSize) {
          await emit(
            Uint8List.sublistView(data, offset, offset + segmentSize),
            last: false,
          );
          offset += segmentSize;
        }
        pending.add(Uint8List.sublistView(data, offset));
      }
    }
    await emit(pending.takeBytes(), last: true);
    return total;
  }

  /// Decrypts [file] segment by segment.
  static Stream<Uint8List> decryptFile(
    File file, {
    required SecretKey key,
    required List<int> associatedData,
  }) async* {
    final handle = await file.open();
    try {
      final length = await handle.length();
      final header = await handle.read(headerLength);
      final aad = _checkHeader(header, length, associatedData);
      final prefix = header.sublist(4);
      final body = length - headerLength;
      final count = (body + _encryptedSegment - 1) ~/ _encryptedSegment;

      for (var i = 0; i < count; i++) {
        final last = i == count - 1;
        final size = last ? body - i * _encryptedSegment : _encryptedSegment;
        final segment = await handle.read(size);
        if (segment.length != size) {
          throw const CryptoFailure('Unexpected end of file');
        }
        yield await VaultCrypto.decryptWithNonce(
          segment,
          key,
          nonce: _nonce(prefix, i, last: last),
          aad: aad,
        );
      }
    } finally {
      await handle.close();
    }
  }

  static Future<Uint8List> decryptFileToBytes(
    File file, {
    required SecretKey key,
    required List<int> associatedData,
  }) async {
    final out = BytesBuilder(copy: false);
    await for (final segment in decryptFile(
      file,
      key: key,
      associatedData: associatedData,
    )) {
      out.add(segment);
    }
    return out.takeBytes();
  }

  static Future<Uint8List> decryptBytes(
    Uint8List data, {
    required SecretKey key,
    required List<int> associatedData,
  }) async {
    final header = data.length < headerLength
        ? data
        : data.sublist(0, headerLength);
    final aad = _checkHeader(header, data.length, associatedData);
    final prefix = header.sublist(4);
    final body = data.length - headerLength;
    final count = (body + _encryptedSegment - 1) ~/ _encryptedSegment;
    final out = BytesBuilder(copy: false);
    for (var i = 0; i < count; i++) {
      final last = i == count - 1;
      final start = headerLength + i * _encryptedSegment;
      final end = last ? data.length : start + _encryptedSegment;
      out.add(
        await VaultCrypto.decryptWithNonce(
          Uint8List.sublistView(data, start, end),
          key,
          nonce: _nonce(prefix, i, last: last),
          aad: aad,
        ),
      );
    }
    return out.takeBytes();
  }

  static List<int> _checkHeader(
    List<int> header,
    int totalLength,
    List<int> associatedData,
  ) {
    if (totalLength < headerLength + VaultCrypto.macLength ||
        header.length != headerLength) {
      throw const CryptoFailure('File too short');
    }
    for (var i = 0; i < _magic.length; i++) {
      if (header[i] != _magic[i]) throw const CryptoFailure('Not a vault file');
    }
    if (header[3] != version) {
      throw const CryptoFailure('Unsupported format version');
    }
    return [...header, ...associatedData];
  }

  static Uint8List _nonce(List<int> prefix, int index, {required bool last}) {
    final nonce = Uint8List(VaultCrypto.nonceLength)..setAll(0, prefix);
    ByteData.sublistView(nonce).setUint32(_prefixLength, index);
    nonce[VaultCrypto.nonceLength - 1] = last ? 1 : 0;
    return nonce;
  }
}

class _MemorySink implements StreamSink<List<int>> {
  final bytes = BytesBuilder(copy: false);
  final _done = Completer<void>();

  @override
  void add(List<int> data) => bytes.add(data);

  @override
  void addError(Object error, [StackTrace? stackTrace]) =>
      _done.completeError(error, stackTrace);

  @override
  Future<void> addStream(Stream<List<int>> stream) => stream.forEach(add);

  @override
  Future<void> close() async {
    if (!_done.isCompleted) _done.complete();
  }

  @override
  Future<void> get done => _done.future;
}
