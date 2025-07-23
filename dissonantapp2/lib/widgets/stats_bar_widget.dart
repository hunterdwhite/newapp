import 'package:flutter/material.dart';

class StatsBarWidget extends StatelessWidget {
  final int albumsSentBack;
  final int albumsKept;

  StatsBarWidget({required this.albumsSentBack, required this.albumsKept});

  @override
  Widget build(BuildContext context) {
    final totalAlbums = albumsSentBack + albumsKept;
    final double indicatorPosition =
        totalAlbums == 0 ? 0.5 : albumsKept / totalAlbums;

    // Calculate alignment based on indicatorPosition
    // Alignment.x ranges from -1 (left) to 1 (right)
    final double alignmentX = indicatorPosition * 2 - 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Display the counts
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Albums Sent Back: $albumsSentBack',
              style: TextStyle(fontSize: 16, color: Colors.black),
            ),
            Text(
              'Albums Kept: $albumsKept',
              style: TextStyle(fontSize: 16, color: Colors.black),
            ),
          ],
        ),
        SizedBox(height: 10),
        // Progress bar with indicator
        Stack(
          children: [
            // Background bar
            Container(
              height: 20,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            // Indicator
            Align(
              alignment: Alignment(alignmentX, 0),
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: Color(0xFFFFA500), // Orange
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
