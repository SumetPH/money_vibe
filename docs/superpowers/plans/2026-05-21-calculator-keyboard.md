# Custom Calculator Keyboard Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement a custom calculator keyboard for numerical amount inputs in the transaction creation and editing form.

**Architecture:** A reusable `CalculatorKeyboard` widget renders a 5x4 grid of buttons and updates the active `TextEditingController`. It evaluates math expressions using `math_expressions`. In `TransactionFormScreen`, the keyboard is presented using a Scaffold bottom sheet triggered by `FocusNode` state changes on read-only, cursor-enabled text fields.

**Tech Stack:** Flutter (Dart), `math_expressions` package, Provider (for settings/theme)

---

### Task 1: Add Dependency

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Modify pubspec.yaml**
  Add `math_expressions: ^2.6.0` to the dependencies section of [pubspec.yaml](file:///Users/sumetph/Development/money/money_vibe/pubspec.yaml).

  ```yaml
  dependencies:
    flutter:
      sdk: flutter
    # ... other dependencies
    math_expressions: ^2.6.0
  ```

- [ ] **Step 2: Run pub get**
  Run command: `flutter pub get` in `/Users/sumetph/Development/money/money_vibe`.
  Expected: Command completes successfully with exit code 0.

- [ ] **Step 3: Commit**
  Run:
  ```bash
  git add pubspec.yaml
  git commit -m "chore: add math_expressions dependency"
  ```

---

### Task 2: Math Evaluator Utility and Tests

**Files:**
- Create: `lib/utils/math_evaluator.dart`
- Create: `test/math_evaluator_test.dart`

- [ ] **Step 1: Write the unit tests for evaluator**
  Create [math_evaluator_test.dart](file:///Users/sumetph/Development/money/money_vibe/test/math_evaluator_test.dart) with test cases verifying basic operations, decimal arithmetic, operator replacement, and error scenarios.

  ```dart
  import 'package:flutter_test/flutter_test.dart';
  import 'package:money_vibe/utils/math_evaluator.dart';

  void main() {
    group('Math Evaluator Tests', () {
      test('should parse and evaluate basic math expressions', () {
        expect(MathEvaluator.evaluate('100+50-20'), 130.0);
        expect(MathEvaluator.evaluate('10*5/2'), 25.0);
      });

      test('should strip trailing operators before evaluating', () {
        expect(MathEvaluator.evaluate('100+50-'), 150.0);
        expect(MathEvaluator.evaluate('20*5/'), 100.0);
      });

      test('should return null for invalid expressions', () {
        expect(MathEvaluator.evaluate('100++50'), null);
        expect(MathEvaluator.evaluate('abc'), null);
        expect(MathEvaluator.evaluate(''), null);
      });

      test('should handle decimal values correctly', () {
        expect(MathEvaluator.evaluate('10.5+2.3'), 12.8);
      });
      
      test('should handle negative numbers at the beginning', () {
        expect(MathEvaluator.evaluate('-100+50'), -50.0);
      });
    });
  }
  ```

- [ ] **Step 2: Run the test to verify it fails**
  Run command: `flutter test test/math_evaluator_test.dart`
  Expected: FAIL with compilation error (MathEvaluator class not found).

- [ ] **Step 3: Implement math evaluator**
  Create [math_evaluator.dart](file:///Users/sumetph/Development/money/money_vibe/lib/utils/math_evaluator.dart) to parse expressions using the `math_expressions` package.

  ```dart
  import 'package:math_expressions/math_expressions.dart';

  class MathEvaluator {
    static double? evaluate(String expression) {
      String sanitized = expression.replaceAll(',', '').trim();
      
      // Keep removing trailing operators (+, -, *, /) until none remain
      while (sanitized.isNotEmpty && RegExp(r'[+\-*/]$').hasMatch(sanitized)) {
        sanitized = sanitized.substring(0, sanitized.length - 1);
      }
      
      if (sanitized.isEmpty) return null;

      try {
        Parser p = Parser();
        Expression exp = p.parse(sanitized);
        ContextModel cm = ContextModel();
        double val = exp.evaluate(EvaluationType.REAL, cm);
        if (val.isNaN || val.isInfinite) return null;
        return val;
      } catch (e) {
        return null;
      }
    }
  }
  ```

- [ ] **Step 4: Run the test to verify it passes**
  Run command: `flutter test test/math_evaluator_test.dart`
  Expected: ALL TESTS PASS.

- [ ] **Step 5: Commit**
  Run:
  ```bash
  git add lib/utils/math_evaluator.dart test/math_evaluator_test.dart
  git commit -m "feat: implement MathEvaluator and its tests"
  ```

---

### Task 3: Custom Calculator Keyboard Widget & Tests

**Files:**
- Create: `lib/widgets/calculator_keyboard.dart`
- Create: `test/calculator_keyboard_test.dart`

- [ ] **Step 1: Write keyboard widget test**
  Create [calculator_keyboard_test.dart](file:///Users/sumetph/Development/money/money_vibe/test/calculator_keyboard_test.dart) to check basic inputs, backspace, operators, and OK button triggers.

  ```dart
  import 'package:flutter/material.dart';
  import 'package:flutter_test/flutter_test.dart';
  import 'package:money_vibe/widgets/calculator_keyboard.dart';

  void main() {
    testWidgets('CalculatorKeyboard updates text controller and triggers done', (WidgetTester tester) async {
      final controller = TextEditingController();
      bool doneCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CalculatorKeyboard(
              controller: controller,
              onDone: () => doneCalled = true,
              actionButtonColor: Colors.blue,
            ),
          ),
        ),
      );

      // Verify buttons are rendered
      expect(find.text('7'), findsOneWidget);
      expect(find.text('C'), findsOneWidget);
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

      // Tap Backspace
      await tester.tap(find.byIcon(Icons.backspace_outlined));
      await tester.pump();
      expect(controller.text, '8');

      // Tap 'ตกลง' (Done)
      await tester.tap(find.text('ตกลง'));
      await tester.pump();
      expect(doneCalled, isTrue);
    });
  }
  ```

- [ ] **Step 2: Run test to verify it fails**
  Run command: `flutter test test/calculator_keyboard_test.dart`
  Expected: FAIL with compilation error (CalculatorKeyboard not found).

- [ ] **Step 3: Implement CalculatorKeyboard**
  Create [calculator_keyboard.dart](file:///Users/sumetph/Development/money/money_vibe/lib/widgets/calculator_keyboard.dart). Apply standard layout with responsive sizing and dark mode integration using `AppColors`.

  ```dart
  import 'package:flutter/material.dart';
  import 'package:provider/provider.dart';
  import '../theme/app_colors.dart';
  import '../providers/settings_provider.dart';
  import '../utils/math_evaluator.dart';

  class CalculatorKeyboard extends StatelessWidget {
    final TextEditingController controller;
    final VoidCallback onDone;
    final Color actionButtonColor;

    const CalculatorKeyboard({
      super.key,
      required this.controller,
      required this.onDone,
      required this.actionButtonColor,
    });

    void _handleKeyPress(String key) {
      final text = controller.text;
      final selection = controller.selection;
      
      // Default to cursor at end if no selection
      int start = selection.isValid ? selection.start : text.length;
      int end = selection.isValid ? selection.end : text.length;

      if (key == 'C') {
        controller.clear();
        return;
      }

      if (key == '⌫') {
        if (start == end && start > 0) {
          final newText = text.substring(0, start - 1) + text.substring(start);
          controller.value = TextEditingValue(
            text: newText,
            selection: TextSelection.collapsed(offset: start - 1),
          );
        } else if (start != end) {
          final newText = text.substring(0, start) + text.substring(end);
          controller.value = TextEditingValue(
            text: newText,
            selection: TextSelection.collapsed(offset: start),
          );
        }
        return;
      }

      if (key == '=') {
        _evaluateExpression();
        return;
      }

      if (key == 'ตกลง') {
        _evaluateExpression();
        onDone();
        return;
      }

      // If typed an operator (+, -, *, /), check if previous char is also an operator and replace it
      final isOperator = RegExp(r'[+\-*/]').hasMatch(key);
      if (isOperator) {
        if (text.isNotEmpty && start > 0) {
          final prevChar = text.substring(start - 1, start);
          if (RegExp(r'[+\-*/]').hasMatch(prevChar)) {
            // Replace operator
            final newText = text.substring(0, start - 1) + key + text.substring(end);
            controller.value = TextEditingValue(
              text: newText,
              selection: TextSelection.collapsed(offset: start),
            );
            return;
          }
        } else if (text.isEmpty && key != '-') {
          // Don't allow operators at start, except negative sign
          return;
        }
      }

      // General character insertion
      final newText = text.substring(0, start) + key + text.substring(end);
      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: start + key.length),
      );
    }

    void _evaluateExpression() {
      final expression = controller.text;
      if (expression.isEmpty) return;

      final result = MathEvaluator.evaluate(expression);
      if (result != null) {
        // Format result: Remove unnecessary decimal places (e.g. 150.0 -> 150)
        String formatted;
        if (result == result.toInt()) {
          formatted = result.toInt().toString();
        } else {
          formatted = result.toStringAsFixed(2);
          // Strip trailing zero if possible
          if (formatted.endsWith('0')) {
            formatted = formatted.substring(0, formatted.length - 1);
          }
        }
        controller.value = TextEditingValue(
          text: formatted,
          selection: TextSelection.collapsed(offset: formatted.length),
        );
      }
    }

    @override
    Widget build(BuildContext context) {
      final isDarkMode = context.watch<SettingsProvider>().isDarkMode;
      final keyboardBg = isDarkMode ? AppColors.darkBackground : AppColors.background;
      final primaryText = isDarkMode ? AppColors.darkTextPrimary : AppColors.textPrimary;
      final numberKeyBg = isDarkMode ? AppColors.darkSurface : AppColors.surface;
      final opKeyBg = isDarkMode ? AppColors.darkSurfaceVariant : AppColors.sectionHeader;

      return Container(
        color: keyboardBg,
        padding: const EdgeInsets.all(6),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Row 1
              _buildRow(['C', '/', '*', '⌫'], primaryText, numberKeyBg, opKeyBg),
              const SizedBox(height: 6),
              // Row 2
              _buildRow(['7', '8', '9', '-'], primaryText, numberKeyBg, opKeyBg),
              const SizedBox(height: 6),
              // Row 3
              _buildRow(['4', '5', '6', '+'], primaryText, numberKeyBg, opKeyBg),
              const SizedBox(height: 6),
              // Row 4
              _buildRow(['1', '2', '3', '='], primaryText, numberKeyBg, opKeyBg),
              const SizedBox(height: 6),
              // Row 5
              _buildRow(['0', '.', 'ตกลง'], primaryText, numberKeyBg, opKeyBg),
            ],
          ),
        ),
      );
    }

    Widget _buildRow(List<String> keys, Color textColor, Color numBg, Color opBg) {
      return Row(
        children: keys.map((key) {
          final isOp = RegExp(r'[+\-*/C⌫=]').hasMatch(key);
          final isDone = key == 'ตกลง';
          
          Color bg = numBg;
          Color txtColor = textColor;
          if (isDone) {
            bg = actionButtonColor;
            txtColor = Colors.white;
          } else if (isOp) {
            bg = opBg;
          }

          int flex = isDone ? 2 : 1;

          return Expanded(
            flex: flex,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: SizedBox(
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: bg,
                    foregroundColor: txtColor,
                    elevation: 1,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  onPressed: () => _handleKeyPress(key),
                  child: key == '⌫'
                      ? Icon(Icons.backspace_outlined, color: textColor, size: 20)
                      : Text(
                          key,
                          style: TextStyle(
                            fontSize: isDone ? 16 : 18,
                            fontWeight: isDone ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                ),
              ),
            ),
          );
        }).toList(),
      );
    }
  }
  ```

- [ ] **Step 4: Run test to verify it passes**
  Run command: `flutter test test/calculator_keyboard_test.dart`
  Expected: ALL TESTS PASS.

- [ ] **Step 5: Commit**
  Run:
  ```bash
  git add lib/widgets/calculator_keyboard.dart test/calculator_keyboard_test.dart
  git commit -m "feat: implement CalculatorKeyboard and its widget tests"
  ```

---

### Task 4: Form Screen Integration & Verification

**Files:**
- Modify: `lib/screens/transaction/transaction_form_screen.dart`

- [ ] **Step 1: Set up FocusNodes and listeners in transaction_form_screen.dart**
  Modify [transaction_form_screen.dart](file:///Users/sumetph/Development/money/money_vibe/lib/screens/transaction/transaction_form_screen.dart).
  1. Add `final _amountFocusNode = FocusNode();` and `final _toAmountFocusNode = FocusNode();` to state.
  2. Implement focus listeners inside `initState` and clean them up in `dispose`.
  3. Change the TextFields for `_amountController` and `_toAmountController` to have `readOnly: true`, `showCursor: true`, and attach their respective `focusNode`. Remove the regex input formatters on these fields since the keyboard is custom (filtering is handled by key options).
  4. Implement `_showCalculatorKeyboard()` and `_hideCalculatorKeyboard()` using `Scaffold.of(context).showBottomSheet()`.
  5. Style actionButtonColor dynamically:
     ```dart
     Color _getTransactionTypeColor() {
       final isDarkMode = context.read<SettingsProvider>().isDarkMode;
       switch (_type) {
         case TransactionType.income:
           return isDarkMode ? AppColors.darkIncome : AppColors.income;
         case TransactionType.expense:
           return isDarkMode ? AppColors.darkExpense : AppColors.expense;
         case TransactionType.transfer:
           return isDarkMode ? AppColors.darkTransfer : AppColors.transfer;
         default:
           return isDarkMode ? AppColors.darkFabYellow : AppColors.fabYellow;
       }
     }
     ```
  6. Wrap Scaffold body in `GestureDetector` to dismiss on tap outside.

- [ ] **Step 2: Run compilation check**
  Run command: `flutter analyze`
  Expected: 0 errors/warnings.

- [ ] **Step 3: Run all unit and widget tests**
  Run command: `flutter test`
  Expected: All tests pass.

- [ ] **Step 4: Commit integration changes**
  Run:
  ```bash
  git add lib/screens/transaction/transaction_form_screen.dart
  git commit -m "feat: integrate custom calculator keyboard in TransactionFormScreen"
  ```
