import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';
import '../widgets/app_bar_widget.dart';
import '../widgets/grainy_background_widget.dart';
import '../widgets/retro_button_widget.dart';

class ReturnAlbumScreen extends StatefulWidget {
  final String orderId;

  ReturnAlbumScreen({required this.orderId});

  @override
  _ReturnAlbumScreenState createState() => _ReturnAlbumScreenState();
}

class _ReturnAlbumScreenState extends State<ReturnAlbumScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;
  bool _isLoading = true;

  String _heardBefore = 'Yes';
  String _ownAlbum = 'Yes';
  String _likedAlbum = 'Yes!';
  String _review = '';
  String _curatorReview = '';
  double _curatorRating = 0.0;
  String _albumCoverUrl = '';
  String _albumInfo = '';
  String? _albumId;
  String? _curatorId;
  int _flowVersion = 1;

  @override
  void initState() {
    super.initState();
    _fetchAlbumDetails();
  }

  Future<void> _fetchAlbumDetails() async {
    try {
      final orderDoc = await _firestoreService.getOrderById(widget.orderId);
      if (orderDoc != null && orderDoc.exists) {
        final orderData = orderDoc.data() as Map<String, dynamic>;
        _flowVersion = orderData['flowVersion'] ?? 1;
        // Get albumId - try both new and old data structures
        final albumId = orderData['albumId'] ?? orderData['details']?['albumId'];
        _albumId = albumId;
        _curatorId = orderData['curatorId'];

        final albumDoc = await _firestoreService.getAlbumById(albumId);
        if (albumDoc.exists) {
          final album = albumDoc.data() as Map<String, dynamic>;
          if (mounted) {
            setState(() {
              _albumCoverUrl = album['coverUrl'] ?? '';
              _albumInfo = '${album['artist']} - ${album['albumName']}';
              _isLoading = false;
            });
          }
        } else {
          setState(() {
            _albumInfo = 'Album not found';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _albumInfo = 'Order not found';
          _isLoading = false;
        });
      }
    } catch (_) {
      setState(() {
        _albumInfo = 'Failed to load album details';
        _isLoading = false;
      });
    }
  }

  Future<void> _submitReview(String comment) async {
    if (_albumId == null) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await _firestoreService.addReview(
      albumId: _albumId!,
      userId: user.uid,
      orderId: widget.orderId,
      comment: comment,
    );
  }

  Future<void> _submitCuratorReview(String comment, double rating) async {
    if (_curatorId == null) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await _firestoreService.addCuratorReview(
      curatorId: _curatorId!,
      userId: user.uid,
      orderId: widget.orderId,
      comment: comment,
      rating: rating,
    );
  }

  // Helper method to dismiss keyboard
  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }

  // Handle return key press - add new line instead of dismissing keyboard
  void _handleReturnKey(String value) {
    // Allow multi-line input by not dismissing keyboard
    // The return key will naturally add a new line
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      // Dismiss keyboard before submitting
      _dismissKeyboard();
      setState(() => _isSubmitting = true);

      Map<String, dynamic> feedback = {
        'heardBefore': _heardBefore,
        'ownAlbum': _ownAlbum,
        'likedAlbum': _likedAlbum,
      };

      await _firestoreService.submitFeedback(widget.orderId, feedback);
      if (_review.trim().isNotEmpty && _albumId != null) {
        await _submitReview(_review.trim());
      }
      if (_curatorRating > 0 && _curatorId != null) {
        await _submitCuratorReview(_curatorReview.trim(), _curatorRating);
      }

      await _firestoreService.updateOrderStatus(widget.orderId, 'returned');

      final user = FirebaseAuth.instance.currentUser;
      if (user != null && _flowVersion == 2) {
        await _firestoreService.updateUserDoc(user.uid, {'freeOrder': true});
      }

      setState(() => _isSubmitting = false);

      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: CustomAppBarWidget(title: 'Return Album'),
      body: SafeArea(
        child: GrainyBackgroundWidget(
        child: _isSubmitting || _isLoading
            ? Center(child: CircularProgressIndicator())
            : GestureDetector(
                // Add tap-to-dismiss keyboard functionality
                onTap: _dismissKeyboard,
                child: SingleChildScrollView(
                  physics: ClampingScrollPhysics(),
                  padding: EdgeInsets.only(
                    top: 16.0,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 300.0,
                    left: 16.0,
                    right: 16.0,
                  ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                      if (_albumCoverUrl.isNotEmpty)
                        Image.network(
                          _albumCoverUrl,
                          height: 200,
                          width: 200,
                          errorBuilder: (context, error, stackTrace) => Text(
                            'Failed to load image',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      if (_albumInfo.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 16.0),
                          child: Text(
                            _albumInfo,
                            style: TextStyle(fontSize: 24, color: Colors.white),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      const SizedBox(height: 24),
                      // Dissonant styled feedback form
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4F4F4),
                          border: Border.all(color: Colors.black, width: 2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title bar
                            Container(
                              width: double.infinity,
                              height: 30,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: const BoxDecoration(
                                color: Color(0xFFFFA12C),
                                border: Border(
                                  bottom: BorderSide(color: Colors.black, width: 2),
                                ),
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(4),
                                  topRight: Radius.circular(4),
                                ),
                              ),
                              child: const Text(
                                'Return Feedback',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            // Content area
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  children: [
                                    _buildDropdown(
                                      label: 'Had you heard this album before?',
                                      value: _heardBefore,
                                      onChanged: (val) => setState(() => _heardBefore = val!),
                                      options: ['Yes', 'No'],
                                    ),
                                    const SizedBox(height: 16),
                                    _buildDropdown(
                                      label: 'Do you already own this album?',
                                      value: _ownAlbum,
                                      onChanged: (val) => setState(() => _ownAlbum = val!),
                                      options: ['Yes', 'No'],
                                    ),
                                    const SizedBox(height: 16),
                                    _buildDropdown(
                                      label: 'Did you like this album?',
                                      value: _likedAlbum,
                                      onChanged: (val) => setState(() => _likedAlbum = val!),
                                      options: ['Yes!', 'Meh', 'Nah'],
                                    ),
                                    const SizedBox(height: 16),
                                    // Review field
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Leave a review!',
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontSize: 14,
                                            fontFamily: 'MS Sans Serif',
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Container(
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            border: Border.all(color: Colors.black54, width: 1),
                                          ),
                                          child: TextFormField(
                                            decoration: const InputDecoration(
                                              border: InputBorder.none,
                                              contentPadding: EdgeInsets.all(8),
                                            ),
                                            style: const TextStyle(
                                              color: Colors.black, 
                                              fontSize: 14,
                                              fontFamily: 'MS Sans Serif',
                                            ),
                                            maxLines: 3,
                                            textInputAction: TextInputAction.newline,
                                            onFieldSubmitted: _handleReturnKey,
                                            onChanged: (value) => _review = value,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 20),
                                    // Curator Rating Section
                                    const Text(
                                      'Rate Your Curator',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                        fontFamily: 'MS Sans Serif',
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: List.generate(3, (index) {
                                        return GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              _curatorRating = index + 1.0;
                                            });
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 4),
                                            child: Icon(
                                              index < _curatorRating ? Icons.star : Icons.star_border,
                                              color: const Color(0xFFFFA12C),
                                              size: 28,
                                            ),
                                          ),
                                        );
                                      }),
                                    ),
                                    const SizedBox(height: 12),
                                    // Curator Review Field
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Leave feedback for your curator!',
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontSize: 14,
                                            fontFamily: 'MS Sans Serif',
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Container(
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            border: Border.all(color: Colors.black54, width: 1),
                                          ),
                                          child: TextFormField(
                                            decoration: const InputDecoration(
                                              border: InputBorder.none,
                                              contentPadding: EdgeInsets.all(8),
                                            ),
                                            style: const TextStyle(
                                              color: Colors.black, 
                                              fontSize: 14,
                                              fontFamily: 'MS Sans Serif',
                                            ),
                                            maxLines: 3,
                                            textInputAction: TextInputAction.newline,
                                            onFieldSubmitted: _handleReturnKey,
                                            onChanged: (value) => _curatorReview = value,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 20),
                                    RetroButtonWidget(
                                      text: 'Submit Feedback',
                                      onPressed: _submitForm,
                                      style: RetroButtonStyle.light,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      ],
                    ),
                ),
              ),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required void Function(String?) onChanged,
    required List<String> options,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 14,
            fontFamily: 'MS Sans Serif',
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.black54, width: 1),
          ),
          child: DropdownButtonFormField<String>(
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
            dropdownColor: const Color(0xFFF4F4F4),
            style: const TextStyle(
              color: Colors.black,
              fontSize: 14,
              fontFamily: 'MS Sans Serif',
            ),
            value: value,
            items: options.map((opt) {
              return DropdownMenuItem(
                value: opt,
                child: Text(
                  opt, 
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 14,
                    fontFamily: 'MS Sans Serif',
                  ),
                ),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
