import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/common.dart';
import '../../../core/widgets/pin_pad.dart';
import '../domain/pin_policy.dart';
import 'session_cubit.dart';

enum _Stage { current, fresh, confirm }

class ChangePinPage extends StatefulWidget {
  const ChangePinPage({super.key});

  @override
  State<ChangePinPage> createState() => _ChangePinPageState();
}

class _ChangePinPageState extends State<ChangePinPage> {
  _Stage _stage = _Stage.current;
  String? _current;
  String? _fresh;
  String? _error;
  int _errorTick = 0;

  void _fail(String message, {_Stage? restartAt}) => setState(() {
    _error = message;
    _errorTick++;
    if (restartAt != null) _stage = restartAt;
  });

  Future<void> _onPin(String pin) async {
    final session = context.read<SessionCubit>();
    switch (_stage) {
      case _Stage.current:
        if (!await session.checkPin(pin)) return _fail('That PIN is wrong.');
        setState(() {
          _current = pin;
          _error = null;
          _stage = _Stage.fresh;
        });
      case _Stage.fresh:
        final reason = PinPolicy.weaknessReason(pin);
        if (reason != null) return _fail(reason);
        if (pin == _current) return _fail('Choose a PIN you have not used.');
        setState(() {
          _fresh = pin;
          _error = null;
          _stage = _Stage.confirm;
        });
      case _Stage.confirm:
        if (pin != _fresh) {
          return _fail(
            "Those PINs didn't match. Enter the new PIN again.",
            restartAt: _Stage.fresh,
          );
        }
        final messenger = ScaffoldMessenger.of(context);
        await session.changePin(currentPin: _current!, newPin: pin);
        if (!mounted) return;
        context.pop();
        messenger.showSnackBar(const SnackBar(content: Text('PIN changed')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = switch (_stage) {
      _Stage.current => 'Enter your current PIN',
      _Stage.fresh => 'Choose a new PIN',
      _Stage.confirm => 'Confirm your new PIN',
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Change PIN')),
      body: SafeArea(
        child: ScrollFill(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 24),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Text(
                    title,
                    key: ValueKey(title),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _error ?? '',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
                const Spacer(),
                PinPad(errorTick: _errorTick, onCompleted: _onPin),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
