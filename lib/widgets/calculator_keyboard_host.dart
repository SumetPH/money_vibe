import 'package:flutter/material.dart';

import 'calculator_keyboard.dart';

/// ต่อ [CalculatorKeyboard] เข้ากับช่องจำนวนเงินของฟอร์ม (แบบเดียวกับฟอร์มรายการประจำ):
/// เปิดคีย์บอร์ดเมื่อช่องได้ focus และจัดรูปแบบตัวเลขพร้อมคอมมา
mixin CalculatorKeyboardHost<T extends StatefulWidget> on State<T> {
  static final _operatorPattern = RegExp(r'[+\-*/]');
  static final _thousandsPattern = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');

  GlobalKey<ScaffoldState> get calculatorScaffoldKey;
  TextEditingController get calculatorController;
  FocusNode get calculatorFocusNode;
  Color get calculatorActionColor;

  PersistentBottomSheetController? _keyboardController;
  bool _isFormatting = false;

  /// จำนวนเงินที่กรอก (ไม่มีคอมมา) หรือ null ถ้าไม่ใช่ตัวเลข
  double? get calculatorAmount =>
      double.tryParse(calculatorController.text.replaceAll(',', '').trim());

  void attachCalculatorKeyboard() {
    calculatorFocusNode.addListener(_onFocusChange);
    calculatorController.addListener(_onAmountChanged);
  }

  void detachCalculatorKeyboard() {
    calculatorFocusNode.removeListener(_onFocusChange);
    calculatorController.removeListener(_onAmountChanged);
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
      final text = calculatorController.text;
      // ระหว่างพิมพ์สูตร (มี operator) ไม่ใส่คอมมา
      final formatted = _operatorPattern.hasMatch(text)
          ? text.replaceAll(',', '')
          : _withThousands(text.replaceAll(',', ''));
      if (formatted != text) {
        calculatorController.value = TextEditingValue(
          text: formatted,
          selection: TextSelection.collapsed(offset: formatted.length),
        );
      }
    } finally {
      _isFormatting = false;
    }
  }

  static String _withThousands(String raw) {
    if (raw.isEmpty) return raw;
    final parts = raw.split('.');
    final intPart = parts[0].replaceAllMapped(
      _thousandsPattern,
      (m) => '${m[1]},',
    );
    return parts.length > 1 ? '$intPart.${parts[1]}' : intPart;
  }
}
