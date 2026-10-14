import 'package:flutter_test/flutter_test.dart';
import 'package:tapless/main.dart';
void main() { testWidgets('Tapless boots', (tester) async { await tester.pumpWidget(const TaplessApp()); await tester.pump(const Duration(seconds: 1)); expect(find.text('TAPLESS'), findsOneWidget); }); }
