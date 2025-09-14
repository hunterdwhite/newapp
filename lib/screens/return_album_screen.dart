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
  String _albumCoverUrl = '';
  String _albumInfo = '';
  String? _albumId;
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
        final albumId = orderData['details']['albumId'] as String;
        _albumId = albumId;

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
      body: GrainyBackgroundWidget(
        child: _isSubmitting || _isLoading
            ? Center(child: CircularProgressIndicator())
            : GestureDetector(
                // Add tap-to-dismiss keyboard functionality
                onTap: _dismissKeyboard,
                child: Center(
                  child: SingleChildScrollView(
                    physics: ClampingScrollPhysics(),
                    padding: const EdgeInsets.all(16.0),
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
                      Text(
                        'Return Feedback',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Form(
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
                            TextFormField(
                              decoration: InputDecoration(
                                labelText: 'Leave a review!',
                                labelStyle: TextStyle(color: Colors.white),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.white, width: 2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.orange, width: 2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              style: TextStyle(color: Colors.black, fontSize: 16),
                              maxLines: 3,
                              // Improved keyboard handling
                              textInputAction: TextInputAction.newline,
                              onFieldSubmitted: _handleReturnKey,
                              onChanged: (value) => _review = value,
                            ),
                            const SizedBox(height: 24),
                            RetroButtonWidget(
                              text: 'Submit Feedback',
                              onPressed: _submitForm,
                              style: RetroButtonStyle.light,
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
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white),
        filled: true,
        fillColor: Colors.white10,
        border: OutlineInputBorder(),
      ),
      dropdownColor: Colors.black87,
      style: TextStyle(color: Colors.white),
      value: value,
      items: options.map((opt) {
        return DropdownMenuItem(
          value: opt,
          child: Text(opt, style: TextStyle(color: Colors.white)),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }
}
