import 'album.dart';

class FeedItem {
  final String username;
  final String userId; // <-- crucial
  final String status;
  final Album album;

  FeedItem({
    required this.username,
    required this.userId,
    required this.status,
    required this.album,
  });
}
