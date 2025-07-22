import 'package:flutter/material.dart';
import 'package:dissonantapp2/widgets/grainy_background_widget.dart'; // Import the GrainyBackgroundWidget

class ArticleDetailScreen extends StatelessWidget {
  final String title;
  final String authorName;
  final String authorProfileImageUrl;
  final String content;
  final String imageUrl;
  final DateTime timestamp;

  ArticleDetailScreen({
    required this.title,
    required this.authorName,
    required this.authorProfileImageUrl,
    required this.content,
    required this.imageUrl,
    required this.timestamp,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: GrainyBackgroundWidget( // Wrap the content with GrainyBackgroundWidget
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (imageUrl.isNotEmpty)
                  Image.network(imageUrl),
                SizedBox(height: 16.0),
                Row(
                  children: [
                    if (authorProfileImageUrl.isNotEmpty)
                      CircleAvatar(
                        backgroundImage: NetworkImage(authorProfileImageUrl),
                      ),
                    if (authorProfileImageUrl.isEmpty)
                      CircleAvatar(
                        child: Icon(Icons.person),
                      ),
                    SizedBox(width: 8.0),
                    Text(
                      authorName,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0),
                    ),
                    SizedBox(width: 16.0),
                    Text(
                      '${timestamp.day}/${timestamp.month}/${timestamp.year}',
                      style: TextStyle(color: Colors.grey, fontSize: 14.0),
                    ),
                  ],
                ),
                SizedBox(height: 16.0),
                Text(
                  content,
                  style: TextStyle(fontSize: 18.0),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}