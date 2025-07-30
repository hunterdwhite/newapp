import 'package:flutter/material.dart';
import '../constants/responsive_utils.dart';

class ResponsiveFormContainer extends StatelessWidget {
  final Widget child;
  final double? width;
  final bool showCloseButton;
  final VoidCallback? onClose;

  const ResponsiveFormContainer({
    Key? key,
    required this.child,
    this.width,
    this.showCloseButton = true,
    this.onClose,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Calculate responsive width if not provided
    final double containerWidth = width ?? ResponsiveUtils.getFormWidth(context);
    
    // Responsive padding
    final double containerPadding = ResponsiveUtils.getResponsiveSpacing(context, 
        mobile: 12, tablet: 16, desktop: 20);
    
    // Responsive title bar height
    final double titleBarHeight = ResponsiveUtils.isMobile(context) ? 36 : 40;

    return Container(
      width: containerWidth,
      padding: EdgeInsets.only(bottom: ResponsiveUtils.isMobile(context) ? 8 : 12),
      decoration: BoxDecoration(
        color: Color(0xFFF4F4F4),
        border: Border.all(color: Colors.black, width: 2),
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.8),
            offset: Offset(4, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Window frame/title bar
          Container(
            width: double.infinity,
            height: titleBarHeight,
            decoration: BoxDecoration(
              color: Color(0xFFFFA12C),
              border: Border(
                bottom: BorderSide(color: Colors.black, width: 2),
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
            child: showCloseButton ? Stack(
              children: [
                Positioned(
                  right: ResponsiveUtils.isMobile(context) ? 6 : 8,
                  top: ResponsiveUtils.isMobile(context) ? 6 : 8,
                  child: GestureDetector(
                    onTap: onClose ?? () => Navigator.pop(context),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black, width: 2),
                        color: Color(0xFFF4F4F4),
                      ),
                      width: ResponsiveUtils.isMobile(context) ? 18 : 20,
                      height: ResponsiveUtils.isMobile(context) ? 18 : 20,
                      alignment: Alignment.center,
                      child: Text(
                        'X',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: ResponsiveUtils.isMobile(context) ? 12 : 14,
                          height: 1,
                          color: Colors.black,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ],
            ) : null,
          ),
          // Content with responsive padding
          Padding(
            padding: EdgeInsets.all(containerPadding),
            child: child,
          ),
        ],
      ),
    );
  }
}

class ResponsiveTextField extends StatelessWidget {
  final String labelText;
  final bool obscureText;
  final ValueChanged<String>? onChanged;
  final Color textColor;
  final bool isFlat;
  final bool isCompact;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final TextEditingController? controller;

  const ResponsiveTextField({
    Key? key,
    required this.labelText,
    this.obscureText = false,
    this.onChanged,
    this.textColor = Colors.black,
    this.isFlat = false,
    this.isCompact = false,
    this.validator,
    this.keyboardType,
    this.controller,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final double fontSize = ResponsiveUtils.getResponsiveFontSize(context, 
        mobile: 14, tablet: 16, desktop: 16);
    final double marginBottom = isCompact 
        ? (ResponsiveUtils.isMobile(context) ? 6 : 8)
        : (ResponsiveUtils.isMobile(context) ? 8 : 12);
    
    return Container(
      margin: EdgeInsets.only(bottom: marginBottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 4.0),
            child: Text(
              labelText,
              style: TextStyle(
                fontSize: fontSize - 2,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ),
          TextFormField(
            controller: controller,
            onChanged: onChanged,
            obscureText: obscureText,
            validator: validator,
            keyboardType: keyboardType,
            style: TextStyle(
              color: textColor,
              fontSize: fontSize,
            ),
            decoration: InputDecoration(
              border: isFlat
                  ? OutlineInputBorder(
                      borderRadius: BorderRadius.circular(0),
                      borderSide: BorderSide(color: Colors.black, width: 2),
                    )
                  : OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.black, width: 2),
                    ),
              enabledBorder: isFlat
                  ? OutlineInputBorder(
                      borderRadius: BorderRadius.circular(0),
                      borderSide: BorderSide(color: Colors.black, width: 2),
                    )
                  : OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.black, width: 2),
                    ),
              focusedBorder: isFlat
                  ? OutlineInputBorder(
                      borderRadius: BorderRadius.circular(0),
                      borderSide: BorderSide(color: Colors.orange, width: 2),
                    )
                  : OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.orange, width: 2),
                    ),
              fillColor: Colors.white,
              filled: true,
              contentPadding: EdgeInsets.symmetric(
                horizontal: ResponsiveUtils.isMobile(context) ? 8 : 12,
                vertical: ResponsiveUtils.isMobile(context) ? 8 : 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}