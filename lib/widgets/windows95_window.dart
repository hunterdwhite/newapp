// lib/widgets/windows95_window.dart

import 'package:flutter/material.dart';

class Windows95Window extends StatelessWidget {
  final String? title;
  final Widget? titleWidget;
  final bool showCloseButton;
  final bool showTitleBar;
  final EdgeInsets contentPadding;
  final Widget child;
  final Color backgroundColor; // Background color for the entire window
  final Color? contentBackgroundColor; // Background color for the content area

  const Windows95Window({
    Key? key,
    this.title,
    this.titleWidget,
    this.showCloseButton = false,
    this.showTitleBar = true, // Named parameter with default value
    this.contentPadding = const EdgeInsets.all(4.0),
    required this.child,
    this.backgroundColor = const Color(0xFFC0C0C0), // Default grey color
    this.contentBackgroundColor, // Will default to backgroundColor if not specified
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget titleRow = SizedBox.shrink(); // Default to empty if no title

    if (showTitleBar) {
      if (titleWidget != null) {
        titleRow = titleWidget!;
      } else if (title != null) {
        titleRow = Row(
          children: [
            Expanded(
              child: Text(
                title!,
                style: TextStyle(color: Colors.black, fontSize: 12),
              ),
            ),
            if (showCloseButton)
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Icon(Icons.close, color: Colors.white, size: 12),
              ),
          ],
        );
      } else {
        titleRow = Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (showCloseButton)
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Icon(Icons.close, color: Colors.white, size: 12),
              ),
          ],
        );
      }
    }

    // Use contentBackgroundColor if provided; otherwise, default to backgroundColor
    final Color contentBgColor = contentBackgroundColor ?? backgroundColor;

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border.all(color: Colors.black),
        boxShadow: [
          // Retain shadows to maintain the Windows 95 aesthetic
          BoxShadow(color: Colors.white, offset: Offset(-2, -2), blurRadius: 0),
          BoxShadow(color: Colors.black, offset: Offset(2, 2), blurRadius: 0),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showTitleBar)
            Container(
              color: Color(0xFFFFA12C),
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: titleRow,
            ),
          Container(
            padding: contentPadding,
            color: contentBgColor,
            child: child,
          ),
        ],
      ),
    );
  }
}
