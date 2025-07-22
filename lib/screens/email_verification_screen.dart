// email_verification_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/grainy_background_widget.dart';
import '../widgets/retro_button_widget.dart';
import '../routes.dart';
import '../navigator_service.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({Key? key}) : super(key: key);

  @override
  _EmailVerificationScreenState createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isVerified = false;
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
      setState(() {
        _isVerified = true;
      });
      // Navigate to home screen
      NavigatorService.pushNamed(homeRoute);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background
          GrainyBackgroundWidget(),
          
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
                    style: GoogleFonts.orbitron(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Message
                  Text(
                    'Please check your email and click the verification link to continue.',
                    style: GoogleFonts.orbitron(
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