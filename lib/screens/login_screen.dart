import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dissonantapp2/main.dart';
import 'package:dissonantapp2/screens/taste_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Removed flutter_secure_storage as it's no longer used
import 'email_verification_screen.dart';
import 'forgot_password_screen.dart';
import '../widgets/responsive_form_container.dart';
import '../constants/responsive_utils.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _auth = FirebaseAuth.instance;
  final _formKey = GlobalKey<FormState>();
  // Removed _storage as we are no longer storing credentials locally
  String? _email;
  String? _password;
  bool _rememberMe =
      false; // Optional: Can be used to manage Firebase Auth persistence
  bool _isLoading = false;
  String? _errorMessage;

  // Validators
  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your email';
    }
    // Basic email regex
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
      return 'Please enter a valid email';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your password';
    }
    return null; // Add more password validations if necessary
  }

  void _login() async {
    if (_formKey.currentState!.validate()) {
      // Hide keyboard
      FocusScope.of(context).unfocus();

      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        // Sign in with Firebase Auth
        UserCredential userCredential = await _auth.signInWithEmailAndPassword(
          email: _email!,
          password: _password!,
        );

        User? user = userCredential.user;

        if (user != null) {
          await user.reload(); // Reload to get the latest user data
          user = _auth.currentUser;

          if (user != null && user.emailVerified) {
            // Email is verified, proceed to check user profile
            final userProfile = await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get();

            if (userProfile.exists &&
                (userProfile.data()?['tasteProfile'] == null ||
                    userProfile.data()?['tasteProfile'] == '')) {
              // Redirect to TasteProfileScreen if tasteProfile is not set
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => TasteProfileScreen()),
                (Route<dynamic> route) => false,
              );
            } else {
              // Redirect to HomeScreen if tasteProfile exists
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => MyHomePage()),
                (Route<dynamic> route) => false,
              );
            }
          } else {
            // Email not verified, navigate to EmailVerificationScreen
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                  builder: (context) => EmailVerificationScreen()),
              (Route<dynamic> route) => false,
            );
          }
        } else {
          setState(() {
            _errorMessage = 'User not found. Please try again.';
          });
        }
      } on FirebaseAuthException catch (e) {
        String message;
        switch (e.code) {
          case 'user-not-found':
            message = 'No user found for that email.';
            break;
          case 'wrong-password':
            message = 'Wrong password provided.';
            break;
          case 'invalid-email':
            message = 'The email address is badly formatted.';
            break;
          case 'user-disabled':
            message = 'The user account has been disabled.';
            break;
          case 'too-many-requests':
            message = 'Too many requests. Try again later.';
            break;
          case 'invalid-credential':
            message =
                'The supplied auth credential is incorrect, malformed, or has expired.';
            break;
          default:
            message = 'An unknown error occurred.';
        }
        setState(() {
          _errorMessage = message;
        });
      } catch (e) {
        // Optionally log the error using Firebase Crashlytics or another logging service
        setState(() {
          _errorMessage =
              'An unexpected error occurred. Please try again later.';
        });
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Optional: Implement Firebase Auth persistence based on _rememberMe
  @override
  void initState() {
    super.initState();
    _initializeAuthPersistence();
  }

  void _initializeAuthPersistence() async {
    // You can set Firebase Auth persistence here if needed
    // For mobile apps, Firebase handles persistence by default
    // This is more relevant for web apps
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          SizedBox.expand(
            child: Image.asset(
              'assets/welcome_background.png',
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: ResponsiveUtils.getResponsiveHorizontalPadding(context),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo with responsive sizing
                  Image.asset(
                    'assets/dissonantlogotext.png', // Path to your Dissonant logo
                    height: ResponsiveUtils.isMobile(context) ? 70 : 80,
                  ),
                  SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, mobile: 16, tablet: 20, desktop: 24)),
                  _isLoading
                      ? CircularProgressIndicator()
                      : ResponsiveFormContainer(
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (_errorMessage != null)
                                  Padding(
                                    padding: EdgeInsets.only(
                                      bottom: ResponsiveUtils.getResponsiveSpacing(context, mobile: 8, tablet: 10, desktop: 12)
                                    ),
                                    child: Text(
                                      _errorMessage!,
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontSize: ResponsiveUtils.getResponsiveFontSize(context, mobile: 14, tablet: 15, desktop: 16),
                                      ),
                                    ),
                                  ),
                                ResponsiveTextField(
                                  labelText: "Email",
                                  textColor: Colors.black,
                                  onChanged: (value) {
                                    setState(() {
                                      _email = value;
                                    });
                                  },
                                  validator: _validateEmail,
                                  isFlat: true,
                                  keyboardType: TextInputType.emailAddress,
                                ),
                                ResponsiveTextField(
                                  labelText: "Password",
                                  obscureText: true,
                                  textColor: Colors.black,
                                  onChanged: (value) {
                                    setState(() {
                                      _password = value;
                                    });
                                  },
                                  validator: _validatePassword,
                                  isFlat: true,
                                ),
                                SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, mobile: 8, tablet: 12, desktop: 16)),
                                // Remember me and forgot password row with responsive layout
                                ResponsiveUtils.isMobile(context) 
                                  ? Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        ResponsiveCheckbox(
                                          value: _rememberMe,
                                          onChanged: (value) {
                                            setState(() {
                                              _rememberMe = value!;
                                            });
                                          },
                                          label: 'Remember me',
                                        ),
                                        SizedBox(height: 8),
                                        TextButton(
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                  builder: (context) =>
                                                      ForgotPasswordScreen()),
                                            );
                                          },
                                          child: Text(
                                            'Forgot Password?',
                                            style: TextStyle(
                                              color: Colors.blue,
                                              fontSize: ResponsiveUtils.getResponsiveFontSize(context, mobile: 14, tablet: 15, desktop: 16),
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        ResponsiveCheckbox(
                                          value: _rememberMe,
                                          onChanged: (value) {
                                            setState(() {
                                              _rememberMe = value!;
                                            });
                                          },
                                          label: 'Remember me',
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                  builder: (context) =>
                                                      ForgotPasswordScreen()),
                                            );
                                          },
                                          child: Text(
                                            'Forgot Password?',
                                            style: TextStyle(
                                              color: Colors.blue,
                                              fontSize: ResponsiveUtils.getResponsiveFontSize(context, mobile: 14, tablet: 15, desktop: 16),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, mobile: 16, tablet: 20, desktop: 24)),
                                ResponsiveRetroButton(
                                  text: 'Log In',
                                  onPressed: _isLoading ? null : _login,
                                ),
                              ],
                            ),
                          ),
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Responsive checkbox widget
class ResponsiveCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool?> onChanged;
  final String label;

  const ResponsiveCheckbox({
    Key? key,
    required this.value,
    required this.onChanged,
    required this.label,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Transform.scale(
          scale: ResponsiveUtils.isMobile(context) ? 0.9 : 1.0,
          child: Checkbox(
            value: value,
            onChanged: onChanged,
            fillColor: MaterialStateProperty.all(Colors.white),
            checkColor: Colors.black,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.black,
            fontSize: ResponsiveUtils.getResponsiveFontSize(context, mobile: 14, tablet: 15, desktop: 16),
          ),
        ),
      ],
    );
  }
}

// Responsive retro button wrapper
class ResponsiveRetroButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;

  const ResponsiveRetroButton({
    Key? key,
    required this.text,
    this.onPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: ResponsiveUtils.isMobile(context) ? 48 : 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Color(0xFFD24407),
          foregroundColor: Colors.white,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
            side: BorderSide(color: Colors.black, width: 2),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: ResponsiveUtils.getResponsiveFontSize(context, mobile: 16, tablet: 18, desktop: 18),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
