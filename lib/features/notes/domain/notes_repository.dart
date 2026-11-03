import 'note.dart';

abstract interface class NotesRepository {
  Future<List<Note>> loadAll();

  /// Inserts or replaces a note; the body is encrypted at rest.
  Future<void> save(Note note);

  Future<void> delete(String id);
}
