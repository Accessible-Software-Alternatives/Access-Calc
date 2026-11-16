import 'package:graphing_calculator/models/calc_dialog.dart';
import 'package:graphing_calculator/models/calc_menu.dart';
import 'package:graphing_calculator/models/calc_token.dart';
import 'package:graphing_calculator/models/calculator_buffer.dart';
import 'package:graphing_calculator/models/graph_function.dart';

class CalcMenus {
  static CalcDialog graphStyle(CalculatorBuffer buffer, int functionIndex) {
    final fn = buffer.functions[functionIndex];

    final color = DialogField(
      'Color:',
      [for (final c in GraphColor.values) c.label],
      selected: fn.color.index,
      optionColors: [for (final c in GraphColor.values) c.color],
    );

    final line = DialogField('Line:', [
      for (final s in GraphLineStyle.values) s.glyph,
    ], selected: fn.lineStyle.index);

    return CalcDialog(
      fields: [color, line],
      buttons: const ['OK', 'CLEAR'],
      onButton: (dialog, button) {
        if (button == 0) {
          fn.color = GraphColor.values[color.selected];
          fn.lineStyle = GraphLineStyle.values[line.selected];
          buffer.popMenu();
        } else {
          color.selected = GraphColor.defaultFor(functionIndex).index;
          line.selected = GraphLineStyle.normal.index;
        }
      },
      onCancel: (_) => buffer.popMenu(),
    );
  }

  static CalcMenu math(CalculatorBuffer buffer) {
    return CalcMenu(
      pages: const [
        MenuPage('MATH', [
          MenuItem('▶Frac', enabled: false),
          MenuItem('▶Dec', enabled: false),
          MenuItem('³', enabled: false),
          MenuItem('³√(', enabled: false),
          MenuItem('ˣ√', enabled: false),
          MenuItem('fMin(', enabled: false),
          MenuItem('fMax(', enabled: false),
          MenuItem('nDeriv(', enabled: false),
          MenuItem('fnInt(', enabled: false),
          MenuItem('summation Σ(', enabled: false),
          MenuItem('logBASE(', enabled: false),
        ]),
        MenuPage('NUM', [
          MenuItem('abs('),
          MenuItem('round('),
          MenuItem('iPart('),
          MenuItem('fPart('),
          MenuItem('int('),
          MenuItem('min('),
          MenuItem('max('),
          MenuItem('lcm('),
          MenuItem('gcd('),
        ]),
        MenuPage('CMPLX', [
          MenuItem('conj(', enabled: false),
          MenuItem('real(', enabled: false),
          MenuItem('imag(', enabled: false),
          MenuItem('angle(', enabled: false),
          MenuItem('abs(', enabled: false),
        ]),
        MenuPage('PROB', [
          MenuItem('rand', enabled: false),
          MenuItem('nPr', enabled: false),
          MenuItem('nCr', enabled: false),
          MenuItem('!', enabled: false),
          MenuItem('randInt(', enabled: false),
        ]),
      ],
      onSelect: (menu, pageIndex, itemIndex) {
        final type = _mathFunctions['$pageIndex:$itemIndex'];
        buffer.popMenu();
        if (type != null) buffer.insertToken(FunctionToken(type));
      },
      onCancel: (_) => buffer.popMenu(),
    );
  }

  // Maybe change
  static const Map<String, FunctionType> _mathFunctions = {
    '1:0': FunctionType.abs,
    '1:1': FunctionType.round,
    '1:2': FunctionType.iPart,
    '1:3': FunctionType.fPart,
    '1:4': FunctionType.intFloor,
    '1:5': FunctionType.min,
    '1:6': FunctionType.max,
    '1:7': FunctionType.lcm,
    '1:8': FunctionType.gcd,
  };
}
