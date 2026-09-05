abstract class CalcError implements Exception {
  final int tokenIndex;
  CalcError(this.tokenIndex);

  String get title;
  String get message;
}

class DivideByZeroError extends CalcError {
  DivideByZeroError(super.tokenIndex);

  @override
  String get title => 'DIVIDE BY 0';
  @override
  String get message =>
      'Attempted calculation contains division by 0.\nCalculation fails.';
}

class SyntaxError extends CalcError {
  SyntaxError(super.tokenIndex);

  @override
  String get title => 'SYNTAX';
  @override
  String get message =>
      'Check all arguments entered.\nPress + on menu item for Catalog Help.';
}

class NonrealAnswersError extends CalcError {
  NonrealAnswersError(super.tokenIndex);

  @override
  String get title => 'NONREAL ANSWERS';
  @override
  String get message =>
      'In REAL MODE, all calculations must result in a real number.';
}

class OverflowError extends CalcError {
  OverflowError(super.tokenIndex);

  @override
  String get title => 'OVERFLOW';
  @override
  String get message =>
      'Calculation exceeds the range of values that this machine can display.';
}
