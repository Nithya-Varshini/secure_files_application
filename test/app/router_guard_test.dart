import 'package:flutter_test/flutter_test.dart';
import 'package:secure_files_application/app/router.dart';
import 'package:secure_files_application/features/authentication/presentation/session_cubit.dart';

void main() {
  String? go(VaultStatus status, String location) =>
      guard(status, Uri.parse(location));

  group('no vault', () {
    test('sends everything to onboarding', () {
      expect(go(VaultStatus.noVault, '/home'), '/welcome');
      expect(go(VaultStatus.noVault, '/lock'), '/welcome');
    });

    test('allows the setup steps', () {
      expect(go(VaultStatus.noVault, '/welcome'), isNull);
      expect(go(VaultStatus.noVault, '/restore'), isNull);
      expect(go(VaultStatus.noVault, '/setup/recovery'), isNull);
    });
  });

  group('locked', () {
    test('redirects to the lock screen and remembers where you were', () {
      expect(go(VaultStatus.locked, '/note/n1'), '/lock?from=%2Fnote%2Fn1');
    });

    test('allows only lock and recovery', () {
      expect(go(VaultStatus.locked, '/lock'), isNull);
      expect(go(VaultStatus.locked, '/recover'), isNull);
    });
  });

  group('unlocked', () {
    test('returns to the remembered location after unlocking', () {
      expect(go(VaultStatus.unlocked, '/lock?from=%2Fnote%2Fn1'), '/note/n1');
    });

    test('keeps onboarding and lock out of reach', () {
      expect(go(VaultStatus.unlocked, '/lock'), '/home');
      expect(go(VaultStatus.unlocked, '/welcome'), '/home');
    });

    test('allows vault screens', () {
      expect(go(VaultStatus.unlocked, '/files'), isNull);
    });
  });
}
