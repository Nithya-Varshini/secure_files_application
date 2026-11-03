import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/common.dart';
import 'vault_setup_cubit.dart';

/// Proves the user really wrote the phrase down before any data is stored.
class VerifyPhrasePage extends StatefulWidget {
  const VerifyPhrasePage({super.key});

  @override
  State<VerifyPhrasePage> createState() => _VerifyPhrasePageState();
}

class _VerifyPhrasePageState extends State<VerifyPhrasePage> {
  late final List<String> _phrase;
  late final List<int> _positions;
  late final Map<int, List<String>> _options;
  final Map<int, String> _answers = {};

  @override
  void initState() {
    super.initState();
    _phrase = context.read<VaultSetupCubit>().state.phrase;
    final random = Random.secure();
    _positions = (List.generate(
      _phrase.length,
      (i) => i,
    )..shuffle(random)).take(3).toList()..sort();
    _options = {
      for (final p in _positions)
        p: () {
          final decoys = [..._phrase]
            ..removeAt(p)
            ..shuffle(random);
          return [_phrase[p], ...decoys.take(3)]..shuffle(random);
        }(),
    };
  }

  bool get _allCorrect => _positions.every((p) => _answers[p] == _phrase[p]);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: ScrollFill(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const StepHeader(
                  step: 3,
                  total: 3,
                  title: 'Check your phrase',
                  subtitle: 'Pick the right word for each position.',
                ),
                const SizedBox(height: 12),
                for (final p in _positions) ...[
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Text(
                        'Word #${p + 1}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        transitionBuilder: (child, animation) =>
                            ScaleTransition(scale: animation, child: child),
                        child: _answers[p] == null
                            ? const SizedBox.shrink()
                            : Icon(
                                _answers[p] == _phrase[p]
                                    ? Icons.check_circle_rounded
                                    : Icons.cancel_rounded,
                                key: ValueKey(_answers[p]),
                                size: 20,
                                color: _answers[p] == _phrase[p]
                                    ? AppColors.success
                                    : scheme.error,
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final word in _options[p]!)
                        ChoiceChip(
                          label: Text(word),
                          selected: _answers[p] == word,
                          selectedColor: word == _phrase[p]
                              ? scheme.primaryContainer
                              : scheme.errorContainer,
                          onSelected: (_) => setState(() => _answers[p] = word),
                        ),
                    ],
                  ),
                ],
                const Spacer(),
                const SizedBox(height: 24),
                PrimaryButton(
                  label: 'Continue',
                  onPressed: _allCorrect
                      ? () => context.push(Routes.setupBiometric)
                      : null,
                ),
                TextButton(
                  onPressed: () => context.pop(),
                  child: const Text('Show my phrase again'),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
