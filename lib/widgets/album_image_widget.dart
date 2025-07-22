// album_image_widget.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:path/path.dart' as path;

class CustomAlbumImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;

  const CustomAlbumImage({
    Key? key,
    required this.imageUrl,
    this.fit = BoxFit.contain,
  }) : super(key: key);

  /// Utility function to check if the image format is supported.
  bool isSupportedImageFormat(String url) {
    try {
      Uri uri = Uri.parse(url);
      String extension = path.extension(uri.path).toLowerCase(); // e.g., '.png'
      // Removed debug print statement for production
      return (extension == '.jpg' || extension == '.jpeg' || extension == '.png');
    } catch (e) {
      // Only print errors in debug mode (this would be better handled with proper logging)
      assert(() {
        print('Error parsing image URL: $url, error: $e');
        return true;
      }());
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Validate the image format
    bool isSupported = isSupportedImageFormat(imageUrl);

    if (!isSupported) {
      // Removed debug print statement for production
      // Return a fallback image
      return Image.asset(
        'assets/blank_cd.png', // Ensure this image exists in your assets
        fit: fit,
      );
    }

    return imageUrl.isNotEmpty
        ? CachedNetworkImage(
            imageUrl: imageUrl,
            fit: fit,
            placeholder: (context, url) => Center(child: CircularProgressIndicator()),
            errorWidget: (context, url, error) {
              // Only print errors in debug mode
              assert(() {
                print('Error loading image from $url: $error');
                return true;
              }());
              return Image.asset(
                'assets/blank_cd.png', // Fallback image
                fit: fit,
              );
            },
          )
        : Icon(
            Icons.album,
            size: 120,
          );
  }
}
