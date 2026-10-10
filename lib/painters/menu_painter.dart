import 'package:flutter/material.dart';
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
