import 'dart:io';
import 'dart:typed_data';

import 'package:mime/mime.dart';

import '../../../core/platform/pickers.dart';
import '../../../core/platform/thumbnailer.dart';
import '../../../core/storage/blob_store.dart';
import '../../../core/storage/encrypted_index.dart';
import '../domain/media_item.dart';
import '../domain/media_repository.dart';

/// Photos and videos, each encrypted with its own key. Titles, dates,
/// sizes and thumbnails live only inside the encrypted index and blobs.
class LocalMediaRepository implements MediaRepository {
  LocalMediaRepository(this._index, this._blobs, this._thumbnailer);

  static const _collection = 'media';

  /// Photos larger than this are stored by streaming, without a thumbnail,
  /// to avoid holding huge images in memory.
  static const _maxInMemoryImage = 60 * 1024 * 1024;

  final EncryptedIndex _index;
  final BlobStore _blobs;
  final Thumbnailer _thumbnailer;

  Future<List<_Record>> _records() async =>
      (await _index.read(_collection)).map(_Record.fromJson).toList();

  Future<void> _save(List<_Record> records) =>
      _index.write(_collection, [for (final r in records) r.toJson()]);

  Future<_Record> _find(String id) async =>
      (await _records()).firstWhere((r) => r.item.id == id);

  @override
  Future<List<MediaItem>> loadAll() async =>
      [for (final r in await _records()) r.item]
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  Future<List<MediaItem>> import(List<PickedFile> files) async {
    final records = await _records();
    final added = <MediaItem>[];
    for (final file in files) {
      try {
        final mime = file.resolvedMimeType;
        final isVideo = mime.startsWith('video/');
        StoredBlob content;
        Thumbnail? thumb;
        StoredBlob? thumbBlob;

        if (!isVideo) {
          final bytes = await file.readAll();
          content = await _blobs.putBytes(bytes);
          if (bytes.length <= _maxInMemoryImage) {
            thumb = await _thumbnailer.make(bytes);
            if (thumb != null) thumbBlob = await _blobs.putBytes(thumb.png);
          }
        } else {
          content = await _blobs.put(file.open());
        }

        final item = MediaItem(
          id: BlobStore.newId(),
          title: _titleFrom(file.name),
          type: isVideo ? MediaType.video : MediaType.photo,
          mimeType: mime,
          createdAt: DateTime.now(),
          sizeBytes: content.size,
          width: thumb?.width,
          height: thumb?.height,
          hasThumbnail: thumbBlob != null,
        );
        records.add(_Record(item, content, thumbBlob));
        added.add(item);
        // Save after each file so an interrupted import keeps what is done
        // and never indexes a half-written item.
        await _save(records);
      } on FileSystemException {
        // Unreadable source: skip it; the caller reports the shortfall.
        continue;
      } finally {
        await file.discardPluginCopy();
      }
    }
    return added;
  }

  static String _titleFrom(String name) {
    final dot = name.lastIndexOf('.');
    return dot > 0 ? name.substring(0, dot) : name;
  }

  @override
  Future<Uint8List?> thumbnail(String id) async {
    final record = await _find(id);
    final thumb = record.thumb;
    return thumb == null ? null : _blobs.readBytes(thumb);
  }

  @override
  Future<Uint8List> original(String id) async =>
      _blobs.readBytes((await _find(id)).content);

  @override
  Future<File> openVideo(String id) async {
    final record = await _find(id);
    final ext = extensionFromMime(record.item.mimeType);
    return _blobs.decryptToTemp(
      record.content,
      extension: ext == null ? '' : '.$ext',
    );
  }

  @override
  Future<void> delete(Set<String> ids) async {
    final records = await _records();
    final removed = records.where((r) => ids.contains(r.item.id)).toList();
    records.removeWhere((r) => ids.contains(r.item.id));
    // Index first: once the keys are gone the blobs are unreadable even if
    // deleting a file below fails.
    await _save(records);
    for (final r in removed) {
      await _blobs.delete(r.content);
      if (r.thumb != null) await _blobs.delete(r.thumb!);
    }
  }

  @override
  Future<void> setFavorite(String id, {required bool favorite}) async {
    final records = await _records();
    final i = records.indexWhere((r) => r.item.id == id);
    if (i == -1) return;
    records[i] = records[i].withItem(
      records[i].item.copyWith(favorite: favorite),
    );
    await _save(records);
  }
}

class _Record {
  const _Record(this.item, this.content, this.thumb);

  final MediaItem item;
  final StoredBlob content;
  final StoredBlob? thumb;

  _Record withItem(MediaItem item) => _Record(item, content, thumb);

  Map<String, Object?> toJson() => {
    'id': item.id,
    'title': item.title,
    'type': item.type.name,
    'mime': item.mimeType,
    'created': item.createdAt.millisecondsSinceEpoch,
    'size': item.sizeBytes,
    'w': item.width,
    'h': item.height,
    'fav': item.favorite,
    'content': content.toJson(),
    if (thumb != null) 'thumb': thumb!.toJson(),
  };

  factory _Record.fromJson(Map<String, Object?> j) {
    final thumb = j['thumb'] == null
        ? null
        : StoredBlob.fromJson((j['thumb']! as Map).cast());
    return _Record(
      MediaItem(
        id: j['id']! as String,
        title: j['title']! as String,
        type: MediaType.values.byName(j['type']! as String),
        mimeType: j['mime']! as String,
        createdAt: DateTime.fromMillisecondsSinceEpoch(j['created']! as int),
        sizeBytes: j['size']! as int,
        width: j['w'] as int?,
        height: j['h'] as int?,
        hasThumbnail: thumb != null,
        favorite: j['fav'] as bool? ?? false,
      ),
      StoredBlob.fromJson((j['content']! as Map).cast()),
      thumb,
    );
  }
}
