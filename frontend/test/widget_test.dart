import 'package:flutter_test/flutter_test.dart';
import 'package:kabin/main.dart';

void main() {
  testWidgets('KabinApp smoke test renders scaffold placeholder', (tester) async {
    await tester.pumpWidget(const KabinApp());
    expect(find.text('Kabin — scaffold'), findsOneWidget);
  });
}
