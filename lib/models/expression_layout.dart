import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'calc_token.dart';

const double kSuperscriptRaise = 0.62;

const double kRadicalBarGap = 0.28;

const double kRadicalTickWidth = 0.62;

const double kRadicalTrailingPad = 0.12;

// Placeholder
const String kEmptyBoxGlyph = '▭';

const double kExponentScale = 0.65;

const double kFractionBarGap = 0.08;

const double kFractionAxis = 0.28;

const double kFractionSidePad = 0.15;

const int kMaxFractionDepth = 4;

const int kMaxPowerDepth = 4;

const int kMaxRootDepth = 4;

const double kMaxLineHeightRows = 12.5;

class TokenLayout {
  final CalcToken token;
  final double width;
  final double ascent;
  final double descent;

  final double fontSize;

  final ExpressionLayout? child;

  final ExpressionLayout? child2;
  final double numeratorX;
  final double denominatorX;
  final double numeratorRise;
  final double denominatorDrop;
  final double barRise;
  final double barStart;
  final double barWidth;

  final double leadPad;

  TokenLayout({
    required this.token,
    required this.width,
    required this.ascent,
    required this.descent,
    required this.fontSize,
    this.child,
    this.child2,
    this.numeratorX = 0,
    this.denominatorX = 0,
    this.numeratorRise = 0,
    this.denominatorDrop = 0,
    this.barRise = 0,
    this.barStart = 0,
    this.barWidth = 0,
    this.leadPad = 0,
  });

  double get height => ascent + descent;

  double scaleRelativeTo(double baseFontSize) =>
      baseFontSize == 0 ? 1 : fontSize / baseFontSize;
}

class ExpressionLayout {
  final List<TokenLayout> tokens;
  final double width;
  final double ascent;
  final double descent;

  ExpressionLayout({
    required this.tokens,
    required this.width,
    required this.ascent,
    required this.descent,
  });

  double get height => ascent + descent;
}

enum EmptyStyle { none, glyph }

class ExpressionLayoutEngine {
  final TextStyle style;
  final double rowHeight;

  final double charWidth;

  final double _baseFontSize;
  final Map<bool, _Metrics> _metricsCache = {};

  ExpressionLayoutEngine({required this.style, required this.rowHeight})
    : _baseFontSize = style.fontSize ?? rowHeight * 0.72,
      charWidth = _measureCharWidth(style, style.fontSize ?? rowHeight * 0.72);

  /// Text-free engine in units of one row, for measuring heights only.
  ExpressionLayoutEngine.forMeasuring()
    : style = const TextStyle(),
      rowHeight = 1.0,
      charWidth = 0.6,
      _baseFontSize = 0.72;

  static double _measureCharWidth(TextStyle style, double fontSize) {
    final tp = TextPainter(
      text: TextSpan(
        text: '0',
        style: style.copyWith(fontSize: fontSize),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    return tp.width;
  }

  double get baseFontSize => _baseFontSize;

  _Metrics _metricsFor(bool smallText) {
    return _metricsCache.putIfAbsent(smallText, () {
      final scale = smallText ? kExponentScale : 1.0;
      return _Metrics(
        fontSize: _baseFontSize * scale,
        ascent: rowHeight * 0.78 * scale,
        descent: rowHeight * 0.22 * scale,
        charWidth: charWidth * scale,
        scale: scale,
      );
    });
  }

  ({double ascent, double descent, double charWidth, double fontSize})
  leafMetricsFor(bool smallText) {
    final m = _metricsFor(smallText);
    return (
      ascent: m.ascent,
      descent: m.descent,
      charWidth: m.charWidth,
      fontSize: m.fontSize,
    );
  }

  ExpressionLayout layout(
    List<CalcToken> tokens, {
    bool smallText = false,
    EmptyStyle emptyStyle = EmptyStyle.none,
    BoxToken? cursorEndOwner,
    FractionToken? leadArrowOwner,
  }) {
    final m = _metricsFor(smallText);

    if (tokens.isEmpty) {
      switch (emptyStyle) {
        case EmptyStyle.none:
          return ExpressionLayout(
            tokens: const [],
            width: 0,
            ascent: m.ascent,
            descent: m.descent,
          );
        case EmptyStyle.glyph:
          final placeholder = _layoutToken(
            _EmptyBoxPlaceholderToken(),
            smallText,
            cursorEndOwner,
            leadArrowOwner,
          );
          return ExpressionLayout(
            tokens: [placeholder],
            width: placeholder.width,
            ascent: placeholder.ascent,
            descent: placeholder.descent,
          );
      }
    }

    final layouts = <TokenLayout>[];
    double width = 0;
    double ascent = m.ascent;
    double descent = m.descent;

    for (final token in tokens) {
      final tl = _layoutToken(token, smallText, cursorEndOwner, leadArrowOwner);
      layouts.add(tl);
      width += tl.width;
      if (tl.ascent > ascent) ascent = tl.ascent;
      if (tl.descent > descent) descent = tl.descent;
    }

    return ExpressionLayout(
      tokens: layouts,
      width: width,
      ascent: ascent,
      descent: descent,
    );
  }

  TokenLayout _layoutToken(
    CalcToken token,
    bool smallText,
    BoxToken? cursorEndOwner,
    FractionToken? leadArrowOwner,
  ) {
    final m = _metricsFor(smallText);

    if (token is FractionToken) {
      final top = layout(
        token.numerator,
        smallText: smallText,
        emptyStyle: EmptyStyle.glyph,
        cursorEndOwner: cursorEndOwner,
        leadArrowOwner: leadArrowOwner,
      );
      final bottom = layout(
        token.denominator,
        smallText: smallText,
        emptyStyle: EmptyStyle.glyph,
        cursorEndOwner: cursorEndOwner,
        leadArrowOwner: leadArrowOwner,
      );

      final gap = rowHeight * kFractionBarGap * m.scale;
      final axis = rowHeight * kFractionAxis * m.scale;
      final side = m.charWidth * kFractionSidePad;
      final lead = identical(token, leadArrowOwner) ? m.charWidth : 0.0;

      final inner = math.max(top.width, bottom.width);
      final barWidth = inner + 2 * side;

      return TokenLayout(
        token: token,
        width: lead + barWidth,
        ascent: axis + gap + top.height,
        descent: bottom.height + gap - axis,
        fontSize: m.fontSize,
        child: top,
        child2: bottom,
        numeratorX: lead + side + (inner - top.width) / 2,
        denominatorX: lead + side + (inner - bottom.width) / 2,
        numeratorRise: axis + gap + top.descent,
        denominatorDrop: gap + bottom.ascent - axis,
        barRise: axis,
        barStart: lead,
        barWidth: barWidth,
        leadPad: lead,
      );
    }

    if (token is ExponentToken) {
      final child = layout(
        token.children,
        smallText: true,
        emptyStyle: EmptyStyle.glyph,
        cursorEndOwner: cursorEndOwner,
        leadArrowOwner: leadArrowOwner,
      );
      final raise = rowHeight * kSuperscriptRaise * m.scale;

      return TokenLayout(
        token: token,
        width: child.width,
        ascent: raise + child.ascent,
        descent: 0,
        fontSize: m.fontSize,
        child: child,
      );
    }

    if (token is RootToken) {
      final child = layout(
        token.children,
        smallText: smallText,
        emptyStyle: EmptyStyle.glyph,
        cursorEndOwner: cursorEndOwner,
        leadArrowOwner: leadArrowOwner,
      );
      final tickWidth = m.charWidth * kRadicalTickWidth;
      final barGap = rowHeight * kRadicalBarGap * m.scale;
      final trailingPad = m.charWidth * kRadicalTrailingPad;

      var contentWidth = child.width;
      if (identical(token, cursorEndOwner)) {
        contentWidth += m.charWidth;
      }

      return TokenLayout(
        token: token,
        width: tickWidth + contentWidth + trailingPad,
        ascent: child.ascent + barGap,
        descent: child.descent,
        fontSize: m.fontSize,
        child: child,
      );
    }

    return TokenLayout(
      token: token,
      width: m.charWidth * token.displayText.length,
      ascent: m.ascent,
      descent: m.descent,
      fontSize: m.fontSize,
    );
  }
}

class _EmptyBoxPlaceholderToken extends CalcToken {
  @override
  String get displayText => kEmptyBoxGlyph;
}

class _Metrics {
  final double fontSize;
  final double ascent;
  final double descent;
  final double charWidth;
  final double scale;

  _Metrics({
    required this.fontSize,
    required this.ascent,
    required this.descent,
    required this.charWidth,
    required this.scale,
  });
}
