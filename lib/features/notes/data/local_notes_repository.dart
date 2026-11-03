import '../../../core/storage/encrypted_index.dart';
import '../domain/note.dart';
import '../domain/notes_repository.dart';

/// Notes live entirely inside the encrypted index: titles and bodies are
/// encrypted at rest with the vault's index key.
class LocalNotesRepository implements NotesRepository {
  LocalNotesRepository(this._index);

  static const _collection = 'notes';
  final EncryptedIndex _index;

  @override
  Future<List<Note>> loadAll() async =>
      (await _index.read(_collection)).map(_fromJson).toList();

  @override
  Future<void> save(Note note) async {
    final notes = await loadAll();
    final i = notes.indexWhere((n) => n.id == note.id);
    if (i == -1) {
      notes.insert(0, note);
    } else {
      notes[i] = note;
    }
    await _index.write(_collection, notes.map(_toJson).toList());
  }

  @override
  Future<void> delete(String id) async {
    final notes = await loadAll()
      ..removeWhere((n) => n.id == id);
    await _index.write(_collection, notes.map(_toJson).toList());
  }

  static Map<String, Object?> _toJson(Note n) => {
    'id': n.id,
    'title': n.title,
    'body': n.body,
    'updated': n.updatedAt.millisecondsSinceEpoch,
    'pinned': n.pinned,
  };

  static Note _fromJson(Map<String, Object?> j) => Note(
    id: j['id']! as String,
    title: j['title']! as String,
    body: j['body']! as String,
    updatedAt: DateTime.fromMillisecondsSinceEpoch(j['updated']! as int),
    pinned: j['pinned'] as bool? ?? false,
  );
}
