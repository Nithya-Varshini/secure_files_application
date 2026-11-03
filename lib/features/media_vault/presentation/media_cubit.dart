import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
  MediaCubit(this._repository) : super(const MediaState());

  final MediaRepository _repository;

  Future<void> load() async {
    emit(const MediaState(status: LoadStatus.loading));
    final items = await _repository.loadAll();
    if (!isClosed) emit(MediaState(status: LoadStatus.ready, items: items));
  }

  /// Drops decrypted data from memory when the vault locks.
  void clear() => emit(const MediaState());

  Future<int> importFromPicker() async {
    final added = await _repository.importFromPicker();
    emit(MediaState(status: state.status, items: [...added, ...state.items]));
    return added.length;
  }

  Future<void> delete(Set<String> ids) async {
    await _repository.delete(ids);
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
