import 'package:flutter_test/flutter_test.dart';
import 'package:jass_app/main.dart';

void main() {
  testWidgets('JassApp renders HomeScreen', (WidgetTester tester) async {
    await tester.pumpWidget(const JassApp());
    expect(find.text('JASS'), findsOneWidget);
  });
}
