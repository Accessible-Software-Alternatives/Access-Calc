import 'package:flutter/material.dart';
import 'package:graphing_calculator/models/button_mode.dart';
import 'package:graphing_calculator/models/calc_token.dart';
import 'package:graphing_calculator/models/calculator_buffer.dart';
import 'package:graphing_calculator/models/expression_layout.dart';
import 'package:graphing_calculator/painters/menu_painter.dart';

class CalculatorPainter extends CustomPainter {
  final CalculatorBuffer buffer;

  CalculatorPainter({required this.buffer});

  static const int columns = CalculatorBuffer.displayColumns;

  static const double _rowsOnScreen = 7;

  static const Color _highlightTextColor = Color(0xFFD8E0C8);

  @override
  void paint(Canvas canvas, Size size) {
    final menuRowHeight = size.height / CalculatorBuffer.visibleLineCount;

    final menuTextStyle = TextStyle(
      fontFamily: 'Courier',
      fontSize: menuRowHeight * 0.75,
      color: Colors.black,
      fontWeight: FontWeight.w600,
      height: 1,
    );

    final menu = buffer.activeMenu;
    if (menu != null) {
      MenuPainter.paint(
        canvas: canvas,
        size: size,
        menu: menu,
        textStyle: menuTextStyle,
        columns: columns,
        visibleRows: CalculatorBuffer.visibleLineCount,
      );
      return;
    }

    final rowHeight = size.height / _rowsOnScreen;

    final textStyle = TextStyle(
      fontFamily: 'Courier',
      fontSize: rowHeight * 0.72,
      color: Colors.black,
      fontWeight: FontWeight.w600,
      height: 1,
    );

    final engine = ExpressionLayoutEngine(
      style: textStyle,
      rowHeight: rowHeight,
    );

    final cursorEndOwner =
        (buffer.isOnEditableLine &&
            buffer.isAtEndOfCurrentBox &&
            buffer.currentBoxOwner is RootToken)
        ? buffer.currentBoxOwner
        : null;

    final leadArrowOwner = buffer.isOnEditableLine
        ? buffer.fractionBeforeCursor
        : null;

    final candidates = buffer.visibleLines;
    final candidateLayouts = <ExpressionLayout>[
      for (int i = 0; i < candidates.length; i++)
        engine.layout(
          candidates[i].tokens,
          cursorEndOwner: (buffer.scrollOffset + i == buffer.cursorRow)
              ? cursorEndOwner
              : null,
          leadArrowOwner: (buffer.scrollOffset + i == buffer.cursorRow)
              ? leadArrowOwner
              : null,
        ),
    ];

    int cursorIdx = candidates.length - 1;
    for (int i = 0; i < candidates.length; i++) {
      if (buffer.scrollOffset + i == buffer.cursorRow) {
        cursorIdx = i;
        break;
      }
    }

    final rows = <_Row>[];

    if (candidates.isNotEmpty) {
      int startIdx = cursorIdx;
      int endIdx = cursorIdx;
      double usedHeight = candidateLayouts[cursorIdx].height;

      while (endIdx + 1 < candidates.length) {
        final h = candidateLayouts[endIdx + 1].height;
        if (usedHeight + h > size.height) break;
        endIdx++;
        usedHeight += h;
      }
      while (startIdx - 1 >= 0) {
        final h = candidateLayouts[startIdx - 1].height;
        if (usedHeight + h > size.height) break;
        startIdx--;
        usedHeight += h;
      }

      for (int i = startIdx; i <= endIdx; i++) {
        rows.add(
          _Row(
            line: candidates[i],
            layout: candidateLayouts[i],
            absoluteIndex: buffer.scrollOffset + i,
          ),
        );
      }
    }

    double scrollY = 0;
    if (rows.length == 1 &&
        buffer.isOnEditableLine &&
        rows.first.absoluteIndex == buffer.cursorRow &&
        rows.first.layout.height > size.height) {
      final located = _locateCursorIn(engine, rows.first, 0);
      if (located != null) {
        final leaf = engine.leafMetricsFor(located.smallText);
        final cursorTop = located.baselineY - leaf.ascent;
        final cursorBottom = located.baselineY + leaf.descent;
        if (cursorBottom > size.height) scrollY = cursorBottom - size.height;
        if (cursorTop - scrollY < 0) scrollY = cursorTop;
        scrollY = scrollY.clamp(0.0, rows.first.layout.height - size.height);
      }
    }

    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(0, -scrollY);

    double y = 0;
    _Row? editableRow;
    double editableTop = 0;

    for (final row in rows) {
      final isSelected =
          !buffer.isOnEditableLine && row.absoluteIndex == buffer.cursorRow;
      final isEditable =
          buffer.isOnEditableLine && row.absoluteIndex == buffer.cursorRow;

      _paintLine(
        canvas: canvas,
        size: size,
        engine: engine,
        row: row,
        top: y,
        textStyle: textStyle,
        isSelected: isSelected,
      );

      if (isEditable) {
        editableRow = row;
        editableTop = y;
      }

      y += row.layout.height;
    }

    if (buffer.cursorVisible && editableRow != null) {
      _paintCursor(
        canvas: canvas,
        engine: engine,
        row: editableRow,
        top: editableTop,
      );
    }

    canvas.restore();
  }

  void _paintLine({
    required Canvas canvas,
    required Size size,
    required ExpressionLayoutEngine engine,
    required _Row row,
    required double top,
    required TextStyle textStyle,
    required bool isSelected,
  }) {
    final availableWidth = size.width;
    final layout = row.layout;

    double contentX = 0;
    double dotLeaderWidth = 0;

    if (row.line.isResult) {
      final leftover = availableWidth - layout.width;
      if (leftover > 0) {
        dotLeaderWidth = leftover;
        contentX = leftover;
      } else {
        contentX = availableWidth - layout.width;
      }
    } else if (layout.width > availableWidth) {
      contentX = availableWidth - layout.width;
    }

    if (isSelected) {
      final left = contentX.clamp(0.0, availableWidth);
      final right = (contentX + layout.width).clamp(0.0, availableWidth);
      canvas.drawRect(
        Rect.fromLTWH(left, top, right - left, layout.height),
        Paint()..color = Colors.black,
      );
    }

    final style = isSelected
        ? textStyle.copyWith(color: _highlightTextColor)
        : textStyle;

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, top, availableWidth, layout.height));

    if (dotLeaderWidth > 0) {
      _paintDotLeader(
        canvas: canvas,
        style: textStyle,
        width: dotLeaderWidth,
        charWidth: engine.charWidth,
        baselineY: top + layout.ascent,
      );
    }

    _paintExpression(
      canvas: canvas,
      engine: engine,
      expr: layout,
      origin: Offset(contentX, top),
      style: style,
    );

    canvas.restore();
  }

  void _paintDotLeader({
    required Canvas canvas,
    required TextStyle style,
    required double width,
    required double charWidth,
    required double baselineY,
  }) {
    final dotPainter = TextPainter(
      text: TextSpan(text: '.', style: style),
      textDirection: TextDirection.ltr,
    )..layout();

    final dotCount = (width / charWidth).floor();
    final dotY = baselineY - dotPainter.height * 0.7;

    for (int i = 0; i < dotCount; i++) {
      dotPainter.paint(canvas, Offset(i * charWidth + 1, dotY));
    }
  }

  void _paintExpression({
    required Canvas canvas,
    required ExpressionLayoutEngine engine,
    required ExpressionLayout expr,
    required Offset origin,
    required TextStyle style,
  }) {
    double x = origin.dx;
    final baselineY = origin.dy + expr.ascent;

    for (final tl in expr.tokens) {
      _paintToken(
        canvas: canvas,
        engine: engine,
        tl: tl,
        x: x,
        baselineY: baselineY,
        style: style,
      );
      x += tl.width;
    }
  }

  void _paintToken({
    required Canvas canvas,
    required ExpressionLayoutEngine engine,
    required TokenLayout tl,
    required double x,
    required double baselineY,
    required TextStyle style,
  }) {
    final token = tl.token;
    final rowHeight = engine.rowHeight;
    final scale = tl.scaleRelativeTo(engine.baseFontSize);

    if (token is FractionToken) {
      final barY = baselineY - tl.barRise;

      _paintExpression(
        canvas: canvas,
        engine: engine,
        expr: tl.child!,
        origin: Offset(
          x + tl.numeratorX,
          baselineY - tl.numeratorRise - tl.child!.ascent,
        ),
        style: style,
      );
      _paintExpression(
        canvas: canvas,
        engine: engine,
        expr: tl.child2!,
        origin: Offset(
          x + tl.denominatorX,
          baselineY + tl.denominatorDrop - tl.child2!.ascent,
        ),
        style: style,
      );

      canvas.drawLine(
        Offset(x + tl.barStart, barY),
        Offset(x + tl.barStart + tl.barWidth, barY),
        Paint()
          ..color = style.color ?? Colors.black
          ..style = PaintingStyle.stroke
          ..strokeWidth = (2 * scale).clamp(1.0, 2.0)
          ..strokeCap = StrokeCap.butt,
      );
      return;
    }

    if (token is ExponentToken) {
      final raise = rowHeight * kSuperscriptRaise * scale;
      final childBaseline = baselineY - raise;

      _paintExpression(
        canvas: canvas,
        engine: engine,
        expr: tl.child!,
        origin: Offset(x, childBaseline - tl.child!.ascent),
        style: style,
      );
      return;
    }

    if (token is RootToken) {
      final charWidth = engine.charWidth * scale;
      final tickWidth = charWidth * kRadicalTickWidth;
      final trailingPad = charWidth * kRadicalTrailingPad;
      final barGap = rowHeight * kRadicalBarGap * scale;
      final barY = baselineY - tl.child!.ascent - barGap * 0.35;

      final barWidth = tl.width - tickWidth - trailingPad;

      final tickPaint = Paint()
        ..color = style.color ?? Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = (2 * scale).clamp(1.0, 2.0)
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round;

      final tick = Path()
        ..moveTo(x, baselineY - tl.descent - rowHeight * 0.1 * scale)
        ..lineTo(x + tickWidth * 0.35, baselineY + tl.descent)
        ..lineTo(x + tickWidth, barY);

      canvas.drawPath(tick, tickPaint);

      canvas.drawLine(
        Offset(x + tickWidth, barY),
        Offset(x + tickWidth + barWidth, barY),
        tickPaint,
      );

      _paintExpression(
        canvas: canvas,
        engine: engine,
        expr: tl.child!,
        origin: Offset(x + tickWidth, baselineY - tl.child!.ascent),
        style: style,
      );
      return;
    }

    final painter = TextPainter(
      text: TextSpan(
        text: token.displayText,
        style: style.copyWith(fontSize: tl.fontSize),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final boxTop = baselineY - tl.ascent;
    final centeredY = boxTop + ((tl.ascent + tl.descent - painter.height) / 2);

    painter.paint(canvas, Offset(x + 1, centeredY));
  }

  void _paintCursor({
    required Canvas canvas,
    required ExpressionLayoutEngine engine,
    required _Row row,
    required double top,
  }) {
    final located = _locateCursorIn(engine, row, top);

    if (located == null) return;

    final leaf = engine.leafMetricsFor(located.smallText);

    final rect = Rect.fromLTWH(
      located.x,
      located.baselineY - leaf.ascent,
      located.width ?? leaf.charWidth,
      leaf.ascent + leaf.descent,
    );

    String? modeSymbol;
    switch (buffer.mode) {
      case ButtonMode.normal:
        modeSymbol = null;
        break;
      case ButtonMode.second:
        modeSymbol = '↑';
        break;
      case ButtonMode.alpha:
      case ButtonMode.alphaLock:
        modeSymbol = 'A';
        break;
    }

    if (modeSymbol != null) {
      canvas.drawRect(rect, Paint()..color = Colors.black);

      final glyph = TextPainter(
        text: TextSpan(
          text: modeSymbol,
          style: TextStyle(
            color: _highlightTextColor,
            fontWeight: FontWeight.bold,
            fontSize: leaf.fontSize,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      glyph.paint(
        canvas,
        Offset(
          rect.center.dx - glyph.width / 2,
          rect.center.dy - glyph.height / 2,
        ),
      );
      return;
    }

    final showLeftArrow = buffer.fractionBeforeCursor != null;
    final showExitArrow =
        buffer.currentBoxOwner is RootToken && buffer.isAtEndOfCurrentBox;

    if (showExitArrow || showLeftArrow) {
      final arrow = TextPainter(
        text: TextSpan(
          text: showLeftArrow ? '←' : '→',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: leaf.fontSize,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      arrow.paint(
        canvas,
        Offset(
          rect.left + (rect.width - arrow.width) / 2,
          rect.top + (rect.height - arrow.height) / 2,
        ),
      );
    } else if (buffer.overwriteMode) {
      canvas.drawRect(rect, Paint()..color = Colors.black);
    } else {
      canvas.drawRect(
        Rect.fromLTWH(rect.left, rect.top, 2, rect.height),
        Paint()..color = Colors.black,
      );
    }
  }

  _CursorLocation? _locateCursorIn(
    ExpressionLayoutEngine engine,
    _Row row,
    double top,
  ) {
    return _locateCursor(
      expr: row.layout,
      path: buffer.cursorPath,
      level: 0,
      originX: 0,
      baselineY: top + row.layout.ascent,
      smallText: false,
      engine: engine,
    );
  }

  _CursorLocation? _locateCursor({
    required ExpressionLayout expr,
    required List<CursorPosition> path,
    required int level,
    required double originX,
    required double baselineY,
    required bool smallText,
    required ExpressionLayoutEngine engine,
  }) {
    if (level >= path.length) return null;

    final pos = path[level];
    final leaf = engine.leafMetricsFor(smallText);

    double x = originX;
    for (int i = 0; i < pos.tokenIndex && i < expr.tokens.length; i++) {
      x += expr.tokens[i].width;
    }

    if (level == path.length - 1) {
      x += pos.offset * leaf.charWidth;

      double? width;
      if (pos.tokenIndex < expr.tokens.length) {
        final under = expr.tokens[pos.tokenIndex];
        if (under.token is! BoxToken &&
            under.token.cursorLength == 1 &&
            under.token.displayText.length > 1) {
          width = under.width;
        }
      }

      return _CursorLocation(
        x: x,
        baselineY: baselineY,
        smallText: smallText,
        width: width,
      );
    }

    if (pos.tokenIndex >= expr.tokens.length) return null;
    final tl = expr.tokens[pos.tokenIndex];
    final boxToken = tl.token;
    if (boxToken is! BoxToken || tl.child == null) return null;

    final scale = tl.scaleRelativeTo(engine.baseFontSize);

    double childOriginX = x;
    double childBaselineY;
    bool childSmallText;

    ExpressionLayout childLayout = tl.child!;

    if (boxToken is FractionToken) {
      final inDenominator = path[level + 1].part == 1;
      childLayout = inDenominator ? tl.child2! : tl.child!;
      childOriginX += inDenominator ? tl.denominatorX : tl.numeratorX;
      childBaselineY = inDenominator
          ? baselineY + tl.denominatorDrop
          : baselineY - tl.numeratorRise;
      childSmallText = smallText;
    } else if (boxToken is ExponentToken) {
      childBaselineY = baselineY - engine.rowHeight * kSuperscriptRaise * scale;
      childSmallText = true;
    } else {
      childOriginX += leaf.charWidth * kRadicalTickWidth;
      childBaselineY = baselineY;
      childSmallText = smallText;
    }

    return _locateCursor(
      expr: childLayout,
      path: path,
      level: level + 1,
      originX: childOriginX,
      baselineY: childBaselineY,
      smallText: childSmallText,
      engine: engine,
    );
  }

  @override
  bool shouldRepaint(covariant CalculatorPainter oldDelegate) {
    return true;
  }
}

class _Row {
  final CalcLine line;
  final ExpressionLayout layout;
  final int absoluteIndex;

  _Row({required this.line, required this.layout, required this.absoluteIndex});
}

class _CursorLocation {
  final double x;
  final double baselineY;
  final bool smallText;

  final double? width;

  _CursorLocation({
    required this.x,
    required this.baselineY,
    required this.smallText,
    this.width,
  });
}
