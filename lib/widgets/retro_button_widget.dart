import 'package:flutter/material.dart';

enum RetroButtonStyle { light, dark }

class RetroButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final RetroButtonStyle style;
  final bool fixedHeight;
  final Widget? leading;

  const RetroButton({
    Key? key,
    required this.text,
    this.onPressed,
    this.style = RetroButtonStyle.light,
    this.fixedHeight = false,
    this.leading,
  }) : super(key: key);

  static const _lightFill = Color(0xFFE9E9E9);
  static const _lightHighlight = Color(0xFFFFFFFF);
  static const _lightText = Colors.black;

  static const _darkFill = Color(0xFF2A2A2A);
  static const _darkHighlight = Color(0x1AFFFFFF); // 10%
  static const _darkText = Colors.white;

  static const _shadowColor = Color(0x26000000); // 15% black

  Color get _fill => style == RetroButtonStyle.light ? _lightFill : _darkFill;
  Color get _highlight => style == RetroButtonStyle.light ? _lightHighlight : _darkHighlight;
  Color get _textColor => style == RetroButtonStyle.light ? _lightText : _darkText;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;

    return GestureDetector(
      onTap: enabled ? onPressed : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Container(
          width: 160,
          height: fixedHeight ? 45 : 50,
          decoration: BoxDecoration(
            color: _fill,
            border: Border(
              top: BorderSide(color: _highlight, width: 2), // bevel highlight
              left: BorderSide(color: _highlight, width: 2),
              right: const BorderSide(color: Colors.black, width: 2),
              bottom: const BorderSide(color: Colors.black, width: 2),
            ),
            boxShadow: [
              BoxShadow(color: _shadowColor, offset: const Offset(2, 2), blurRadius: 0),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: 8),
              ],
              Text(
                text,
                style: TextStyle(
                  color: _textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
