import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../theme/app_colors.dart';
import '../providers/settings_provider.dart';
import '../utils/math_evaluator.dart';

class _CalculatorKey {
  final String label;
  final String value;

  const _CalculatorKey(this.label, {String? value}) : value = value ?? label;
}

class CalculatorKeyboard extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onDone;
  final Color actionButtonColor;
  final int resultDecimalPlaces;

  const CalculatorKeyboard({
    super.key,
    required this.controller,
    required this.onDone,
    required this.actionButtonColor,
    this.resultDecimalPlaces = 2,
  });

  @override
  State<CalculatorKeyboard> createState() => _CalculatorKeyboardState();
}

class _CalculatorKeyboardState extends State<CalculatorKeyboard> {
  Timer? _backspaceTimer;

  void _handleKeyPress(String key) {
    HapticFeedback.lightImpact();

    final text = widget.controller.text;
    final selection = widget.controller.selection;

    // Default to cursor at end if no selection
    int start = selection.isValid ? selection.start : text.length;
    int end = selection.isValid ? selection.end : text.length;

    if (key == 'AC') {
      widget.controller.clear();
      return;
    }

    if (key == '⌫') {
      if (start == end && start > 0) {
        final newText = text.substring(0, start - 1) + text.substring(start);
        widget.controller.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: start - 1),
        );
      } else if (start != end) {
        final newText = text.substring(0, start) + text.substring(end);
        widget.controller.value = TextEditingValue(
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
      widget.onDone();
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
          widget.controller.value = TextEditingValue(
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
    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + key.length),
    );
  }

  void _startBackspaceAutoRepeat() {
    _backspaceTimer?.cancel();
    // After 350ms delay, repeat backspace every 70ms
    _backspaceTimer = Timer(const Duration(milliseconds: 350), () {
      _backspaceTimer = Timer.periodic(const Duration(milliseconds: 70), (_) {
        if (widget.controller.text.isEmpty) {
          _stopBackspaceAutoRepeat();
          return;
        }
        _handleKeyPress('⌫');
      });
    });
  }

  void _stopBackspaceAutoRepeat() {
    _backspaceTimer?.cancel();
    _backspaceTimer = null;
  }

  @override
  void dispose() {
    _stopBackspaceAutoRepeat();
    super.dispose();
  }

  void _handlePercent() {
    final text = widget.controller.text;
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
    final formatted = _formatResult(percentValue);

    final prefix = lastOperatorIndex >= 0
        ? text.substring(0, lastOperatorIndex + 1)
        : '';

    final newText = prefix + formatted;
    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }

  void _evaluateExpression() {
    final expression = widget.controller.text;
    if (expression.isEmpty) return;

    final result = MathEvaluator.evaluate(expression);
    if (result != null) {
      final formatted = _formatResult(result);
      widget.controller.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
  }

  String _formatResult(double value) {
    if (value == value.toInt()) {
      return value.toInt().toString();
    }

    return value
        .toStringAsFixed(widget.resultDecimalPlaces)
        .replaceFirst(RegExp(r'\.?0+$'), '');
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
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildRow(
                  const [
                    _CalculatorKey('÷', value: '/'),
                    _CalculatorKey('AC'),
                    _CalculatorKey('ตกลง'),
                  ],
                  primaryText,
                  numberKeyBg,
                  opKeyBg,
                ),
                _buildRow(
                  const [
                    _CalculatorKey('+'),
                    _CalculatorKey('-'),
                    _CalculatorKey('×', value: '*'),
                  ],
                  primaryText,
                  numberKeyBg,
                  opKeyBg,
                ),
                _buildRow(
                  const [
                    _CalculatorKey('7'),
                    _CalculatorKey('8'),
                    _CalculatorKey('9'),
                  ],
                  primaryText,
                  numberKeyBg,
                  opKeyBg,
                ),
                _buildRow(
                  const [
                    _CalculatorKey('4'),
                    _CalculatorKey('5'),
                    _CalculatorKey('6'),
                  ],
                  primaryText,
                  numberKeyBg,
                  opKeyBg,
                ),
                _buildRow(
                  const [
                    _CalculatorKey('1'),
                    _CalculatorKey('2'),
                    _CalculatorKey('3'),
                  ],
                  primaryText,
                  numberKeyBg,
                  opKeyBg,
                ),
                _buildRow(
                  const [
                    _CalculatorKey('.'),
                    _CalculatorKey('0'),
                    _CalculatorKey('⌫'),
                  ],
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
    List<_CalculatorKey> keys,
    Color textColor,
    Color numBg,
    Color opBg, {
    double height = 52,
  }) {
    return Row(
      children: keys.map((key) {
        final isOp = {'+', '-', '*', '/', 'AC', '%'}.contains(key.value);
        final isDone = key.value == 'ตกลง';

        Color bg = numBg;
        Color txtColor = textColor;
        if (isDone) {
          bg = widget.actionButtonColor;
          txtColor = Colors.white;
        } else if (isOp) {
          bg = opBg;
        }

        return Expanded(
          child: SizedBox(
            height: height,
            child: _CalculatorKeyButton(
              keyInfo: key,
              backgroundColor: bg,
              textColor: txtColor,
              isDone: isDone,
              onTap: () => _handleKeyPress(key.value),
              onLongPressStart: key.value == '⌫'
                  ? _startBackspaceAutoRepeat
                  : null,
              onLongPressEnd: key.value == '⌫'
                  ? _stopBackspaceAutoRepeat
                  : null,
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _CalculatorKeyButton extends StatefulWidget {
  final _CalculatorKey keyInfo;
  final Color backgroundColor;
  final Color textColor;
  final bool isDone;
  final VoidCallback onTap;
  final VoidCallback? onLongPressStart;
  final VoidCallback? onLongPressEnd;

  const _CalculatorKeyButton({
    required this.keyInfo,
    required this.backgroundColor,
    required this.textColor,
    required this.isDone,
    required this.onTap,
    this.onLongPressStart,
    this.onLongPressEnd,
  });

  @override
  State<_CalculatorKeyButton> createState() => _CalculatorKeyButtonState();
}

class _CalculatorKeyButtonState extends State<_CalculatorKeyButton> {
  void _onTapDown(TapDownDetails details) {
    widget.onTap();
    widget.onLongPressStart?.call();
  }

  void _onTapUp(TapUpDetails details) {
    widget.onLongPressEnd?.call();
  }

  void _onTapCancel() {
    widget.onLongPressEnd?.call();
  }

  @override
  Widget build(BuildContext context) {
    final splashColor = widget.textColor.withValues(alpha: 0.2);
    final highlightColor = widget.textColor.withValues(alpha: 0.1);

    return Material(
      color: widget.backgroundColor,
      child: InkWell(
        onTapDown: _onTapDown,
        onTapUp: (details) => _onTapUp(details),
        onTapCancel: _onTapCancel,
        onTap: () {}, // Required for InkWell ripple animation
        splashColor: splashColor,
        highlightColor: highlightColor,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.grey.withValues(alpha: 0.2),
              width: 0.1,
            ),
          ),
          alignment: Alignment.center,
          child: widget.keyInfo.value == '⌫'
              ? Icon(
                  Icons.backspace_outlined,
                  color: widget.textColor,
                  size: 20,
                )
              : Text(
                  widget.keyInfo.label,
                  style: TextStyle(
                    color: widget.textColor,
                    fontSize: widget.isDone ? 16 : 18,
                    fontWeight: widget.isDone
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
        ),
      ),
    );
  }
}
