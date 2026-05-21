import 'package:math_expressions/math_expressions.dart';

class MathEvaluator {
  static double? evaluate(String expression) {
    String sanitized = expression.replaceAll(',', '').trim();

    // Keep removing trailing operators (+, -, *, /) until none remain
    while (sanitized.isNotEmpty && RegExp(r'[+\-*/]$').hasMatch(sanitized)) {
      sanitized = sanitized.substring(0, sanitized.length - 1);
    }

    if (sanitized.isEmpty) return null;

    // Reject consecutive operators (e.g. ++, +*, etc.)
    if (RegExp(r'[+\-*/]{2,}').hasMatch(sanitized)) {
      return null;
    }

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
