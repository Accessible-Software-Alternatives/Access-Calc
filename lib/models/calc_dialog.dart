import 'package:flutter/painting.dart';
import 'package:graphing_calculator/models/calc_menu.dart';

class DialogField {
  final String label;

  final List<String> options;

  final List<Color>? optionColors;

  int selected;

  DialogField(this.label, this.options, {this.selected = 0, this.optionColors})
    : assert(options.isNotEmpty),
      assert(optionColors == null || optionColors.length == options.length);

  String get text => options[selected];

  Color? get backgroundColor => optionColors?[selected];

  int get valueWidth =>
      options.fold(0, (widest, o) => o.length > widest ? o.length : widest);

  void step(int delta) {
    selected = (selected + delta) % options.length;
    if (selected < 0) selected += options.length;
  }
}

class CalcDialog extends CalcMenuBase {
  final List<DialogField> fields;
  final List<String> buttons;

  final void Function(CalcDialog dialog, int buttonIndex) onButton;

  final void Function(CalcDialog dialog)? onCancel;

  int focus = 0;
  int buttonIndex = 0;

  CalcDialog({
    required this.fields,
    required this.buttons,
    required this.onButton,
    this.onCancel,
  }) : assert(fields.isNotEmpty || buttons.isNotEmpty);

  int get _focusCount => fields.length + (buttons.isEmpty ? 0 : 1);

  bool get isOnButtons => buttons.isNotEmpty && focus == fields.length;

  DialogField? get focusedField => isOnButtons ? null : fields[focus];

  @override
  bool handleKey(MenuKey key, {String? selector}) {
    switch (key) {
      case MenuKey.up:
        focus = (focus - 1 + _focusCount) % _focusCount;
        return true;
      case MenuKey.down:
        focus = (focus + 1) % _focusCount;
        return true;
      case MenuKey.left:
        _horizontal(-1);
        return true;
      case MenuKey.right:
        _horizontal(1);
        return true;
      case MenuKey.enter:
        if (isOnButtons) {
          onButton(this, buttonIndex);
        } else {
          focus = (focus + 1) % _focusCount;
        }
        return true;
      case MenuKey.cancel:
        onCancel?.call(this);
        return true;
      case MenuKey.selector:
        return false;
    }
  }

  void _horizontal(int delta) {
    if (isOnButtons) {
      buttonIndex = (buttonIndex + delta + buttons.length) % buttons.length;
    } else {
      fields[focus].step(delta);
    }
  }
}
