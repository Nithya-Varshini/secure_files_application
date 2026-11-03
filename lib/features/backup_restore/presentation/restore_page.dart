import 'dart:typed_data';

import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/di.dart';
import '../../../core/platform/pickers.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/pin_pad.dart';
import '../../authentication/domain/pin_policy.dart';
import '../../authentication/domain/recovery_phrase.dart';
import '../../authentication/presentation/session_cubit.dart';
import '../data/backup_service.dart';

enum _Stage { file, phrase, pin, confirm, restoring }

/// Restores a vault on a new phone (or after reinstalling) from a backup
/// file and the 12-word phrase. Nothing is written until the whole backup
/// has been decrypted and verified.
class RestorePage extends StatefulWidget {
  const RestorePage({super.key});

  @override
  State<RestorePage> createState() => _RestorePageState();
}

class _RestorePageState extends State<RestorePage> {
  final _phrase = TextEditingController();
  _Stage _stage = _Stage.file;
  Uint8List? _backup;
  String? _fileName;
  List<String> _words = const [];
  String? _pin;
  String? _error;
  int _errorTick = 0;
  bool _busy = false;

  @override
  void dispose() {
    _phrase.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final picked = await getIt<DocumentPicker>().pickDocuments();
    if (!mounted) return;
    if (picked.isEmpty) {
      setState(() => _busy = false);
      return;
    }
    final file = picked.first;
    final bytes = await file.readAll();
    await file.discardPluginCopy();
    setState(() {
      _busy = false;
      _backup = bytes;
      _fileName = file.name;
      _stage = _Stage.phrase;
    });
  }

  void _checkPhrase() {
    final words = RecoveryPhrase.normalise(_phrase.text);
    if (!RecoveryPhrase.isValid(words)) {
      setState(
        () => _error =
            "Those words don't form a valid phrase. Check the spelling and "
            'the order.',
      );
      return;
    }
    setState(() {
      _words = words;
      _error = null;
      _stage = _Stage.pin;
    });
  }

  Future<void> _onPin(String pin) async {
    if (_stage == _Stage.pin) {
      final reason = PinPolicy.weaknessReason(pin);
      setState(() {
        if (reason != null) {
          _error = reason;
          _errorTick++;
        } else {
          _error = null;
          _pin = pin;
          _stage = _Stage.confirm;
        }
      });
      return;
    }
    if (pin != _pin) {
      setState(() {
        _error = "Those PINs didn't match. Let's start again.";
        _errorTick++;
        _stage = _Stage.pin;
      });
      return;
    }
    await _restore();
  }

  Future<void> _restore() async {
    setState(() {
      _stage = _Stage.restoring;
      _error = null;
    });
    final session = context.read<SessionCubit>();
    try {
      final ok = await getIt<BackupService>().restore(
        backup: _backup!,
        words: _words,
        newPin: _pin!,
      );
      if (!mounted) return;
      if (ok) {
        // The router takes the user into the restored vault.
        session.restoredFromBackup();
      } else {
        setState(() {
          _stage = _Stage.phrase;
          _error = "This phrase doesn't open that backup.";
        });
      }
    } on BackupFormatException catch (e) {
      if (!mounted) return;
      setState(() {
        _stage = _Stage.file;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Restore from a backup')),
      body: SafeArea(
        child: PageTransitionSwitcher(
          transitionBuilder: (child, animation, secondary) =>
              SharedAxisTransition(
                animation: animation,
                secondaryAnimation: secondary,
                transitionType: SharedAxisTransitionType.horizontal,
                child: child,
              ),
          child: switch (_stage) {
            _Stage.file => _buildFile(context),
            _Stage.phrase => _buildPhrase(context),
            _Stage.pin || _Stage.confirm => _buildPin(context),
            _Stage.restoring => const Center(
              key: ValueKey('restoring'),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Decrypting and checking your backup…'),
                ],
              ),
            ),
          },
        ),
      ),
    );
  }

  Widget _buildFile(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      key: const ValueKey('file'),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Choose your backup file',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'It ends in .vbak. You will then need your 12-word recovery '
            'phrase to open it.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            InfoBanner(
              icon: Icons.error_outline_rounded,
              tone: BannerTone.warning,
              text: _error!,
            ),
          ],
          const Spacer(),
          PrimaryButton(
            label: _busy ? 'Opening…' : 'Choose file',
            icon: Icons.folder_open_rounded,
            onPressed: _busy ? null : _pickFile,
          ),
        ],
      ),
    );
  }

  Widget _buildPhrase(BuildContext context) {
    return ScrollFill(
      key: const ValueKey('phrase'),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InfoBanner(
              icon: Icons.description_outlined,
              text: 'Backup: ${_fileName ?? 'selected file'}',
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _phrase,
              minLines: 4,
              maxLines: 6,
              autocorrect: false,
              enableSuggestions: false,
              enableIMEPersonalizedLearning: false,
              decoration: InputDecoration(
                hintText: 'Your 12 words, separated by spaces',
                errorText: _error,
              ),
            ),
            const Spacer(),
            const SizedBox(height: 24),
            PrimaryButton(label: 'Continue', onPressed: _checkPhrase),
          ],
        ),
      ),
    );
  }

  Widget _buildPin(BuildContext context) {
    final confirming = _stage == _Stage.confirm;
    final theme = Theme.of(context);
    return ScrollFill(
      key: const ValueKey('pin'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const SizedBox(height: 16),
            Text(
              confirming
                  ? 'Confirm your new PIN'
                  : 'Choose a PIN for this phone',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
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
    );
  }
}
