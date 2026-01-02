import 'package:dissonantapp2/main.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/constants.dart';
import '../widgets/grainy_background_widget.dart';
import '../widgets/windows95_window.dart';
import '../widgets/retro_button_widget.dart';
 // Make sure to import MyHomePage

class TasteProfileScreen extends StatefulWidget {
  @override
  _TasteProfileScreenState createState() => _TasteProfileScreenState();
}

class _TasteProfileScreenState extends State<TasteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _musicalBioController = TextEditingController(); // Add controller for text field
  final ScrollController _scrollController = ScrollController(); // Add scroll controller

  // Existing variables
  List<String> _selectedGenres = [];
  String _albumsListened = '';

  // New variables for decades and musical bio
  final List<String> _decades = MusicConstants.availableDecades;
  List<String> _selectedDecades = [];
  String _musicalBio = '';

  final List<String> _genres = MusicConstants.availableGenres;

  final List<String> _albumsListenedOptions = MusicConstants.albumListeningLevels;

  bool _isLoading = true; // Added to track loading state

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _loadUserTasteProfile(user.uid);
    } else {
      // If no user is logged in, set _isLoading to false
      _isLoading = false;
    }
  }

  @override
  void dispose() {
    _musicalBioController.dispose(); // Dispose the controller
    _scrollController.dispose(); // Dispose the scroll controller
    super.dispose();
  }

  void _loadUserTasteProfile(String userId) async {
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        Map<String, dynamic>? data = userDoc.data() as Map<String, dynamic>?;
        if (data != null && data.containsKey('tasteProfile')) {
          Map<String, dynamic> tasteProfile = data['tasteProfile'];
          setState(() {
            _selectedGenres = List<String>.from(tasteProfile['genres'] ?? []);
            _albumsListened = tasteProfile['albumsListened'] ?? '';
            _selectedDecades = List<String>.from(tasteProfile['decades'] ?? []);
            _musicalBio = tasteProfile['musicalBio'] ?? '';
            _musicalBioController.text = _musicalBio; // Set controller text
            _isLoading = false;
          });
        } else {
          setState(() {
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading taste profile: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _submitTasteProfile(String userId) async {
    await FirebaseFirestore.instance.collection('users').doc(userId).update({
      'tasteProfile': {
        'genres': _selectedGenres,
        'albumsListened': _albumsListened,
        'decades': _selectedDecades,
        'musicalBio': _musicalBio,
      },
    });
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => MyHomePage()),
      (Route<dynamic> route) => false,
    );
  }

  // Helper method to dismiss keyboard
  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }

  // Helper method to scroll to text field when focused
  void _scrollToTextField() {
    // Add a delay to ensure the keyboard is fully shown
    Future.delayed(Duration(milliseconds: 350), () {
      if (_scrollController.hasClients && mounted) {
        // Calculate a good scroll position to show the text field above keyboard
        final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
        final targetPosition = _scrollController.position.maxScrollExtent;
        
        // Only scroll if keyboard is actually visible
        if (keyboardHeight > 0 || targetPosition > _scrollController.offset) {
          _scrollController.animateTo(
            targetPosition,
            duration: Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
          );
        }
      }
    });
  }

  Widget _buildRetroCheckboxList(String title, List<String> options, List<String> selectedOptions, Function(String, bool) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
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
            children: options.map((option) {
              final isSelected = selectedOptions.contains(option);
              return Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade300, width: 1),
                  ),
                ),
                child: InkWell(
                  onTap: () => onChanged(option, !isSelected),
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
                            option,
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
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildRetroDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'About how many albums have you listened to?',
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
          child: DropdownButtonFormField<String>(
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            dropdownColor: Color(0xFFF4F4F4),
            value: _albumsListened.isNotEmpty ? _albumsListened : null,
            hint: Text(
              'Select your listening level...',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            items: _albumsListenedOptions.map((String option) {
              return DropdownMenuItem<String>(
                value: option,
                child: Text(
                  option,
                  style: TextStyle(fontSize: 14, color: Colors.black),
                ),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                _albumsListened = newValue ?? '';
              });
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please select an option';
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRetroTextArea() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Is there anything else you\'d like us to know about your music taste?',
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
            controller: _musicalBioController,
            maxLines: 4,
            minLines: 3,
            style: TextStyle(fontSize: 14, color: Colors.black),
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (value) {
              _dismissKeyboard();
            },
            onTap: _scrollToTextField,
            decoration: InputDecoration(
              hintText: 'Tell us about your musical journey...',
              hintStyle: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(12),
            ),
            onChanged: (value) {
              setState(() {
                _musicalBio = value;
              });
            },
          ),
        ),
        // Helpful hint about dismissing keyboard
        Padding(
          padding: EdgeInsets.only(top: 6),
          child: Text(
            'Tap "Done" on keyboard or tap outside to dismiss',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade500,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

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
                      'Loading your taste profile...',
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
      // This is crucial - it tells the scaffold to resize when keyboard appears
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
                    // This ensures the content takes at least the full height minus padding
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
                                title: 'Taste Profile Survey',
                                showCloseButton: false,
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
                                          'Help us curate the perfect albums for you by sharing your music taste!',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                      SizedBox(height: 24),

                                      // Favorite Genres
                                      _buildRetroCheckboxList(
                                        'Select your favorite music genres:',
                                        _genres,
                                        _selectedGenres,
                                        (genre, isSelected) {
                                          setState(() {
                                            if (isSelected) {
                                              _selectedGenres.add(genre);
                                            } else {
                                              _selectedGenres.remove(genre);
                                            }
                                          });
                                        },
                                      ),
                                      SizedBox(height: 24),

                                      // Favorite Decades
                                      _buildRetroCheckboxList(
                                        'Select your favorite decades of music:',
                                        _decades,
                                        _selectedDecades,
                                        (decade, isSelected) {
                                          setState(() {
                                            if (isSelected) {
                                              _selectedDecades.add(decade);
                                            } else {
                                              _selectedDecades.remove(decade);
                                            }
                                          });
                                        },
                                      ),
                                      SizedBox(height: 24),

                                      // Albums Listened
                                      _buildRetroDropdown(),
                                      SizedBox(height: 24),

                                      // Musical Bio
                                      _buildRetroTextArea(),
                                      SizedBox(height: 32),

                                      // Submit Button
                                      Center(
                                        child: RetroButtonWidget(
                                          text: 'Save Taste Profile',
                                          onPressed: () {
                                            // Dismiss keyboard before submitting
                                            _dismissKeyboard();
                                            if (_formKey.currentState?.validate() ?? false) {
                                              _submitTasteProfile(user?.uid ?? '');
                                            }
                                          },
                                        ),
                                      ),
                                      SizedBox(height: 16),
                                    ],
                                  ),
                                ),
                              ),
                              // Extra space at bottom to ensure content can scroll above keyboard
                              SizedBox(height: MediaQuery.of(context).viewInsets.bottom > 0 
                                ? MediaQuery.of(context).viewInsets.bottom + 20
                                : 100),
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
