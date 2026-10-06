# 18 Use CalculatorKeyboardHost in the remaining forms

Status: resolved

`lib/widgets/calculator_keyboard_host.dart` is only used by the two `cash_flow` forms.
`account_form`, `recurring_form`, `budget_form`, `transaction_form` each copy ~150 lines of keyboard code.

## Diff vs the mixin

account / recurring / budget forms are identical to the mixin (focus → show, unfocus on done,
`closed` cleanup, thousands formatting, empty input) **except one thing**:

- When the text contains an operator, the forms strip commas and **keep the cursor where it was**
  (`commasBeforeCursor`). The mixin moves the cursor to the end. `CalculatorKeyboard` inserts at the
  cursor, so this matters if the user moved the cursor mid-expression.

transaction_form additionally has:
- Two amount fields (`_amountController`, `_toAmountController`) sharing one keyboard.
- `onDone` closes the keyboard and unfocuses both fields.
- Action button color depends on transaction type (already fits the `calculatorActionColor` getter).
- After-change side effects: `_calculateAccountBalance()` and `setState`.

## Plan

1. Mixin: preserve the cursor when stripping commas (port the forms' `commasBeforeCursor` logic).
   This is also a small fix for the two `cash_flow` forms.
2. Migrate `account_form`, `recurring_form`, `budget_form` to the mixin. One commit each.
3. Extend the mixin for multiple fields + a change hook, e.g.
   `List<(TextEditingController, FocusNode)> get calculatorFields` and
   `void onCalculatorAmountChanged(TextEditingController controller) {}`;
   keep the single-field getters working for existing users.
4. Migrate `transaction_form`.

## Manual test per form

Type a number (commas appear), type an expression with an operator (commas removed, cursor stays),
move the cursor mid-number and type, press `=`, press done, tap outside, switch fields (transaction transfer).

## Comments

Done.
- `formatCalculatorAmountInput` (in `calculator_keyboard_host.dart`) now keeps the cursor when stripping commas; the mixin uses it, so the cash_flow forms get the fix too.
- account / recurring / budget forms use `CalculatorKeyboardHost` (logic was identical apart from the cursor handling).
- transaction form keeps its own two-field show/close logic and only uses the shared formatter. Steps 3–4 of the plan (multi-field mixin) were skipped: the two-field close/refocus timing differs from the mixin, and nothing else needs it (YAGNI).
- Manual test checklist above still applies to all four forms.
