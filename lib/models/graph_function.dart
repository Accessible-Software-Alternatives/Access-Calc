import 'package:flutter/material.dart';
import 'package:graphing_calculator/models/calc_token.dart';

enum GraphLineStyle {
  // probably temp
  normal('\\'),

  shadeBelow('◣'),

  shadeAbove('◥');

  const GraphLineStyle(this.glyph);

  final String glyph;
}

enum GraphColor {
  blue('BLUE', Color(0xFF0000FF)),
  red('RED', Color(0xFFFF0000)),
  black('BLACK', Color(0xFF000000)),
  magenta('MAGENTA', Color(0xFFFF00FF)),
  green('GREEN', Color(0xFF008000)),
  orange('ORANGE', Color(0xFFFF8000)),
  brown('BROWN', Color(0xFFA05A00)),
  navy('NAVY', Color(0xFF000080)),
  ltBlue('LTBLUE', Color(0xFF00A0F0)),
  yellow('YELLOW', Color(0xFFFFE000)),
  white('WHITE', Color(0xFFFFFFFF)),
  ltGray('LTGRAY', Color(0xFFC0C0C0)),
  medGray('MEDGRAY', Color(0xFF808080)),
  gray('GRAY', Color(0xFF606060)),
  darkGray('DARKGRAY', Color(0xFF404040));

  const GraphColor(this.label, this.color);

  final String label;

  final Color color;

  static GraphColor defaultFor(int functionIndex) => values[functionIndex % 9];
}

class GraphFunction {
  static const int count = 9;

  final int index;

  final List<CalcToken> tokens = [];

  GraphColor color;
  GraphLineStyle lineStyle;

  GraphFunction(this.index)
    : color = GraphColor.defaultFor(index),
      lineStyle = GraphLineStyle.normal;

  String get name => 'Y${index + 1}';

  bool get isDefined => tokens.isNotEmpty;

  void resetStyle() {
    color = GraphColor.defaultFor(index);
    lineStyle = GraphLineStyle.normal;
  }

  static List<GraphFunction> createDefaults() => [
    for (int i = 0; i < count; i++) GraphFunction(i),
  ];
}
