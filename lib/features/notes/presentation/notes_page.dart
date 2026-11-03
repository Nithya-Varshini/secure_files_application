import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/state/load_status.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/skeleton.dart';
import '../domain/note.dart';
import 'note_editor_page.dart';
import 'notes_cubit.dart';

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  final _search = TextEditingController();
  bool _searching = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final state = context.watch<NotesCubit>().state;
    final query = _search.text.trim().toLowerCase();
    final notes = state.sorted
        .where(
          (n) =>
              query.isEmpty ||
              n.title.toLowerCase().contains(query) ||
              n.body.toLowerCase().contains(query),
        )
        .toList();
    final pinned = notes.where((n) => n.pinned).toList();
    final others = notes.where((n) => !n.pinned).toList();

    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _search,
                autofocus: true,
                enableIMEPersonalizedLearning: false,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Search notes',
                  filled: false,
                  border: InputBorder.none,
                ),
              )
            : const Text('Notes'),
        actions: [
          IconButton(
            tooltip: _searching ? 'Close search' : 'Search',
            icon: Icon(_searching ? Icons.close_rounded : Icons.search_rounded),
            onPressed: () => setState(() {
              _searching = !_searching;
              if (!_searching) _search.clear();
            }),
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: switch (state.status) {
          LoadStatus.ready when notes.isEmpty => EmptyState(
            key: const ValueKey('empty'),
            icon: Icons.sticky_note_2_outlined,
            title: query.isEmpty ? 'No notes yet' : 'No matches',
            message: query.isEmpty
                ? 'Private notes are encrypted like everything else in '
                      'your vault.'
                : 'Try another word.',
          ),
          LoadStatus.ready => ListView(
            key: const ValueKey('list'),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
            children: [
              if (pinned.isNotEmpty) ...[
                _Label('Pinned', icon: Icons.push_pin_rounded),
                for (final n in pinned) _NoteCard(note: n),
              ],
              if (others.isNotEmpty) ...[
                if (pinned.isNotEmpty) const _Label('Other notes'),
                for (final n in others) _NoteCard(note: n),
              ],
            ],
          ),
          _ => const _NotesSkeleton(),
        },
      ),
      floatingActionButton: OpenContainer(
        // Root navigator: the opened page covers the bottom navigation bar.
        useRootNavigator: true,
        closedElevation: 3,
        openElevation: 0,
        closedColor: scheme.primaryContainer,
        openColor: scheme.surface,
        closedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        transitionDuration: const Duration(milliseconds: 450),
        openBuilder: (context, _) => const NoteEditorPage(),
        closedBuilder: (context, _) => SizedBox(
          height: 56,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.edit_outlined, color: scheme.onPrimaryContainer),
                const SizedBox(width: 12),
                Text(
                  'New note',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text, {this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
          ],
          Text(
            text,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.note});

  final Note note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: OpenContainer(
        // Root navigator: the opened page covers the bottom navigation bar.
        useRootNavigator: true,
        closedElevation: 0,
        openElevation: 0,
        closedColor: scheme.surfaceContainerLow,
        openColor: scheme.surface,
        closedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        transitionDuration: const Duration(milliseconds: 450),
        openBuilder: (context, _) => NoteEditorPage(noteId: note.id),
        closedBuilder: (context, _) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                note.title.isEmpty ? 'Untitled' : note.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (note.body.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  note.body,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Text(
                formatRelative(note.updatedAt),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotesSkeleton extends StatelessWidget {
  const _NotesSkeleton();

  @override
  Widget build(BuildContext context) {
    return Pulse(
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const NeverScrollableScrollPhysics(),
        children: [
          for (var i = 0; i < 4; i++)
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: SkeletonBox(height: 110, radius: 20),
            ),
        ],
      ),
    );
  }
}
