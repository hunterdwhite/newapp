import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';

class CarouselWidget extends StatelessWidget {
  final List<String> imgList;

  CarouselWidget({required this.imgList});

  @override
  Widget build(BuildContext context) {
    return CarouselSlider(
      options: CarouselOptions(
        height: 300, // Increase the height for larger images
        autoPlay: true,
        enlargeCenterPage: true,
        viewportFraction: 0.7, // Closer to 1.0 -> larger items
        aspectRatio: 2.0,
        initialPage: 0,
      ),
      items: imgList.map((item) {
        return Container(
          margin: EdgeInsets.all(5.0),
          child: ClipRRect(
            borderRadius: BorderRadius.all(Radius.circular(5.0)),
            child: Image.network(
              item,
              fit: BoxFit.contain,
              width: 1000.0,

              // 1) Show a loading spinner while the image is downloading
              loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? progress) {
                if (progress == null) {
                  // The image is fully loaded
                  return child;
                } else {
                  // The image is still loading -> show a spinner
                  return Center(
                    child: CircularProgressIndicator(
                      value: progress.expectedTotalBytes != null
                          ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                          : null,
                    ),
                  );
                }
              },

              // 2) Show a fallback widget if loading the image fails
              errorBuilder: (context, error, stackTrace) {
                return Center(
                  child: Text(
                    'Failed to load image',
                    style: TextStyle(color: Colors.white),
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
