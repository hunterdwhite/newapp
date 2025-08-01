import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import '../constants/responsive_utils.dart';

class CarouselWidget extends StatelessWidget {
  final List<String> imgList;

  CarouselWidget({required this.imgList});

  @override
  Widget build(BuildContext context) {
    // Make height responsive
    final height = ResponsiveUtils.isMobile(context) ? 200 : 250;
    
    return CarouselSlider(
      options: CarouselOptions(
        height: height.toDouble(),
        autoPlay: true,
        enlargeCenterPage: true,
        viewportFraction: 0.6, // Reduced to show partial albums on sides
        aspectRatio: 1.2, // Better aspect ratio for album covers (slightly wider than square)
        initialPage: 0,
        autoPlayInterval: Duration(seconds: 3),
        autoPlayAnimationDuration: Duration(milliseconds: 800),
      ),
      items: imgList.map((item) {
        return Container(
          margin: EdgeInsets.all(8.0), // Increased margin for better spacing
          child: ClipRRect(
            borderRadius: BorderRadius.all(Radius.circular(8.0)), // Increased border radius
            child: Image.network(
              item,
              fit: BoxFit.contain, // Changed back to contain to show full album covers without cropping
              width: double.infinity,
              height: double.infinity,

              // 1) Show a loading spinner while the image is downloading
              loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? progress) {
                if (progress == null) {
                  // The image is fully loaded
                  return child;
                } else {
                  // The image is still loading -> show a spinner
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: Center(
                      child: CircularProgressIndicator(
                        value: progress.expectedTotalBytes != null
                            ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                            : null,
                      ),
                    ),
                  );
                }
              },

              // 2) Show a fallback widget if loading the image fails
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, color: Colors.grey[600], size: 32),
                        SizedBox(height: 8),
                        Text(
                          'Failed to load image',
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      }).toList(),
    );
  }
}
