// lib/services/performance_service.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_performance/firebase_performance.dart';

class PerformanceService {
  static final PerformanceService _instance = PerformanceService._internal();
  factory PerformanceService() => _instance;
  PerformanceService._internal();

  // Performance monitoring
  final Map<String, Trace> _activeTraces = {};
  
  // Memory management
  static const int _maxCacheSize = 100;
  static const Duration _cacheCleanupInterval = Duration(minutes: 5);
  
  Timer? _cacheCleanupTimer;
  
  /// Initialize performance monitoring
  Future<void> initialize() async {
    if (!kReleaseMode) return; // Only in release mode
    
    try {
      // Start periodic cache cleanup
      _startCacheCleanup();
      
      // Monitor app startup
      startTrace('app_startup');
      
    } catch (e) {
      debugPrint('Error initializing performance service: $e');
    }
  }

  /// Start a performance trace
  void startTrace(String traceName) {
    if (!kReleaseMode) return;
    
    try {
      final trace = FirebasePerformance.instance.newTrace(traceName);
      trace.start();
      _activeTraces[traceName] = trace;
    } catch (e) {
      debugPrint('Error starting trace $traceName: $e');
    }
  }

  /// Stop a performance trace
  void stopTrace(String traceName) {
    if (!kReleaseMode) return;
    
    try {
      final trace = _activeTraces[traceName];
      if (trace != null) {
        trace.stop();
        _activeTraces.remove(traceName);
      }
    } catch (e) {
      debugPrint('Error stopping trace $traceName: $e');
    }
  }

  /// Add custom metric to trace
  void addMetric(String traceName, String metricName, int value) {
    if (!kReleaseMode) return;
    
    try {
      final trace = _activeTraces[traceName];
      trace?.setMetric(metricName, value);
    } catch (e) {
      debugPrint('Error adding metric to trace $traceName: $e');
    }
  }

  /// Optimize image cache
  void optimizeImageCache() {
    try {
      final imageCache = PaintingBinding.instance.imageCache;
      
      // Limit cache size for better memory management
      imageCache.maximumSize = _maxCacheSize;
      imageCache.maximumSizeBytes = 50 * 1024 * 1024; // 50MB
      
      // Clear cache if too large
      if (imageCache.currentSize > _maxCacheSize * 0.8) {
        imageCache.clear();
      }
    } catch (e) {
      debugPrint('Error optimizing image cache: $e');
    }
  }

  /// Clear expired caches
  void clearExpiredCaches() {
    try {
      // Clear image cache
      PaintingBinding.instance.imageCache.clear();
      
      // Force garbage collection in debug mode
      if (!kReleaseMode) {
        // Note: System.gc() is not available in Dart, but clearing caches helps
      }
    } catch (e) {
      debugPrint('Error clearing caches: $e');
    }
  }

  /// Monitor memory usage
  void monitorMemory(String screenName) {
    if (!kReleaseMode) return;
    
    try {
      startTrace('memory_$screenName');
      
      // Add memory-related metrics
      final imageCache = PaintingBinding.instance.imageCache;
      addMetric('memory_$screenName', 'image_cache_size', imageCache.currentSize);
      addMetric('memory_$screenName', 'image_cache_bytes', imageCache.currentSizeBytes);
      
    } catch (e) {
      debugPrint('Error monitoring memory for $screenName: $e');
    }
  }

  /// Start periodic cache cleanup
  void _startCacheCleanup() {
    _cacheCleanupTimer?.cancel();
    _cacheCleanupTimer = Timer.periodic(_cacheCleanupInterval, (timer) {
      optimizeImageCache();
    });
  }

  /// Dispose of the service
  void dispose() {
    _cacheCleanupTimer?.cancel();
    
    // Stop all active traces
    for (final trace in _activeTraces.values) {
      try {
        trace.stop();
      } catch (e) {
        debugPrint('Error stopping trace: $e');
      }
    }
    _activeTraces.clear();
  }

  /// Preload critical images for better UX
  static Future<void> preloadCriticalImages(BuildContext context) async {
    const criticalImages = [
      'assets/dissonantlogo.png',
      'assets/blank_cd.png',
      'assets/homeicon.png',
      'assets/mymusicicon.png',
      'assets/ordericon.png',
      'assets/profileicon.png',
      'assets/icon/basicintroicon.png',
      'assets/icon/firstordericon.png',
      'assets/icon/libraryicon.png',
      'assets/icon/nextorderfreeicon.png',
      'assets/icon/hiddengemicon.png',
      'assets/icon/radicalsharemusicicon.png',
      'assets/icon/donate.png',
    ];

    for (final image in criticalImages) {
      try {
        await precacheImage(AssetImage(image), context);
      } catch (e) {
        debugPrint('Error preloading image $image: $e');
      }
    }
  }

  /// Optimize widget rebuilds by checking if rebuild is necessary
  static bool shouldRebuild<T>(T? oldValue, T? newValue) {
    return oldValue != newValue;
  }

  /// Debounce function to prevent excessive API calls
  static Timer? _debounceTimer;
  static void debounce(Duration duration, VoidCallback callback) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(duration, callback);
  }

  /// Throttle function to limit function execution frequency
  static DateTime? _lastThrottleCall;
  static void throttle(Duration duration, VoidCallback callback) {
    final now = DateTime.now();
    if (_lastThrottleCall == null || 
        now.difference(_lastThrottleCall!) >= duration) {
      _lastThrottleCall = now;
      callback();
    }
  }

  /// Get memory usage info for debugging
  Map<String, dynamic> getMemoryInfo() {
    final imageCache = PaintingBinding.instance.imageCache;
    return {
      'imageCacheSize': imageCache.currentSize,
      'imageCacheBytes': imageCache.currentSizeBytes,
      'imageCacheMaxSize': imageCache.maximumSize,
      'imageCacheMaxBytes': imageCache.maximumSizeBytes,
    };
  }
}