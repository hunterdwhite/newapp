/// Base service class
/// 
/// This class provides common functionality for all services including
/// error handling, logging, and standardized response handling.

import 'package:flutter/foundation.dart';

abstract class BaseService {
  /// Service name for logging purposes
  String get serviceName;
  
  /// Handle errors in a consistent way across all services
  void handleError(String methodName, dynamic error, [StackTrace? stackTrace]) {
    if (kDebugMode) {
      print('[$serviceName] Error in $methodName: $error');
      if (stackTrace != null) {
        print('Stack trace: $stackTrace');
      }
    }
    // In production, you might want to send this to a crash reporting service
  }
  
  /// Log debug information
  void logDebug(String methodName, String message) {
    if (kDebugMode) {
      print('[$serviceName] $methodName: $message');
    }
  }
  
  /// Log info messages
  void logInfo(String methodName, String message) {
    if (kDebugMode) {
      print('[$serviceName] INFO $methodName: $message');
    }
  }
}