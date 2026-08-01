import 'package:graphing_calculator/models/button_mode.dart';
import 'package:graphing_calculator/models/calc_token.dart';
import 'package:graphing_calculator/models/calculator_buffer.dart';

import 'button_type.dart';

enum ButtonAction {
  digit0,
  digit1,
  digit2,
  digit3,
  digit4,
  digit5,
  digit6,
  digit7,
  digit8,
  digit9,

  add,
  subtract,
  multiply,
  divide,
  power,

  decimal,
  negative,

  sin,
  cos,
  tan,
  log,
  ln,

  leftParen,
  rightParen,

  comma,

  left,
  right,
  up,
  down,

  delete,
  enter,

  yEquals,
  window,
  zoom,
  trace,
  graph,

  math,
  apps,
  prgm,
  vars,
  clear,

  reciprocal,
  square,
  squareRoot,

  store,

  second,
  mode,
  alpha,
  xtheta,
  stat,

  on,

  asin,
  acos,
  atan,
  tenToX,
  eToX,
  statPlot,
  tblSet,
  format,
  calcMenu,
  table,
  quit,
  ins,
  link,
  fraction,
  list,
  test,
  angle,
  draw,
  distr,
  matrix,
  piConst,
  ee,
  leftBrace,
  rightBrace,
  leftBracket,
  rightBracket,
  eConst,
  rcl,
  mem,
  off,
  catalog,
  colon,
  quotation,
  space,
  questionMark,
  ans,
  entry,

  f1,
  f2,
  f3,
  f4,
  f5,
  letterA,
  letterB,
  letterC,
  letterD,
  letterE,
  letterF,
  letterG,
  letterH,
  letterI,
  letterJ,
  letterK,
  letterL,
  letterM,
  letterN,
  letterO,
  letterP,
  letterQ,
  letterR,
  letterS,
  letterT,
  letterU,
  letterV,
  letterW,
  letterX,
  letterY,
  letterZ,
  letteru,
  letterv,
  letterw,
  l1,
  l2,
  l3,
  l4,
  l5,
  l6,
  theta,
  imaginaryUnit,
  solve,
}

class CalcButtonFunction {
  final String label;
  final ButtonType type;
  final ButtonAction action;

  const CalcButtonFunction(this.label, this.type, this.action);
}

class CalcButtonData {
  final String label;
  final ButtonType type;
  final ButtonAction action;

  final CalcButtonFunction? secondFunction;

  final CalcButtonFunction? alphaFunction;

  const CalcButtonData(
    this.label,
    this.type,
    this.action, {
    this.secondFunction,
    this.alphaFunction,
  });

  CalcButtonFunction resolve(ButtonMode mode) {
    if (mode.isAlpha && alphaFunction != null) return alphaFunction!;
    if (mode.isSecond && secondFunction != null) return secondFunction!;
    return CalcButtonFunction(label, type, action);
  }
}

extension ButtonActionExecutor on ButtonAction {
  void execute(CalculatorBuffer buffer) {
    if (buffer.error != null) {
      switch (this) {
        // will replace this with an actual menu navigation when the rest of the menu is implemented
        case ButtonAction.digit1:
          buffer.quitError();
          break;
        case ButtonAction.digit2:
          buffer.gotoError();
          break;
        default:
          break;
      }
      return;
    }

    if (this == ButtonAction.second) {
      _advanceSecond(buffer);
      return;
    }
    if (this == ButtonAction.alpha) {
      _advanceAlpha(buffer);
      return;
    }

    switch (this) {
      case ButtonAction.left:
        buffer.moveLeft();
        break;
      case ButtonAction.right:
        buffer.moveRight();
        break;
      case ButtonAction.up:
        buffer.moveUp();
        break;
      case ButtonAction.down:
        buffer.moveDown();
        break;

      case ButtonAction.clear:
        buffer.clear();
        break;
      case ButtonAction.delete:
        buffer.delete();
        break;
      case ButtonAction.enter:
        buffer.enter();
        break;

      case ButtonAction.digit0:
        buffer.insertDigit("0");
        break;
      case ButtonAction.digit1:
        buffer.insertDigit("1");
        break;
      case ButtonAction.digit2:
        buffer.insertDigit("2");
        break;
      case ButtonAction.digit3:
        buffer.insertDigit("3");
        break;
      case ButtonAction.digit4:
        buffer.insertDigit("4");
        break;
      case ButtonAction.digit5:
        buffer.insertDigit("5");
        break;
      case ButtonAction.digit6:
        buffer.insertDigit("6");
        break;
      case ButtonAction.digit7:
        buffer.insertDigit("7");
        break;
      case ButtonAction.digit8:
        buffer.insertDigit("8");
        break;
      case ButtonAction.digit9:
        buffer.insertDigit("9");
        break;

      case ButtonAction.decimal:
        buffer.insertDigit(".");
        break;
      case ButtonAction.negative:
        buffer.insertDigit("-");
        break;

      case ButtonAction.add:
        buffer.insertToken(OperatorToken(OperatorType.add));
        break;
      case ButtonAction.subtract:
        buffer.insertToken(OperatorToken(OperatorType.subtract));
        break;
      case ButtonAction.multiply:
        buffer.insertToken(OperatorToken(OperatorType.multiply));
        break;
      case ButtonAction.divide:
        buffer.insertToken(OperatorToken(OperatorType.divide));
        break;
      case ButtonAction.power:
        buffer.insertToken(OperatorToken(OperatorType.power));
        break;

      case ButtonAction.sin:
        buffer.insertToken(FunctionToken(FunctionType.sin));
        break;
      case ButtonAction.cos:
        buffer.insertToken(FunctionToken(FunctionType.cos));
        break;
      case ButtonAction.tan:
        buffer.insertToken(FunctionToken(FunctionType.tan));
        break;
      case ButtonAction.log:
        buffer.insertToken(FunctionToken(FunctionType.log));
        break;
      case ButtonAction.ln:
        buffer.insertToken(FunctionToken(FunctionType.ln));
        break;

      case ButtonAction.asin:
        buffer.insertToken(FunctionToken(FunctionType.asin));
        break;
      case ButtonAction.acos:
        buffer.insertToken(FunctionToken(FunctionType.acos));
        break;
      case ButtonAction.atan:
        buffer.insertToken(FunctionToken(FunctionType.atan));
        break;

      case ButtonAction.squareRoot:
        buffer.insertToken(FunctionToken(FunctionType.squareRoot));
        break;

      case ButtonAction.leftParen:
        buffer.insertToken(LeftParenToken());
        break;
      case ButtonAction.rightParen:
        buffer.insertToken(RightParenToken());
        break;

      case ButtonAction.comma:
      case ButtonAction.yEquals:
      case ButtonAction.window:
      case ButtonAction.zoom:
      case ButtonAction.trace:
      case ButtonAction.graph:
      case ButtonAction.math:
      case ButtonAction.apps:
      case ButtonAction.prgm:
      case ButtonAction.vars:
      case ButtonAction.reciprocal:
      case ButtonAction.square:
      case ButtonAction.store:
      case ButtonAction.mode:
      case ButtonAction.xtheta:
      case ButtonAction.stat:
      case ButtonAction.on:
      case ButtonAction.tenToX:
      case ButtonAction.eToX:
      case ButtonAction.statPlot:
      case ButtonAction.tblSet:
      case ButtonAction.format:
      case ButtonAction.calcMenu:
      case ButtonAction.table:
      case ButtonAction.quit:
      case ButtonAction.ins:
      case ButtonAction.link:
      case ButtonAction.fraction:
      case ButtonAction.list:
      case ButtonAction.test:
      case ButtonAction.angle:
      case ButtonAction.draw:
      case ButtonAction.distr:
      case ButtonAction.matrix:
      case ButtonAction.piConst:
      case ButtonAction.ee:
      case ButtonAction.leftBrace:
      case ButtonAction.rightBrace:
      case ButtonAction.leftBracket:
      case ButtonAction.rightBracket:
      case ButtonAction.eConst:
      case ButtonAction.rcl:
      case ButtonAction.mem:
      case ButtonAction.off:
      case ButtonAction.catalog:
      case ButtonAction.colon:
      case ButtonAction.quotation:
      case ButtonAction.space:
      case ButtonAction.questionMark:
      case ButtonAction.ans:
      case ButtonAction.entry:
      case ButtonAction.f1:
      case ButtonAction.f2:
      case ButtonAction.f3:
      case ButtonAction.f4:
      case ButtonAction.f5:
      case ButtonAction.letterA:
      case ButtonAction.letterB:
      case ButtonAction.letterC:
      case ButtonAction.letterD:
      case ButtonAction.letterE:
      case ButtonAction.letterF:
      case ButtonAction.letterG:
      case ButtonAction.letterH:
      case ButtonAction.letterI:
      case ButtonAction.letterJ:
      case ButtonAction.letterK:
      case ButtonAction.letterL:
      case ButtonAction.letterM:
      case ButtonAction.letterN:
      case ButtonAction.letterO:
      case ButtonAction.letterP:
      case ButtonAction.letterQ:
      case ButtonAction.letterR:
      case ButtonAction.letterS:
      case ButtonAction.letterT:
      case ButtonAction.letterU:
      case ButtonAction.letterV:
      case ButtonAction.letterW:
      case ButtonAction.letterX:
      case ButtonAction.letterY:
      case ButtonAction.letterZ:
      case ButtonAction.letteru:
      case ButtonAction.letterv:
      case ButtonAction.letterw:
      case ButtonAction.l1:
      case ButtonAction.l2:
      case ButtonAction.l3:
      case ButtonAction.l4:
      case ButtonAction.l5:
      case ButtonAction.l6:
      case ButtonAction.theta:
      case ButtonAction.imaginaryUnit:
      case ButtonAction.solve:
        // TODO
        break;

      case ButtonAction.second:
      case ButtonAction.alpha:
        // Handled above before this switch is reached.
        break;
    }

    _consumeShift(buffer);
  }
}

void _advanceSecond(CalculatorBuffer buffer) {
  switch (buffer.mode) {
    case ButtonMode.normal:
      buffer.setMode(ButtonMode.second);
      break;
    case ButtonMode.second:
      buffer.setMode(ButtonMode.normal);
      break;
    case ButtonMode.alpha:
    case ButtonMode.alphaLock:
      buffer.setMode(ButtonMode.second);
      break;
  }
}

void _advanceAlpha(CalculatorBuffer buffer) {
  switch (buffer.mode) {
    case ButtonMode.normal:
      buffer.setMode(ButtonMode.alpha);
      break;
    case ButtonMode.second:
      buffer.setMode(ButtonMode.alphaLock);
      break;
    case ButtonMode.alpha:
    case ButtonMode.alphaLock:
      buffer.setMode(ButtonMode.normal);
      break;
  }
}

void _consumeShift(CalculatorBuffer buffer) {
  switch (buffer.mode) {
    case ButtonMode.second:
      buffer.setMode(ButtonMode.normal);
      break;
    case ButtonMode.alpha:
      buffer.setMode(ButtonMode.normal);
      break;
    case ButtonMode.alphaLock:
      break;
    case ButtonMode.normal:
      break;
  }
}
