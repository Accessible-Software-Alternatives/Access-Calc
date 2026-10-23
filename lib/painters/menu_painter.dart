import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:graphing_calculator/models/calc_dialog.dart';
import 'package:graphing_calculator/models/calc_menu.dart';
import 'package:graphing_calculator/widgets/text_grid.dart';

class MenuPainter {
  static const Color highlightTextColor = Color(0xFFD8E0C8);

  static void paint({
    required Canvas canvas,
    required Size size,
    required CalcMenu menu,
    required TextStyle textStyle,
    required int columns,
    required int visibleRows,
  }) {
    final inverted = textStyle.copyWith(color: highlightTextColor);

    final tabsAtTop = menu.hasTabs && menu.tabPosition == MenuTabPosition.top;
    final tabsAtBottom =
        menu.hasTabs && menu.tabPosition == MenuTabPosition.bottom;

    var row = 0;

    if (tabsAtTop) {
      _paintTabs(
        canvas: canvas,
        size: size,
        menu: menu,
        row: row,
        textStyle: textStyle,
        inverted: inverted,
        columns: columns,
        visibleRows: visibleRows,
      );
      row++;
    }

    if (menu.heading != null) {
      TextGrid.drawHighlight(
        canvas: canvas,
        size: size,
        row: row,
        startCol: 0,
        width: columns,
        columns: columns,
        visibleRows: visibleRows,
      );
      TextGrid.drawRow(
        canvas: canvas,
        size: size,
        row: row,
        text: menu.heading!,
        style: inverted,
        columns: columns,
        visibleRows: visibleRows,
      );
      row++;
    }

    final reservedBelow =
        (tabsAtBottom ? 1 : 0) + (menu.body.isEmpty ? 0 : menu.body.length + 1);

    menu.viewportRows = (visibleRows - row - reservedBelow).clamp(1, 99);
    menu.clampScroll();

    final firstIndex = menu.firstVisibleIndex;
    final visible = menu.visibleItems;

    for (int i = 0; i < visible.length; i++) {
      final index = firstIndex + i;
      final isFirstRow = i == 0;
      final isLastRow = i == visible.length - 1;

      var separator = ':';
      if (isFirstRow && menu.hasItemsAbove) {
        separator = '↑';
      } else if (isLastRow && menu.hasItemsBelow) {
        separator = '↓';
      }

      _paintItem(
        canvas: canvas,
        size: size,
        menu: menu,
        item: menu.items[index],
        index: index,
        separator: separator,
        row: row + i,
        textStyle: textStyle,
        inverted: inverted,
        columns: columns,
        visibleRows: visibleRows,
      );
    }

    if (menu.body.isNotEmpty) {
      var bodyRow = row + visible.length + 1;
      for (final line in menu.body) {
        if (bodyRow >= visibleRows) break;
        TextGrid.drawRow(
          canvas: canvas,
          size: size,
          row: bodyRow,
          text: line,
          style: textStyle,
          columns: columns,
          visibleRows: visibleRows,
        );
        bodyRow++;
      }
    }

    if (tabsAtBottom) {
      _paintTabs(
        canvas: canvas,
        size: size,
        menu: menu,
        row: visibleRows - 1,
        textStyle: textStyle,
        inverted: inverted,
        columns: columns,
        visibleRows: visibleRows,
      );
    }
  }

  static void paintDialog({
    required Canvas canvas,
    required Size size,
    required CalcDialog dialog,
    required TextStyle textStyle,
    required int columns,
    required int visibleRows,
    Color background = Colors.white,
  }) {
    final cellW = size.width / columns;
    final cellH = size.height / visibleRows;
    final inverted = textStyle.copyWith(color: highlightTextColor);

    const padCells = 1.0;
    const valuePad = 2.0;
    const arrowGap = 0.25;
    const arrowCells = 2.0;
    const fieldRows = 1.5;
    const boxRows = 1.2;
    const vPad = 0.4;
    const ruleRows = 0.2;

    final labelCols = dialog.fields.fold<int>(
      0,
      (widest, f) => f.label.length > widest ? f.label.length : widest,
    );
    final widestValue = dialog.fields.fold<int>(
      0,
      (widest, f) => f.valueWidth > widest ? f.valueWidth : widest,
    );

    final fieldsWidth =
        padCells +
        labelCols +
        1 +
        (widestValue + valuePad) +
        arrowGap +
        arrowCells +
        padCells;

    final buttonsWidth =
        padCells * 2 +
        dialog.buttons.fold<double>(0, (sum, b) => sum + b.length + valuePad) +
        (dialog.buttons.length > 1 ? dialog.buttons.length - 1 : 0);

    final contentCols = math.max(fieldsWidth, buttonsWidth).ceilToDouble();
    final boxCols = math.min(contentCols + 2, columns.toDouble());
    final boxWidth = boxCols * cellW;

    final hasButtons = dialog.buttons.isNotEmpty;
    final boxRowsTotal =
        vPad +
        dialog.fields.length * fieldRows +
        (hasButtons ? ruleRows + fieldRows : 0) +
        vPad;
    final boxHeight = boxRowsTotal * cellH;

    final left = (size.width - boxWidth) / 2;
    final top = math.max(0.0, (size.height - boxHeight) / 2);
    final box = Rect.fromLTWH(left, top, boxWidth, boxHeight);

    final fill = Paint()..color = background;
    final black = Paint()..color = Colors.black;
    final line = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawRect(box, fill);
    canvas.drawRect(
      box.deflate(1),
      Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    void centeredText(String text, TextStyle style, Rect rect) {
      final tp = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(
          rect.left + (rect.width - tp.width) / 2,
          rect.top + (rect.height - tp.height) / 2,
        ),
      );
    }

    var y = top + vPad * cellH;

    for (int i = 0; i < dialog.fields.length; i++) {
      final field = dialog.fields[i];
      final focused = !dialog.isOnButtons && dialog.focus == i;
      final rowRect = Rect.fromLTWH(left, y, boxWidth, fieldRows * cellH);

      final labelTp = TextPainter(
        text: TextSpan(text: field.label, style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      labelTp.paint(
        canvas,
        Offset(
          left + (1 + padCells) * cellW,
          rowRect.center.dy - labelTp.height / 2,
        ),
      );

      final valueLeft = left + (1 + padCells + labelCols + 1) * cellW;
      final valueRect = Rect.fromLTWH(
        valueLeft,
        rowRect.center.dy - boxRows * cellH / 2,
        (field.valueWidth + valuePad) * cellW,
        boxRows * cellH,
      );

      final swatch = field.backgroundColor;
      if (swatch != null) {
        canvas.drawRect(valueRect, Paint()..color = swatch);
      }
      canvas.drawRect(valueRect, line);
      centeredText(
        field.text,
        swatch != null && swatch.computeLuminance() < 0.4
            ? inverted
            : textStyle,
        valueRect,
      );

      if (focused) {
        final arrowRect = Rect.fromLTWH(
          valueRect.right + arrowGap * cellW,
          valueRect.top,
          arrowCells * cellW,
          valueRect.height,
        );
        canvas.drawRect(arrowRect, line);
        _paintChoiceArrows(canvas, arrowRect, black);
      }

      y += fieldRows * cellH;
    }

    if (hasButtons) {
      final ruleY = y + ruleRows * cellH / 2;
      canvas.drawLine(
        Offset(left + 1, ruleY),
        Offset(left + boxWidth - 1, ruleY),
        line,
      );
      y += ruleRows * cellH;

      final rowRect = Rect.fromLTWH(left, y, boxWidth, fieldRows * cellH);
      final widths = [
        for (final b in dialog.buttons) (b.length + valuePad) * cellW,
      ];
      final gap = cellW;
      final total =
          widths.fold<double>(0, (a, b) => a + b) +
          gap * (dialog.buttons.length - 1);

      var x = left + (boxWidth - total) / 2;
      for (int i = 0; i < dialog.buttons.length; i++) {
        final focused = dialog.isOnButtons && dialog.buttonIndex == i;
        final rect = Rect.fromLTWH(
          x,
          rowRect.center.dy - boxRows * cellH / 2,
          widths[i],
          boxRows * cellH,
        );
        if (focused) {
          canvas.drawRect(rect, black);
          centeredText(dialog.buttons[i], inverted, rect);
        } else {
          canvas.drawRect(rect, line);
          centeredText(dialog.buttons[i], textStyle, rect);
        }
        x += widths[i] + gap;
      }
    }
  }

  static void _paintChoiceArrows(Canvas canvas, Rect rect, Paint paint) {
    final h = rect.height * 0.5;
    final w = rect.width * 0.28;
    final cy = rect.center.dy;
    final gap = rect.width * 0.06;

    final leftTip = rect.center.dx - gap - w;
    final rightTip = rect.center.dx + gap + w;

    final leftArrow = Path()
      ..moveTo(leftTip, cy)
      ..lineTo(rect.center.dx - gap, cy - h / 2)
      ..lineTo(rect.center.dx - gap, cy + h / 2)
      ..close();

    final rightArrow = Path()
      ..moveTo(rightTip, cy)
      ..lineTo(rect.center.dx + gap, cy - h / 2)
      ..lineTo(rect.center.dx + gap, cy + h / 2)
      ..close();

    canvas.drawPath(leftArrow, paint);
    canvas.drawPath(rightArrow, paint);
  }

  static void _paintItem({
    required Canvas canvas,
    required Size size,
    required CalcMenu menu,
    required MenuItem item,
    required int index,
    required String separator,
    required int row,
    required TextStyle textStyle,
    required TextStyle inverted,
    required int columns,
    required int visibleRows,
  }) {
    final selector = CalcMenu.selectorFor(index);
    final isSelected = index == menu.itemIndex;

    if (isSelected) {
      TextGrid.drawHighlight(
        canvas: canvas,
        size: size,
        row: row,
        startCol: 0,
        width: selector.length,
        columns: columns,
        visibleRows: visibleRows,
      );
    }

    TextGrid.drawRow(
      canvas: canvas,
      size: size,
      row: row,
      text: selector,
      style: isSelected ? inverted : textStyle,
      columns: columns,
      visibleRows: visibleRows,
    );

    TextGrid.drawRow(
      canvas: canvas,
      size: size,
      row: row,
      text: '$separator${item.label}',
      style: textStyle,
      columns: columns,
      visibleRows: visibleRows,
      startCol: selector.length,
    );

    final trailing = item.trailing;
    if (trailing != null && trailing.length < columns) {
      TextGrid.drawRow(
        canvas: canvas,
        size: size,
        row: row,
        text: trailing,
        style: textStyle,
        columns: columns,
        visibleRows: visibleRows,
        startCol: columns - trailing.length,
      );
    }
  }

  static void _paintTabs({
    required Canvas canvas,
    required Size size,
    required CalcMenu menu,
    required int row,
    required TextStyle textStyle,
    required TextStyle inverted,
    required int columns,
    required int visibleRows,
  }) {
    var col = 0;

    for (int i = 0; i < menu.pages.length; i++) {
      final title = menu.pages[i].title;
      if (col + title.length > columns) break;

      final isSelected = i == menu.pageIndex;

      if (isSelected) {
        TextGrid.drawHighlight(
          canvas: canvas,
          size: size,
          row: row,
          startCol: col,
          width: title.length,
          columns: columns,
          visibleRows: visibleRows,
        );
      }

      TextGrid.drawRow(
        canvas: canvas,
        size: size,
        row: row,
        text: title,
        style: isSelected ? inverted : textStyle,
        columns: columns,
        visibleRows: visibleRows,
        startCol: col,
      );

      col += title.length + 1;
    }
  }
}
