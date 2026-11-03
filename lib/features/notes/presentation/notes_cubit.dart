import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/state/load_status.dart';
import '../domain/note.dart';
import '../domain/notes_repository.dart';

class NotesState extends Equatable {
  const NotesState({this.status = LoadStatus.idle, this.notes = const []});

  final LoadStatus status;
  final List<Note> notes;

  /// Pinned first, then most recently edited.
  List<Note> get sorted => [...notes]
    ..sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });

  Note? byId(String id) {
    for (final n in notes) {
      if (n.id == id) return n;
    }
    return null;
  }

  @override
  List<Object?> get props => [status, notes];
}

class NotesCubit extends Cubit<NotesState> {
  NotesCubit(this._repository) : super(const NotesState());

  final NotesRepository _repository;

  Future<void> load() async {
    emit(const NotesState(status: LoadStatus.loading));
    final notes = await _repository.loadAll();
    if (!isClosed) emit(NotesState(status: LoadStatus.ready, notes: notes));
  }

  void clear() => emit(const NotesState());

  Future<void> upsert(Note note) async {
    await _repository.save(note);
    final exists = state.notes.any((n) => n.id == note.id);
    emit(
      NotesState(
        status: state.status,
        notes: exists
            ? [for (final n in state.notes) n.id == note.id ? note : n]
            : [note, ...state.notes],
      ),
    );
  }

  Future<void> delete(String id) async {
    await _repository.delete(id);
    emit(
      NotesState(
        status: state.status,
        notes: state.notes.where((n) => n.id != id).toList(),
      ),
    );
  }

  static String newId() => 'note-${DateTime.now().microsecondsSinceEpoch}';
}
