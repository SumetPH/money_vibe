import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:money_vibe/providers/settings_provider.dart';
import 'package:money_vibe/widgets/calculator_keyboard.dart';

void main() {
  testWidgets('CalculatorKeyboard updates text controller and triggers done', (
    WidgetTester tester,
  ) async {
    final controller = TextEditingController();
    bool doneCalled = false;
    final settingsProvider =
        SettingsProvider(); // defaults to isDarkMode = true

    await tester.pumpWidget(
      ChangeNotifierProvider<SettingsProvider>.value(
        value: settingsProvider,
        child: MaterialApp(
          home: Scaffold(
            body: CalculatorKeyboard(
              controller: controller,
              onDone: () => doneCalled = true,
              actionButtonColor: Colors.blue,
            ),
          ),
        ),
      ),
    );

    // Verify buttons are rendered
    expect(find.text('7'), findsOneWidget);
    expect(find.text('AC'), findsOneWidget);
    expect(find.text('ตกลง'), findsOneWidget);

    // Tap '7', '8', '+'
    await tester.tap(find.text('7'));
    await tester.tap(find.text('8'));
    await tester.tap(find.text('+'));
    await tester.pump();
    expect(controller.text, '78+');

    // Tap '2', '='
    await tester.tap(find.text('2'));
    await tester.tap(find.text('='));
    await tester.pump();
    expect(controller.text, '80');

    // Tap Backspace (find by Icon)
    await tester.tap(find.byIcon(Icons.backspace_outlined));
    await tester.pump();
    expect(controller.text, '8');

    // Tap 'ตกลง' (Done)
    await tester.tap(find.text('ตกลง'));
    await tester.pump();
    expect(doneCalled, isTrue);
  });
}
