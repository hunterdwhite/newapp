import 'package:dissonantapp2/main.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_screen.dart'; // Make sure to import MyHomePage

class TasteProfileScreen extends StatefulWidget {
  @override
  _TasteProfileScreenState createState() => _TasteProfileScreenState();
}

class _TasteProfileScreenState extends State<TasteProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  // Existing variables
  List<String> _selectedGenres = [];
  String _albumsListened = '';

  // New variables for decades and musical bio
  final List<String> _decades = ['60s', '70s', '80s', '90s', '00s', '10s', '20s'];
  List<String> _selectedDecades = [];
  String _musicalBio = '';

  final List<String> _genres = [
    'Rock',
    'Pop',
    'Jazz',
    'Classical',
    'Hip-hop',
    'Country',
    'Electronic',
    'Metal',
    'Folk',
    'Experimental',
    'Alternative',
    'R&B'
  ];

  final List<String> _albumsListenedOptions = [
    'Music Enjoyer (0-200)',
    'Music Lover (200-1000)',
    'Music Nerd (1000-4000)',
    'Music Fanatic (4000+)'
  ];

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

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Taste Profile Survey'),
        ),
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Taste Profile Survey'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Favorite Genres
              Text(
                'Select your favorite music genres:',
                style: TextStyle(fontSize: 18),
              ),
              ..._genres.map((genre) {
                return CheckboxListTile(
                  title: Text(genre),
                  value: _selectedGenres.contains(genre),
                  onChanged: (bool? value) {
                    setState(() {
                      if (value == true) {
                        _selectedGenres.add(genre);
                      } else {
                        _selectedGenres.remove(genre);
                      }
                    });
                  },
                );
              }).toList(),
              SizedBox(height: 16.0),

              // Favorite Decades
              Text(
                'Select your favorite decades of music:',
                style: TextStyle(fontSize: 18),
              ),
              ..._decades.map((decade) {
                return CheckboxListTile(
                  title: Text(decade),
                  value: _selectedDecades.contains(decade),
                  onChanged: (bool? value) {
                    setState(() {
                      if (value == true) {
                        _selectedDecades.add(decade);
                      } else {
                        _selectedDecades.remove(decade);
                      }
                    });
                  },
                );
              }).toList(),
              SizedBox(height: 16.0),

              // Albums Listened
              Text(
                'About how many albums have you listened to?',
                style: TextStyle(fontSize: 18),
              ),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                ),
                value: _albumsListened.isNotEmpty ? _albumsListened : null,
                items: _albumsListenedOptions.map((String option) {
                  return DropdownMenuItem<String>(
                    value: option,
                    child: Text(option),
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
              SizedBox(height: 16.0),

              // Musical Bio
              Text(
                'Is there anything else you\'d like us to know about your music taste?',
                style: TextStyle(fontSize: 18),
              ),
              SizedBox(height: 8.0),
              TextFormField(
                initialValue: _musicalBio,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: 'Your Musical Bio',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  setState(() {
                    _musicalBio = value;
                  });
                },
              ),
              SizedBox(height: 16.0),

              // Submit Button
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState?.validate() ?? false) {
                    _submitTasteProfile(user?.uid ?? '');
                  }
                },
                child: Text('Submit'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
