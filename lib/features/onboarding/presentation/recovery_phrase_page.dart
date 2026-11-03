import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/common.dart';
import 'vault_setup_cubit.dart';

class RecoveryPhrasePage extends StatefulWidget {
  const RecoveryPhrasePage({super.key});

  @override
  State<RecoveryPhrasePage> createState() => _RecoveryPhrasePageState();
}

class _RecoveryPhrasePageState extends State<RecoveryPhrasePage> {
  bool _revealed = false;
  bool _writtenDown = false;

  @override
  Widget build(BuildContext context) {
    final phrase = context.select((VaultSetupCubit c) => c.state.phrase);
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
                  step: 2,
                  total: 3,
                  title: 'Save your recovery phrase',
                  subtitle:
                      'If you forget your PIN or lose this phone, these 12 '
                      'words are the only way to restore your vault.',
                ),
                const SizedBox(height: 20),
                const InfoBanner(
                  icon: Icons.edit_note_rounded,
                  text:
                      'Write the words on paper, in order. Copy is turned off '
                      'because other apps can read your clipboard.',
                ),
                const SizedBox(height: 20),
                _PhraseGrid(
                  words: phrase,
                  revealed: _revealed,
                  onReveal: () => setState(() => _revealed = true),
                ),
                const Spacer(),
                const SizedBox(height: 16),
                CheckboxListTile(
                  value: _writtenDown,
                  onChanged: _revealed
                      ? (v) => setState(() => _writtenDown = v ?? false)
                      : null,
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  title: const Text("I've written down all 12 words"),
                ),
                const SizedBox(height: 8),
                PrimaryButton(
                  label: 'Continue',
                  onPressed: _writtenDown
                      ? () => context.push(Routes.setupVerify)
                      : null,
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

class _PhraseGrid extends StatelessWidget {
  const _PhraseGrid({
    required this.words,
    required this.revealed,
    required this.onReveal,
  });

  final List<String> words;
  final bool revealed;
  final VoidCallback onReveal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final grid = GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: words.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 3.6,
      ),
      itemBuilder: (context, i) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 26,
              child: Text(
                '${i + 1}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            Text(
              words[i],
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );

    // Blurred until tapped, so a glance over the shoulder reveals nothing.
    return Stack(
      alignment: Alignment.center,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(end: revealed ? 0 : 9),
          duration: const Duration(milliseconds: 400),
          builder: (context, sigma, child) => ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
            child: child,
          ),
          child: ExcludeSemantics(excluding: !revealed, child: grid),
        ),
        IgnorePointer(
          ignoring: revealed,
          child: AnimatedOpacity(
            opacity: revealed ? 0 : 1,
            duration: const Duration(milliseconds: 250),
            child: FilledButton.tonalIcon(
              onPressed: onReveal,
              icon: const Icon(Icons.visibility_outlined),
              label: const Text('Tap to reveal'),
            ),
          ),
        ),
      ],
    );
  }
}
