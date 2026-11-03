import 'dart:math';

import '../domain/media_item.dart';
import '../domain/media_repository.dart';

/// PREVIEW ONLY: sample media kept in memory.
class FakeMediaRepository implements MediaRepository {
  FakeMediaRepository() : _items = _seed();

  final List<MediaItem> _items;
  int _imported = 0;

  static const _albums = ['Family', 'Travel', 'Documents', 'Personal'];
  static const _titles = {
    MediaSubject.landscape: 'Mountain view',
    MediaSubject.portrait: 'Portrait',
    MediaSubject.pet: 'Milo',
    MediaSubject.food: 'Dinner',
    MediaSubject.travel: 'Airport',
    MediaSubject.celebration: 'Birthday',
    MediaSubject.nature: 'Garden',
  };

  static List<MediaItem> _seed() {
    final random = Random(7);
    final now = DateTime.now();
    return List.generate(26, (i) {
      final subject =
          MediaSubject.values[random.nextInt(MediaSubject.values.length)];
      final isVideo = i % 5 == 2;
      return MediaItem(
        id: 'm$i',
        title: '${_titles[subject]} ${i + 1}',
        type: isVideo ? MediaType.video : MediaType.photo,
        subject: subject,
        album: _albums[random.nextInt(_albums.length)],
        createdAt: now.subtract(Duration(hours: i * 19 + random.nextInt(12))),
        sizeBytes: isVideo
            ? 20000000 + random.nextInt(90000000)
            : 1500000 + random.nextInt(4000000),
        seed: i * 13 + 5,
        duration: isVideo ? Duration(seconds: 12 + random.nextInt(200)) : null,
        favorite: i % 7 == 0,
      );
    });
  }

  @override
  Future<List<MediaItem>> loadAll() async {
    // Simulates decrypting the index after unlock.
    await Future<void>.delayed(const Duration(milliseconds: 450));
    return List.unmodifiable(_items);
  }

  @override
  Future<List<MediaItem>> importFromPicker() async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    final now = DateTime.now();
    final added = List.generate(3, (i) {
      final n = _imported++;
      return MediaItem(
        id: 'import-$n-${now.microsecondsSinceEpoch}',
        title: 'Imported photo ${n + 1}',
        type: MediaType.photo,
        subject: MediaSubject.values[n % MediaSubject.values.length],
        album: 'Personal',
        createdAt: now,
        sizeBytes: 2400000,
        seed: 300 + n * 11,
      );
    });
    _items.insertAll(0, added);
    return added;
  }

  @override
  Future<void> delete(Set<String> ids) async =>
      _items.removeWhere((m) => ids.contains(m.id));

  @override
  Future<void> setFavorite(String id, {required bool favorite}) async {
    final index = _items.indexWhere((m) => m.id == id);
    if (index != -1) _items[index] = _items[index].copyWith(favorite: favorite);
  }
}
