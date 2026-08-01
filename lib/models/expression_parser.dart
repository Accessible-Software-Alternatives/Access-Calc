import 'dart:math' as math;

import 'package:graphing_calculator/models/calc_error.dart';
import 'package:graphing_calculator/models/calc_token.dart';

class ExpressionParser {
  final List<CalcToken> tokens;
  int _pos = 0;

  ExpressionParser(this.tokens);

  CalcToken? get _current => _pos < tokens.length ? tokens[_pos] : null;

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

    while (_current is OperatorToken) {
      final op = _current as OperatorToken;
      if (op.type != OperatorType.multiply && op.type != OperatorType.divide) {
        break;
      }
      _pos++;
      final right = _parsePower();
      if (op.type == OperatorType.divide) {
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

  double _parsePower() {
    var base = _parsePrimary();

    if (_current is OperatorToken &&
        (_current as OperatorToken).type == OperatorType.power) {
      _pos++;
      final exp = _parsePower();
      base = math.pow(base, exp).toDouble();
    }

    return base;
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

    if (token is FunctionToken) {
      _pos++;
      if (_current is LeftParenToken) _pos++;
      final arg = parseExpression();

      final errorIndex = _current is RightParenToken ? _pos : tokens.length;
      if (_current is RightParenToken) _pos++;

      if ((token.type == FunctionType.log || token.type == FunctionType.ln) &&
          arg <= 0) {
        throw NonrealAnswersError(errorIndex);
      }
      if (token.type == FunctionType.squareRoot && arg < 0) {
        throw NonrealAnswersError(errorIndex);
      }

      return _applyFunction(token.type, arg);
    }

    throw SyntaxError(_pos);
  }

  double _applyFunction(FunctionType type, double arg) {
    switch (type) {
      case FunctionType.sin:
        return math.sin(arg);
      case FunctionType.cos:
        return math.cos(arg);
      case FunctionType.tan:
        return math.tan(arg);
      case FunctionType.log:
        return math.log(arg) / math.ln10;
      case FunctionType.ln:
        return math.log(arg);
      case FunctionType.asin:
        return math.asin(arg);
      case FunctionType.acos:
        return math.acos(arg);
      case FunctionType.atan:
        return math.atan(arg);
      case FunctionType.squareRoot:
        return math.sqrt(arg);
    }
  }
}
