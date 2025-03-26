import 'package:flutter/material.dart';

class RetroButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final Color color;
  final bool fixedHeight;
  final Color shadowColor; // Custom shadow color
  final Widget? leading; // Optional leading icon or widget

  const RetroButton({
    Key? key,
    required this.text,
    this.onPressed, // Now nullable, allowing for a disabled state
    this.color = const Color(0xFFD24407),
    this.fixedHeight = false,
    this.shadowColor = Colors.black,
    this.leading,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = onPressed != null;

    return IntrinsicWidth(
      child: Container(
        decoration: BoxDecoration(
          boxShadow: [
            // Slight white outline
            BoxShadow(
              color: Colors.white,
              offset: Offset(4.5, 4.5),
              blurRadius: 0,
            ),
            // Darker shadow offset for a retro 3D effect
            BoxShadow(
              color: shadowColor.withOpacity(0.9),
              offset: Offset(4, 4),
              blurRadius: 0,
            ),
          ],
          borderRadius: BorderRadius.circular(4),
        ),
        child: GestureDetector(
          onTap: isEnabled ? onPressed : null, // Disable tap if not enabled
          child: Opacity(
            opacity: isEnabled ? 1.0 : 0.5, // Lower opacity if disabled
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              height: fixedHeight ? 45 : 50, // Adjust if needed
              decoration: BoxDecoration(
                color: color,
                border: Border.all(color: Colors.black, width: 2),
                borderRadius: BorderRadius.circular(4),
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (leading != null) ...[
                    leading!,
                    SizedBox(width: 8),
                  ],
                  Text(
                    text,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
