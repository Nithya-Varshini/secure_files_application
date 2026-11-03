import 'dart:io';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/platform/pickers.dart';
import '../../../core/state/load_status.dart';
import '../domain/media_item.dart';
import '../domain/media_repository.dart';

class MediaState extends Equatable {
  const MediaState({this.status = LoadStatus.idle, this.items = const []});

  final LoadStatus status;
  final List<MediaItem> items;

  int get photoCount => items.where((m) => !m.isVideo).length;
  int get videoCount => items.where((m) => m.isVideo).length;
  int get totalBytes => items.fold(0, (sum, m) => sum + m.sizeBytes);

  @override
  List<Object?> get props => [status, items];
}

class MediaCubit extends Cubit<MediaState> {
  MediaCubit(this._repository, this._picker) : super(const MediaState());

  final MediaRepository _repository;
  final MediaPicker _picker;

  /// Decrypted thumbnails, held in memory only and dropped on lock.
  final _thumbnails = <String, Future<Uint8List?>>{};

  Future<void> load() async {
    emit(const MediaState(status: LoadStatus.loading));
    final items = await _repository.loadAll();
    if (!isClosed) emit(MediaState(status: LoadStatus.ready, items: items));
  }

  /// Drops decrypted data from memory when the vault locks.
  void clear() {
    _thumbnails.clear();
    emit(const MediaState());
  }

  Future<Uint8List?> thumbnail(String id) =>
      _thumbnails.putIfAbsent(id, () => _repository.thumbnail(id));

  Future<Uint8List> original(String id) => _repository.original(id);

  Future<File> openVideo(String id) => _repository.openVideo(id);

  /// Opens the system Photo Picker. Returns (imported, picked).
  Future<(int, int)> importFromPicker() async {
    final picked = await _picker.pickPhotosAndVideos();
    if (picked.isEmpty) return (0, 0);
    final added = await _repository.import(picked);
    emit(MediaState(status: state.status, items: [...added, ...state.items]));
    return (added.length, picked.length);
  }

  Future<void> delete(Set<String> ids) async {
    await _repository.delete(ids);
    ids.forEach(_thumbnails.remove);
    emit(
      MediaState(
        status: state.status,
        items: state.items.where((m) => !ids.contains(m.id)).toList(),
      ),
    );
  }

  Future<void> toggleFavorite(String id) async {
    final item = state.items.firstWhere((m) => m.id == id);
    await _repository.setFavorite(id, favorite: !item.favorite);
    emit(
      MediaState(
        status: state.status,
        items: [
          for (final m in state.items)
            m.id == id ? m.copyWith(favorite: !m.favorite) : m,
        ],
      ),
    );
  }
}
