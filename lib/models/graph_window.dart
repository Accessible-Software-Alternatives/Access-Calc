enum WindowField {
  xMin('Xmin'),
  xMax('Xmax'),
  xScl('Xscl'),
  yMin('Ymin'),
  yMax('Ymax'),
  yScl('Yscl');

  const WindowField(this.label);

  final String label;

  bool get isScale => this == xScl || this == yScl;
}

class GraphWindow {
  double xMin = -10;
  double xMax = 10;
  double xScl = 1;
  double yMin = -10;
  double yMax = 10;
  double yScl = 1;

  bool get isValid => xMin < xMax && yMin < yMax;

  double operator [](WindowField field) {
    switch (field) {
      case WindowField.xMin:
        return xMin;
      case WindowField.xMax:
        return xMax;
      case WindowField.xScl:
        return xScl;
      case WindowField.yMin:
        return yMin;
      case WindowField.yMax:
        return yMax;
      case WindowField.yScl:
        return yScl;
    }
  }

  void operator []=(WindowField field, double value) {
    switch (field) {
      case WindowField.xMin:
        xMin = value;
        break;
      case WindowField.xMax:
        xMax = value;
        break;
      case WindowField.xScl:
        xScl = value;
        break;
      case WindowField.yMin:
        yMin = value;
        break;
      case WindowField.yMax:
        yMax = value;
        break;
      case WindowField.yScl:
        yScl = value;
        break;
    }
  }

  void reset() {
    xMin = -10;
    xMax = 10;
    xScl = 1;
    yMin = -10;
    yMax = 10;
    yScl = 1;
  }
}

String formatWindowValue(double value) {
  if (value == 0) return '0';
  if (value == value.roundToDouble() && value.abs() < 1e12) {
    return value.toStringAsFixed(0);
  }

  final parts = value.toStringAsPrecision(10).split('e');
  var mantissa = parts[0];
  if (mantissa.contains('.')) {
    mantissa = mantissa.replaceAll(RegExp(r'0+$'), '');
    mantissa = mantissa.replaceAll(RegExp(r'\.$'), '');
  }
  return parts.length > 1 ? '${mantissa}e${parts[1]}' : mantissa;
}
