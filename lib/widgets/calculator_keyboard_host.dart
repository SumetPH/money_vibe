import 'package:flutter/material.dart';

import 'calculator_keyboard.dart';

final _operatorPattern = RegExp(r'[+\-*/]');
final _thousandsPattern = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');

/// จัดรูปแบบช่องจำนวนเงินของ [CalculatorKeyboard]: ใส่คอมมาหลักพัน
/// ระหว่างพิมพ์สูตร (มี operator) จะเอาคอมมาออกโดยคงตำแหน่ง cursor ไว้
/// เพราะคีย์บอร์ดแทรกตัวอักษรที่ตำแหน่ง cursor
void formatCalculatorAmountInput(
  TextEditingController controller, {
  TextEditingValue? previousValue,
}) {
  final currentValue = controller.value;
  final text = currentValue.text;
  if (!_operatorPattern.hasMatch(text)) {
    var raw = text.replaceAll(',', '');
    var baseOffset = _rawOffset(text, currentValue.selection.baseOffset);
    var extentOffset = _rawOffset(text, currentValue.selection.extentOffset);

    final deletedCommaIndex = previousValue == null
        ? null
        : _singleDeletedCommaIndex(previousValue, currentValue);
    var handledDeletedComma = false;
    if (deletedCommaIndex != null && previousValue != null && raw.isNotEmpty) {
      final rawCommaOffset = _rawOffset(previousValue.text, deletedCommaIndex);
      final isBackspace =
          previousValue.selection.extentOffset >
          currentValue.selection.extentOffset;
      final digitIndex = isBackspace ? rawCommaOffset - 1 : rawCommaOffset;
      if (digitIndex >= 0 &&
          digitIndex < raw.length &&
          _isDigit(raw[digitIndex])) {
        // Treat deleting a generated separator as deleting its adjacent digit.
        raw = raw.replaceRange(digitIndex, digitIndex + 1, '');
        if (baseOffset > digitIndex) baseOffset--;
        if (extentOffset > digitIndex) extentOffset--;
        handledDeletedComma = true;
      }
    }

    final formatted = _withThousands(raw);
    final selection = formatted == text && !handledDeletedComma
        ? currentValue.selection
        : TextSelection(
            baseOffset: _formattedOffset(formatted, raw.length, baseOffset),
            extentOffset: _formattedOffset(formatted, raw.length, extentOffset),
            affinity: currentValue.selection.affinity,
            isDirectional: currentValue.selection.isDirectional,
          );
    _setFormattedValue(controller, currentValue, formatted, selection);
    return;
  }

  final sanitized = text.replaceAll(',', '');
  if (sanitized == text) return;
  final selection = TextSelection(
    baseOffset: _rawOffset(text, currentValue.selection.baseOffset),
    extentOffset: _rawOffset(text, currentValue.selection.extentOffset),
    affinity: currentValue.selection.affinity,
    isDirectional: currentValue.selection.isDirectional,
  );
  _setFormattedValue(controller, currentValue, sanitized, selection);
}

int _rawOffset(String text, int formattedOffset) {
  if (formattedOffset < 0) return text.replaceAll(',', '').length;
  final safeOffset = formattedOffset.clamp(0, text.length);
  return text.substring(0, safeOffset).replaceAll(',', '').length;
}

int _formattedOffset(String formatted, int rawLength, int rawOffset) {
  final safeRawOffset = rawOffset.clamp(0, rawLength);
  if (safeRawOffset == 0) return 0;
  return (formatted.length - (rawLength - safeRawOffset)).clamp(
    0,
    formatted.length,
  );
}

int? _singleDeletedCommaIndex(
  TextEditingValue previousValue,
  TextEditingValue currentValue,
) {
  if (!previousValue.selection.isCollapsed ||
      !currentValue.selection.isCollapsed ||
      previousValue.text.length != currentValue.text.length + 1) {
    return null;
  }

  final candidateIndex = currentValue.selection.extentOffset.clamp(
    0,
    previousValue.text.length - 1,
  );
  if (previousValue.text[candidateIndex] != ',') return null;
  final withoutCandidate = previousValue.text.replaceRange(
    candidateIndex,
    candidateIndex + 1,
    '',
  );
  return withoutCandidate == currentValue.text ? candidateIndex : null;
}

bool _isDigit(String value) =>
    value.codeUnitAt(0) >= 48 && value.codeUnitAt(0) <= 57;

void _setFormattedValue(
  TextEditingController controller,
  TextEditingValue currentValue,
  String text,
  TextSelection selection,
) {
  if (text == currentValue.text && selection == currentValue.selection) return;
  controller.value = TextEditingValue(text: text, selection: selection);
}

String _withThousands(String raw) {
  if (raw.isEmpty) return raw;
  final parts = raw.split('.');
  final intPart = parts[0].replaceAllMapped(
    _thousandsPattern,
    (m) => '${m[1]},',
  );
  return parts.length > 1 ? '$intPart.${parts[1]}' : intPart;
}

/// ต่อ [CalculatorKeyboard] เข้ากับช่องจำนวนเงินของฟอร์ม (แบบเดียวกับฟอร์มรายการประจำ):
/// เปิดคีย์บอร์ดเมื่อช่องได้ focus และจัดรูปแบบตัวเลขพร้อมคอมมา
mixin CalculatorKeyboardHost<T extends StatefulWidget> on State<T> {
  GlobalKey<ScaffoldState> get calculatorScaffoldKey;
  TextEditingController get calculatorController;
  FocusNode get calculatorFocusNode;
  Color get calculatorActionColor;

  PersistentBottomSheetController? _keyboardController;
  bool _isFormatting = false;
  TextEditingValue? _previousAmountValue;

  /// จำนวนเงินที่กรอก (ไม่มีคอมมา) หรือ null ถ้าไม่ใช่ตัวเลข
  double? get calculatorAmount =>
      double.tryParse(calculatorController.text.replaceAll(',', '').trim());

  void attachCalculatorKeyboard() {
    _previousAmountValue = calculatorController.value;
    calculatorFocusNode.addListener(_onFocusChange);
    calculatorController.addListener(_onAmountChanged);
  }

  void detachCalculatorKeyboard() {
    calculatorFocusNode.removeListener(_onFocusChange);
    calculatorController.removeListener(_onAmountChanged);
    _previousAmountValue = null;
  }

  void closeCalculatorKeyboard() {
    _keyboardController?.close();
    _keyboardController = null;
  }

  void _onFocusChange() {
    if (!mounted) return;
    if (calculatorFocusNode.hasFocus) {
      _showKeyboard();
    } else {
      closeCalculatorKeyboard();
    }
  }

  void _showKeyboard() {
    if (_keyboardController != null) return;
    final controller = calculatorScaffoldKey.currentState?.showBottomSheet(
      (_) => CalculatorKeyboard(
        controller: calculatorController,
        actionButtonColor: calculatorActionColor,
        onDone: calculatorFocusNode.unfocus,
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
    );
    _keyboardController = controller;
    controller?.closed.then((_) {
      if (_keyboardController != controller) return;
      _keyboardController = null;
      if (calculatorFocusNode.hasFocus) calculatorFocusNode.unfocus();
    });
  }

  void _onAmountChanged() {
    if (_isFormatting) return;
    _isFormatting = true;
    try {
      formatCalculatorAmountInput(
        calculatorController,
        previousValue: _previousAmountValue,
      );
      _previousAmountValue = calculatorController.value;
    } finally {
      _isFormatting = false;
    }
  }
}
