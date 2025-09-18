import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/grainy_background_widget.dart';
import '../widgets/retro_button_widget.dart';

class AlbumConfirmationScreen extends StatefulWidget {
  final String orderId;
  final Map<String, dynamic> orderData;
  final String albumId;
  final Map<String, dynamic> albumData;

  const AlbumConfirmationScreen({
    Key? key,
    required this.orderId,
    required this.orderData,
    required this.albumId,
    required this.albumData,
  }) : super(key: key);

  @override
  _AlbumConfirmationScreenState createState() => _AlbumConfirmationScreenState();
}

class _AlbumConfirmationScreenState extends State<AlbumConfirmationScreen> {
  final TextEditingController _noteController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  
  bool _isConfirming = false;
  
  // Taste profile data
  Map<String, dynamic>? _tasteProfile;
  bool _isLoadingProfile = true;
  bool _tasteProfileExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadTasteProfile();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadTasteProfile() async {
    try {
      final userId = widget.orderData['userId'] as String?;
      if (userId != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();
        
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          
          // Try to get tasteProfile first, fallback to profileCustomization
          if (userData.containsKey('tasteProfile')) {
            _tasteProfile = userData['tasteProfile'] as Map<String, dynamic>?;
          } else if (userData.containsKey('profileCustomization')) {
            _tasteProfile = userData['profileCustomization'] as Map<String, dynamic>?;
          }
        }
      }
    } catch (e) {
      print('Error loading taste profile: $e');
    }
    
    if (mounted) {
      setState(() {
        _isLoadingProfile = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirm Album Selection'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: GrainyBackgroundWidget(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: _buildTasteProfile()),
                const SizedBox(height: 24),
                _buildAlbumDetails(),
                const SizedBox(height: 24),
                _buildNoteSection(),
                const SizedBox(height: 32),
                _buildConfirmationButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTasteProfile() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 500),
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        border: Border.all(color: Colors.orangeAccent, width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _tasteProfileExpanded = !_tasteProfileExpanded;
              });
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Customer\'s Taste Profile',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.orangeAccent,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _tasteProfileExpanded 
                        ? Icons.keyboard_arrow_up 
                        : Icons.keyboard_arrow_down,
                    color: Colors.orangeAccent,
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
          if (_tasteProfileExpanded) ...[
            const Divider(color: Colors.orangeAccent, height: 1),
            _buildTasteProfileContent(),
          ],
        ],
      ),
    );
  }

  Widget _buildTasteProfileContent() {
    if (_isLoadingProfile) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(
          child: CircularProgressIndicator(color: Colors.orangeAccent),
        ),
      );
    }

    if (_tasteProfile == null) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Text(
          'No taste profile available for this customer.',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontStyle: FontStyle.italic,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    final genres = _tasteProfile!['genres'] as List?;
    final decades = _tasteProfile!['decades'] as List?;
    final musicalBio = _tasteProfile!['musicalBio'] as String?;
    final albumsListened = _tasteProfile!['albumsListened'];

    final hasGenres = genres != null && genres.isNotEmpty;
    final hasDecades = decades != null && decades.isNotEmpty;
    final hasBio = musicalBio != null && musicalBio.isNotEmpty;
    final hasAlbumsListened = albumsListened != null && albumsListened.toString().isNotEmpty;

    if (!hasGenres && !hasDecades && !hasBio && !hasAlbumsListened) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Text(
          'This customer hasn\'t filled out their taste profile yet.',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontStyle: FontStyle.italic,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasGenres) ...[
            _buildTasteProfileItem('Favorite Genres', genres.join(', ')),
            const SizedBox(height: 12),
          ],
          if (hasDecades) ...[
            _buildTasteProfileItem('Favorite Decades', decades.join(', ')),
            const SizedBox(height: 12),
          ],
          if (hasAlbumsListened) ...[
            _buildTasteProfileItem('Albums Listened', albumsListened.toString()),
            const SizedBox(height: 12),
          ],
          if (hasBio) ...[
            _buildTasteProfileItem('Musical Bio', musicalBio),
          ],
        ],
      ),
    );
  }

  Widget _buildTasteProfileItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }


  Widget _buildAlbumDetails() {
    final artist = widget.albumData['artist'] ?? 'Unknown Artist';
    final albumName = widget.albumData['albumName'] ?? 'Unknown Album';
    final releaseYear = widget.albumData['releaseYear'] ?? '';
    final quality = widget.albumData['quality'] ?? '';
    final genres = widget.albumData['genres'] ?? [];
    final genre = genres is List && genres.isNotEmpty ? genres[0].toString() : '';
    final coverUrl = widget.albumData['coverUrl'] as String?;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        border: Border.all(color: Colors.white, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Selected Album',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Album cover
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  border: Border.all(color: Colors.white, width: 1),
                ),
                child: coverUrl != null && coverUrl.isNotEmpty
                    ? Image.network(
                        coverUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.music_note,
                            color: Colors.white60,
                            size: 40,
                          );
                        },
                      )
                    : const Icon(
                        Icons.music_note,
                        color: Colors.white60,
                        size: 40,
                      ),
              ),
              const SizedBox(width: 20),
              // Album info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      albumName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      artist,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (releaseYear.isNotEmpty)
                          _buildInfoChip(releaseYear),
                        if (genre.isNotEmpty)
                          _buildInfoChip(genre),
                        if (quality.isNotEmpty)
                          _buildInfoChip(quality),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.orangeAccent.withOpacity(0.2),
        border: Border.all(color: Colors.orangeAccent, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          color: Colors.orangeAccent,
        ),
      ),
    );
  }

  Widget _buildNoteSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        border: Border.all(color: Colors.white, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Curator Note',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Write a personal note about why you selected this album for them. This will be displayed to them when their order is delivered.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _noteController,
            maxLines: 5,
            maxLength: 500,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: '"this is the first album that made me sob uncontrollably..."',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: const BorderSide(color: Colors.white, width: 1),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: const BorderSide(color: Colors.white, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.zero,
                borderSide: const BorderSide(color: Colors.orangeAccent, width: 1),
              ),
              filled: true,
              fillColor: Colors.black,
              counterStyle: const TextStyle(color: Colors.white60),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please write a note!';
              }
              if (value.trim().length < 20) {
                return 'Please write a more detailed note (at least 20 characters)';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmationButtons() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orangeAccent.withOpacity(0.1),
            border: Border.all(color: Colors.orangeAccent, width: 1),
          ),
          child: const Row(
            children: [
              Icon(
                Icons.warning_amber,
                color: Colors.orangeAccent,
                size: 20,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Once confirmed, this album will be sent to them and the order will be marked as fulfilled!',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.orangeAccent,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: RetroButtonWidget(
                text: 'Go Back',
                onPressed: _isConfirming ? null : () => Navigator.of(context).pop(),
                style: RetroButtonStyle.dark,
                fixedHeight: true,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: RetroButtonWidget(
                text: _isConfirming ? 'Confirming...' : 'Confirm Selection',
                onPressed: _isConfirming ? null : _confirmSelection,
                style: RetroButtonStyle.light,
                fixedHeight: true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _confirmSelection() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isConfirming = true;
    });

    try {
      // First, get the discogsId from the album document to find the correct inventory document
      final albumDoc = await FirebaseFirestore.instance
          .collection('albums')
          .doc(widget.albumId)
          .get();
      
      if (!albumDoc.exists) {
        throw Exception('Album document not found');
      }
      
      final albumData = albumDoc.data() as Map<String, dynamic>;
      final discogsId = albumData['discogsId'];
      
      if (discogsId == null) {
        throw Exception('Album missing Discogs ID - cannot update inventory');
      }

      final batch = FirebaseFirestore.instance.batch();

      // Update the order with the selected album and curator note
      final orderRef = FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId);
      
      batch.update(orderRef, {
        'albumId': widget.albumId,
        'status': 'ready_to_ship', // Mark as ready for admin to ship (not sent yet!)
        'curatorNote': _noteController.text.trim(),
        'curatedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Decrement inventory quantity using the correct discogsId as document key
      final inventoryRef = FirebaseFirestore.instance
          .collection('inventory')
          .doc(discogsId.toString());
      
      batch.update(inventoryRef, {
        'quantity': FieldValue.increment(-1),
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      // Execute the batch
      await batch.commit();

      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Album selection confirmed! The order is now ready for admin to ship.'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate back to curator dashboard
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isConfirming = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error confirming selection: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

}
