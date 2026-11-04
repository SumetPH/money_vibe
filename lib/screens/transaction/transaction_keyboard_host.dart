import 'package:flutter/material.dart';
import '../../widgets/calculator_keyboard.dart';

/// ต่อ [CalculatorKeyboard] เข้ากับหลายช่องตัวเลขของฟอร์มรายการ
/// เปิดคีย์บอร์ดของช่องที่ได้ focus และสลับช่องได้โดยไม่ปิด sheet ใหม่
mixin TransactionKeyboardHost<T extends StatefulWidget> on State<T> {
  GlobalKey<ScaffoldState> get keyboardScaffoldKey;
  Color get keyboardActionColor;

  /// ช่องที่ใช้คีย์บอร์ดเครื่องคิดเลข: focus node → controller
  Map<FocusNode, TextEditingController> get keyboardFields;

  PersistentBottomSheetController? _keyboardController;
  TextEditingController? _activeKeyboardController;

  void attachTransactionKeyboard() {
    for (final node in keyboardFields.keys) {
      node.addListener(_onKeyboardFocusChange);
    }
  }

  void detachTransactionKeyboard() {
    for (final node in keyboardFields.keys) {
      node.removeListener(_onKeyboardFocusChange);
    }
  }

  void _onKeyboardFocusChange() {
    if (!mounted) return;
    for (final entry in keyboardFields.entries) {
      if (entry.key.hasFocus) {
        _showKeyboard(entry.value);
        return;
      }
    }
    closeTransactionKeyboard();
  }

  void _showKeyboard(TextEditingController controller) {
    if (_keyboardController != null) {
      if (_activeKeyboardController == controller) return;
      // Close only the old sheet; closeTransactionKeyboard() would also
      // unfocus the field being switched to and close the new sheet.
      _keyboardController?.close();
    }

    _activeKeyboardController = controller;
    final keyboardController = keyboardScaffoldKey.currentState
        ?.showBottomSheet(
          (context) => CalculatorKeyboard(
            controller: controller,
            actionButtonColor: keyboardActionColor,
            onDone: closeTransactionKeyboard,
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
        );
    _keyboardController = keyboardController;

    keyboardController?.closed.then((_) {
      // Old sheet closes after a new one opened (switching amount fields):
      // don't clear the new sheet's reference, or it can't be closed before pop.
      if (_keyboardController != keyboardController) return;
      _keyboardController = null;
      _activeKeyboardController = null;
      if (mounted) _unfocusKeyboardFields();
    });
  }

  void closeTransactionKeyboard() {
    if (_keyboardController != null) {
      _keyboardController?.close();
      _keyboardController = null;
      _activeKeyboardController = null;
    }
    _unfocusKeyboardFields();
  }

  void _unfocusKeyboardFields() {
    for (final node in keyboardFields.keys) {
      if (node.hasFocus) node.unfocus();
    }
  }
}
