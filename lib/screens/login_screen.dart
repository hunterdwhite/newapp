import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dissonantapp2/main.dart';
import 'package:dissonantapp2/screens/taste_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Removed flutter_secure_storage as it's no longer used
import 'email_verification_screen.dart';
import 'forgot_password_screen.dart';

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
    // Make UI responsive by using MediaQuery
    double screenWidth = MediaQuery.of(context).size.width;
    double formWidth = screenWidth * 0.85; // 85% of screen width
    formWidth = formWidth > 350 ? 350 : formWidth; // Max width of 350

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/welcome_background.png', // Path to your background image
              fit: BoxFit.cover,
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  Image.asset(
                    'assets/dissonantlogotext.png', // Path to your Dissonant logo
                    height: 80, // Adjust height as needed
                  ),
                  SizedBox(height: 16.0),
                  _isLoading
                      ? CircularProgressIndicator()
                      : CustomFormContainer(
                          width: formWidth,
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (_errorMessage != null)
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 8.0),
                                      child: Text(
                                        _errorMessage!,
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                  CustomTextField(
                                    labelText: "Email",
                                    textColor: Colors.black,
                                    onChanged: (value) {
                                      setState(() {
                                        _email = value;
                                      });
                                    },
                                    validator:
                                        _validateEmail, // Added validation
                                    isFlat: true, // Flatter input field
                                  ),
                                  SizedBox(height: 12.0),
                                  CustomTextField(
                                    labelText: "Password",
                                    obscureText: true,
                                    textColor: Colors.black,
                                    onChanged: (value) {
                                      setState(() {
                                        _password = value;
                                      });
                                    },
                                    validator:
                                        _validatePassword, // Added validation
                                    isFlat: true, // Flatter input field
                                  ),
                                  SizedBox(height: 12.0),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          CustomCheckbox(
                                            value: _rememberMe,
                                            onChanged: (value) {
                                              setState(() {
                                                _rememberMe = value!;
                                              });
                                            },
                                            label: 'Remember me',
                                          ),
                                        ],
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
                                        child: Text('Forgot Password?',
                                            style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey)),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 8.0),
                                  CustomRetroButtonWidget(
                                    text: 'Log in',
                                    onPressed: _isLoading ? null : _login,
                                    color: Color(
                                        0xFFD24407), // Updated color for the Log in button
                                    fixedHeight:
                                        true, // Ensure the button height is constrained
                                    shadowColor: Colors.black.withOpacity(
                                        0.9), // Darker shadow for the button
                                  ),
                                ],
                              ),
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

// Updated CustomCheckbox with Semantic Labels
class CustomCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool?> onChanged;
  final String label;

  const CustomCheckbox({
    required this.value,
    required this.onChanged,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      checked: value,
      child: GestureDetector(
        onTap: () => onChanged(!value),
        child: Row(
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: value ? Colors.orange : Colors.white,
                border: Border.all(color: Colors.black, width: 2),
                borderRadius: BorderRadius.circular(2),
              ),
              child: value
                  ? Icon(
                      Icons.check,
                      size: 12,
                      color: Colors.black,
                    )
                  : null,
            ),
            SizedBox(width: 4.0), // Space between checkbox and label
            Text(
              label,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

// Updated CustomFormContainer to be more flexible
class CustomFormContainer extends StatelessWidget {
  final Widget child;
  final double width;

  const CustomFormContainer({required this.child, required this.width});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: EdgeInsets.only(
          bottom: 12.0), // Adjusted padding to remove extra white space
      decoration: BoxDecoration(
        color: Color(0xFFF4F4F4),
        border: Border.all(
            color: Colors.black, width: 2), // Uniform thin black outline
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.8), // Darker shadow
            offset: Offset(4, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize
            .min, // Ensure the column only takes up the necessary vertical space
        children: [
          CustomWindowFrame(), // Including window frame with the correct border
          child,
        ],
      ),
    );
  }
}

// CustomTextField updated to accept validator
class CustomTextField extends StatelessWidget {
  final String labelText;
  final bool obscureText;
  final ValueChanged<String>? onChanged;
  final Color textColor;
  final bool isFlat;
  final String? Function(String?)? validator;

  const CustomTextField({
    required this.labelText,
    this.obscureText = false,
    this.onChanged,
    this.textColor = Colors.black,
    this.isFlat = false, // Flatter input field
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin:
          const EdgeInsets.only(bottom: 8.0), // Space between label and input
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            labelText,
            style: TextStyle(
              fontSize: 16,
              color: textColor,
            ),
          ),
          SizedBox(height: 4.0), // Space between label and input
          Container(
            decoration: BoxDecoration(
              color: Color(0xFFF5F5F5),
              border: Border.all(color: Colors.black, width: 2),
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.8), // Darker shadow
                  offset: Offset(3, 3),
                  blurRadius: 0,
                ),
              ],
            ),
            child: TextFormField(
              obscureText: obscureText,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.transparent,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: isFlat ? 12 : 18), // Flatter input field
              ),
              onChanged: onChanged,
              style: TextStyle(color: textColor),
              validator: validator, // Added validator
            ),
          ),
        ],
      ),
    );
  }
}

// Updated CustomRetroButton to handle disabled state
class CustomRetroButtonWidget extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed; // Made nullable to handle disabled state
  final Color color;
  final bool fixedHeight;
  final Color shadowColor; // Custom shadow color

  const CustomRetroButtonWidget({
    required this.text,
    required this.onPressed,
    this.color = const Color(0xFFD24407), // Updated color for the Log in button
    this.fixedHeight = false, // Allow control over height adjustment
    this.shadowColor = Colors.black, // Default shadow color
  });

  @override
  Widget build(BuildContext context) {
    // Adjust opacity based on whether the button is enabled
    final bool isEnabled = onPressed != null;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: shadowColor.withOpacity(0.9), // Darker shadow color
            offset: Offset(
                4, 4), // Slightly larger offset for more pronounced effect
            blurRadius: 0,
          ),
        ],
        borderRadius: BorderRadius.circular(4),
      ),
      child: GestureDetector(
        onTap: isEnabled ? onPressed : null,
        child: Opacity(
          opacity: isEnabled ? 1.0 : 0.5, // Visual feedback for disabled state
          child: Container(
            height: fixedHeight ? 45 : 50, // Adjust height to prevent overflow
            decoration: BoxDecoration(
              color: color,
              border: Border.all(color: Colors.black, width: 2),
              borderRadius: BorderRadius.circular(4),
            ),
            alignment: Alignment.center,
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// CustomWindowFrame remains unchanged
class CustomWindowFrame extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 40,
      decoration: BoxDecoration(
        color: Color(0xFFFFA12C), // Updated color for the top bar
        border: Border(
          bottom: BorderSide(
              color: Colors.black,
              width: 2), // Only bottom border for the orange bar
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(4),
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: 8.0,
            top: 8.0,
            child: GestureDetector(
              onTap: () {
                Navigator.pop(context); // Pop the current page off the stack
              },
              child: Container(
                decoration: BoxDecoration(
                  border:
                      Border.all(color: Colors.black, width: 2), // Black border
                  color: Color(
                      0xFFF4F4F4), // Off-white color matching the Figma design
                ),
                width: 20,
                height: 20,
                alignment: Alignment
                    .center, // Center the content both horizontally and vertically
                child: Text(
                  'X',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14, // Slightly adjust the font size
                    height:
                        1, // Adjust line height to better center the text vertically
                    color: Colors.black, // Black "X"
                  ),
                  textAlign: TextAlign.center, // Center the text within the box
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
