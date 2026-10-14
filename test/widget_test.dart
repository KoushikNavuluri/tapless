import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tapless/main.dart';

Future<void> boot(WidgetTester tester) async {
  await tester.pumpWidget(const TaplessApp());
  await tester.pumpAndSettle();
}

Future<void> tapText(WidgetTester tester, String text) async {
  final finder = find.text(text).first;
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('boots to the home screen', (tester) async {
    await boot(tester);

    expect(find.text('TAPLESS'), findsOneWidget);
    expect(find.text('Car mode'), findsOneWidget);
  });

  testWidgets('test run writes a run', (tester) async {
    await boot(tester);
    await tapText(tester, 'Test run');

    expect(find.text('Car mode ran'), findsOneWidget);
  });

  testWidgets('builder saves a gym automation', (tester) async {
    await boot(tester);
    await tapText(tester, 'Build an automation');

    await tester.enterText(find.byType(TextField), 'At the gym, silence my phone');
    await tester.pumpAndSettle();
    await tapText(tester, 'Build');
    expect(find.text('Recipe matched · no AI call'), findsOneWidget);

    await tapText(tester, 'Cult.fit Kondapur');
    await tapText(tester, 'Gym Bangers');
    await tapText(tester, 'Save to Tapless');

    expect(find.text('Gym mode saved and armed'), findsOneWidget);
  });

  test('compiler maps plain text to a rule', () {
    final rule = compileText('When I plug in, turn on DND');

    expect(rule.trigger, 'You plug in');
    expect(rule.actions, contains('Do Not Disturb priority'));
  });
}
