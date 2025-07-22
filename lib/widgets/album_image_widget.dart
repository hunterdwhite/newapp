// album_image_widget.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:path/path.dart' as path;

class CustomAlbumImageWidget extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final bool enableMemoryCache;

  const CustomAlbumImageWidget({
    Key? key,
    required this.imageUrl,
    this.fit = BoxFit.contain,
    this.width,
    this.height,
    this.enableMemoryCache = true,
  }) : super(key: key);

  /// Utility function to check if the image format is supported.
  bool isSupportedImageFormat(String url) {
    try {
      Uri uri = Uri.parse(url);
      String extension = path.extension(uri.path).toLowerCase(); // e.g., '.png'
      return (extension == '.jpg' || extension == '.jpeg' || extension == '.png' || extension == '.webp');
    } catch (e) {
      // Only print errors in debug mode (this would be better handled with proper logging)
      assert(() {
        debugPrint('Error parsing image URL: $url, error: $e');
        return true;
      }());
      return false;
    }
  }

  Widget _buildPlaceholder() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Icon(
        Icons.album,
        color: Colors.grey,
        size: 48,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Early return for empty URLs
    if (imageUrl.isEmpty) {
      return SizedBox(
        width: width,
        height: height,
        child: Image.asset(
          'assets/blank_cd.png',
          fit: fit,
          errorBuilder: (context, error, stackTrace) => _buildErrorWidget(),
        ),
      );
    }

    // Validate the image format
    if (!isSupportedImageFormat(imageUrl)) {
      return SizedBox(
        width: width,
        height: height,
        child: Image.asset(
          'assets/blank_cd.png',
          fit: fit,
          errorBuilder: (context, error, stackTrace) => _buildErrorWidget(),
        ),
      );
    }

    return SizedBox(
      width: width,
      height: height,
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        fit: fit,
        width: width,
        height: height,
        memCacheWidth: width?.toInt(),
        memCacheHeight: height?.toInt(),
        maxWidthDiskCache: 800, // Limit disk cache size
        maxHeightDiskCache: 800,
        fadeInDuration: const Duration(milliseconds: 200),
        fadeOutDuration: const Duration(milliseconds: 100),
        placeholder: (context, url) => _buildPlaceholder(),
        errorWidget: (context, url, error) {
          // Only print errors in debug mode
          assert(() {
            debugPrint('Error loading image from $url: $error');
            return true;
          }());
          return _buildErrorWidget();
        },
        cacheManager: enableMemoryCache ? null : CacheManager(
          Config(
            'customCacheKey',
            stalePeriod: const Duration(days: 7),
            maxNrOfCacheObjects: 200,
            repo: JsonCacheInfoRepository(databaseName: 'customCacheKey'),
            fileService: HttpFileService(),
          ),
        ),
      ),
    );
  }
}

// Import CacheManager classes
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
