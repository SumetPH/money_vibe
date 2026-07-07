import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

bool get calculatorTextFieldReadOnly => !kIsWeb;

TextInputType? get calculatorTextInputType =>
    kIsWeb ? TextInputType.text : null;

List<TextInputFormatter>? get calculatorTextInputFormatters => kIsWeb
    ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-*/.,]'))]
    : null;
