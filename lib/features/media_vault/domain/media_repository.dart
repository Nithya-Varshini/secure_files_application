import 'media_item.dart';

abstract interface class MediaRepository {
  Future<List<MediaItem>> loadAll();

  /// Imports items chosen with the Android Photo Picker, encrypting each one.
  Future<List<MediaItem>> importFromPicker();

  Future<void> delete(Set<String> ids);

  Future<void> setFavorite(String id, {required bool favorite});
}
