// registration_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../routes.dart';
import '/services/firestore_service.dart';
import '/services/referral_service.dart';

class RegistrationScreen extends StatefulWidget {
  @override
  _RegistrationScreenState createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestoreService = FirestoreService();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  String username = '';
  String email = '';
  String password = '';
  String confirmPassword = '';
  String country = 'United States';
  String referralCode = '';
  bool isLoading = false;
  String errorMessage = '';

  /// Handles the registration process.
  Future<void> _register() async {
    if (_formKey.currentState!.validate()) {
      // Hide keyboard
      FocusScope.of(context).unfocus();

      setState(() {
        isLoading = true;
        errorMessage = '';
      });

      User? user;

      try {
        // Step 1: Check if the username already exists
        bool usernameExists = await _firestoreService.checkUsernameExists(username);
        if (usernameExists) {
          setState(() {
            isLoading = false;
            errorMessage = 'The username is already taken. Please choose another one.';
          });
          return;
        }

        // Step 2: Create user with Firebase Authentication
        UserCredential userCredential =
            await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        user = userCredential.user;

        if (user == null) {
          throw Exception('User creation failed. Please try again.');
        }

        // Step 3: Update display name and send custom email verification
        await user.updateDisplayName(username);
        await user.reload();
        
        // Send custom professional email verification
        try {
          final callable = FirebaseFunctions.instance.httpsCallable('sendCustomEmailVerification');
          await callable.call({
            'email': email,
            'displayName': username,
          });
          print('Custom verification email sent successfully');
        } catch (emailError) {
          print('Failed to send custom email, falling back to default: $emailError');
          // Fallback to default Firebase email verification
          await user.sendEmailVerification();
        }

        // Step 4: Reserve the username using a batch write
        WriteBatch batch = FirebaseFirestore.instance.batch();

        // Reserve the username
        DocumentReference usernameRef =
            FirebaseFirestore.instance.collection('usernames').doc(username);
        batch.set(usernameRef, {'uid': user.uid});

        // Commit the batch to reserve the username
        await batch.commit();

        // Step 5: Add user details using FirestoreService's addUser method
        // This will create the main user document and the public profile document
        await _firestoreService.addUser(user.uid, username, email, country);

        // Step 6: Process referral code if provided
        if (referralCode.trim().isNotEmpty) {
          print('Attempting to process referral code: ${referralCode.trim()}');
          bool referralProcessed = await ReferralService.processReferral(
            referralCode.trim(), 
            user.uid
          );
          if (!referralProcessed) {
            // Referral code was invalid, but don't fail registration
            print('Invalid referral code: $referralCode');
          } else {
            print('Referral code processed successfully: $referralCode');
          }
        } else {
          print('No referral code provided during registration');
        }

        setState(() {
          isLoading = false;
        });

        // Step 7: Navigate to the email verification screen
        Navigator.pushReplacementNamed(context, emailVerificationRoute);
      } on FirebaseAuthException catch (e) {
        setState(() {
          isLoading = false;
          if (e.code == 'email-already-in-use') {
            errorMessage = 'The email address is already in use by another account.';
          } else if (e.code == 'weak-password') {
            errorMessage = 'The password provided is too weak.';
          } else if (e.code == 'invalid-email') {
            errorMessage = 'The email address is invalid.';
          } else {
            errorMessage = e.message ?? 'Registration failed. Please try again.';
          }
        });
      } catch (e, stackTrace) {
        setState(() {
          isLoading = false;
          errorMessage = 'An unexpected error occurred. Please try again later.';
        });
        print('Registration error: $e');
        print('Stack trace: $stackTrace');
      } finally {
        // If an error occurred and a user was created, delete the user
        if (errorMessage.isNotEmpty && user != null) {
          try {
            await user.delete();
          } catch (deleteError) {
            print('Error deleting user after failure: $deleteError');
          }
        }
      }
    }
  }

  // Validation functions
  String? _validateUsername(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your username';
    }
    if (value.trim().length < 3) {
      return 'Username must be at least 3 characters long';
    }
    // Ensure username contains only letters, numbers, and underscores
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value.trim())) {
      return 'Username can only contain letters, numbers, and underscores';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your email';
    }
    // Basic email regex
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value.trim())) {
      return 'Please enter a valid email';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your password';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters long';
    }
    if (!RegExp(r'^(?=.*[A-Za-z])(?=.*\d).{8,}$').hasMatch(value)) {
      return 'Password must contain letters and numbers';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != password) {
      return 'Passwords do not match';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double formWidth = screenWidth * 0.85; 
    formWidth = formWidth > 350 ? 350 : formWidth; 

         return Scaffold(
       resizeToAvoidBottomInset: true,
       body: Container(
         constraints: BoxConstraints(
           minHeight: MediaQuery.of(context).size.height,
         ),
         decoration: BoxDecoration(
           image: DecorationImage(
             image: AssetImage('assets/welcome_background.png'),
             fit: BoxFit.cover,
           ),
         ),
         child: SafeArea(
           child: SingleChildScrollView(
             padding: EdgeInsets.only(
               left: 16.0,
               right: 16.0,
               top: 16.0,
               bottom: MediaQuery.of(context).viewInsets.bottom + 16.0,
             ),
             child: ConstrainedBox(
               constraints: BoxConstraints(
                 minHeight: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom,
               ),
               child: Column(
                                 children: [
                   Image.asset(
                     'assets/dissonantlogotext.png', // Path to your Dissonant logo
                     height: 60, // Reduced from 80
                   ),
                   SizedBox(height: 12.0), // Reduced from 16.0
                   isLoading
                       ? CircularProgressIndicator()
                       : CustomFormContainer(
                           width: formWidth,
                           child: Padding(
                             padding: const EdgeInsets.all(8.0), // Reduced from 12.0
                             child: Form(
                               key: _formKey,
                               child: Column(
                                 crossAxisAlignment: CrossAxisAlignment.stretch,
                                 children: [
                                   if (errorMessage.isNotEmpty)
                                     Padding(
                                       padding: const EdgeInsets.only(bottom: 6.0), // Reduced from 8.0
                                       child: Text(
                                         errorMessage,
                                         style: TextStyle(color: Colors.red, fontSize: 14), // Smaller text
                                       ),
                                     ),
                                   CustomTextField(
                                     labelText: "Username",
                                     textColor: Colors.black,
                                     onChanged: (value) {
                                       setState(() {
                                         username = value.trim();
                                       });
                                     },
                                     validator: _validateUsername,
                                     isFlat: true,
                                     isCompact: true, // New parameter for compact mode
                                   ),
                                   SizedBox(height: 8.0), // Reduced from 12.0
                                   CustomTextField(
                                     labelText: "Email",
                                     textColor: Colors.black,
                                     onChanged: (value) {
                                       setState(() {
                                         email = value.trim();
                                       });
                                     },
                                     validator: _validateEmail,
                                     isFlat: true,
                                     isCompact: true,
                                   ),
                                   SizedBox(height: 8.0),
                                   CustomTextField(
                                     labelText: "Password",
                                     obscureText: true,
                                     textColor: Colors.black,
                                     onChanged: (value) {
                                       setState(() {
                                         password = value;
                                       });
                                     },
                                     validator: _validatePassword,
                                     isFlat: true,
                                     isCompact: true,
                                   ),
                                   SizedBox(height: 8.0),
                                   CustomTextField(
                                     labelText: "Confirm Password",
                                     obscureText: true,
                                     textColor: Colors.black,
                                     onChanged: (value) {
                                       setState(() {
                                         confirmPassword = value;
                                       });
                                     },
                                     validator: _validateConfirmPassword,
                                     isFlat: true,
                                     isCompact: true,
                                   ),
                                   SizedBox(height: 8.0),
                                   CustomTextField(
                                     labelText: "Referral Code (Optional)",
                                     textColor: Colors.black,
                                     onChanged: (value) {
                                       setState(() {
                                         referralCode = value;
                                       });
                                     },
                                     isFlat: true,
                                     isCompact: true,
                                   ),
                                   SizedBox(height: 6.0), // Reduced from 8.0
                                   Text(
                                     'Have a friend already using DISSONANT? Enter their referral code to earn them a credit!',
                                     style: TextStyle(fontSize: 11, color: Colors.grey), // Smaller text
                                   ),
                                   SizedBox(height: 12.0), // Reduced from 16.0
                                   CustomRetroButtonWidget(
                                     text: 'Sign Up',
                                     onPressed: isLoading ? null : _register,
                                     color: Color(0xFFD24407),
                                     fixedHeight: true,
                                     shadowColor: Colors.black.withOpacity(0.9),
                                   ),
                                 ],
                               ),
                             ),
                           ),
                         ),
                   SizedBox(height: 100), // Increased space at bottom for scrolling
                 ],
               ),
             ),
           ),
         ),
       ),
     );
  }
}

// Below are your custom widgets (CustomFormContainer, CustomTextField, CustomRetroButton, etc.)
// Ensure these are implemented as per your design, as previously shared in your original code.

class CustomScrollViewWithKeyboardPadding extends StatelessWidget {
  final Widget child;

  const CustomScrollViewWithKeyboardPadding({required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: child,
            ),
          ),
        );
      },
    );
  }
}

class CustomWindowFrame extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 40,
      decoration: BoxDecoration(
        color: Color(0xFFFFA12C),
        border: Border(
          bottom: BorderSide(color: Colors.black, width: 2),
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
                Navigator.pop(context);
              },
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black, width: 2),
                  color: Color(0xFFF4F4F4),
                ),
                width: 20,
                height: 20,
                alignment: Alignment.center,
                child: Text(
                  'X',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    height: 1,
                    color: Colors.black,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CustomCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool?> onChanged;

  const CustomCheckbox({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
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
    );
  }
}

class CustomFormContainer extends StatelessWidget {
  final Widget child;
  final double width;

  const CustomFormContainer({required this.child, required this.width});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: EdgeInsets.only(bottom: 12.0),
      decoration: BoxDecoration(
        color: Color(0xFFF4F4F4),
        border: Border.all(color: Colors.black, width: 2),
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.8),
            offset: Offset(4, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomWindowFrame(),
          child,
        ],
      ),
    );
  }
}

class CustomTextField extends StatelessWidget {
  final String labelText;
  final bool obscureText;
  final ValueChanged<String>? onChanged;
  final Color textColor;
  final bool isFlat;
  final bool isCompact;
  final String? Function(String?)? validator;

  const CustomTextField({
    required this.labelText,
    this.obscureText = false,
    this.onChanged,
    this.textColor = Colors.black,
    this.isFlat = false,
    this.isCompact = false,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: isCompact ? 4.0 : 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            labelText,
            style: TextStyle(
              fontSize: isCompact ? 14 : 16, 
              color: textColor
            ),
          ),
          SizedBox(height: isCompact ? 2.0 : 4.0),
          Container(
            decoration: BoxDecoration(
              color: Color(0xFFF5F5F5),
              border: Border.all(color: Colors.black, width: 2),
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.8),
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
                  vertical: isCompact ? 8 : (isFlat ? 12 : 18),
                ),
              ),
              onChanged: onChanged,
              style: TextStyle(color: textColor),
              validator: validator,
            ),
          ),
        ],
      ),
    );
  }
}

class CustomRetroButtonWidget extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final Color color;
  final bool fixedHeight;
  final Color shadowColor;

  const CustomRetroButtonWidget({
    Key? key,
    required this.text,
    this.onPressed,
    this.color = const Color(0xFFD24407),
    this.fixedHeight = false,
    this.shadowColor = Colors.black,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = onPressed != null;

    return GestureDetector(
      onTap: isEnabled ? onPressed : null,
      child: Opacity(
        opacity: isEnabled ? 1.0 : 0.5,
        child: Container(
          width: double.infinity,
          height: fixedHeight ? 45 : 50,
          decoration: BoxDecoration(
            color: color,
            border: Border.all(color: Colors.black, width: 2),
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(
                color: shadowColor.withOpacity(0.9),
                offset: Offset(4, 4),
                blurRadius: 0,
              ),
            ],
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
    );
  }
}
