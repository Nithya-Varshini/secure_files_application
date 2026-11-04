import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:secure_files_application/app/app.dart';
import 'package:secure_files_application/app/di.dart';
import 'package:secure_files_application/core/crypto/vault_crypto.dart';
import 'package:secure_files_application/core/storage/vault_paths.dart';
import 'package:secure_files_application/features/authentication/presentation/session_cubit.dart';

import 'support/fakes.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('vault_app');
    await getIt.reset();
    await configureDependencies(
      paths: VaultPaths(
        root: Directory('${dir.path}/vault'),
        temp: Directory('${dir.path}/tmp'),
      ),
      keystore: FakeKeystore(),
      biometrics: FakeBiometrics(),
      kdf: KdfParams.testing,
    );
  });

  tearDown(() => dir.delete(recursive: true));

  testWidgets('first launch shows onboarding', (tester) async {
    await tester.pumpWidget(const VaultApp());
    await tester.pumpAndSettle();

    expect(find.text('Your private space'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
  });

  testWidgets('onboarding leads to PIN creation', (tester) async {
    await tester.pumpWidget(const VaultApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create my vault'));
    await tester.pumpAndSettle();

    expect(find.text('Create a 6-digit PIN'), findsOneWidget);
  });

  testWidgets('Back on a tab goes Home; Back on Home closes the app', (
    tester,
  ) async {
    var exits = 0;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'SystemNavigator.pop') exits++;
        return null;
      },
    );
    await tester.runAsync(
      () => getIt<SessionCubit>().createVault(
        pin: '482915',
        phrase: const [
          'abandon', 'abandon', 'abandon', 'abandon', 'abandon', 'abandon', //
          'abandon', 'abandon', 'abandon', 'abandon', 'abandon', 'about',
        ],
      ),
    );
    await tester.pumpWidget(const VaultApp());
    await tester.pumpAndSettle();

    for (final tab in ['Gallery', 'Files', 'Notes']) {
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(tab),
        ),
      );
      // Tabs show an endless loading skeleton here (their data loads with
      // real file I/O), so pump fixed time instead of pumpAndSettle.
      await tester.pump(const Duration(seconds: 1));
      final home = find.text('Your vault').hitTestable();
      expect(home, findsNothing, reason: 'on $tab');

      await tester.binding.handlePopRoute(); // Android Back
      await tester.pump(const Duration(seconds: 1));
      expect(exits, 0, reason: 'Back on $tab must not close the app');
      expect(home, findsOneWidget, reason: 'Back on $tab goes Home');
    }

    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(seconds: 1));
    expect(exits, 1, reason: 'Back on Home closes the app');
  });

  testWidgets('locking the vault shows the lock screen', (tester) async {
    // Real file and crypto work must run outside the fake test clock.
    await tester.runAsync(
      () => getIt<SessionCubit>().createVault(
        pin: '482915',
        phrase: const [
          'abandon', 'abandon', 'abandon', 'abandon', 'abandon', 'abandon', //
          'abandon', 'abandon', 'abandon', 'abandon', 'abandon', 'about',
        ],
      ),
    );
    await tester.pumpWidget(const VaultApp());
    await tester.pumpAndSettle();
    expect(find.text('Your vault'), findsOneWidget);

    getIt<SessionCubit>().lock();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
  });
}
