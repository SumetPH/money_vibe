import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    HapticFeedback.lightImpact();
    SystemSound.play(SystemSoundType.click);

    final text = controller.text;
    final selection = controller.selection;

    // Default to cursor at end if no selection
    int start = selection.isValid ? selection.start : text.length;
    int end = selection.isValid ? selection.end : text.length;

    if (key == 'AC') {
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

    if (key == '%') {
      _handlePercent();
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
          final newText =
              text.substring(0, start - 1) + key + text.substring(end);
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

  void _handlePercent() {
    final text = controller.text;
    if (text.isEmpty) return;

    // Find the last number in the expression (after the last operator)
    final operatorPattern = RegExp(r'[+\-*/]');
    int lastOperatorIndex = -1;
    for (int i = text.length - 1; i >= 0; i--) {
      // Allow negative sign at the start
      if (operatorPattern.hasMatch(text[i]) && i > 0) {
        lastOperatorIndex = i;
        break;
      }
    }

    final numberPart = lastOperatorIndex >= 0
        ? text.substring(lastOperatorIndex + 1)
        : text;

    if (numberPart.isEmpty) return;

    final number = double.tryParse(numberPart);
    if (number == null) return;

    final percentValue = number / 100;
    String formatted;
    if (percentValue == percentValue.toInt()) {
      formatted = percentValue.toInt().toString();
    } else {
      formatted = percentValue.toStringAsFixed(2);
      if (formatted.endsWith('0')) {
        formatted = formatted.substring(0, formatted.length - 1);
      }
    }

    final prefix = lastOperatorIndex >= 0
        ? text.substring(0, lastOperatorIndex + 1)
        : '';

    final newText = prefix + formatted;
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
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
    final keyboardBg = isDarkMode
        ? AppColors.darkBackground
        : AppColors.background;
    final primaryText = isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final numberKeyBg = isDarkMode ? AppColors.darkSurface : AppColors.surface;
    final opKeyBg = isDarkMode
        ? AppColors.darkSurfaceVariant
        : AppColors.sectionHeader;

    return TextFieldTapRegion(
      child: ExcludeFocus(
        child: Container(
          color: keyboardBg,
          padding: const EdgeInsets.all(6),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Row 1
                _buildRow(
                  ['⌫', 'AC', '%', '/'],
                  primaryText,
                  numberKeyBg,
                  opKeyBg,
                ),
                const SizedBox(height: 6),
                // Row 2
                _buildRow(
                  ['7', '8', '9', '*'],
                  primaryText,
                  numberKeyBg,
                  opKeyBg,
                ),
                const SizedBox(height: 6),
                // Row 3
                _buildRow(
                  ['4', '5', '6', '-'],
                  primaryText,
                  numberKeyBg,
                  opKeyBg,
                ),
                const SizedBox(height: 6),
                // Row 4
                _buildRow(
                  ['1', '2', '3', '+'],
                  primaryText,
                  numberKeyBg,
                  opKeyBg,
                ),
                const SizedBox(height: 6),
                // Row 5
                _buildRow(
                  ['=', '0', '.', 'ตกลง'],
                  primaryText,
                  numberKeyBg,
                  opKeyBg,
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRow(
    List<String> keys,
    Color textColor,
    Color numBg,
    Color opBg,
  ) {
    return Row(
      children: keys.map((key) {
        final isOp = RegExp(r'[+\-*/AC⌫%]').hasMatch(key);
        final isDone = key == 'ตกลง';

        Color bg = numBg;
        Color txtColor = textColor;
        if (isDone) {
          bg = actionButtonColor;
          txtColor = Colors.white;
        } else if (isOp) {
          bg = opBg;
        }

        return Expanded(
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
                  shadowColor: Colors.transparent,
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
                          fontWeight: isDone
                              ? FontWeight.bold
                              : FontWeight.normal,
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
