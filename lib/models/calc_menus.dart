import 'package:graphing_calculator/models/calc_menu.dart';
import 'package:graphing_calculator/models/calculator_buffer.dart';

class CalcMenus {
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
          MenuItem('abs(', enabled: false),
          MenuItem('round(', enabled: false),
          MenuItem('iPart(', enabled: false),
          MenuItem('fPart(', enabled: false),
          MenuItem('int(', enabled: false),
          MenuItem('min(', enabled: false),
          MenuItem('max(', enabled: false),
          MenuItem('lcm(', enabled: false),
          MenuItem('gcd(', enabled: false),
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
      onSelect: (menu, _, __) => buffer.popMenu(),
      onCancel: (_) => buffer.popMenu(),
    );
  }
}
