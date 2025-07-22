/// Application-wide constants
/// 
/// This file contains all constants used throughout the app including
/// colors, dimensions, animation durations, and other shared values.

import 'package:flutter/material.dart';

// App Information
class AppInfo {
  static const String appName = 'Dissonant App';
  static const String version = '1.0.7';
}

// Color Constants
class AppColors {
  // Primary colors
  static const Color primaryColor = Color(0xFF1A1A1A);
  static const Color accentColor = Color(0xFF4CAF50);
  static const Color backgroundColor = Color(0xFF121212);
  
  // Text colors
  static const Color primaryTextColor = Colors.white;
  static const Color secondaryTextColor = Color(0xFF999999);
  static const Color hintTextColor = Color(0xFF666666);
  
  // Status colors
  static const Color successColor = Color(0xFF4CAF50);
  static const Color errorColor = Color(0xFFFF5722);
  static const Color warningColor = Color(0xFFFF9800);
  static const Color infoColor = Color(0xFF2196F3);
}

// Dimension Constants
class AppDimensions {
  // Padding and margins
  static const double paddingXS = 4.0;
  static const double paddingS = 8.0;
  static const double paddingM = 16.0;
  static const double paddingL = 24.0;
  static const double paddingXL = 32.0;
  
  // Border radius
  static const double borderRadiusS = 4.0;
  static const double borderRadiusM = 8.0;
  static const double borderRadiusL = 12.0;
  static const double borderRadiusXL = 16.0;
  
  // Button dimensions
  static const double buttonHeight = 48.0;
  static const double buttonHeightLarge = 56.0;
  
  // Icon sizes
  static const double iconSizeS = 16.0;
  static const double iconSizeM = 24.0;
  static const double iconSizeL = 32.0;
  static const double iconSizeXL = 48.0;
}

// Animation Constants
class AppAnimations {
  static const Duration fastDuration = Duration(milliseconds: 150);
  static const Duration normalDuration = Duration(milliseconds: 300);
  static const Duration slowDuration = Duration(milliseconds: 500);
}

// String Constants
class AppStrings {
  // Common labels
  static const String loading = 'Loading...';
  static const String retry = 'Retry';
  static const String cancel = 'Cancel';
  static const String save = 'Save';
  static const String delete = 'Delete';
  static const String edit = 'Edit';
  static const String done = 'Done';
  
  // Error messages
  static const String genericError = 'Something went wrong. Please try again.';
  static const String networkError = 'Network connection error. Please check your internet connection.';
  static const String authError = 'Authentication failed. Please try again.';
  
  // Success messages
  static const String saveSuccess = 'Changes saved successfully.';
  static const String deleteSuccess = 'Item deleted successfully.';
}

// API Constants
class ApiConstants {
  static const int timeoutDuration = 30; // seconds
  static const int maxRetries = 3;
}