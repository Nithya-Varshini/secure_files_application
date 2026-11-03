import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/buttons.dart';
import '../../files/presentation/files_cubit.dart';
import '../../media_vault/presentation/media_cubit.dart';
import '../../notes/presentation/notes_cubit.dart';
import 'backup_cubit.dart';

class BackupPage extends StatelessWidget {
  const BackupPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backup = context.watch<BackupCubit>().state;
    final itemCount =
        context.select<MediaCubit, int>((c) => c.state.items.length) +
        context.select<FilesCubit, int>((c) => c.state.files.length) +
        context.select<NotesCubit, int>((c) => c.state.notes.length);
    final recent = backup.isRecent(DateTime.now());

    return BlocListener<BackupCubit, BackupState>(
      listenWhen: (a, b) => a.running && !b.running && b.lastFileName != null,
      listener: (context, state) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Backup saved as ${state.lastFileName}')),
      ),
      child: Scaffold(
        appBar: AppBar(title: const Text('Backup & restore')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Icon(
                        recent
                            ? Icons.verified_rounded
                            : Icons.warning_amber_rounded,
                        key: ValueKey(recent),
                        size: 40,
                        color: recent ? AppColors.success : AppColors.warning,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Last backup',
                            style: theme.textTheme.labelLarge,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            backup.lastBackupAt == null
                                ? 'Never'
                                : formatRelative(backup.lastBackupAt!),
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (backup.lastFileName != null)
                            Text(
                              backup.lastFileName!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              child: backup.running
                  ? Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LinearProgressIndicator(
                            value: backup.progress,
                            minHeight: 8,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          const SizedBox(height: 8),
                          Text(backup.step, style: theme.textTheme.bodyMedium),
                        ],
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              label: backup.running ? 'Backing up…' : 'Create encrypted backup',
              icon: Icons.lock_outline_rounded,
              onPressed: backup.running
                  ? null
                  : () => context.read<BackupCubit>().runBackup(
                      itemCount: itemCount,
                    ),
            ),
            const SizedBox(height: 12),
            SecondaryButton(
              label: 'Restore from a backup',
              icon: Icons.settings_backup_restore_rounded,
              onPressed: () => _explainRestore(context),
            ),
            const SizedBox(height: 32),
            Text(
              'How backups work',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const _HowItem(
              icon: Icons.key_rounded,
              title: 'Locked with your recovery phrase',
              body:
                  "The file is encrypted separately from this phone's "
                  'hardware keys, so your 12 words can open it on a new phone.',
            ),
            const _HowItem(
              icon: Icons.sd_storage_outlined,
              title: 'You choose where it goes',
              body:
                  'Save it to a computer, a USB drive or a cloud folder. It '
                  'stays unreadable without your phrase.',
            ),
            const _HowItem(
              icon: Icons.phonelink_erase_rounded,
              title: 'Keep a copy off this phone',
              body:
                  'If the phone is lost and the only backup was on it, the '
                  'vault cannot be recovered.',
            ),
          ],
        ),
      ),
    );
  }

  void _explainRestore(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.settings_backup_restore_rounded),
        title: const Text('Restoring a backup'),
        content: const Text(
          'Choose a backup file, then enter your 12-word recovery phrase. '
          'Items in the backup are added to this vault.\n\n'
          'Preview: restore arrives with the backup module.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}

class _HowItem extends StatelessWidget {
  const _HowItem({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: theme.colorScheme.onSecondaryContainer),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
