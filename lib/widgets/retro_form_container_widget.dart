import 'package:flutter/material.dart';
import '../constants/responsive_utils.dart';

class RetroFormContainerWidget extends StatelessWidget {
  final Widget child;
  final double? width; // Make width optional for auto-calculation
  final double? maxWidth; // Optional max width constraint

  const RetroFormContainerWidget({
    required this.child, 
    this.width,
    this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate responsive width if not provided
    final double containerWidth = width ?? ResponsiveUtils.getFormWidth(context);
    final double effectiveMaxWidth = maxWidth ?? ResponsiveUtils.getContainerMaxWidth(context);
    
    // Responsive padding
    final double containerPadding = ResponsiveUtils.getResponsiveSpacing(context, 
        mobile: 12, tablet: 16, desktop: 20);
    
    // Responsive title bar height
    final double titleBarHeight = ResponsiveUtils.isMobile(context) ? 28 : 30;
    
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: effectiveMaxWidth,
        minWidth: ResponsiveUtils.isMobile(context) ? 280 : 300,
      ),
      child: Container(
        width: containerWidth,
        decoration: BoxDecoration(
          color: Color(0xFFF4F4F4), // Background color for the retro container
          border: Border.all(color: Colors.black, width: 2), // Black outline around the container
          borderRadius: BorderRadius.circular(4),
          boxShadow: [
            BoxShadow(
              color: Colors.white.withOpacity(0.8), // Black shadow
              offset: Offset(4, 4), // Shadow offset
              blurRadius: 0, // No blur for sharp retro shadow
            ),
            BoxShadow(
              color: Colors.black, // Thin white outline outside the shadow
              offset: Offset(4, 4), // Position the white outline around the shadow
              spreadRadius: -1, // Slight inward spread to ensure the white outline is thin
              blurRadius: 0, // No blur for retro effect
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min, // Ensure the column only takes up the necessary vertical space
          children: [
            // Top bar simulating the title bar of a retro window
            Container(
              width: double.infinity,
              height: titleBarHeight,
              decoration: BoxDecoration(
                color: Color(0xFFFFA12C), // Updated orange color for the top bar
                border: Border(
                  bottom: BorderSide(color: Colors.black, width: 2), // Bottom black border for the bar
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(containerPadding), // Responsive padding for the content inside the retro window
              child: child, // Pass the child widget (form or any other content)
            ),
          ],
        ),
      ),
    );
  }
}