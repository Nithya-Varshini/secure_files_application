import 'package:flutter_test/flutter_test.dart';
import 'package:secure_files_application/app/app.dart';
import 'package:secure_files_application/app/di.dart';
import 'package:secure_files_application/features/authentication/presentation/session_cubit.dart';

void main() {
  setUp(() async {
    await getIt.reset();
    configureDependencies();
  });

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
    await getIt<SessionCubit>().createVault(
      pin: '482915',
      phrase: List.filled(12, 'word'),
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
