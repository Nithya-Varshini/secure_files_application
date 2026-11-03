import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/widgets/buttons.dart';
import '../../authentication/presentation/session_cubit.dart';
import '../../settings/presentation/settings_cubit.dart';
import 'vault_setup_cubit.dart';

class BiometricSetupPage extends StatefulWidget {
  const BiometricSetupPage({super.key});

  @override
  State<BiometricSetupPage> createState() => _BiometricSetupPageState();
}

class _BiometricSetupPageState extends State<BiometricSetupPage> {
  bool _done = false;
  bool _opening = false;

  void _choose(bool enabled) {
    context.read<VaultSetupCubit>().setBiometric(enabled);
    setState(() => _done = true);
  }

  Future<void> _openVault() async {
    setState(() => _opening = true);
    final setup = context.read<VaultSetupCubit>().state;
    context.read<SettingsCubit>().setBiometric(setup.biometric);
    // The router redirects to the home screen as soon as the session
    // reports the vault as unlocked.
    await context.read<SessionCubit>().createVault(
      pin: setup.pin!,
      phrase: setup.phrase,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _done ? null : AppBar(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: PageTransitionSwitcher(
            duration: const Duration(milliseconds: 500),
            transitionBuilder: (child, animation, secondary) =>
                SharedAxisTransition(
                  animation: animation,
                  secondaryAnimation: secondary,
                  transitionType: SharedAxisTransitionType.scaled,
                  child: child,
                ),
            child: _done
                ? _ReadyView(
                    key: const ValueKey('ready'),
                    busy: _opening,
                    onOpen: _openVault,
                  )
                : _AskView(key: const ValueKey('ask'), onChoose: _choose),
          ),
        ),
      ),
    );
  }
}

class _AskView extends StatelessWidget {
  const _AskView({super.key, required this.onChoose});

  final ValueChanged<bool> onChoose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      children: [
        const Spacer(),
        Container(
          width: 160,
          height: 160,
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.fingerprint_rounded,
            size: 88,
            color: scheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(height: 32),
        Text(
          'Unlock faster with your fingerprint',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'Your PIN still protects the vault. Biometrics only let you skip '
          'typing it.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const Spacer(),
        PrimaryButton(
          label: 'Use fingerprint',
          icon: Icons.fingerprint_rounded,
          onPressed: () => onChoose(true),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => onChoose(false),
          child: const Text('Not now'),
        ),
      ],
    );
  }
}

class _ReadyView extends StatelessWidget {
  const _ReadyView({super.key, required this.busy, required this.onOpen});

  final bool busy;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      children: [
        const Spacer(),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 900),
          curve: Curves.elasticOut,
          builder: (context, scale, child) =>
              Transform.scale(scale: scale, child: child),
          child: Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [scheme.primary, scheme.tertiary],
              ),
            ),
            child: Icon(Icons.check_rounded, size: 76, color: scheme.onPrimary),
          ),
        ),
        const SizedBox(height: 32),
        Text(
          'Your vault is ready',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Add your first photo, document or note. Everything stays on this '
          'phone.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const Spacer(),
        PrimaryButton(
          label: busy ? 'Opening…' : 'Open my vault',
          onPressed: busy ? null : onOpen,
        ),
      ],
    );
  }
}
