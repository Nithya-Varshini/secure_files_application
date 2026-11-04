import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_files_application/app/splash.dart';

void main() {
  Widget app(VoidCallback onTap) => MaterialApp(
    home: SplashOverlay(
      child: Scaffold(
        body: Center(
          child: ElevatedButton(onPressed: onTap, child: const Text('Go')),
        ),
      ),
    ),
  );

  testWidgets('blocks touches while playing, then removes itself', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(app(() => taps++));

    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(AbsorbPointer), findsWidgets);
    await tester.tap(find.text('Go'), warnIfMissed: false);
    expect(taps, 0);

    await tester.pumpAndSettle();
    await tester.tap(find.text('Go'));
    expect(taps, 1);
  });

  testWidgets('is short when the system asks for no animations', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: app(() => taps++),
      ),
    );
    await tester.pump(const Duration(milliseconds: 450));
    await tester.tap(find.text('Go'));
    expect(taps, 1);
  });
}
