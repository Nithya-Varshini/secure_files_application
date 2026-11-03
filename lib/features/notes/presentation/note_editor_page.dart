import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/dialogs.dart';
import '../domain/note.dart';
import 'notes_cubit.dart';

/// Distraction-free editor with debounced autosave.
class NoteEditorPage extends StatefulWidget {
  const NoteEditorPage({super.key, this.noteId});

  /// Null creates a new note on the first keystroke.
  final String? noteId;

  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  late final NotesCubit _notes = context.read<NotesCubit>();
  late final TextEditingController _title;
  late final TextEditingController _body;
  String? _id;
  bool _pinned = false;
  DateTime? _savedAt;
  Timer? _debounce;
  bool _dirty = false;
  bool _deleted = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.noteId == null
        ? null
        : _notes.state.byId(widget.noteId!);
    _id = existing?.id;
    _pinned = existing?.pinned ?? false;
    _savedAt = existing?.updatedAt;
    _title = TextEditingController(text: existing?.title ?? '')
      ..addListener(_changed);
    _body = TextEditingController(text: existing?.body ?? '')
      ..addListener(_changed);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    if (!_deleted) _flush(closing: true);
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  void _changed() {
    if (!_dirty) setState(() => _dirty = true);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), _flush);
  }

  /// Saves the note. Leaving an untouched new note creates nothing, and
  /// emptying an existing note removes it.
  void _flush({bool closing = false}) {
    final note = Note(
      id: _id ?? NotesCubit.newId(),
      title: _title.text.trim(),
      body: _body.text,
      updatedAt: DateTime.now(),
      pinned: _pinned,
    );
    if (note.isEmpty) {
      if (_id != null && closing) _notes.delete(_id!);
      return;
    }
    if (!_dirty && closing) return;
    _id = note.id;
    _notes.upsert(note);
    if (!closing && mounted) {
      setState(() {
        _dirty = false;
        _savedAt = note.updatedAt;
      });
    }
  }

  Future<void> _delete() async {
    final navigator = Navigator.of(context);
    if (_id == null) {
      _deleted = true;
      navigator.pop();
      return;
    }
    if (!await confirmDelete(context, what: 'this note')) return;
    _deleted = true;
    _debounce?.cancel();
    await _notes.delete(_id!);
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final status = _dirty
        ? 'Saving…'
        : _savedAt == null
        ? 'New note'
        : 'Saved ${formatRelative(_savedAt!).toLowerCase()}';

    return Scaffold(
      appBar: AppBar(
        actions: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Row(
              key: ValueKey(status),
              children: [
                Icon(
                  _dirty ? Icons.sync_rounded : Icons.lock_outline_rounded,
                  size: 16,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  status,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: _pinned ? 'Unpin' : 'Pin',
            icon: Icon(
              _pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
            ),
            onPressed: () {
              setState(() => _pinned = !_pinned);
              _changed();
            },
          ),
          IconButton(
            tooltip: 'Delete note',
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: _delete,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              TextField(
                controller: _title,
                autofocus: widget.noteId == null,
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                // Keyboards must not learn or sync private text (threat L10).
                enableIMEPersonalizedLearning: false,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                decoration: const InputDecoration.collapsed(hintText: 'Title'),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: TextField(
                  controller: _body,
                  expands: true,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  enableIMEPersonalizedLearning: false,
                  style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
                  textAlignVertical: TextAlignVertical.top,
                  decoration: const InputDecoration.collapsed(
                    hintText: 'Start writing…',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
