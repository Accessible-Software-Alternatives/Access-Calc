enum MenuKey { up, down, left, right, enter, cancel, selector }

List<String> wrapMenuText(String text, int width, {int hangingIndent = 2}) {
  final lines = <String>[];

  for (final paragraph in text.split('\n')) {
    final words = paragraph.split(' ').where((w) => w.isNotEmpty);
    var current = '';
    var indent = '';

    for (final word in words) {
      final candidate = current.isEmpty ? '$indent$word' : '$current $word';

      if (candidate.length > width && current.isNotEmpty) {
        lines.add(current);
        indent = ' ' * hangingIndent;
        current = '$indent$word';
      } else {
        current = candidate;
      }
    }

    if (current.isNotEmpty) lines.add(current);
  }

  return lines;
}

enum MenuTabPosition { top, bottom }

class MenuItem {
  final String label;

  final String? trailing;

  final Object? value;

  final bool enabled;

  const MenuItem(this.label, {this.trailing, this.value, this.enabled = true});
}

class MenuPage {
  final String title;
  final List<MenuItem> items;

  const MenuPage(this.title, this.items);
}

class CalcMenu {
  final String? heading;

  final List<MenuPage> pages;
  final MenuTabPosition tabPosition;

  final List<String> body;

  final void Function(CalcMenu menu, int pageIndex, int itemIndex) onSelect;

  final void Function(CalcMenu menu)? onCancel;

  int pageIndex = 0;
  int itemIndex = 0;
  int scrollOffset = 0;

  int viewportRows = 7;

  CalcMenu({
    required this.pages,
    required this.onSelect,
    this.heading,
    this.body = const [],
    this.tabPosition = MenuTabPosition.top,
    this.onCancel,
  });

  bool get hasTabs => pages.length > 1;

  MenuPage get page => pages[pageIndex];

  List<MenuItem> get items => page.items;

  bool get hasItemsAbove => scrollOffset > 0;

  bool get hasItemsBelow => scrollOffset + viewportRows < items.length;

  static String selectorFor(int index) {
    if (index < 9) return '${index + 1}';
    return String.fromCharCode('A'.codeUnitAt(0) + index - 9);
  }

  List<MenuItem> get visibleItems {
    if (items.length <= viewportRows) return items;
    return items.skip(scrollOffset).take(viewportRows).toList();
  }

  int get firstVisibleIndex => items.length <= viewportRows ? 0 : scrollOffset;

  void moveUp() {
    if (items.isEmpty) return;
    itemIndex = itemIndex == 0 ? items.length - 1 : itemIndex - 1;
    _revealSelection();
  }

  void moveDown() {
    if (items.isEmpty) return;
    itemIndex = itemIndex == items.length - 1 ? 0 : itemIndex + 1;
    _revealSelection();
  }

  void nextPage() {
    if (!hasTabs) return;
    pageIndex = (pageIndex + 1) % pages.length;
    _resetSelection();
  }

  void previousPage() {
    if (!hasTabs) return;
    pageIndex = pageIndex == 0 ? pages.length - 1 : pageIndex - 1;
    _resetSelection();
  }

  bool activateSelector(String key) {
    final upper = key.toUpperCase();

    for (int i = 0; i < items.length; i++) {
      if (selectorFor(i) == upper) {
        if (!items[i].enabled) return true;
        itemIndex = i;
        _revealSelection();
        onSelect(this, pageIndex, i);
        return true;
      }
    }

    return false;
  }

  void activateSelection() {
    if (items.isEmpty) return;
    if (!items[itemIndex].enabled) return;
    onSelect(this, pageIndex, itemIndex);
  }

  void cancel() => onCancel?.call(this);

  void _resetSelection() {
    itemIndex = 0;
    scrollOffset = 0;
  }

  void _revealSelection() {
    if (items.length <= viewportRows) {
      scrollOffset = 0;
      return;
    }

    if (itemIndex < scrollOffset) {
      scrollOffset = itemIndex;
    } else if (itemIndex >= scrollOffset + viewportRows) {
      scrollOffset = itemIndex - viewportRows + 1;
    }

    clampScroll();
  }

  void clampScroll() {
    final maxOffset = items.length - viewportRows;
    if (maxOffset <= 0) {
      scrollOffset = 0;
    } else if (scrollOffset > maxOffset) {
      scrollOffset = maxOffset;
    } else if (scrollOffset < 0) {
      scrollOffset = 0;
    }
  }
}
