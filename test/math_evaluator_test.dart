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
