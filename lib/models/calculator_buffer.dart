import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:graphing_calculator/models/button_mode.dart';
import 'package:graphing_calculator/models/calc_error.dart';
import 'package:graphing_calculator/models/calc_menu.dart';
import 'package:graphing_calculator/models/calc_token.dart';
import 'package:graphing_calculator/models/exact_parser.dart';
import 'package:graphing_calculator/models/expression_layout.dart';
import 'package:graphing_calculator/models/expression_parser.dart';

class CalculatorBuffer extends ChangeNotifier {
  List<CalcLine> lines = [CalcLine([])];
  int cursorRow = 0;
  int scrollOffset = 0;

  static const int visibleLineCount = 10;

  static const int displayColumns = 26;

  Timer? _cursorTimer;

  bool cursorVisible = true;

  ButtonMode mode = ButtonMode.normal;

  bool overwriteMode = true;

  final Map<String, double> variables = {};

  double lastAnswer = 0;

  CalcError? error;
  List<CalcToken>? _erroredTokens;

  final List<CalcMenu> menuStack = [];

  CalcMenu? get activeMenu => menuStack.isEmpty ? null : menuStack.last;

  bool get hasMenu => menuStack.isNotEmpty;

  void pushMenu(CalcMenu menu) {
    menuStack.add(menu);
    notifyListeners();
  }

  void popMenu() {
    if (menuStack.isEmpty) return;
    menuStack.removeLast();
    notifyListeners();
  }

  void closeMenus() {
    if (menuStack.isEmpty) return;
    menuStack.clear();
    notifyListeners();
  }

  bool handleMenuKey(MenuKey key, {String? selector}) {
    final menu = activeMenu;
    if (menu == null) return false;

    switch (key) {
      case MenuKey.up:
        menu.moveUp();
        break;
      case MenuKey.down:
        menu.moveDown();
        break;
      case MenuKey.left:
        menu.previousPage();
        break;
      case MenuKey.right:
        menu.nextPage();
        break;
      case MenuKey.enter:
        menu.activateSelection();
        break;
      case MenuKey.cancel:
        menu.cancel();
        break;
      case MenuKey.selector:
        if (selector == null) return false;
        if (!menu.activateSelector(selector)) return false;
        break;
    }

    notifyListeners();
    return true;
  }

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

  FractionToken? get fractionBeforeCursor {
    if (!isOnEditableLine) return null;
    final frame = _currentFrame;
    final pos = _positionInFrame(frame);
    if (pos.offset != 0 || pos.tokenIndex >= frame.tokens.length) return null;
    final token = frame.tokens[pos.tokenIndex];
    return token is FractionToken ? token : null;
  }

  int get _fractionDepth => _path.where((f) => f.owner is FractionToken).length;

  int get _powerDepth => _path.where((f) => f.owner is ExponentToken).length;

  int get _rootDepth => _path.where((f) => f.owner is RootToken).length;

  bool get _canAddPower =>
      _powerDepth < kMaxPowerDepth && _fitsAfterInsert(ExponentToken());

  final ExpressionLayoutEngine _measureEngine =
      ExpressionLayoutEngine.forMeasuring();

  bool _fitsAfterInsert(CalcToken probe) {
    final frame = _currentFrame;
    final index = _positionInFrame(
      frame,
    ).tokenIndex.clamp(0, frame.tokens.length);
    frame.tokens.insert(index, probe);
    try {
      final height = _measureEngine.layout(lines[cursorRow].tokens).height;
      return height <= kMaxLineHeightRows;
    } finally {
      frame.tokens.removeAt(index);
    }
  }

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
    } else if (token is FractionToken) {
      return;
    } else if (token is BoxToken) {
      frame.tokens.removeAt(pos.tokenIndex);
      frame.tokens.insertAll(pos.tokenIndex, token.children);
    } else {
      frame.tokens.removeAt(pos.tokenIndex);
    }
  }

  void insertToken(CalcToken token, {bool overwrite = true}) {
    if (!isOnEditableLine) {
      return;
    }

    _resetCursorBlink();

    final frame = _currentFrame;
    if (overwrite) _applyOverwrite(frame);

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

  void insertExponent({bool overwrite = true}) {
    if (!isOnEditableLine) return;

    if (!_canAddPower) return;
    _ensureLeftOperand();
    _insertBoxAndEnter(ExponentToken(), overwrite: overwrite);
  }

  void insertSquare() {
    if (!isOnEditableLine) return;

    if (!_canAddPower) return;
    _ensureLeftOperand();
    insertToken(ExponentToken([NumberToken('2')]));
  }

  void insertReciprocal() {
    if (!isOnEditableLine) return;

    if (!_canAddPower) return;
    _ensureLeftOperand();
    insertToken(ExponentToken([NumberToken('-1')]));
  }

  void insertConstant(ConstantType type) {
    if (!isOnEditableLine) return;

    insertToken(ConstantToken(type));
  }

  void insertVariable(String name) {
    if (!isOnEditableLine) return;

    insertToken(VariableToken(name));
  }

  void insertAns() {
    if (!isOnEditableLine) return;

    insertToken(AnsToken());
  }

  void insertOperator(OperatorType type) {
    if (!isOnEditableLine) return;

    _ensureLeftOperand();
    insertToken(OperatorToken(type));
  }

  void insertStore() {
    if (!isOnEditableLine) return;

    _ensureLeftOperand();
    insertToken(StoreToken());
  }

  void insertPowerOfTen() {
    if (!isOnEditableLine) return;

    if (!_canAddPower) return;
    insertToken(ConstantToken(ConstantType.ten));
    insertExponent(overwrite: false);
  }

  void _ensureLeftOperand() {
    final pos = _positionInFrame(_currentFrame);

    if (pos.tokenIndex > 0 || pos.offset > 0) return;

    insertToken(AnsToken(), overwrite: false);
  }

  void insertRoot() {
    if (!isOnEditableLine) return;

    if (_rootDepth >= kMaxRootDepth) return;
    if (!_fitsAfterInsert(RootToken())) return;
    _insertBoxAndEnter(RootToken());
  }

  void insertFraction() {
    if (!isOnEditableLine) return;
    if (_fractionDepth >= kMaxFractionDepth) return;

    _resetCursorBlink();

    final frame = _currentFrame;
    final backupTokens = List<CalcToken>.of(frame.tokens);
    final backupColumn = frame.column;

    _applyOverwrite(frame);
    _splitNumberAtCursor(frame);

    final pos = _positionInFrame(frame);
    final grabbed = pos.offset == 0
        ? _grabOperand(frame.tokens, pos.tokenIndex)
        : null;

    final fraction = FractionToken(grabbed?.tokens);
    var insertAt = pos.tokenIndex;

    if (grabbed != null) {
      var removedColumns = 0;
      for (int i = grabbed.start; i < pos.tokenIndex; i++) {
        removedColumns += frame.tokens[i].cursorLength;
      }
      frame.tokens.removeRange(grabbed.start, pos.tokenIndex);
      frame.column -= removedColumns;
      insertAt = grabbed.start;
    }
    frame.tokens.insert(insertAt, fraction);

    final fits =
        _fractionDepth + _fractionNesting(fraction) <= kMaxFractionDepth &&
        _measureEngine.layout(lines[cursorRow].tokens).height <=
            kMaxLineHeightRows;

    if (!fits) {
      frame.tokens
        ..clear()
        ..addAll(backupTokens);
      frame.column = backupColumn;
      return;
    }

    _path.add(
      grabbed != null
          ? _CursorFrame(fraction.denominator, 0, fraction, 1)
          : _CursorFrame(fraction.numerator, 0, fraction),
    );

    notifyListeners();
  }

  void _splitNumberAtCursor(_CursorFrame frame) {
    final pos = _positionInFrame(frame);
    if (pos.offset == 0 || pos.tokenIndex >= frame.tokens.length) return;

    final token = frame.tokens[pos.tokenIndex];
    if (token is! NumberToken) return;

    frame.tokens
      ..removeAt(pos.tokenIndex)
      ..insert(pos.tokenIndex, NumberToken(token.value.substring(pos.offset)))
      ..insert(
        pos.tokenIndex,
        NumberToken(token.value.substring(0, pos.offset)),
      );
  }

  int _fractionNesting(CalcToken token) {
    if (token is FractionToken) {
      var deepest = 0;
      for (final t in [...token.numerator, ...token.denominator]) {
        deepest = math.max(deepest, _fractionNesting(t));
      }
      return 1 + deepest;
    }
    if (token is BoxToken) {
      var deepest = 0;
      for (final t in token.children) {
        deepest = math.max(deepest, _fractionNesting(t));
      }
      return deepest;
    }
    return 0;
  }

  ({int start, List<CalcToken> tokens})? _grabOperand(
    List<CalcToken> tokens,
    int end,
  ) {
    var start = end;
    while (true) {
      final next = _factorStart(tokens, start);
      if (next == null) break;
      start = next;
    }
    if (start == end) return null;

    var grabbed = tokens.sublist(start, end);

    if (grabbed.length >= 2 &&
        grabbed.first is LeftParenToken &&
        grabbed.last is RightParenToken &&
        _matchingOpen(tokens, end - 1) == start) {
      grabbed = grabbed.sublist(1, grabbed.length - 1);
    }

    return (start: start, tokens: grabbed);
  }

  int? _factorStart(List<CalcToken> tokens, int end) {
    final i = end - 1;
    if (i < 0) return null;
    final token = tokens[i];

    if (token is ExponentToken) {
      return _factorStart(tokens, i) ?? i;
    }
    if (token is RightParenToken) {
      return _matchingOpen(tokens, i);
    }
    if (token is NumberToken ||
        token is ConstantToken ||
        token is VariableToken ||
        token is AnsToken ||
        token is RootToken ||
        token is FractionToken) {
      return i;
    }
    return null;
  }

  int? _matchingOpen(List<CalcToken> tokens, int closeIndex) {
    var depth = 0;
    for (int j = closeIndex; j >= 0; j--) {
      final t = tokens[j];
      if (t is RightParenToken) {
        depth++;
      } else if (t is LeftParenToken || t is FunctionToken) {
        depth--;
        if (depth == 0) return j;
      }
    }
    return null;
  }

  void _insertBoxAndEnter(BoxToken box, {bool overwrite = true}) {
    _resetCursorBlink();

    final frame = _currentFrame;
    if (overwrite) _applyOverwrite(frame);
    _splitNumberAtCursor(frame);

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
      final owner = frame.owner;
      if (owner is FractionToken && frame.part == 1) {
        _path[_path.length - 1] = _CursorFrame(
          owner.numerator,
          _frameEndColumn(owner.numerator),
          owner,
          0,
        );
        notifyListeners();
      } else if (_path.length > 1) {
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
      if (token is FractionToken) {
        _path.add(
          _CursorFrame(
            token.denominator,
            _frameEndColumn(token.denominator),
            token,
            1,
          ),
        );
      } else {
        _path.add(
          _CursorFrame(token.children, _frameEndColumn(token.children), token),
        );
      }
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
      final owner = frame.owner;
      if (owner is FractionToken && frame.part == 0) {
        _path[_path.length - 1] = _CursorFrame(owner.denominator, 0, owner, 1);
        notifyListeners();
        return;
      }
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

  bool _moveWithinFraction({required bool up}) {
    if (!isOnEditableLine) return false;

    for (int level = _path.length - 1; level >= 1; level--) {
      final frame = _path[level];
      final owner = frame.owner;
      if (owner is! FractionToken) continue;
      if (up ? frame.part == 0 : frame.part == 1) continue;

      final target = up ? owner.numerator : owner.denominator;
      final column = level == _path.length - 1
          ? frame.column.clamp(0, _frameEndColumn(target))
          : 0;
      _path.removeRange(level, _path.length);
      _path.add(_CursorFrame(target, column, owner, up ? 0 : 1));
      return true;
    }
    return false;
  }

  void moveUp() {
    _resetCursorBlink();

    if (_moveWithinFraction(up: true)) {
      notifyListeners();
      return;
    }

    if (cursorRow > 0) {
      _switchLine(cursorRow - 1);
      _updateScroll();
      notifyListeners();
    }
  }

  void moveDown() {
    _resetCursorBlink();

    if (_moveWithinFraction(up: false)) {
      notifyListeners();
      return;
    }

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
        return CursorPosition(i, remaining, frame.part);
      }

      remaining -= length;
    }

    return CursorPosition(tokens.length, 0, frame.part);
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
      menuStack.clear();
    }

    if (!isOnEditableLine) {
      _clearHistoryEntry();
      notifyListeners();
      return;
    }

    if (_path.length > 1 && _currentFrame.tokens.isNotEmpty) {
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
      final owner = frame.owner;
      final bothPartsEmpty =
          owner is! FractionToken ||
          (owner.numerator.isEmpty && owner.denominator.isEmpty);
      if (_path.length > 1 && tokens.isEmpty && bothPartsEmpty) {
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
      lines.add(CalcLine(result, isResult: true));
      lines.add(CalcLine([]));
    } catch (e) {
      final calcError = e is CalcError ? e : SyntaxError(tokens.length);
      _erroredTokens = List<CalcToken>.from(tokens);
      lines.add(CalcLine(stringToTokens('Error'), isResult: true));
      lines.add(CalcLine([]));
      error = calcError;
      pushMenu(_buildErrorMenu(calcError));
    }
  }

  CalcMenu _buildErrorMenu(CalcError calcError) {
    return CalcMenu(
      heading: 'ERROR: ${calcError.title}',
      body: wrapMenuText(calcError.message, displayColumns),
      pages: [
        const MenuPage('ERROR', [MenuItem('Quit'), MenuItem('Goto')]),
      ],
      onSelect: (menu, _, itemIndex) {
        if (itemIndex == 0) {
          quitError();
        } else {
          gotoError();
        }
      },
      onCancel: (_) => quitError(),
    );
  }

  List<CalcToken> _evaluate(List<CalcToken> tokens) {
    final storeIndex = tokens.indexWhere((t) => t is StoreToken);

    if (storeIndex >= 0) {
      return _evaluateStore(tokens, storeIndex);
    }

    final result = ExpressionParser(
      tokens,
      variables: variables,
      ans: lastAnswer,
    ).parseExpression();

    final output = _resultTokens(result, tokens, tokens.length);
    _recordAnswer(result);
    return output;
  }

  static const int _maxFractionDigits = 10;

  List<CalcToken> _resultTokens(
    double value,
    List<CalcToken> source,
    int tokenIndex,
  ) {
    final formatted = _formatResult(value, tokenIndex);

    if (ExactParser.containsFraction(source)) {
      final exact = ExactParser.tryEvaluate(
        source,
        variables: variables,
        ans: lastAnswer,
      );

      if (exact != null && !exact.isInteger) {
        final top = exact.numerator.toString();
        final bottom = exact.denominator.toString();
        final topDigits = top.startsWith('-') ? top.length - 1 : top.length;

        if (topDigits <= _maxFractionDigits &&
            bottom.length <= _maxFractionDigits) {
          return [
            FractionToken([NumberToken(top)], [NumberToken(bottom)]),
          ];
        }
      }
    }

    return stringToTokens(formatted);
  }

  void _recordAnswer(double value) {
    if (!value.isNaN) lastAnswer = value;
  }

  List<CalcToken> _evaluateStore(List<CalcToken> tokens, int storeIndex) {
    final target = tokens.length == storeIndex + 2
        ? tokens[storeIndex + 1]
        : null;

    if (target is! VariableToken) {
      throw SyntaxError(storeIndex + 1);
    }

    final source = tokens.sublist(0, storeIndex);
    if (source.isEmpty) {
      throw SyntaxError(storeIndex);
    }

    final value = ExpressionParser(
      source,
      variables: variables,
      ans: lastAnswer,
    ).parseExpression();

    final output = _resultTokens(value, source, storeIndex);
    variables[target.name] = value;
    _recordAnswer(value);

    return output;
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
    menuStack.clear();
    notifyListeners();
  }

  void gotoError() {
    if (error == null) return;

    final tokens = _erroredTokens;
    final tokenIndex = error!.tokenIndex;
    error = null;
    _erroredTokens = null;
    menuStack.clear();

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
    if (token is FractionToken) {
      return FractionToken(
        token.numerator.map(_cloneToken).toList(),
        token.denominator.map(_cloneToken).toList(),
      );
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

  final int part;

  const CursorPosition(this.tokenIndex, this.offset, [this.part = 0]);
}

class _CursorFrame {
  final List<CalcToken> tokens;
  int column;

  final BoxToken? owner;

  final int part;

  _CursorFrame(this.tokens, this.column, [this.owner, this.part = 0]);
}
