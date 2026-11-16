import 'dart:math' as math;

import 'package:graphing_calculator/models/calc_error.dart';
import 'package:graphing_calculator/models/calc_token.dart';

class ExpressionParser {
  final List<CalcToken> tokens;

  final Map<String, double> variables;

  final double ans;

  int _pos = 0;

  ExpressionParser(this.tokens, {this.variables = const {}, this.ans = 0});

  CalcToken? get _current => _pos < tokens.length ? tokens[_pos] : null;

  double parseComplete() {
    final result = parseExpression();
    if (_current is CommaToken) throw SyntaxError(_pos);
    return result;
  }

  double parseExpression() {
    var result = _parseTerm();

    while (_current is OperatorToken) {
      final op = _current as OperatorToken;
      if (op.type != OperatorType.add && op.type != OperatorType.subtract) {
        break;
      }
      _pos++;
      final right = _parseTerm();
      result = op.type == OperatorType.add ? result + right : result - right;
    }

    return result;
  }

  double _parseTerm() {
    var result = _parsePower();

    while (true) {
      final current = _current;
      final OperatorToken? op =
          (current is OperatorToken &&
              (current.type == OperatorType.multiply ||
                  current.type == OperatorType.divide))
          ? current
          : null;

      if (op == null && !_startsOperand(current)) break;

      if (op != null) _pos++;
      final right = _parsePower();

      if (op != null && op.type == OperatorType.divide) {
        if (right == 0) {
          throw DivideByZeroError(_pos);
        }
        result = result / right;
      } else {
        result = result * right;
      }
    }

    return result;
  }

  bool _startsOperand(CalcToken? token) {
    return token is NumberToken ||
        token is NegateToken ||
        token is ConstantToken ||
        token is VariableToken ||
        token is AnsToken ||
        token is RootToken ||
        token is FractionToken ||
        token is FunctionToken ||
        token is LeftParenToken;
  }

  double _parsePower() {
    final leading = _current;
    if (leading is NegateToken) {
      _pos++;
      return -_parsePower();
    }

    bool negate = false;
    double base;

    if (leading is NumberToken && leading.value.startsWith('-')) {
      final magnitude = leading.value.substring(1);
      if (magnitude.isNotEmpty && double.tryParse(magnitude) != null) {
        negate = true;
        _pos++;
        base = double.parse(magnitude);
      } else {
        base = _parsePrimary();
      }
    } else {
      base = _parsePrimary();
    }

    while (true) {
      if (_current is ExponentToken) {
        final exponent = _current as ExponentToken;
        _pos++;
        final exp = ExpressionParser(
          exponent.children,
          variables: variables,
          ans: ans,
        ).parseExpression();
        base = math.pow(base, exp).toDouble();
        continue;
      }

      if (_current is OperatorToken &&
          (_current as OperatorToken).type == OperatorType.power) {
        _pos++;
        final exp = _parsePower();
        base = math.pow(base, exp).toDouble();
        continue;
      }

      break;
    }

    return negate ? -base : base;
  }

  double _parsePrimary() {
    final token = _current;

    if (token is NumberToken) {
      _pos++;
      return double.parse(token.value);
    }

    if (token is LeftParenToken) {
      _pos++;
      final result = parseExpression();
      if (_current is RightParenToken) _pos++;
      return result;
    }

    if (token is ConstantToken) {
      _pos++;
      return token.value;
    }

    if (token is VariableToken) {
      _pos++;
      return variables[token.name] ?? 0;
    }

    if (token is AnsToken) {
      _pos++;
      return ans;
    }

    if (token is FractionToken) {
      _pos++;
      final top = ExpressionParser(
        token.numerator,
        variables: variables,
        ans: ans,
      ).parseExpression();
      final bottom = ExpressionParser(
        token.denominator,
        variables: variables,
        ans: ans,
      ).parseExpression();

      if (bottom == 0) {
        throw DivideByZeroError(_pos - 1);
      }

      return top / bottom;
    }

    if (token is RootToken) {
      _pos++;
      final arg = ExpressionParser(
        token.children,
        variables: variables,
        ans: ans,
      ).parseExpression();

      if (arg < 0) {
        throw NonrealAnswersError(_pos - 1);
      }

      return math.sqrt(arg);
    }

    if (token is FunctionToken) {
      _pos++;
      if (_current is LeftParenToken) _pos++;

      final args = <double>[parseExpression()];
      while (_current is CommaToken) {
        _pos++;
        args.add(parseExpression());
      }

      final errorIndex = _current is RightParenToken ? _pos : tokens.length;
      if (_current is RightParenToken) _pos++;

      return _applyFunction(token.type, args, errorIndex);
    }

    throw SyntaxError(_pos);
  }

  static int _minArgs(FunctionType type) {
    switch (type) {
      case FunctionType.min:
      case FunctionType.max:
      case FunctionType.lcm:
      case FunctionType.gcd:
        return 2;
      default:
        return 1;
    }
  }

  static int _maxArgs(FunctionType type) =>
      type == FunctionType.round ? 2 : _minArgs(type);

  static bool _isInt(double v) => v.isFinite && v == v.truncateToDouble();

  double _applyFunction(FunctionType type, List<double> args, int errorIndex) {
    if (args.length < _minArgs(type) || args.length > _maxArgs(type)) {
      throw SyntaxError(errorIndex);
    }

    final arg = args[0];

    switch (type) {
      case FunctionType.sin:
        return math.sin(arg);
      case FunctionType.cos:
        return math.cos(arg);
      case FunctionType.tan:
        return math.tan(arg);
      case FunctionType.log:
        if (arg <= 0) throw NonrealAnswersError(errorIndex);
        return math.log(arg) / math.ln10;
      case FunctionType.ln:
        if (arg <= 0) throw NonrealAnswersError(errorIndex);
        return math.log(arg);
      case FunctionType.asin:
        return math.asin(arg);
      case FunctionType.acos:
        return math.acos(arg);
      case FunctionType.atan:
        return math.atan(arg);
      case FunctionType.squareRoot:
        if (arg < 0) throw NonrealAnswersError(errorIndex);
        return math.sqrt(arg);
      case FunctionType.abs:
        return arg.abs();
      case FunctionType.iPart:
        return arg.truncateToDouble();
      case FunctionType.fPart:
        return arg - arg.truncateToDouble();
      case FunctionType.intFloor:
        return arg.floorToDouble();
      case FunctionType.round:
        final digits = args.length == 2 ? args[1] : 0.0;
        if (!_isInt(digits) || digits < 0 || digits > 9) {
          throw ArgumentError(errorIndex);
        }
        final factor = math.pow(10, digits).toDouble();
        return (arg * factor).roundToDouble() / factor;
      case FunctionType.min:
        return math.min(arg, args[1]);
      case FunctionType.max:
        return math.max(arg, args[1]);
      case FunctionType.gcd:
      case FunctionType.lcm:
        final a = arg;
        final b = args[1];
        if (!_isInt(a) || !_isInt(b) || a < 0 || b < 0) {
          throw ArgumentError(errorIndex);
        }
        final g = _gcd(a, b);
        if (type == FunctionType.gcd) return g;
        return g == 0 ? 0 : a / g * b;
    }
  }

  static double _gcd(double a, double b) {
    while (b != 0) {
      final t = a % b;
      a = b;
      b = t;
    }
    return a;
  }
}
