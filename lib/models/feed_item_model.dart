import 'album_model.dart';

class FeedItem {
  final String username;
  final String userId;            // whose profile we'll open
  final String status;            // "kept" or "returnedConfirmed"
  final Album album;

  /// NEW: avatar image to show next to username
  final String profilePictureUrl; // may be empty
  
  /// CURATOR INFO (for curated orders)
  final String? curatorUsername;
  final String? curatorId;
  final String? curatorProfilePictureUrl;

  FeedItem({
    required this.username,
    required this.userId,
    required this.status,
    required this.album,
    required this.profilePictureUrl,
    this.curatorUsername,
    this.curatorId,
    this.curatorProfilePictureUrl,
  });
  
  bool get isCurated => curatorId != null && curatorId!.isNotEmpty;
}
