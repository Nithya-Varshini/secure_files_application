import 'package:flutter_test/flutter_test.dart';
import 'package:secure_files_application/main.dart';

void main() {
  testWidgets('app boots and renders the home screen', (tester) async {
    await tester.pumpWidget(const MainApp());
    expect(find.text('Hello World!'), findsOneWidget);
  });
}
