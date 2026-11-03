import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/pin_pad.dart';
import '../../settings/presentation/settings_cubit.dart';
import 'session_cubit.dart';

class LockPage extends StatefulWidget {
  const LockPage({super.key});

  @override
  State<LockPage> createState() => _LockPageState();
}

class _LockPageState extends State<LockPage> {
  int _errorTick = 0;
  String? _message;
  bool _checking = false;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    if (context.read<SessionCubit>().state.isLockedOut(DateTime.now())) {
      _startCountdown();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      final session = context.read<SessionCubit>().state;
      if (!session.isLockedOut(DateTime.now())) {
        timer.cancel();
        _message = null;
      }
      setState(() {});
    });
  }

  Future<void> _submit(String pin) async {
    final session = context.read<SessionCubit>();
    setState(() => _checking = true);
    final result = await session.unlockWithPin(pin);
    if (!mounted) return;
    setState(() {
      _checking = false;
      switch (result) {
        case UnlockResult.success:
          _message = null;
        case UnlockResult.wrongPin:
          _errorTick++;
          final left = session.attemptsLeft;
          _message = left == 1
              ? 'Wrong PIN. 1 try left before a short wait.'
              : 'Wrong PIN. $left tries left before a short wait.';
        case UnlockResult.lockedOut:
          _errorTick++;
          _message = null;
          _startCountdown();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final session = context.watch<SessionCubit>().state;
    final biometric = context.select(
      (SettingsCubit c) => c.state.biometricEnabled,
    );
    final now = DateTime.now();
    final lockedOut = session.isLockedOut(now);
    final wait = lockedOut ? session.lockedOutUntil!.difference(now) : null;

    final status = lockedOut
        ? 'Too many attempts. Try again in ${wait!.inSeconds + 1}s.'
        : _checking
        ? 'Checking…'
        : _message ?? 'Enter your PIN to unlock';
    final isError = lockedOut || (_message != null && !_checking);

    return Scaffold(
      body: SafeArea(
        child: ScrollFill(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 48),
                const AppLogo(size: 72),
                const SizedBox(height: 24),
                Text(
                  'Welcome back',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    status,
                    key: ValueKey(status),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: isError ? scheme.error : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const Spacer(),
                const SizedBox(height: 24),
                PinPad(
                  enabled: !lockedOut && !_checking,
                  errorTick: _errorTick,
                  onCompleted: _submit,
                  onBiometric: biometric && !lockedOut
                      ? context.read<SessionCubit>().unlockWithBiometric
                      : null,
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => context.push(Routes.recover),
                  child: const Text('Forgot PIN? Use your recovery phrase'),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
