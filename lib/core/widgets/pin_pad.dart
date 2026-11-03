import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Numeric keypad with animated PIN dots.
///
/// Bump [errorTick] to shake the dots and clear the entry after a wrong PIN.
class PinPad extends StatefulWidget {
  const PinPad({
    super.key,
    required this.onCompleted,
    this.length = 6,
    this.errorTick = 0,
    this.enabled = true,
    this.onBiometric,
  });

  final ValueChanged<String> onCompleted;
  final int length;
  final int errorTick;
  final bool enabled;
  final VoidCallback? onBiometric;

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> with SingleTickerProviderStateMixin {
  String _value = '';
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void didUpdateWidget(PinPad oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.errorTick != oldWidget.errorTick) {
      HapticFeedback.heavyImpact();
      _shake.forward(from: 0);
      setState(() => _value = '');
    }
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  void _press(String digit) {
    if (!widget.enabled || _value.length >= widget.length) return;
    HapticFeedback.selectionClick();
    setState(() => _value += digit);
    if (_value.length == widget.length) {
      final pin = _value;
      // A short pause lets the last dot fill before the parent reacts.
      Future<void>.delayed(const Duration(milliseconds: 140), () {
        if (!mounted) return;
        setState(() => _value = '');
        widget.onCompleted(pin);
      });
    }
  }

  void _backspace() {
    if (!widget.enabled || _value.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() => _value = _value.substring(0, _value.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _shake,
          builder: (context, child) {
            final t = _shake.value;
            final dx = math.sin(t * math.pi * 6) * 14 * (1 - t);
            return Transform.translate(offset: Offset(dx, 0), child: child);
          },
          child: Semantics(
            label: '${_value.length} of ${widget.length} digits entered',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < widget.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutBack,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    width: i < _value.length ? 16 : 14,
                    height: i < _value.length ? 16 : 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < _value.length
                          ? scheme.primary
                          : Colors.transparent,
                      border: Border.all(
                        color: i < _value.length
                            ? scheme.primary
                            : scheme.outline,
                        width: 2,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final digit in row)
                _Key(
                  label: digit,
                  enabled: widget.enabled,
                  onTap: () => _press(digit),
                ),
            ],
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.onBiometric != null)
              _Key(
                icon: Icons.fingerprint_rounded,
                semanticLabel: 'Unlock with biometrics',
                enabled: widget.enabled,
                onTap: widget.onBiometric!,
              )
            else
              const SizedBox.square(dimension: _Key.size + _Key.gap * 2),
            _Key(label: '0', enabled: widget.enabled, onTap: () => _press('0')),
            _Key(
              icon: Icons.backspace_outlined,
              semanticLabel: 'Delete last digit',
              enabled: widget.enabled,
              onTap: _backspace,
            ),
          ],
        ),
      ],
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({
    this.label,
    this.icon,
    this.semanticLabel,
    required this.enabled,
    required this.onTap,
  });

  static const double size = 68;
  static const double gap = 10;

  final String? label;
  final IconData? icon;
  final String? semanticLabel;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDigit = label != null;
    return Padding(
      padding: const EdgeInsets.all(gap),
      child: SizedBox.square(
        dimension: size,
        child: Material(
          color: isDigit ? scheme.surfaceContainerHigh : Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: enabled ? onTap : null,
            child: Center(
              child: isDigit
                  ? Text(
                      label!,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: enabled
                            ? scheme.onSurface
                            : scheme.onSurface.withValues(alpha: 0.38),
                      ),
                    )
                  : Icon(icon, size: 28, semanticLabel: semanticLabel),
            ),
          ),
        ),
      ),
    );
  }
}
