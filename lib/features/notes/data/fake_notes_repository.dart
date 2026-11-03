import '../domain/note.dart';
import '../domain/notes_repository.dart';

/// PREVIEW ONLY: sample notes kept in memory.
class FakeNotesRepository implements NotesRepository {
  FakeNotesRepository() : _notes = _seed();

  final List<Note> _notes;

  static List<Note> _seed() {
    final now = DateTime.now();
    return [
      Note(
        id: 'n1',
        title: 'Emergency contacts',
        body: 'Dr. Mehta (family doctor)\nInsurance helpline: on the back of the card\nBlood group: O+',
        updatedAt: now.subtract(const Duration(hours: 3)),
        pinned: true,
      ),
      Note(
        id: 'n2',
        title: 'Gift ideas',
        body: 'Mum: silk scarf, plant stand\nArjun: running watch\nPriya: pottery class',
        updatedAt: now.subtract(const Duration(days: 1, hours: 2)),
      ),
      Note(
        id: 'n3',
        title: 'Journal - October',
        body: 'Finally finished the course. Feeling proud and a little tired. Next: start the vault app project properly.',
        updatedAt: now.subtract(const Duration(days: 4)),
      ),
      Note(
        id: 'n4',
        title: 'Locker details',
        body: 'Branch: MG Road\nLocker 214\nNominee updated in March',
        updatedAt: now.subtract(const Duration(days: 12)),
        pinned: true,
      ),
    ];
  }

  @override
  Future<List<Note>> loadAll() async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    return List.unmodifiable(_notes);
  }

  @override
  Future<void> save(Note note) async {
    final index = _notes.indexWhere((n) => n.id == note.id);
    if (index == -1) {
      _notes.insert(0, note);
    } else {
      _notes[index] = note;
    }
  }

  @override
  Future<void> delete(String id) async => _notes.removeWhere((n) => n.id == id);
}
