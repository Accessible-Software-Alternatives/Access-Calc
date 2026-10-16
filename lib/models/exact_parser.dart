import 'dart:math' as math;

import 'package:graphing_calculator/models/calc_token.dart';

class Rational {
  final BigInt numerator;
  final BigInt denominator;

  Rational._(this.numerator, this.denominator);

  factory Rational(BigInt numerator, [BigInt? denominator]) {
    var n = numerator;
    var d = denominator ?? BigInt.one;
    if (d == BigInt.zero) throw const NotExactException();
    if (d < BigInt.zero) {
      n = -n;
      d = -d;
    }
    final g = n.gcd(d);
    if (g > BigInt.one) {
      n = n ~/ g;
      d = d ~/ g;
    }
    return Rational._(n, d);
  }

  bool get isInteger => denominator == BigInt.one;
  bool get isZero => numerator == BigInt.zero;
  bool get isNegative => numerator < BigInt.zero;

  Rational operator +(Rational o) => Rational(
    numerator * o.denominator + o.numerator * denominator,
    denominator * o.denominator,
  );

  Rational operator -(Rational o) => Rational(
    numerator * o.denominator - o.numerator * denominator,
    denominator * o.denominator,
  );

  Rational operator *(Rational o) =>
      Rational(numerator * o.numerator, denominator * o.denominator);

  Rational operator /(Rational o) =>
      Rational(numerator * o.denominator, denominator * o.numerator);

  Rational operator -() => Rational._(-numerator, denominator);

  Rational pow(int exponent) {
    if (exponent >= 0) {
      return Rational._(numerator.pow(exponent), denominator.pow(exponent));
    }
    if (isZero) throw const NotExactException();
    return Rational(denominator.pow(-exponent), numerator.pow(-exponent));
  }
}

class NotExactException implements Exception {
  const NotExactException();
}

// for fractions
class ExactParser {
  final List<CalcToken> tokens;
  final Map<String, double> variables;
  final double ans;

  int _pos = 0;

  ExactParser(this.tokens, {this.variables = const {}, this.ans = 0});

  static const int _maxExponent = 64;

  static bool containsFraction(List<CalcToken> tokens) {
    for (final t in tokens) {
      if (t is FractionToken) return true;
      if (t is BoxToken) {
        if (containsFraction(t.children)) return true;
      }
    }
    return false;
  }

  static Rational? tryEvaluate(
    List<CalcToken> tokens, {
    Map<String, double> variables = const {},
    double ans = 0,
  }) {
    try {
      return ExactParser(tokens, variables: variables, ans: ans)._expression();
    } on NotExactException {
      return null;
    }
  }

  CalcToken? get _current => _pos < tokens.length ? tokens[_pos] : null;

  Rational _sub(List<CalcToken> children) =>
      ExactParser(children, variables: variables, ans: ans)._expression();

  Rational _expression() {
    var result = _term();

    while (_current is OperatorToken) {
      final op = _current as OperatorToken;
      if (op.type != OperatorType.add && op.type != OperatorType.subtract) {
        break;
      }
      _pos++;
      final right = _term();
      result = op.type == OperatorType.add ? result + right : result - right;
    }

    return result;
  }

  Rational _term() {
    var result = _power();

    while (true) {
      final current = _current;
      if (current is OperatorToken) {
        if (current.type == OperatorType.divide) {
          throw const NotExactException();
        }
        if (current.type != OperatorType.multiply) break;
        _pos++;
        result = result * _power();
      } else if (_startsOperand(current)) {
        result = result * _power();
      } else {
        break;
      }
    }

    return result;
  }

  bool _startsOperand(CalcToken? token) {
    return token is NumberToken ||
        token is ConstantToken ||
        token is VariableToken ||
        token is AnsToken ||
        token is RootToken ||
        token is FractionToken ||
        token is FunctionToken ||
        token is LeftParenToken;
  }

  Rational _power() {
    final leading = _current;
    var negate = false;
    Rational base;

    if (leading is NumberToken && leading.value.startsWith('-')) {
      final magnitude = leading.value.substring(1);
      if (magnitude.isNotEmpty && double.tryParse(magnitude) != null) {
        negate = true;
        _pos++;
        base = _number(magnitude);
      } else {
        base = _primary();
      }
    } else {
      base = _primary();
    }

    while (true) {
      final current = _current;
      if (current is ExponentToken) {
        _pos++;
        base = _applyPower(base, _sub(current.children));
        continue;
      }
      if (current is OperatorToken && current.type == OperatorType.power) {
        _pos++;
        base = _applyPower(base, _power());
        continue;
      }
      break;
    }

    return negate ? -base : base;
  }

  Rational _applyPower(Rational base, Rational exponent) {
    if (!exponent.isInteger) throw const NotExactException();
    if (exponent.numerator.abs() > BigInt.from(_maxExponent)) {
      throw const NotExactException();
    }
    return base.pow(exponent.numerator.toInt());
  }

  Rational _number(String text) {
    if (text.contains('.')) throw const NotExactException();
    final value = BigInt.tryParse(text);
    if (value == null) throw const NotExactException();
    return Rational(value);
  }

  Rational _fromDouble(double value) {
    if (value.isFinite &&
        value == value.truncateToDouble() &&
        value.abs() < 1e15) {
      return Rational(BigInt.from(value.toInt()));
    }
    throw const NotExactException();
  }

  Rational _primary() {
    final token = _current;

    if (token is NumberToken) {
      _pos++;
      return _number(token.value);
    }

    if (token is LeftParenToken) {
      _pos++;
      final result = _expression();
      if (_current is RightParenToken) _pos++;
      return result;
    }

    if (token is ConstantToken) {
      _pos++;
      if (token.type == ConstantType.ten) return Rational(BigInt.from(10));
      throw const NotExactException();
    }

    if (token is VariableToken) {
      _pos++;
      return _fromDouble(variables[token.name] ?? 0);
    }

    if (token is AnsToken) {
      _pos++;
      return _fromDouble(ans);
    }

    if (token is FractionToken) {
      _pos++;
      final top = _sub(token.numerator);
      final bottom = _sub(token.denominator);
      if (bottom.isZero) throw const NotExactException();
      return top / bottom;
    }

    if (token is RootToken) {
      _pos++;
      final arg = _sub(token.children);
      if (arg.isNegative) throw const NotExactException();
      return Rational(_exactSqrt(arg.numerator), _exactSqrt(arg.denominator));
    }

    throw const NotExactException();
  }

  BigInt _exactSqrt(BigInt value) {
    if (value.bitLength > 50) throw const NotExactException();
    final root = BigInt.from(math.sqrt(value.toDouble()).round());
    if (root * root != value) throw const NotExactException();
    return root;
  }
}
