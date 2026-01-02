import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dissonantapp2/widgets/retro_button_widget.dart';
import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'waitlist_signup_screen.dart';
import 'key_signup_screen.dart';
import 'registration_screen.dart'; // <--- Make sure to import or create
import '../widgets/carousel_widget.dart'; // Adjust as needed
import '../constants/responsive_utils.dart';

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
        if (albumData['coverUrl'] != null) {
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
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.orange)),
      );
    }

    final isWaitlistMode = _waitlistEnabled == true;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background image - properly fills entire screen
          SizedBox.expand(
            child: Image.asset(
              'assets/waitlistwelcome.png',
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
          ),
          SafeArea(
            child: Padding(
              padding: ResponsiveUtils.getResponsiveHorizontalPadding(context),
              child: Column(
                children: [
                  SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, mobile: 60, tablet: 80, desktop: 100)),
                  // Logo with responsive sizing
                  Center(
                    child: Image.asset(
                      'assets/dissonantlogotext.png',
                      height: ResponsiveUtils.isMobile(context) ? 60 : 70,
                      width: ResponsiveUtils.isMobile(context) ? 300 : 350,
                      fit: BoxFit.contain,
                    ),
                  ),
                  Spacer(flex: 1),

                  // If waitlist is ON, show "Due to high demand..." and a big "Join Waitlist" button
                  if (isWaitlistMode) ...[
                    Padding(
                      padding: ResponsiveUtils.getResponsiveHorizontalPadding(context,
                        mobile: 16, tablet: 32, desktop: 48),
                      child: Text(
                        'Due to high demand, account creation is currently suspended.\n'
                        'Join the waitlist and we will let you in as room opens up!',
                        style: TextStyle(
                          fontSize: ResponsiveUtils.getResponsiveFontSize(context, 
                            mobile: 16, tablet: 18, desktop: 20),
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, mobile: 16, tablet: 20, desktop: 24)),
                    RetroButtonWidget(
                      text: 'Join Waitlist',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => WaitlistSignUpScreen()),
                        );
                      },
                    ),
                    Spacer(flex: 1),
                  ],

                  // Carousel or loading indicator with responsive height
                  if (_isLoading)
                    Center(child: CircularProgressIndicator())
                  else if (_albumImages.isEmpty)
                    Text(
                      'No recent albums found.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: ResponsiveUtils.getResponsiveFontSize(context, mobile: 14, tablet: 16, desktop: 18),
                      ),
                    )
                  else
                    Container(
                      height: ResponsiveUtils.isMobile(context) ? 220 : 270,
                      child: CarouselWidget(imgList: _albumImages),
                    ),

                  Spacer(flex: 1),

                  // Responsive button layout
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: ResponsiveUtils.getContainerMaxWidth(context),
                    ),
                    child: Column(
                      children: [
                        // If waitlist is ON => smaller "Sign Up with Key" / "Log In" 
                        // If waitlist is OFF => bigger "Sign Up" / "Log In"
                        if (isWaitlistMode) ...[
                          // Waitlist ON => show "Sign Up with Key" and "Log In" as before
                          RetroButtonWidget(
                            text: 'Sign Up with Key',
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => KeySignUpScreen()),
                              );
                            },
                          ),
                          SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, mobile: 12, tablet: 16, desktop: 20)),
                          RetroButtonWidget(
                            text: 'Log In',
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => LoginScreen()),
                              );
                            },
                          ),
                        ] else ...[
                          // Waitlist OFF => bigger "Sign Up" and bigger "Log In"
                          RetroButtonWidget(
                            text: 'Sign Up',
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => RegistrationScreen()),
                              );
                            },
                          ),
                          SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, mobile: 12, tablet: 16, desktop: 20)),
                          RetroButtonWidget(
                            text: 'Log In',
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => LoginScreen()),
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  ),

                  Spacer(flex: 2),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Same custom "retro style" button as before
