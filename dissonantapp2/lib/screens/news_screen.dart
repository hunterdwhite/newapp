import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'article_detail_screen.dart';  // Import your ArticleDetailScreen for navigation

class NewsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Latest News'),
        backgroundColor: Colors.black,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('articles')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData) {
            return Center(child: Text('No news found.'));
          }

          final articles = snapshot.data!.docs;

          return ListView.builder(
            itemCount: articles.length,
            itemBuilder: (context, index) {
              var article = articles[index];
              DateTime articleDate = (article['timestamp'] as Timestamp).toDate();
              String formattedDate = DateFormat('MM/dd/yyyy').format(articleDate);

              return Card(
                margin: EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
                color: Colors.transparent,  // Set the background to transparent
                elevation: 0,  // Remove elevation to make it fully transparent
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ArticleDetailScreen(
                          title: article['title'] ?? 'Untitled',
                          authorName: article['authorName'] ?? 'Unknown Author',
                          authorProfileImageUrl: article['authorProfileImageUrl'] ?? '',
                          content: article['content'] ?? 'No content available.',
                          imageUrl: article['imageUrl'] ?? '',
                          timestamp: articleDate,
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          article['title'] ?? 'Untitled',
                          style: TextStyle(
                            color: Colors.white,  // Keep the text color white
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8.0),
                        Text(
                          article['summary'] ?? '',
                          style: TextStyle(
                            color: Colors.white70,  // Keep the summary text color white
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 8.0),
                        Row(
                          children: [
                            if ((article['authorProfileImageUrl'] ?? '').isNotEmpty)
                              CircleAvatar(
                                backgroundImage: NetworkImage(article['authorProfileImageUrl']),
                                radius: 16,
                              ),
                            if ((article['authorProfileImageUrl'] ?? '').isEmpty)
                              CircleAvatar(
                                child: Icon(Icons.person, size: 16),
                                radius: 16,
                              ),
                            SizedBox(width: 8.0),
                            Text(
                              article['authorName'] ?? 'Unknown Author',
                              style: TextStyle(color: Colors.white70),  // Keep author name white
                            ),
                            SizedBox(width: 8.0),
                            Text(
                              formattedDate,
                              style: TextStyle(color: Colors.white38),  // Keep date text white
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}