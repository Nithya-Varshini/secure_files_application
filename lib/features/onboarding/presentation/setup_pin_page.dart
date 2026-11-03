import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/pin_pad.dart';
import '../../authentication/domain/pin_policy.dart';
import 'vault_setup_cubit.dart';

class SetupPinPage extends StatefulWidget {
  const SetupPinPage({super.key});

  @override
  State<SetupPinPage> createState() => _SetupPinPageState();
}

class _SetupPinPageState extends State<SetupPinPage> {
  String? _first;
  String? _error;
  int _errorTick = 0;

  bool get _confirming => _first != null;

  void _onPin(String pin) {
    if (!_confirming) {
      final reason = PinPolicy.weaknessReason(pin);
      setState(() {
        if (reason != null) {
          _error = reason;
          _errorTick++;
        } else {
          _error = null;
          _first = pin;
        }
      });
      return;
    }

    if (pin == _first) {
      context.read<VaultSetupCubit>().setPin(pin);
      setState(() => _first = null);
      context.push(Routes.setupRecovery);
    } else {
      setState(() {
        _first = null;
        _error = "Those PINs didn't match. Let's start again.";
        _errorTick++;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        // First page of the setup ShellRoute's own navigator, so Flutter
        // shows no back arrow by itself.
        leading: BackButton(onPressed: () => context.go(Routes.welcome)),
      ),
      body: SafeArea(
        child: ScrollFill(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: StepHeader(
                    key: ValueKey(_confirming),
                    step: 1,
                    total: 3,
                    title: _confirming
                        ? 'Confirm your PIN'
                        : 'Create a 6-digit PIN',
                    subtitle: _confirming
                        ? 'Enter the same PIN once more.'
                        : "You'll use it to open your vault. Avoid birthdays "
                              'and patterns like 123456.',
                  ),
                ),
                const Spacer(),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    _error ?? '',
                    key: ValueKey(_error),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: scheme.error),
                  ),
                ),
                const SizedBox(height: 16),
                PinPad(errorTick: _errorTick, onCompleted: _onPin),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
