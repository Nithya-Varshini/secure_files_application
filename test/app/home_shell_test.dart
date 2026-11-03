import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_files_application/app/home_shell.dart';

void main() {
  Widget shell(int index) => MaterialApp(
    home: FadingBranchContainer(
      currentIndex: index,
      children: const [Text('first tab'), Text('second tab')],
    ),
  );

  double opacityOf(WidgetTester tester, String text) => tester
      .renderObject<RenderAnimatedOpacity>(
        find
            .ancestor(
              of: find.text(text),
              matching: find.byType(FadeTransition),
            )
            .first, // the nearest one is the tab's own fade
      )
      .opacity
      .value;

  // Regression: the outgoing tab's fade used to freeze at full opacity,
  // so returning to an earlier tab left the later one covering it.
  testWidgets('switching back to an earlier tab hides the later one', (
    tester,
  ) async {
    await tester.pumpWidget(shell(1));
    await tester.pumpAndSettle();
    await tester.pumpWidget(shell(0));
    await tester.pumpAndSettle();

    expect(opacityOf(tester, 'first tab'), 1);
    expect(opacityOf(tester, 'second tab'), 0);
  });
}
