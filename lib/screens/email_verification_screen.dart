// email_verification_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/grainy_background_widget.dart';
import '../widgets/retro_button_widget.dart';
import 'how_it_works_screen.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({Key? key}) : super(key: key);

  @override
  _EmailVerificationScreenState createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _checkEmailVerification();
  }

  _checkEmailVerification() async {
    await FirebaseAuth.instance.currentUser?.reload();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.emailVerified) {
      // Navigate to how it works screen for new users
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => HowItWorksPage(showExitButton: false)),
        (Route<dynamic> route) => false,
      );
    }
  }

  _sendVerificationEmail() async {
    setState(() {
      _isSending = true;
    });

    try {
      final user = _auth.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verification email sent!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending verification email')),
      );
    }

    setState(() {
      _isSending = false;
    });
  }

  _signOutAndRestart() async {
    await _auth.signOut();
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background - fills entire screen
          SizedBox.expand(
            child: GrainyBackgroundWidget(
              child: Container(color: Colors.transparent),
            ),
          ),
          
          // Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Spacer(),
                  
                  // Title
                  Text(
                    'Verify Your Email',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Show current email
                  Text(
                    _auth.currentUser?.email ?? '',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFFFA500),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Message
                  Text(
                    'Please check your email and click the verification link to continue.\n\nDon\'t see it? Check your spam folder.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Resend email button
                  RetroButtonWidget(
                    text: _isSending ? 'Sending...' : 'Resend Email',
                    onPressed: _isSending ? null : _sendVerificationEmail,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Check verification button
                  RetroButtonWidget(
                    text: 'I\'ve Verified',
                    onPressed: _checkEmailVerification,
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Wrong email? Sign out option
                  TextButton(
                    onPressed: _signOutAndRestart,
                    child: Text(
                      'Wrong email? Sign out and try again',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white54,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                                    
                  const Spacer(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}