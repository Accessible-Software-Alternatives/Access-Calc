import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:graphing_calculator/models/button_mode.dart';
import 'package:graphing_calculator/models/calc_error.dart';
import 'package:graphing_calculator/models/calc_token.dart';
import 'package:graphing_calculator/models/expression_parser.dart';

class CalculatorBuffer extends ChangeNotifier {
  List<CalcLine> lines = [CalcLine([])];
  int cursorRow = 0;
  int scrollOffset = 0;

  static const int visibleLineCount = 10;

  Timer? _cursorTimer;

  bool cursorVisible = true;

  ButtonMode mode = ButtonMode.normal;

  bool overwriteMode = true;

  CalcError? error;
  List<CalcToken>? _erroredTokens;

  late List<_CursorFrame> _path;

  CalculatorBuffer() {
    _path = [_CursorFrame(lines[cursorRow].tokens, 0)];
    _startCursorTimer();
  }

  void setMode(ButtonMode newMode) {
    mode = newMode;
    notifyListeners();
  }

  void toggleOverwriteMode() {
    overwriteMode = !overwriteMode;
    notifyListeners();
  }

  _CursorFrame get _currentFrame => _path.last;

  List<CalcToken> get cursorTokens => _currentFrame.tokens;

  List<CursorPosition> get cursorPath =>
      _path.map(_positionInFrame).toList(growable: false);

  bool get isAtEndOfCurrentBox {
    if (_path.length <= 1) return false;
    final frame = _currentFrame;
    return frame.column >= _frameEndColumn(frame.tokens);
  }

  BoxToken? get currentBoxOwner =>
      _path.length > 1 ? _currentFrame.owner : null;

  void _applyOverwrite(_CursorFrame frame) {
    if (!overwriteMode) return;

    final pos = _positionInFrame(frame);
    if (pos.tokenIndex >= frame.tokens.length) return;

    final token = frame.tokens[pos.tokenIndex];

    if (token is NumberToken) {
      final text = token.value;
      final newValue =
          text.substring(0, pos.offset) + text.substring(pos.offset + 1);

      if (newValue.isEmpty) {
        frame.tokens.removeAt(pos.tokenIndex);
      } else {
        frame.tokens[pos.tokenIndex] = NumberToken(newValue);
      }
    } else if (token is BoxToken) {
      frame.tokens.removeAt(pos.tokenIndex);
      frame.tokens.insertAll(pos.tokenIndex, token.children);
    } else {
      frame.tokens.removeAt(pos.tokenIndex);
    }
  }

  void insertToken(CalcToken token) {
    if (!isOnEditableLine) {
      return;
    }

    _resetCursorBlink();

    final frame = _currentFrame;
    _applyOverwrite(frame);

    final tokens = frame.tokens;
    final pos = _positionInFrame(frame);

    if (pos.tokenIndex < tokens.length &&
        tokens[pos.tokenIndex] is NumberToken &&
        pos.offset > 0 &&
        pos.offset < (tokens[pos.tokenIndex] as NumberToken).value.length) {
      final number = tokens[pos.tokenIndex] as NumberToken;

      final left = number.value.substring(0, pos.offset);
      final right = number.value.substring(pos.offset);

      tokens.removeAt(pos.tokenIndex);

      tokens.insert(pos.tokenIndex, NumberToken(right));
      tokens.insert(pos.tokenIndex, token);
      tokens.insert(pos.tokenIndex, NumberToken(left));
    } else {
      tokens.insert(pos.tokenIndex, token);
    }

    frame.column += token.cursorLength;

    notifyListeners();
  }

  void insertDigit(String digit) {
    if (!isOnEditableLine) {
      return;
    }

    _resetCursorBlink();

    final frame = _currentFrame;
    final tokens = frame.tokens;

    var pos = _positionInFrame(frame);

    final prevIndex = pos.tokenIndex - 1;
    final ahead = pos.tokenIndex < tokens.length
        ? tokens[pos.tokenIndex]
        : null;

    final isAfterNumber =
        pos.offset == 0 &&
        prevIndex >= 0 &&
        tokens[prevIndex] is NumberToken &&
        ahead is! BoxToken;

    if (isAfterNumber) {
      final number = tokens[prevIndex] as NumberToken;
      tokens[prevIndex] = NumberToken(number.value + digit);
      frame.column++;
      notifyListeners();
      return;
    }

    _applyOverwrite(frame);
    pos = _positionInFrame(frame);

    final leftIndex = pos.tokenIndex - 1;
    final leftIsNumber =
        pos.offset == 0 && leftIndex >= 0 && tokens[leftIndex] is NumberToken;

    final rightToken = pos.tokenIndex < tokens.length
        ? tokens[pos.tokenIndex]
        : null;
    final rightIsNumber = rightToken is NumberToken;

    if (pos.offset > 0 && rightIsNumber) {
      final text = (rightToken).value;
      tokens[pos.tokenIndex] = NumberToken(
        text.substring(0, pos.offset) + digit + text.substring(pos.offset),
      );
    } else if (leftIsNumber && rightIsNumber) {
      final left = tokens[leftIndex] as NumberToken;
      final right = rightToken;
      tokens[leftIndex] = NumberToken(left.value + digit + right.value);
      tokens.removeAt(pos.tokenIndex);
    } else if (leftIsNumber) {
      final left = tokens[leftIndex] as NumberToken;
      tokens[leftIndex] = NumberToken(left.value + digit);
    } else if (rightIsNumber) {
      final right = rightToken;
      tokens[pos.tokenIndex] = NumberToken(digit + right.value);
    } else {
      tokens.insert(pos.tokenIndex, NumberToken(digit));
    }

    frame.column++;

    notifyListeners();
  }

  void insertExponent() {
    if (!isOnEditableLine) return;

    _insertBoxAndEnter(ExponentToken());
  }

  void insertSquare() {
    if (!isOnEditableLine) return;

    insertToken(ExponentToken([NumberToken('2')]));
  }

  void insertRoot() {
    if (!isOnEditableLine) return;

    _insertBoxAndEnter(RootToken());
  }

  void _insertBoxAndEnter(BoxToken box) {
    _resetCursorBlink();

    final frame = _currentFrame;
    _applyOverwrite(frame);

    final pos = _positionInFrame(frame);
    frame.tokens.insert(pos.tokenIndex, box);

    _path.add(_CursorFrame(box.children, 0, box));

    notifyListeners();
  }

  void moveLeft() {
    _resetCursorBlink();

    if (!isOnEditableLine) return;

    final frame = _currentFrame;

    if (frame.column <= 0) {
      if (_path.length > 1) {
        _path.removeLast();
        notifyListeners();
      }
      return;
    }

    final pos = _positionInFrame(frame, column: frame.column - 1);
    final token = pos.tokenIndex < frame.tokens.length
        ? frame.tokens[pos.tokenIndex]
        : null;

    if (token is BoxToken) {
      frame.column = frame.column - 1 - pos.offset;
      _path.add(
        _CursorFrame(token.children, _frameEndColumn(token.children), token),
      );
    } else if (_isAtomicBlock(token)) {
      frame.column = frame.column - 1 - pos.offset;
    } else {
      frame.column--;
    }

    notifyListeners();
  }

  void moveRight() {
    _resetCursorBlink();

    if (!isOnEditableLine) return;

    final frame = _currentFrame;

    if (frame.column >= _frameEndColumn(frame.tokens)) {
      if (_path.length > 1) {
        _path.removeLast();
        _currentFrame.column += 1;
        notifyListeners();
      }
      return;
    }

    final pos = _positionInFrame(frame);
    final token = pos.tokenIndex < frame.tokens.length
        ? frame.tokens[pos.tokenIndex]
        : null;

    if (token is BoxToken) {
      frame.column = frame.column - pos.offset;
      _path.add(_CursorFrame(token.children, 0, token));
    } else if (_isAtomicBlock(token)) {
      frame.column = (frame.column - pos.offset) + token!.cursorLength;
    } else {
      frame.column++;
    }

    notifyListeners();
  }

  void moveUp() {
    _resetCursorBlink();

    if (cursorRow > 0) {
      _switchLine(cursorRow - 1);
      _updateScroll();
      notifyListeners();
    }
  }

  void moveDown() {
    _resetCursorBlink();

    if (cursorRow < lines.length - 1) {
      _switchLine(cursorRow + 1);
      _updateScroll();
      notifyListeners();
    }
  }

  void _switchLine(int newRow) {
    final column = _path.first.column;
    cursorRow = newRow;

    if (isOnEditableLine) {
      final maxColumn = _frameEndColumn(lines[cursorRow].tokens);
      _resetPath(column.clamp(0, maxColumn));
    } else {
      _resetPath(0);
    }
  }

  CursorPosition _positionInFrame(_CursorFrame frame, {int? column}) {
    final tokens = frame.tokens;

    int remaining = column ?? frame.column;

    for (int i = 0; i < tokens.length; i++) {
      final length = tokens[i].cursorLength;

      if (remaining < length) {
        return CursorPosition(i, remaining);
      }

      remaining -= length;
    }

    return CursorPosition(tokens.length, 0);
  }

  int _frameEndColumn(List<CalcToken> tokens) =>
      tokens.fold(0, (sum, token) => sum + token.cursorLength);

  bool _isAtomicBlock(CalcToken? token) {
    return token != null &&
        token is! NumberToken &&
        token is! BoxToken &&
        token.cursorLength > 1;
  }

  void _resetPath([int column = 0]) {
    _path = [_CursorFrame(lines[cursorRow].tokens, column)];
  }

  void clear() {
    _resetCursorBlink();

    if (error != null) {
      error = null;
      _erroredTokens = null;
    }

    if (!isOnEditableLine) {
      _clearHistoryEntry();
      notifyListeners();
      return;
    }

    if (_path.length > 1) {
      final frame = _currentFrame;
      frame.tokens.clear();
      frame.column = 0;
      notifyListeners();
      return;
    }

    final line = lines[cursorRow];

    if (line.tokens.isNotEmpty) {
      line.tokens.clear();
      _resetPath();
    } else {
      scrollOffset = lines.length - 1;
    }

    notifyListeners();
  }

  void _clearHistoryEntry() {
    int inputIndex;
    int resultIndex;

    if (lines[cursorRow].isResult) {
      resultIndex = cursorRow;
      inputIndex = cursorRow - 1;
    } else {
      inputIndex = cursorRow;
      resultIndex = cursorRow + 1;
    }

    if (resultIndex < lines.length && lines[resultIndex].isResult) {
      lines.removeAt(resultIndex);
    }
    if (inputIndex >= 0 && inputIndex < lines.length) {
      lines.removeAt(inputIndex);
    }

    cursorRow = inputIndex.clamp(0, lines.length - 1);
    _resetPath();

    _updateScroll();
  }

  void delete() {
    if (!isOnEditableLine) {
      return;
    }

    _resetCursorBlink();

    final frame = _currentFrame;
    final tokens = frame.tokens;

    final pos = _positionInFrame(frame);

    if (pos.tokenIndex >= tokens.length) {
      if (_path.length > 1 && tokens.isEmpty) {
        _deleteEnclosingBox();
        notifyListeners();
      }
      return;
    }

    final token = tokens[pos.tokenIndex];

    if (token is NumberToken) {
      final text = token.value;

      tokens[pos.tokenIndex] = NumberToken(
        text.substring(0, pos.offset) + text.substring(pos.offset + 1),
      );

      if ((tokens[pos.tokenIndex] as NumberToken).value.isEmpty) {
        tokens.removeAt(pos.tokenIndex);
      }
    } else {
      tokens.removeAt(pos.tokenIndex);
    }

    notifyListeners();
  }

  void _deleteEnclosingBox() {
    _path.removeLast();

    final parent = _currentFrame;
    final pos = _positionInFrame(parent);

    if (pos.tokenIndex < parent.tokens.length) {
      parent.tokens.removeAt(pos.tokenIndex);
    }
  }

  void enter() {
    _resetCursorBlink();

    if (!isOnEditableLine) {
      final sourceLine = lines[cursorRow];
      final editableLine = lines.last;

      editableLine.tokens.addAll(sourceLine.tokens.map(_cloneToken));

      cursorRow = lines.length - 1;
      _resetPath(_frameEndColumn(editableLine.tokens));

      _updateScroll();
      notifyListeners();
      return;
    }

    final expression = lines[cursorRow].displayText;

    if (expression.trim().isEmpty) {
      for (int i = lines.length - 2; i >= 0; i--) {
        if (!lines[i].isResult && lines[i].displayText.trim().isNotEmpty) {
          final tokens = lines[i].tokens;

          lines.removeLast();
          lines.add(CalcLine(tokens.map(_cloneToken).toList()));
          _pushResultOrError(tokens);

          cursorRow = lines.length - 1;
          _resetPath();

          _updateScroll();
          notifyListeners();
          return;
        }
      }
      return;
    }

    _pushResultOrError(lines[cursorRow].tokens);

    cursorRow = lines.length - 1;
    _resetPath();

    _updateScroll();
    notifyListeners();
  }

  void _pushResultOrError(List<CalcToken> tokens) {
    try {
      final result = _evaluate(tokens);
      lines.add(CalcLine(stringToTokens(result), isResult: true));
      lines.add(CalcLine([]));
    } catch (e) {
      final calcError = e is CalcError ? e : SyntaxError(tokens.length);
      _erroredTokens = List<CalcToken>.from(tokens);
      lines.add(CalcLine(stringToTokens('Error'), isResult: true));
      lines.add(CalcLine([]));
      error = calcError;
    }
  }

  String _evaluate(List<CalcToken> tokens) {
    final parser = ExpressionParser(tokens);
    final result = parser.parseExpression();
    return _formatResult(result, tokens.length);
  }

  static const int _maxResultChars = 15;

  String _formatResult(double result, int tokenIndex) {
    if (result.isNaN) return 'Error';
    if (result.isInfinite) throw OverflowError(tokenIndex);
    if (result == 0) return '0';

    final isNegative = result < 0;
    final magnitude = result.abs();
    final sign = isNegative ? '-' : '';
    final budget = _maxResultChars - sign.length;

    final plain = _plainForm(magnitude, budget);
    if (plain != null) return sign + plain;

    return sign + _scientificForm(magnitude, budget);
  }

  String? _plainForm(double magnitude, int budget) {
    for (int decimals = 10; decimals >= 0; decimals--) {
      var text = magnitude.toStringAsFixed(decimals);

      if (text.contains('.')) {
        text = text.replaceAll(RegExp(r'0+$'), '');
        text = text.replaceAll(RegExp(r'\.$'), '');
      }

      if (text.length > budget) continue;
      if (double.parse(text) == 0) continue;

      return text;
    }

    return null;
  }

  String _scientificForm(double magnitude, int budget) {
    int exponent = (math.log(magnitude) / math.ln10).floor();
    double mantissa = magnitude / math.pow(10, exponent);

    if (mantissa >= 10) {
      mantissa /= 10;
      exponent++;
    } else if (mantissa < 1) {
      mantissa *= 10;
      exponent--;
    }

    var decimals = _scientificDecimals(exponent, budget);
    var mantissaText = mantissa.toStringAsFixed(decimals);

    if (double.parse(mantissaText) >= 10) {
      exponent++;
      mantissa = double.parse(mantissaText) / 10;
      decimals = _scientificDecimals(exponent, budget);
      mantissaText = mantissa.toStringAsFixed(decimals);
    }

    if (mantissaText.contains('.')) {
      mantissaText = mantissaText.replaceAll(RegExp(r'0+$'), '');
      mantissaText = mantissaText.replaceAll(RegExp(r'\.$'), '');
    }

    return '${mantissaText}E$exponent';
  }

  int _scientificDecimals(int exponent, int budget) {
    final fixedChars = 1 + 1 + 1 + exponent.toString().length;
    return (budget - fixedChars).clamp(0, 10);
  }

  void quitError() {
    if (error == null) return;
    error = null;
    _erroredTokens = null;
    notifyListeners();
  }

  void gotoError() {
    if (error == null) return;

    final tokens = _erroredTokens;
    final tokenIndex = error!.tokenIndex;
    error = null;
    _erroredTokens = null;

    if (tokens != null) {
      final editableLine = lines.last;
      editableLine.tokens.addAll(tokens.map(_cloneToken));

      int column = 0;
      for (int i = 0; i < tokens.length && i < tokenIndex; i++) {
        column += tokens[i].cursorLength;
      }
      _resetPath(column);
    }

    notifyListeners();
  }

  CalcToken _cloneToken(CalcToken token) {
    if (token is NumberToken) return NumberToken(token.value);
    if (token is ExponentToken) {
      return ExponentToken(token.children.map(_cloneToken).toList());
    }
    if (token is RootToken) {
      return RootToken(token.children.map(_cloneToken).toList());
    }
    return token;
  }

  // temp
  List<CalcToken> stringToTokens(String text) {
    return [NumberToken(text)];
  }

  void _updateScroll() {
    if (cursorRow >= scrollOffset + visibleLineCount) {
      scrollOffset = cursorRow - visibleLineCount + 1;
    }

    if (cursorRow < scrollOffset) {
      scrollOffset = cursorRow;
    }
  }

  List<CalcLine> get visibleLines {
    return lines.skip(scrollOffset).take(visibleLineCount).toList();
  }

  bool get isOnEditableLine {
    return cursorRow == lines.length - 1;
  }

  void _startCursorTimer() {
    _cursorTimer?.cancel();

    _cursorTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      cursorVisible = !cursorVisible;
      notifyListeners();
    });
  }

  void _resetCursorBlink() {
    cursorVisible = true;

    _startCursorTimer();
  }

  @override
  void dispose() {
    _cursorTimer?.cancel();
    super.dispose();
  }
}

class CalcLine {
  final List<CalcToken> tokens;
  final bool isResult;

  CalcLine(this.tokens, {this.isResult = false});

  String get displayText => tokens.map((t) => t.displayText).join();
}

class CursorPosition {
  final int tokenIndex;
  final int offset;

  const CursorPosition(this.tokenIndex, this.offset);
}

class _CursorFrame {
  final List<CalcToken> tokens;
  int column;

  final BoxToken? owner;

  _CursorFrame(this.tokens, this.column, [this.owner]);
}
