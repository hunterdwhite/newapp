import 'package:flutter/material.dart';

class ResponsiveUtils {
  // Screen size breakpoints
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900;
  static const double desktopBreakpoint = 1200;
  
  // Device type enumeration
  static DeviceScreenType getDeviceType(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    if (width < mobileBreakpoint) {
      return DeviceScreenType.mobile;
    } else if (width < tabletBreakpoint) {
      return DeviceScreenType.tablet;
    } else {
      return DeviceScreenType.desktop;
    }
  }
  
  // Responsive padding
  static EdgeInsets getResponsivePadding(BuildContext context, {
    double mobile = 16.0,
    double tablet = 24.0,
    double desktop = 32.0,
  }) {
    switch (getDeviceType(context)) {
      case DeviceScreenType.mobile:
        return EdgeInsets.all(mobile);
      case DeviceScreenType.tablet:
        return EdgeInsets.all(tablet);
      case DeviceScreenType.desktop:
        return EdgeInsets.all(desktop);
    }
  }
  
  // Responsive horizontal padding
  static EdgeInsets getResponsiveHorizontalPadding(BuildContext context, {
    double mobile = 16.0,
    double tablet = 32.0,
    double desktop = 64.0,
  }) {
    switch (getDeviceType(context)) {
      case DeviceScreenType.mobile:
        return EdgeInsets.symmetric(horizontal: mobile);
      case DeviceScreenType.tablet:
        return EdgeInsets.symmetric(horizontal: tablet);
      case DeviceScreenType.desktop:
        return EdgeInsets.symmetric(horizontal: desktop);
    }
  }
  
  // Responsive font size
  static double getResponsiveFontSize(BuildContext context, {
    double mobile = 16.0,
    double tablet = 18.0,
    double desktop = 20.0,
  }) {
    switch (getDeviceType(context)) {
      case DeviceScreenType.mobile:
        return mobile;
      case DeviceScreenType.tablet:
        return tablet;
      case DeviceScreenType.desktop:
        return desktop;
    }
  }
  
  // Form width calculation for consistent form layouts
  static double getFormWidth(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double maxWidth = getDeviceType(context) == DeviceScreenType.mobile ? 350 : 400;
    return (screenWidth * 0.85).clamp(300, maxWidth);
  }
  
  // Button width calculation
  static double getButtonWidth(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    switch (getDeviceType(context)) {
      case DeviceScreenType.mobile:
        return (screenWidth * 0.8).clamp(160, 280);
      case DeviceScreenType.tablet:
        return (screenWidth * 0.4).clamp(200, 300);
      case DeviceScreenType.desktop:
        return (screenWidth * 0.25).clamp(240, 320);
    }
  }
  
  // Container max width
  static double getContainerMaxWidth(BuildContext context) {
    switch (getDeviceType(context)) {
      case DeviceScreenType.mobile:
        return double.infinity;
      case DeviceScreenType.tablet:
        return 700;
      case DeviceScreenType.desktop:
        return 900;
    }
  }
  
  // Responsive spacing
  static double getResponsiveSpacing(BuildContext context, {
    double mobile = 16.0,
    double tablet = 20.0,
    double desktop = 24.0,
  }) {
    switch (getDeviceType(context)) {
      case DeviceScreenType.mobile:
        return mobile;
      case DeviceScreenType.tablet:
        return tablet;
      case DeviceScreenType.desktop:
        return desktop;
    }
  }
  
  // Check if device is mobile size (including portrait tablets)
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < mobileBreakpoint;
  }
  
  // Check if device is tablet size
  static bool isTablet(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    return width >= mobileBreakpoint && width < tabletBreakpoint;
  }
  
  // Check if device is desktop size
  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= tabletBreakpoint;
  }
  
  // Safe area padding consideration
  static EdgeInsets getSafeAreaPadding(BuildContext context) {
    return EdgeInsets.only(
      top: MediaQuery.of(context).padding.top,
      bottom: MediaQuery.of(context).padding.bottom,
    );
  }
  
  // Keyboard-aware padding
  static EdgeInsets getKeyboardAwarePadding(BuildContext context) {
    return EdgeInsets.only(
      bottom: MediaQuery.of(context).viewInsets.bottom,
    );
  }
}

enum DeviceScreenType {
  mobile,
  tablet,
  desktop,
}