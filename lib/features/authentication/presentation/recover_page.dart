import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/pin_pad.dart';
import '../domain/pin_policy.dart';
import '../domain/recovery_phrase.dart';
import 'session_cubit.dart';

enum _Stage { phrase, newPin, confirmPin }

class RecoverPage extends StatefulWidget {
  const RecoverPage({super.key});

  @override
  State<RecoverPage> createState() => _RecoverPageState();
}

class _RecoverPageState extends State<RecoverPage> {
  final _controller = TextEditingController();
  _Stage _stage = _Stage.phrase;
  List<String> _words = const [];
  String? _newPin;
  String? _error;
  int _errorTick = 0;
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _checkPhrase() async {
    final words = RecoveryPhrase.normalise(_controller.text);
    if (words.length != RecoveryPhrase.wordCount) {
      setState(() => _error = 'Enter all 12 words, separated by spaces.');
      return;
    }
    if (!RecoveryPhrase.isValid(words)) {
      setState(
        () => _error =
            "Those words don't form a valid phrase. Check the spelling and "
            'the order.',
      );
      return;
    }
    setState(() => _busy = true);
    final ok = await context.read<SessionCubit>().checkRecoveryPhrase(words);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (ok) {
        _words = words;
        _error = null;
        _stage = _Stage.newPin;
      } else {
        _error = "That phrase doesn't match this vault. Check the order.";
      }
    });
  }

  Future<void> _onPin(String pin) async {
    if (_stage == _Stage.newPin) {
      final reason = PinPolicy.weaknessReason(pin);
      setState(() {
        if (reason != null) {
          _error = reason;
          _errorTick++;
        } else {
          _error = null;
          _newPin = pin;
          _stage = _Stage.confirmPin;
        }
      });
      return;
    }
    if (pin != _newPin) {
      setState(() {
        _error = "Those PINs didn't match. Let's start again.";
        _errorTick++;
        _newPin = null;
        _stage = _Stage.newPin;
      });
      return;
    }
    // On success the router sends the user straight into the vault.
    await context.read<SessionCubit>().recover(words: _words, newPin: pin);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recover your vault')),
      body: SafeArea(
        child: PageTransitionSwitcher(
          transitionBuilder: (child, animation, secondary) =>
              SharedAxisTransition(
                animation: animation,
                secondaryAnimation: secondary,
                transitionType: SharedAxisTransitionType.horizontal,
                child: child,
              ),
          child: _stage == _Stage.phrase
              ? _buildPhraseStep(context)
              : _buildPinStep(context),
        ),
      ),
    );
  }

  Widget _buildPhraseStep(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ScrollFill(
      key: const ValueKey('phrase'),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Enter the 12 words you wrote down when you created the vault.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _controller,
              minLines: 4,
              maxLines: 6,
              autocorrect: false,
              enableSuggestions: false,
              // Keyboards must not learn or sync the phrase (threat L10).
              enableIMEPersonalizedLearning: false,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                hintText: 'word1 word2 word3 …',
                errorText: _error,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Your PIN will be replaced. Your files stay as they are.',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const Spacer(),
            const SizedBox(height: 24),
            PrimaryButton(
              label: _busy ? 'Checking…' : 'Continue',
              onPressed: _busy ? null : _checkPhrase,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPinStep(BuildContext context) {
    final confirming = _stage == _Stage.confirmPin;
    return ScrollFill(
      key: const ValueKey('pin'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const SizedBox(height: 16),
            Text(
              confirming ? 'Confirm your new PIN' : 'Choose a new PIN',
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(
              _error ?? '',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const Spacer(),
            PinPad(errorTick: _errorTick, onCompleted: _onPin),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
