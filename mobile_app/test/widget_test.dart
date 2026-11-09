import 'package:flutter_test/flutter_test.dart';
import 'package:smokeguard_mobile/main.dart';

void main() {
  testWidgets('SmokeGuardApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const SmokeGuardApp());
    expect(find.text('SmokeGuard AI'), findsOneWidget);
  });
}
