import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_files_application/features/authentication/data/in_memory_auth_repository.dart';
import 'package:secure_files_application/features/authentication/presentation/session_cubit.dart';
import 'package:secure_files_application/features/onboarding/presentation/biometric_setup_page.dart';
import 'package:secure_files_application/features/onboarding/presentation/vault_setup_cubit.dart';

/// Fails like the Android "Empty key" crash seen on a real device.
class _FailingAuth extends InMemoryAuthRepository {
  @override
  Future<void> createVault({
    required String pin,
    required List<String> recoveryPhrase,
  }) async => throw StateError('keystore failure');
}

void main() {
  testWidgets('a failed vault creation shows an error and allows a retry', (
    tester,
  ) async {
    final errors = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = errors.add;
    addTearDown(() => FlutterError.onError = previous);

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => SessionCubit(_FailingAuth())),
          BlocProvider(create: (_) => VaultSetupCubit()..setPin('482915')),
        ],
        child: const MaterialApp(home: BiometricSetupPage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open my vault'));
    await tester.pumpAndSettle();

    expect(find.textContaining("couldn't be created"), findsOneWidget);
    expect(find.text('Open my vault'), findsOneWidget);
    expect(find.text('Encrypting your vault…'), findsNothing);
    expect(errors, hasLength(1));
  });
}
