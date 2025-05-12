import 'package:cloud_firestore/cloud_firestore.dart';

class Album {
  final String albumId;
  final String albumName;
  final String artist;        // kept as “artist”
  final String releaseYear;
  final String albumImageUrl;

  Album({
    required this.albumId,
    required this.albumName,
    required this.artist,
    required this.releaseYear,
    required this.albumImageUrl,
  });

  factory Album.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Album(
      albumId: doc.id,
      albumName: data['albumName'] ?? 'Unknown Album',
      artist:     data['artist']    ?? 'Unknown Artist',
      releaseYear: data['releaseYear']?.toString() ?? 'Unknown Year',
      albumImageUrl: data['coverUrl'] ?? '',
    );
  }

  get artistName => null;
}
