import 'package:flutter/material.dart';
import 'package:graphing_calculator/models/button_mode.dart';
import 'package:graphing_calculator/models/calc_button_data.dart';
import 'package:graphing_calculator/models/calculator_theme.dart';

import 'button_type.dart';

class CalcButton extends StatefulWidget {
  final CalcButtonData data;
  final CalculatorTheme theme;
  final ButtonMode mode;
  final void Function(ButtonAction) onPressed;
  final double unit;

  const CalcButton({
    super.key,
    required this.data,
    required this.theme,
    required this.mode,
    required this.onPressed,
    required this.unit,
  });

  @override
  State<CalcButton> createState() => _CalcButtonState();
}

class _CalcButtonState extends State<CalcButton> {
  bool _pressed = false;

  bool get _isActiveModifier {
    if (widget.data.action == ButtonAction.second) {
      return widget.mode == ButtonMode.second;
    }
    if (widget.data.action == ButtonAction.alpha) {
      return widget.mode.isAlpha;
    }
    return false;
  }

  bool get _isLockedAlpha =>
      widget.data.action == ButtonAction.alpha && widget.mode.isLocked;

  bool get _hasOverrideForCurrentMode {
    if (widget.mode == ButtonMode.second) {
      return widget.data.secondFunction != null;
    }
    if (widget.mode.isAlpha) {
      return widget.data.alphaFunction != null;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final resolved = widget.data.resolve(widget.mode);
    final style = widget.theme.getStyle(resolved.type);

    // When a second/alpha override changes this button's type, blend the
    // button's original color with the override color instead of fully
    // switching to it, so the keypad doesn't turn into a wall of identical
    // second/alpha-colored buttons.
    const overrideBlendAmount = 0.5;
    final Color resolvedBackgroundColor = resolved.type != widget.data.type
        ? Color.lerp(
            widget.theme.getStyle(widget.data.type).backgroundColor,
            style.backgroundColor,
            overrideBlendAmount,
          )!
        : style.backgroundColor;

    final active = _isActiveModifier;

    final Color baseColor = active
        ? Color.alphaBlend(
            Colors.white.withValues(alpha: 0.22),
            resolvedBackgroundColor,
          )
        : resolvedBackgroundColor;

    final legendFontSize = widget.unit * 2.5;

    return Padding(
      padding: EdgeInsets.all(widget.unit * 0.5),
      child: Listener(
        onPointerDown: (_) => setState(() => _pressed = true),
        onPointerUp: (_) => setState(() => _pressed = false),
        onPointerCancel: (_) => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.93 : 1.0,
          duration: const Duration(milliseconds: 90),
          curve: Curves.easeOut,
          child: Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.none,
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _pressed
                      ? Color.alphaBlend(
                          Colors.black.withValues(alpha: 0.18),
                          baseColor,
                        )
                      : baseColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                    side: active
                        ? BorderSide(
                            color: Colors.white.withValues(
                              alpha: _isLockedAlpha ? 0.95 : 0.6,
                            ),
                            width: _isLockedAlpha ? 2.5 : 1.5,
                          )
                        : BorderSide.none,
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: widget.unit * 0.5,
                    vertical: widget.unit * 0.85,
                  ),
                  elevation: _pressed ? 1 : 3,
                ),
                onPressed: () => widget.onPressed(resolved.action),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    resolved.label,
                    style: TextStyle(color: style.textColor),
                  ),
                ),
              ),
              if (widget.mode == ButtonMode.normal) ...[
                if (widget.data.secondFunction != null)
                  Positioned(
                    top: widget.unit * 0.25,
                    left: widget.unit * 0.5,
                    child: IgnorePointer(
                      child: Text(
                        widget.data.secondFunction!.label,
                        maxLines: 1,
                        overflow: TextOverflow.visible,
                        style: TextStyle(
                          fontSize: legendFontSize,
                          color: widget.theme
                              .getStyle(ButtonType.second)
                              .backgroundColor,
                          fontWeight: FontWeight.w600,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                if (widget.data.alphaFunction != null)
                  Positioned(
                    top: widget.unit * 0.18,
                    right: widget.unit * 0.5,
                    child: IgnorePointer(
                      child: Text(
                        widget.data.alphaFunction!.label,
                        maxLines: 1,
                        overflow: TextOverflow.visible,
                        style: TextStyle(
                          fontSize: legendFontSize,
                          color: widget.theme
                              .getStyle(ButtonType.alpha)
                              .backgroundColor,
                          fontWeight: FontWeight.w600,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
              ] else if (_hasOverrideForCurrentMode)
                Positioned(
                  top: widget.unit * 0.18,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Center(
                      child: Text(
                        widget.data.label,
                        maxLines: 1,
                        overflow: TextOverflow.visible,
                        style: TextStyle(
                          fontSize: legendFontSize,
                          color: style.textColor.withValues(alpha: 0.65),
                          fontWeight: FontWeight.w500,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
