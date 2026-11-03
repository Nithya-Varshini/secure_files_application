import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/state/load_status.dart';
import '../domain/files_repository.dart';
import '../domain/vault_file.dart';

class FilesState extends Equatable {
  const FilesState({this.status = LoadStatus.idle, this.files = const []});

  final LoadStatus status;
  final List<VaultFile> files;

  int get totalBytes => files.fold(0, (sum, f) => sum + f.sizeBytes);

  VaultFile? byId(String id) {
    for (final f in files) {
      if (f.id == id) return f;
    }
    return null;
  }

  @override
  List<Object?> get props => [status, files];
}

class FilesCubit extends Cubit<FilesState> {
  FilesCubit(this._repository) : super(const FilesState());

  final FilesRepository _repository;

  Future<void> load() async {
    emit(const FilesState(status: LoadStatus.loading));
    final files = await _repository.loadAll();
    if (!isClosed) emit(FilesState(status: LoadStatus.ready, files: files));
  }

  void clear() => emit(const FilesState());

  Future<int> importFromPicker() async {
    final added = await _repository.importFromPicker();
    emit(FilesState(status: state.status, files: [...added, ...state.files]));
    return added.length;
  }

  Future<VaultFile> addScan({
    required String name,
    required int pageCount,
  }) async {
    final file = await _repository.addScan(name: name, pageCount: pageCount);
    emit(FilesState(status: state.status, files: [file, ...state.files]));
    return file;
  }

  Future<void> rename(String id, String name) async {
    final renamed = await _repository.rename(id, name);
    emit(
      FilesState(
        status: state.status,
        files: [for (final f in state.files) f.id == id ? renamed : f],
      ),
    );
  }

  Future<void> delete(String id) async {
    await _repository.delete(id);
    emit(
      FilesState(
        status: state.status,
        files: state.files.where((f) => f.id != id).toList(),
      ),
    );
  }
}
