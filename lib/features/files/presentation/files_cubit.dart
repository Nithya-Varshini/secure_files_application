import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/platform/pickers.dart';
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
  FilesCubit(this._repository, this._picker) : super(const FilesState());

  final FilesRepository _repository;
  final DocumentPicker _picker;

  Future<void> load() async {
    emit(const FilesState(status: LoadStatus.loading));
    final files = await _repository.loadAll();
    if (!isClosed) emit(FilesState(status: LoadStatus.ready, files: files));
  }

  void clear() => emit(const FilesState());

  /// Opens the system document chooser. Returns (imported, picked).
  Future<(int, int)> importFromPicker() async {
    final picked = await _picker.pickDocuments();
    if (picked.isEmpty) return (0, 0);
    final added = await _repository.import(picked);
    emit(FilesState(status: state.status, files: [...added, ...state.files]));
    return (added.length, picked.length);
  }

  Future<VaultFile> addScan({
    required String name,
    required Uint8List pdf,
  }) async {
    final file = await _repository.addPdf(name: name, bytes: pdf);
    emit(FilesState(status: state.status, files: [file, ...state.files]));
    return file;
  }

  Future<Uint8List> read(String id) => _repository.read(id);

  Future<void> rename(String id, String name) async =>
      _replace(await _repository.rename(id, name));

  Future<void> move(String id, String folder) async =>
      _replace(await _repository.move(id, folder));

  void _replace(VaultFile updated) => emit(
    FilesState(
      status: state.status,
      files: [for (final f in state.files) f.id == updated.id ? updated : f],
    ),
  );

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
