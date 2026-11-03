import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../authentication/presentation/session_cubit.dart';
import '../domain/auto_lock.dart';
import 'settings_cubit.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsCubit>().state;
    final cubit = context.read<SettingsCubit>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          _Group(
            title: 'Security',
            children: [
              ListTile(
                leading: const Icon(Icons.password_rounded),
                title: const Text('Change PIN'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push(Routes.changePin),
              ),
              const _BiometricTile(),
              ListTile(
                leading: const Icon(Icons.timer_outlined),
                title: const Text('Auto-lock'),
                subtitle: Text(settings.autoLock.label),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _pickAutoLock(context, settings.autoLock),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.screenshot_monitor_rounded),
                title: const Text('Block screenshots'),
                subtitle: const Text(
                  'Hide vault content from screenshots and the app switcher',
                ),
                value: settings.screenshotProtection,
                onChanged: cubit.setScreenshotProtection,
              ),
            ],
          ),
          _Group(
            title: 'Your data',
            children: [
              ListTile(
                leading: const Icon(Icons.backup_outlined),
                title: const Text('Backup & restore'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push(Routes.backup),
              ),
              ListTile(
                leading: const Icon(Icons.health_and_safety_outlined),
                title: const Text('Security centre'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push(Routes.security),
              ),
            ],
          ),
          _Group(
            title: 'Appearance',
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.system,
                      icon: Icon(Icons.brightness_auto_rounded),
                      label: Text('System'),
                    ),
                    ButtonSegment(
                      value: ThemeMode.light,
                      icon: Icon(Icons.light_mode_rounded),
                      label: Text('Light'),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      icon: Icon(Icons.dark_mode_rounded),
                      label: Text('Dark'),
                    ),
                  ],
                  selected: {settings.themeMode},
                  onSelectionChanged: (s) => cubit.setThemeMode(s.first),
                ),
              ),
            ],
          ),
          _Group(
            title: 'About',
            children: [
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: const Text('How your data is protected'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _showPrivacy(context),
              ),
              const ListTile(
                leading: Icon(Icons.info_outline_rounded),
                title: Text('Version'),
                subtitle: Text('0.1.0 · Preview build'),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: scheme.error,
                side: BorderSide(color: scheme.error),
                minimumSize: const Size.fromHeight(52),
              ),
              onPressed: () => _confirmDeleteVault(context),
              icon: const Icon(Icons.delete_forever_outlined),
              label: const Text('Delete vault'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAutoLock(
    BuildContext context,
    AutoLockDelay current,
  ) async {
    final cubit = context.read<SettingsCubit>();
    final picked = await showDialog<AutoLockDelay>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Lock the vault'),
        children: [
          for (final delay in AutoLockDelay.values)
            ListTile(
              title: Text(delay.label),
              trailing: delay == current
                  ? Icon(
                      Icons.check_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  : null,
              onTap: () => Navigator.pop(context, delay),
            ),
        ],
      ),
    );
    if (picked != null) cubit.setAutoLock(picked);
  }

  void _showPrivacy(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          children: [
            Text(
              'How your data is protected',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            const Text(
              'Everything in the vault is encrypted on this phone with '
              'AES-256-GCM before it is stored, including file names and '
              'thumbnails.\n\n'
              'Your PIN never leaves the device. It unlocks a key that is also '
              "bound to this phone's secure hardware, so copying the files "
              'elsewhere does not help an attacker.\n\n'
              'There is no account and no server. We cannot see your data, '
              'and we cannot reset your PIN; your recovery phrase is the only '
              'way back in.\n\n'
              'Preview build: these protections are being built module by '
              'module and are not active yet.',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteVault(BuildContext context) async {
    final session = context.read<SessionCubit>();
    final settings = context.read<SettingsCubit>();
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          icon: Icon(
            Icons.delete_forever_outlined,
            color: Theme.of(context).colorScheme.error,
          ),
          title: const Text('Delete this vault?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Everything inside is erased and cannot be recovered, even '
                'with your recovery phrase. Type DELETE to confirm.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                enableIMEPersonalizedLearning: false,
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              onPressed: controller.text.trim() == 'DELETE'
                  ? () => Navigator.pop(context, true)
                  : null,
              child: const Text('Delete'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (confirmed ?? false) {
      settings.reset();
      await session.deleteVault();
    }
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 20, 8),
          child: Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: Column(children: children),
          ),
        ),
      ],
    );
  }
}

/// Enabling asks for a fingerprint, then wraps the master key with a
/// Keystore key that only works right after a biometric check.
class _BiometricTile extends StatefulWidget {
  const _BiometricTile();

  @override
  State<_BiometricTile> createState() => _BiometricTileState();
}

class _BiometricTileState extends State<_BiometricTile> {
  bool? _available;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    context.read<SessionCubit>().biometricsAvailable().then((v) {
      if (mounted) setState(() => _available = v);
    });
  }

  Future<void> _toggle(bool enable) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    final ok = await context.read<SessionCubit>().setBiometrics(enable);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Fingerprint unlock was not turned on')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final enrolled = context.select(
      (SessionCubit c) => c.state.biometricsEnrolled,
    );
    final available = _available ?? false;
    return SwitchListTile(
      secondary: const Icon(Icons.fingerprint_rounded),
      title: const Text('Biometric unlock'),
      subtitle: Text(
        _available == false
            ? 'Not available on this device'
            : 'Use your fingerprint instead of the PIN',
      ),
      value: enrolled,
      onChanged: available && !_busy ? _toggle : null,
    );
  }
}
