import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'waitlist_signup_screen.dart';
import 'key_signup_screen.dart';
import 'registration_screen.dart'; // <--- Make sure to import or create
import '../widgets/carousel_widget.dart'; // Adjust as needed

class WelcomeScreen extends StatefulWidget {
  @override
  _WelcomeScreenState createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _isLoading = true;
  List<String> _albumImages = [];

  // This stores the flag from Firestore. null means "not yet loaded."
  bool? _waitlistEnabled;

  @override
  void initState() {
    super.initState();
    _fetchWaitlistFlag();
    _fetchRecentAlbumImages();
  }

  /// Reads the "flags/welcomeScreen" doc and checks "waitlistEnabled".
  /// If waitlistEnabled == 1, set _waitlistEnabled = true, else false.
  Future<void> _fetchWaitlistFlag() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('flags')
          .doc('welcomeScreen')
          .get();

      if (doc.exists) {
        final data = doc.data();
        if (data != null && data['waitlistEnabled'] == 1) {
          setState(() {
            _waitlistEnabled = true;
          });
        } else {
          setState(() {
            _waitlistEnabled = false;
          });
        }
      } else {
        // Document doesn't exist; default to not showing waitlist
        setState(() {
          _waitlistEnabled = false;
        });
      }
    } catch (e) {
      print('Error fetching waitlist flag: $e');
      // In case of error, fallback to false
      setState(() {
        _waitlistEnabled = false;
      });
    }
  }

  Future<void> _fetchRecentAlbumImages() async {
    try {
      final albumsSnapshot = await FirebaseFirestore.instance
          .collection('albums')
          .orderBy('createdAt', descending: true)
          .limit(25)
          .get();

      List<String> imageUrls = [];
      for (var albumDoc in albumsSnapshot.docs) {
        final albumData = albumDoc.data();
        if (albumData != null && albumData['coverUrl'] != null) {
          imageUrls.add(albumData['coverUrl'] as String);
        }
      }

      setState(() {
        _albumImages = imageUrls;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching album images: $e');
      setState(() {
        _albumImages = [];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // If the waitlist flag is still null, we haven't loaded it yet
    if (_waitlistEnabled == null) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final isWaitlistMode = _waitlistEnabled == true;

    return Scaffold(
      body: Stack(
        children: [
          // Background image
          Positioned.fill(
            child: Image.asset(
              'assets/waitlistwelcome.png',
              fit: BoxFit.contain, // or BoxFit.cover
            ),
          ),
          Column(
            children: [
              SizedBox(height: 80),
              // Logo
              Center(
                child: Image.asset(
                  'assets/dissonantlogotext.png',
                  height: 70,
                  width: 350,
                ),
              ),
              Spacer(flex: 1),

              // If waitlist is ON, show "Due to high demand..." and a big "Join Waitlist" button
              if (isWaitlistMode) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Text(
                    'Due to high demand, account creation is currently suspended.\n'
                    'Join the waitlist and we will let you in as room opens up!',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(height: 16),
                CustomRetroButton(
                  text: 'Join Waitlist',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => WaitlistSignUpScreen()),
                    );
                  },
                  width: 350,
                  height: 60,
                  fontSize: 22,
                ),
                Spacer(flex: 1),
              ],

              // Carousel or loading indicator
              if (_isLoading)
                Center(child: CircularProgressIndicator())
              else if (_albumImages.isEmpty)
                Text(
                  'No recent albums found.',
                  style: TextStyle(color: Colors.white),
                )
              else
                CarouselWidget(imgList: _albumImages),

              Spacer(flex: 1),

              // If waitlist is ON => smaller "Sign Up with Key" / "Log In" 
              // If waitlist is OFF => bigger "Sign Up" / "Log In"
              if (isWaitlistMode) ...[
                // Waitlist ON => show "Sign Up with Key" and "Log In" as before
                CustomRetroButton(
                  text: 'Sign Up with Key',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => KeySignUpScreen()),
                    );
                  },
                  width: 220,
                  height: 50,
                  fontSize: 16,
                ),
                SizedBox(height: 16),
                CustomRetroButton(
                  text: 'Log In',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => LoginScreen()),
                    );
                  },
                  width: 220,
                  height: 50,
                  fontSize: 16,
                ),
              ] else ...[
                // Waitlist OFF => bigger "Sign Up" and bigger "Log In"
                CustomRetroButton(
                  text: 'Sign Up',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => RegistrationScreen()),
                    );
                  },
                  width: 280,
                  height: 60,
                  fontSize: 20,
                ),
                SizedBox(height: 16),
                CustomRetroButton(
                  text: 'Log In',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => LoginScreen()),
                    );
                  },
                  width: 280,
                  height: 60,
                  fontSize: 20,
                ),
              ],

              Spacer(flex: 2),
            ],
          ),
        ],
      ),
    );
  }
}

/// Same custom "retro style" button as before
class CustomRetroButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final double width;
  final double height;
  final double fontSize;

  const CustomRetroButton({
    required this.text,
    required this.onPressed,
    this.width = 350,
    this.height = 60,
    this.fontSize = 22,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Stack(
        children: [
          // Bottom shadow layer
          Container(
            width: width,
            height: height,
            margin: EdgeInsets.only(top: 4, left: 4),
            decoration: BoxDecoration(
              color: Colors.black,  // shadow color
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          // Top button layer
          Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: Color(0xFFF5F5F5),
              border: Border.all(color: Colors.black, width: 2),
              borderRadius: BorderRadius.circular(4),
            ),
            alignment: Alignment.center,
            child: Text(
              text,
              style: TextStyle(
                color: Colors.black,
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
