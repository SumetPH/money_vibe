# Design Spec: Custom Calculator Keyboard for Amount Input

**Date:** 2026-05-21  
**Status:** Approved  
**Author:** AI Pair Programmer  

## 1. Goal & Context

In the transaction creation/editing form (`TransactionFormScreen`), entering amount values often requires quick mathematical calculations (e.g. adding multiple expenses together or splitting bills). Standard system number pads do not support inline calculations, forcing users to switch apps to a calculator. 

This spec details the implementation of a custom calculator keyboard that replaces the system keyboard for numeric amount inputs within `TransactionFormScreen`.

---

## 2. Requirements & Scope

- **Custom Keyboard:** A custom 5-row calculator keyboard layout showing digits, basic operators (`+`, `-`, `*`, `/`), delete (`Backspace`), clear (`C`), equals (`=`), and a prominent `Done` button.
- **Dynamic Accent Color:** The `Done` button background dynamically adopts the color theme of the active transaction type (Expense = Red, Income = Green, Transfer = Blue, etc.).
- **Scaffold Integration:** The keyboard slides up from the bottom of the screen using Scaffold's non-modal BottomSheet. 
- **Focus Management:** Setting `readOnly: true` and `showCursor: true` on the input fields prevents the OS keyboard from popping up while retaining active cursor positioning. The custom keyboard listens to focus changes and targets either the main Amount or To Amount fields.
- **Expression Evaluation:** Full formulas are shown inside the TextField during input (e.g. `100+50-20`). The mathematical expression is evaluated when pressing `=` or `Done` using the `math_expressions` package.
- **Error Handling:** If an expression is syntactically invalid (e.g. trailing operator or unbalanced formula), the system catches the error, maintains the input, and displays a user-friendly SnackBar.
- **Light & Dark Mode:** Full UI compatibility using custom styling derived strictly from `AppColors`.

---

## 3. Component Details

### 3.1 `lib/widgets/calculator_keyboard.dart` [NEW]
A stateless/stateful widget representing the physical keyboard panel.

```dart
class CalculatorKeyboard extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onDone;
  final Color actionButtonColor; // The transaction type color (e.g. AppColors.expense)

  const CalculatorKeyboard({
    super.key,
    required this.controller,
    required this.onDone,
    required this.actionButtonColor,
  });
  
  // Implementation details...
}
```

- **Layout Structure:**
  - Row 1: `C` | `/` | `*` | `⌫` (Delete/Backspace)
  - Row 2: `7` | `8` | `9` | `-`
  - Row 3: `4` | `5` | `6` | `+`
  - Row 4: `1` | `2` | `3` | `=`
  - Row 5: `0` | `.` | `ตกลง` (Done - spans 2 columns)

- **Input Logic:**
  - Standard characters are inserted at the current cursor selection (`selection.start` and `selection.end`).
  - Typing an operator replaces any existing trailing operator to prevent duplicates.
  - Backspace deletes the character immediately preceding the cursor.
  - C clears the input entirely.
  - `=` evaluates the expression and updates the text field.
  - `Done` evaluates the expression first (if valid) and invokes the `onDone` callback.

### 3.2 `math_expressions` Package Integration [NEW dependency]
Add to `pubspec.yaml`:
```yaml
dependencies:
  math_expressions: ^2.6.0
```

- Expression evaluation utility:
```dart
import 'package:math_expressions/math_expressions.dart';

double? evaluateExpression(String input) {
  // Strip trailing operators before parsing
  String sanitized = input.trim();
  while (sanitized.isNotEmpty && RegExp(r'[+\-*/]$').hasMatch(sanitized)) {
    sanitized = sanitized.substring(0, sanitized.length - 1);
  }
  
  if (sanitized.isEmpty) return null;
  
  try {
    Parser p = Parser();
    Expression exp = p.parse(sanitized);
    ContextModel cm = ContextModel();
    return exp.evaluate(EvaluationType.REAL, cm);
  } catch (e) {
    return null; // Signals evaluation error
  }
}
```

### 3.3 `lib/screens/transaction/transaction_form_screen.dart` [MODIFY]
- Set `showCursor: true` and `readOnly: true` on the `TextField` for Amount and To Amount.
- Instantiate `FocusNode _amountFocusNode` and `FocusNode _toAmountFocusNode`.
- Add listeners to focus nodes in `initState` to open/update/close the BottomSheet:
```dart
PersistentBottomSheetController? _keyboardController;

void _setupFocusListeners() {
  _amountFocusNode.addListener(_handleFocusChange);
  _toAmountFocusNode.addListener(_handleFocusChange);
}

void _handleFocusChange() {
  if (_amountFocusNode.hasFocus || _toAmountFocusNode.hasFocus) {
    _showCalculatorKeyboard();
  } else {
    _hideCalculatorKeyboard();
  }
}

void _showCalculatorKeyboard() {
  if (_keyboardController != null) {
    // Already open, trigger rebuild to sync the active controller
    _keyboardController!.setState?(() {});
    return;
  }
  
  _keyboardController = Scaffold.of(context).showBottomSheet(
    (context) => CalculatorKeyboard(
      controller: _amountFocusNode.hasFocus ? _amountController : _toAmountController,
      actionButtonColor: _getTransactionTypeColor(),
      onDone: () {
        _amountFocusNode.unfocus();
        _toAmountFocusNode.unfocus();
      },
    ),
    backgroundColor: Colors.transparent,
    elevation: 8,
  );

  _keyboardController!.closed.then((_) {
    _keyboardController = null;
  });
}

void _hideCalculatorKeyboard() {
  _keyboardController?.close();
  _keyboardController = null;
}
```
- Wrap the main Scaffold body list view in a `GestureDetector` that unfocuses when tapping outside.

---

## 4. UI/UX & Theming Specs

### Light Mode Styling:
- Background: `AppColors.background` (`0xFFF0F0F0`)
- Standard key background: `AppColors.surface` (`0xFFFFFFFF`)
- Standard key text: `AppColors.textPrimary` (`0xFF212121`)
- Operator key background: `AppColors.sectionHeader` (`0xFFEEEEEE`)
- Operator key text: `AppColors.textPrimary` (`0xFF212121`)

### Dark Mode Styling:
- Background: `AppColors.darkBackground` (`0xFF121212`)
- Standard key background: `AppColors.darkSurface` (`0xFF1E1E1E`)
- Standard key text: `AppColors.darkTextPrimary` (`0xFFE0E0E0`)
- Operator key background: `AppColors.darkSurfaceVariant` (`0xFF2A2A2A`)
- Operator key text: `AppColors.darkTextPrimary` (`0xFFE0E0E0`)

### Done / OK Button Accent Color:
- Dependent on transaction type:
  - Expense: `AppColors.expense` or `AppColors.darkExpense`
  - Income: `AppColors.income` or `AppColors.darkIncome`
  - Transfer: `AppColors.transfer` or `AppColors.darkTransfer`
  - Debt: `AppColors.debtRepay` or `AppColors.darkDebtRepay`

---

## 5. Verification Plan

### Manual Verification
1. Open the Transaction form screen.
2. Tap on the Amount field. Ensure the custom calculator keyboard slides up and no OS keyboard appears.
3. Type numbers and operators, ensuring expressions (e.g. `50+25*2`) are typed correctly.
4. Tap `=` to evaluate the result (should show `100.0` or formatted `100`).
5. Tap `Done`. The keyboard should close, and the calculated amount should remain in the field.
6. Test in both Light Mode and Dark Mode settings.
7. Switch to a cross-currency Transfer transaction. Ensure both Amount and To Amount fields trigger the calculator keyboard and edit their respective fields.
8. Tap on the Note field. Ensure the calculator keyboard is dismissed, and the standard system keyboard appears.
