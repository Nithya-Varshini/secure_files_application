import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/protection_ring.dart';
import '../../authentication/presentation/session_cubit.dart';
import '../../settings/presentation/settings_cubit.dart';
import '../domain/security_check.dart';

class SecurityCenterPage extends StatelessWidget {
  const SecurityCenterPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final session = context.watch<SessionCubit>().state;
    final settings = context.watch<SettingsCubit>().state;
    final checks = SecurityChecklist.evaluate(
      recoveryVerified: session.recoveryVerified,
      autoLock: settings.autoLock,
      screenshotProtection: settings.screenshotProtection,
      recentBackup: settings.backupIsRecent(DateTime.now()),
    );
    final done = checks.where((c) => c.ok).length;
    final headline = switch (checks.length - done) {
      0 => 'Well protected',
      1 => 'Almost there',
      _ => 'Needs attention',
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Security centre')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Center(
            child: ProtectionRing(
              done: done,
              total: checks.length,
              size: 148,
              strokeWidth: 12,
              color: done == checks.length ? AppColors.success : scheme.primary,
              label: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$done/${checks.length}',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text('protections on', style: theme.textTheme.labelMedium),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              headline,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final check in checks)
                  ListTile(
                    leading: Icon(
                      check.ok
                          ? Icons.check_circle_rounded
                          : Icons.error_outline_rounded,
                      color: check.ok ? AppColors.success : AppColors.warning,
                    ),
                    title: Text(check.title),
                    subtitle: Text(check.description),
                    trailing: check.ok || check.action == CheckAction.none
                        ? null
                        : const Icon(Icons.chevron_right_rounded),
                    onTap: check.ok
                        ? null
                        : switch (check.action) {
                            CheckAction.settings => () => context.push(
                              Routes.settings,
                            ),
                            CheckAction.backup => () => context.push(
                              Routes.backup,
                            ),
                            CheckAction.none => null,
                          },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'Recent activity',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: session.events.isEmpty
                ? const ListTile(title: Text('No activity yet'))
                : Column(
                    children: [
                      for (final e in session.events.take(8))
                        ListTile(
                          dense: true,
                          leading: Icon(
                            _eventIcon(e.type),
                            color: _isWarning(e.type)
                                ? AppColors.warning
                                : scheme.onSurfaceVariant,
                          ),
                          title: Text(_eventLabel(e.type)),
                          trailing: Text(
                            formatRelative(e.at),
                            style: theme.textTheme.labelSmall,
                          ),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 20),
          Card(
            clipBehavior: Clip.antiAlias,
            child: ExpansionTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: const Text("What this app can't protect against"),
              childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _Limit(
                  'Malware with full control of the phone while the vault is open.',
                ),
                _Limit('Someone who forces you to unlock it.'),
                _Limit(
                  'Copies made before import, such as cloud photo backups.',
                ),
                _Limit('A camera pointed at your screen.'),
                _Limit('Guaranteed erasure from flash storage after deletion.'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static bool _isWarning(SecurityEventType t) =>
      t == SecurityEventType.failedAttempt || t == SecurityEventType.lockedOut;

  static IconData _eventIcon(SecurityEventType t) => switch (t) {
    SecurityEventType.vaultCreated => Icons.add_moderator_outlined,
    SecurityEventType.unlocked => Icons.lock_open_rounded,
    SecurityEventType.biometricUnlock => Icons.fingerprint_rounded,
    SecurityEventType.failedAttempt => Icons.gpp_maybe_outlined,
    SecurityEventType.lockedOut => Icons.timer_outlined,
    SecurityEventType.locked => Icons.lock_outline_rounded,
    SecurityEventType.pinChanged => Icons.password_rounded,
    SecurityEventType.recovered => Icons.settings_backup_restore_rounded,
  };

  static String _eventLabel(SecurityEventType t) => switch (t) {
    SecurityEventType.vaultCreated => 'Vault created',
    SecurityEventType.unlocked => 'Unlocked with PIN',
    SecurityEventType.biometricUnlock => 'Unlocked with fingerprint',
    SecurityEventType.failedAttempt => 'Wrong PIN entered',
    SecurityEventType.lockedOut => 'Too many attempts, paused',
    SecurityEventType.locked => 'Vault locked',
    SecurityEventType.pinChanged => 'PIN changed',
    SecurityEventType.recovered => 'Recovered with phrase',
  };
}

class _Limit extends StatelessWidget {
  const _Limit(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•  '),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
