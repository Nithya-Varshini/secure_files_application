import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/buttons.dart';
import '../../settings/presentation/settings_cubit.dart';
import 'backup_cubit.dart';

class BackupPage extends StatelessWidget {
  const BackupPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backup = context.watch<BackupCubit>().state;
    final lastBackup = context.select(
      (SettingsCubit c) => c.state.lastBackupAt,
    );
    final recent =
        lastBackup != null && DateTime.now().difference(lastBackup).inDays < 30;

    return Scaffold(
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
                        Text('Last backup', style: theme.textTheme.labelLarge),
                        const SizedBox(height: 2),
                        Text(
                          lastBackup == null
                              ? 'Never'
                              : formatRelative(lastBackup),
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
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
            onPressed: backup.running ? null : () => _backup(context),
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
    );
  }

  Future<void> _backup(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final outcome = await context.read<BackupCubit>().runBackup();
    final text = switch (outcome) {
      BackupOutcome.saved => 'Encrypted backup saved',
      BackupOutcome.cancelled => 'Backup not saved',
      BackupOutcome.failed => "The backup couldn't be created",
    };
    messenger.showSnackBar(SnackBar(content: Text(text)));
  }

  void _explainRestore(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.settings_backup_restore_rounded),
        title: const Text('Restoring a backup'),
        content: const Text(
          'Restore on a new phone, or after reinstalling: open the app, and '
          'on the welcome screen choose "Restore from a backup". You will '
          'need the backup file and your 12-word recovery phrase.',
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
