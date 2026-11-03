import 'dart:io';

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
