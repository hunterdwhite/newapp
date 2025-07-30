import 'package:flutter/material.dart';
import '../constants/responsive_utils.dart';

enum RetroButtonStyle { light, dark }

class RetroButtonWidget extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final RetroButtonStyle style;
  final bool fixedHeight;
  final Widget? leading;
  final double? customWidth; // Optional custom width override

  const RetroButtonWidget({
    Key? key,
    required this.text,
    this.onPressed,
    this.style = RetroButtonStyle.light,
    this.fixedHeight = false,
    this.leading,
    this.customWidth,
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
    
    // Use custom width if provided, otherwise calculate responsive width
    final double buttonWidth = customWidth ?? ResponsiveUtils.getButtonWidth(context);
    
    // Responsive height calculation
    final double buttonHeight = fixedHeight 
        ? (ResponsiveUtils.isMobile(context) ? 42 : 45)
        : (ResponsiveUtils.isMobile(context) ? 48 : 50);
    
    // Responsive font size
    final double fontSize = ResponsiveUtils.getResponsiveFontSize(context, 
        mobile: 14, tablet: 16, desktop: 16);

    return GestureDetector(
      onTap: enabled ? onPressed : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Container(
          width: buttonWidth,
          height: buttonHeight,
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
          padding: EdgeInsets.symmetric(
            horizontal: ResponsiveUtils.isMobile(context) ? 8 : 12
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (leading != null) ...[
                leading!,
                SizedBox(width: ResponsiveUtils.isMobile(context) ? 6 : 8),
              ],
              Flexible(
                child: Text(
                  text,
                  style: TextStyle(
                    color: _textColor,
                    fontSize: fontSize,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
