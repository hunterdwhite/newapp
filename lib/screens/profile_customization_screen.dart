import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/constants.dart';
import '../widgets/grainy_background_widget.dart';
import '../widgets/windows95_window.dart';
import '../widgets/retro_button_widget.dart';

class ProfileCustomizationScreen extends StatefulWidget {
  @override
  _ProfileCustomizationScreenState createState() => _ProfileCustomizationScreenState();
}

class _ProfileCustomizationScreenState extends State<ProfileCustomizationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _bioController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Profile customization fields
  String _bio = '';
  List<String> _selectedFavoriteGenres = [];
  String? _selectedFavoriteAlbumId;
  String _selectedFavoriteAlbumTitle = '';
  String _selectedFavoriteAlbumCover = '';

  // Available options
  final List<String> _availableGenres = MusicConstants.availableGenres;
  List<Map<String, dynamic>> _userAlbums = [];

  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _bioController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Load existing profile customization
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        final customization = data['profileCustomization'] as Map<String, dynamic>?;
        
        if (customization != null) {
          setState(() {
            _bio = customization['bio'] ?? '';
            _bioController.text = _bio;
            _selectedFavoriteGenres = List<String>.from(customization['favoriteGenres'] ?? []);
            _selectedFavoriteAlbumId = customization['favoriteAlbumId'];
            _selectedFavoriteAlbumTitle = customization['favoriteAlbumTitle'] ?? '';
            _selectedFavoriteAlbumCover = customization['favoriteAlbumCover'] ?? '';
          });
        }
      }

      // Load user's kept albums for favorite album selection
      await _loadUserAlbums(user.uid);

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadUserAlbums(String userId) async {
    try {
      // Get orders where status is 'kept'
      final ordersSnapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'kept')
          .get();

      final albumIds = <String>[];
      for (final doc in ordersSnapshot.docs) {
        final data = doc.data();
        final albumId = data['albumId'] ?? data['details']?['albumId'];
        if (albumId != null) {
          albumIds.add(albumId);
        }
      }

      // Get album details
      final albums = <Map<String, dynamic>>[];
      for (final albumId in albumIds) {
        final albumDoc = await FirebaseFirestore.instance
            .collection('albums')
            .doc(albumId)
            .get();
        
        if (albumDoc.exists) {
          final albumData = albumDoc.data()!;
          albums.add({
            'id': albumId,
            'title': '${albumData['artist']} - ${albumData['albumName']}',
            'coverUrl': albumData['coverUrl'] ?? '',
            'artist': albumData['artist'] ?? '',
            'albumName': albumData['albumName'] ?? '',
          });
        }
      }

      setState(() {
        _userAlbums = albums;
      });
    } catch (e) {
      print('Error loading user albums: $e');
    }
  }

  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }

  void _scrollToTextField() {
    Future.delayed(Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Future<void> _saveCustomization() async {
    if (!_formKey.currentState!.validate()) return;

    _dismissKeyboard();
    setState(() {
      _isSubmitting = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final customizationData = {
        'bio': _bio.trim(),
        'favoriteGenres': _selectedFavoriteGenres,
        'favoriteAlbumId': _selectedFavoriteAlbumId,
        'favoriteAlbumTitle': _selectedFavoriteAlbumTitle,
        'favoriteAlbumCover': _selectedFavoriteAlbumCover,
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'profileCustomization': customizationData});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profile customization saved successfully!')),
      );

      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving customization: $e')),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  Widget _buildBioSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bio',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Color(0xFFF4F4F4),
            border: Border.all(color: Colors.black, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.white,
                offset: Offset(-1, -1),
                blurRadius: 0,
              ),
              BoxShadow(
                color: Colors.grey.shade600,
                offset: Offset(1, 1),
                blurRadius: 0,
              ),
            ],
          ),
          child: TextFormField(
            controller: _bioController,
            maxLines: 3,
            maxLength: 150,
            style: TextStyle(fontSize: 14, color: Colors.black),
            textInputAction: TextInputAction.newline,
            onTap: _scrollToTextField,
            decoration: InputDecoration(
              hintText: 'Tell people a bit about yourself...',
              hintStyle: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(12),
              counterStyle: TextStyle(color: Colors.grey.shade600),
            ),
            onChanged: (value) {
              setState(() {
                _bio = value;
              });
            },
            validator: (value) {
              if (value != null && value.length > 150) {
                return 'Bio must be 150 characters or less';
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFavoriteGenresSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Favorite Genres (select up to 4)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Color(0xFFF4F4F4),
            border: Border.all(color: Colors.black, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                offset: Offset(1, 1),
                blurRadius: 0,
              ),
            ],
          ),
          child: Column(
            children: _availableGenres.map((genre) {
              final isSelected = _selectedFavoriteGenres.contains(genre);
              final canSelect = _selectedFavoriteGenres.length < 4 || isSelected;
              
              return Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade300, width: 1),
                  ),
                ),
                child: InkWell(
                  onTap: canSelect ? () {
                    setState(() {
                      if (isSelected) {
                        _selectedFavoriteGenres.remove(genre);
                      } else {
                        _selectedFavoriteGenres.add(genre);
                      }
                    });
                  } : null,
                  child: Opacity(
                    opacity: canSelect ? 1.0 : 0.5,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.black : Color(0xFFF4F4F4),
                              border: Border.all(color: Colors.black, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.white,
                                  offset: Offset(-1, -1),
                                  blurRadius: 0,
                                ),
                                BoxShadow(
                                  color: Colors.grey.shade600,
                                  offset: Offset(1, 1),
                                  blurRadius: 0,
                                ),
                              ],
                            ),
                            child: isSelected
                                ? Icon(Icons.check, color: Colors.white, size: 12)
                                : null,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              genre,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildFavoriteAlbumSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Favorite Album from Dissonant',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        SizedBox(height: 8),
        if (_userAlbums.isEmpty)
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Color(0xFFF4F4F4),
              border: Border.all(color: Colors.black, width: 1),
            ),
            child: Text(
              'No albums available. Keep an album from an order to select it as your favorite!',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: Color(0xFFF4F4F4),
              border: Border.all(color: Colors.black, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.white,
                  offset: Offset(-1, -1),
                  blurRadius: 0,
                ),
                BoxShadow(
                  color: Colors.grey.shade600,
                  offset: Offset(1, 1),
                  blurRadius: 0,
                ),
              ],
            ),
            child: DropdownButtonFormField<String>(
              decoration: InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              dropdownColor: Color(0xFFF4F4F4),
              value: _selectedFavoriteAlbumId,
              hint: Text(
                'Select your favorite album...',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              items: [
                DropdownMenuItem<String>(
                  value: null,
                  child: Text(
                    'None selected',
                    style: TextStyle(fontSize: 14, color: Colors.black),
                  ),
                ),
                ..._userAlbums.map((album) {
                  return DropdownMenuItem<String>(
                    value: album['id'],
                    child: Container(
                      width: double.infinity,
                      child: Text(
                        album['title'],
                        style: TextStyle(fontSize: 14, color: Colors.black),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  );
                }).toList(),
              ],
              onChanged: (String? newValue) {
                setState(() {
                  _selectedFavoriteAlbumId = newValue;
                  if (newValue != null) {
                    final album = _userAlbums.firstWhere((a) => a['id'] == newValue);
                    _selectedFavoriteAlbumTitle = album['title'];
                    _selectedFavoriteAlbumCover = album['coverUrl'];
                  } else {
                    _selectedFavoriteAlbumTitle = '';
                    _selectedFavoriteAlbumCover = '';
                  }
                });
              },
            ),
          ),
        if (_selectedFavoriteAlbumId != null && _selectedFavoriteAlbumCover.isNotEmpty) ...[
          SizedBox(height: 12),
          Text(
            'Selected Album:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          SizedBox(height: 8),
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Color(0xFFF4F4F4),
              border: Border.all(color: Colors.black, width: 1),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.network(
                    _selectedFavoriteAlbumCover,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 60,
                        height: 60,
                        color: Colors.grey,
                        child: Icon(Icons.music_note, color: Colors.white),
                      );
                    },
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _selectedFavoriteAlbumTitle,
                    style: TextStyle(fontSize: 14, color: Colors.black),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                    softWrap: true,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: GrainyBackgroundWidget(
          child: Center(
            child: Windows95WindowWidget(
              title: 'Loading...',
              showCloseButton: false,
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE46A14)),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Loading your profile...',
                      style: TextStyle(fontSize: 14, color: Colors.black),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: GrainyBackgroundWidget(
        child: SafeArea(
          child: GestureDetector(
            onTap: _dismissKeyboard,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  controller: _scrollController,
                  physics: ClampingScrollPhysics(),
                  padding: EdgeInsets.all(16.0),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 32,
                    ),
                    child: IntrinsicHeight(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: 600),
                          child: Column(
                            children: [
                              Windows95WindowWidget(
                                title: 'Profile Customization',
                                showCloseButton: true,
                                contentPadding: EdgeInsets.all(20),
                                child: Form(
                                  key: _formKey,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      // Welcome message
                                      Container(
                                        padding: EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: Color(0xFFE46A14),
                                          border: Border.all(color: Colors.black, width: 2),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.white,
                                              offset: Offset(-1, -1),
                                              blurRadius: 0,
                                            ),
                                            BoxShadow(
                                              color: Colors.grey.shade600,
                                              offset: Offset(1, 1),
                                              blurRadius: 0,
                                            ),
                                          ],
                                        ),
                                        child: Text(
                                          'Customize your profile to let others know more about your music taste!',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                      SizedBox(height: 24),

                                      // Bio Section
                                      _buildBioSection(),
                                      SizedBox(height: 24),

                                      // Favorite Genres Section
                                      _buildFavoriteGenresSection(),
                                      SizedBox(height: 24),

                                      // Favorite Album Section
                                      _buildFavoriteAlbumSection(),
                                      SizedBox(height: 32),

                                      // Save Button
                                      Center(
                                        child: _isSubmitting
                                            ? CircularProgressIndicator(
                                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE46A14)),
                                              )
                                            : RetroButtonWidget(
                                                text: 'Save Customization',
                                                onPressed: _saveCustomization,
                                              ),
                                      ),
                                      SizedBox(height: 16),
                                    ],
                                  ),
                                ),
                              ),
                              Spacer(),
                              SizedBox(height: 100),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
