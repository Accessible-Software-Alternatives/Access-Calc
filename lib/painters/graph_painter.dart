import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:graphing_calculator/models/graph_function.dart';
import 'package:graphing_calculator/models/graph_window.dart';

class GraphPainter {
  static const double _maxPixel = 1e4;

  static const double _shadeAlpha = 0.35;

  static const int _sampleCount = 512;

  static final Map<int, _Samples> _cache = {};

  static void paint({
    required Canvas canvas,
    required Size size,
    required GraphWindow window,
    required List<GraphFunction> functions,
    required Map<String, double> variables,
    required int generation,
    double reveal = 1,
  }) {
    if (!window.isValid || size.isEmpty) return;

    canvas.save();
    canvas.clipRect(Offset.zero & size);

    final map = _Mapping(window, size);

    _paintAxes(canvas, size, window, map);

    final defined = functions.where((f) => f.isDefined).toList();
    for (int i = 0; i < defined.length; i++) {
      final progress = (reveal * defined.length - i).clamp(0.0, 1.0);
      if (progress <= 0) break;

      canvas.save();
      if (progress < 1) {
        canvas.clipRect(
          Rect.fromLTWH(
            0,
            0,
            size.width * Curves.easeOut.transform(progress),
            size.height,
          ),
        );
      }
      _paintFunction(
        canvas,
        size,
        window,
        map,
        defined[i],
        variables,
        generation,
      );
      canvas.restore();
    }

    canvas.restore();
  }

  static void _paintAxes(
    Canvas canvas,
    Size size,
    GraphWindow w,
    _Mapping map,
  ) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1;

    final showYAxis = w.xMin <= 0 && 0 <= w.xMax;
    final showXAxis = w.yMin <= 0 && 0 <= w.yMax;

    final axisX = map.sx(0).roundToDouble() + 0.5;
    final axisY = map.sy(0).roundToDouble() + 0.5;

    if (showYAxis) {
      canvas.drawLine(Offset(axisX, 0), Offset(axisX, size.height), paint);
    }
    if (showXAxis) {
      canvas.drawLine(Offset(0, axisY), Offset(size.width, axisY), paint);
    }

    const tick = 3.0;
    const minTickSpacing = 4.0;

    if (showXAxis && w.xScl > 0) {
      final count = (w.xMax - w.xMin) / w.xScl;
      if (count * minTickSpacing <= size.width) {
        final first = (w.xMin / w.xScl).ceil();
        final last = (w.xMax / w.xScl).floor();
        for (int k = first; k <= last; k++) {
          if (k == 0) continue;
          final x = map.sx(k * w.xScl).roundToDouble() + 0.5;
          canvas.drawLine(
            Offset(x, axisY - tick),
            Offset(x, axisY + tick),
            paint,
          );
        }
      }
    }

    if (showYAxis && w.yScl > 0) {
      final count = (w.yMax - w.yMin) / w.yScl;
      if (count * minTickSpacing <= size.height) {
        final first = (w.yMin / w.yScl).ceil();
        final last = (w.yMax / w.yScl).floor();
        for (int k = first; k <= last; k++) {
          if (k == 0) continue;
          final y = map.sy(k * w.yScl).roundToDouble() + 0.5;
          canvas.drawLine(
            Offset(axisX - tick, y),
            Offset(axisX + tick, y),
            paint,
          );
        }
      }
    }
  }

  static void _paintFunction(
    Canvas canvas,
    Size size,
    GraphWindow w,
    _Mapping map,
    GraphFunction fn,
    Map<String, double> variables,
    int generation,
  ) {
    final color = fn.color.color;

    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    final fill = Paint()
      ..color = color.withValues(alpha: _shadeAlpha)
      ..style = PaintingStyle.fill;

    const samples = _sampleCount;
    final step = (w.xMax - w.xMin) / samples;
    final ys = _samplesFor(fn, w, samples, step, variables, generation);

    final run = <Offset>[];
    double? previous;

    void flush() {
      _paintRun(canvas, size, fn, run, stroke, fill);
      run.clear();
    }

    for (int i = 0; i <= samples; i++) {
      final x = w.xMin + i * step;
      final y = ys[i];

      if (y.isNaN) {
        flush();
        previous = null;
        continue;
      }

      if (previous != null && _isJump(previous, y, w)) flush();

      final py = math.max(-_maxPixel, math.min(_maxPixel, map.sy(y)));
      run.add(Offset(map.sx(x), py));
      previous = y;
    }

    flush();
  }

  static List<double> _samplesFor(
    GraphFunction fn,
    GraphWindow w,
    int samples,
    double step,
    Map<String, double> variables,
    int generation,
  ) {
    final key = '$generation';

    final cached = _cache[fn.index];
    if (cached != null && cached.key == key) return cached.ys;

    final vars = Map<String, double>.of(variables);
    final ys = <double>[
      for (int i = 0; i <= samples; i++) fn.valueAt(w.xMin + i * step, vars),
    ];

    _cache[fn.index] = _Samples(key, ys);
    return ys;
  }

  static bool _isJump(double previous, double current, GraphWindow w) {
    if ((previous < 0) == (current < 0)) return false;
    return (current - previous).abs() > 2 * (w.yMax - w.yMin);
  }

  static void _paintRun(
    Canvas canvas,
    Size size,
    GraphFunction fn,
    List<Offset> run,
    Paint stroke,
    Paint fill,
  ) {
    if (run.isEmpty) return;

    if (run.length == 1) {
      canvas.drawCircle(run.first, 1, Paint()..color = stroke.color);
      return;
    }

    final path = Path()..moveTo(run.first.dx, run.first.dy);
    for (int i = 1; i < run.length; i++) {
      path.lineTo(run[i].dx, run[i].dy);
    }

    if (fn.lineStyle != GraphLineStyle.normal) {
      final edge = fn.lineStyle == GraphLineStyle.shadeBelow
          ? size.height
          : 0.0;
      final area = Path.from(path)
        ..lineTo(run.last.dx, edge)
        ..lineTo(run.first.dx, edge)
        ..close();
      canvas.drawPath(area, fill);
    }

    canvas.drawPath(path, stroke);
  }
}

class _Samples {
  final String key;
  final List<double> ys;

  _Samples(this.key, this.ys);
}

class _Mapping {
  final GraphWindow window;
  final Size size;

  _Mapping(this.window, this.size);

  double sx(double x) =>
      (x - window.xMin) / (window.xMax - window.xMin) * size.width;

  double sy(double y) =>
      size.height -
      (y - window.yMin) / (window.yMax - window.yMin) * size.height;
}
