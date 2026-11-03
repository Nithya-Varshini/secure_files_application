import '../../settings/domain/auto_lock.dart';

enum CheckAction { none, settings, backup }

class SecurityCheck {
  const SecurityCheck({
    required this.title,
    required this.okText,
    required this.fixText,
    required this.ok,
    this.action = CheckAction.none,
  });

  final String title;
  final String okText;
  final String fixText;
  final bool ok;
  final CheckAction action;

  String get description => ok ? okText : fixText;
}

/// The protections that actually reduce risk. Biometric unlock is left out
/// on purpose: it is a convenience, not an extra layer of security.
abstract final class SecurityChecklist {
  static List<SecurityCheck> evaluate({
    required bool recoveryVerified,
    required AutoLockDelay autoLock,
    required bool screenshotProtection,
    required bool recentBackup,
  }) {
    return [
      const SecurityCheck(
        title: 'PIN lock',
        okText: 'A 6-digit PIN protects your vault.',
        fixText: '',
        ok: true,
      ),
      SecurityCheck(
        title: 'Recovery phrase',
        okText: 'Verified during setup.',
        fixText: 'Verify your recovery phrase so you can get back in.',
        ok: recoveryVerified,
      ),
      SecurityCheck(
        title: 'Auto-lock',
        okText: 'Locks ${autoLock.label.toLowerCase()} when you leave.',
        fixText: 'Lock within a minute of leaving the app.',
        ok: autoLock.duration <= const Duration(minutes: 1),
        action: CheckAction.settings,
      ),
      SecurityCheck(
        title: 'Screenshot blocking',
        okText: 'Screenshots and the app switcher show nothing.',
        fixText: 'Turn on to hide vault content from screenshots.',
        ok: screenshotProtection,
        action: CheckAction.settings,
      ),
      SecurityCheck(
        title: 'Encrypted backup',
        okText: 'Backed up in the last 30 days.',
        fixText: 'No recent backup. A lost phone means lost files.',
        ok: recentBackup,
        action: CheckAction.backup,
      ),
    ];
  }
}
