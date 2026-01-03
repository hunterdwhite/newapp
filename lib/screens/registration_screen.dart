// registration_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../routes.dart';
import '/services/firestore_service.dart';
import '/services/referral_service.dart';
import '../widgets/responsive_form_container.dart';
import '../constants/responsive_utils.dart';
import '../screens/login_screen.dart'; // For ResponsiveRetroButton

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
    
    final email = value.trim().toLowerCase();
    
    // Basic email regex
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)) {
      return 'Please enter a valid email';
    }
    
    // Check for missing @ symbol variations
    if (!email.contains('@')) {
      return 'Email must contain @';
    }
    
    // Check for double @ or spaces
    if (email.contains('@@') || email.contains(' ')) {
      return 'Please enter a valid email';
    }
    
    // Extract domain for typo checking
    final parts = email.split('@');
    if (parts.length != 2) {
      return 'Please enter a valid email';
    }
    final domain = parts[1];
    
    // Check for common domain typos (must match EXACT domain, not substrings)
    final domainTypos = {
      // Gmail typos
      'gnail.com': 'gmail.com',
      'gmal.com': 'gmail.com',
      'gamil.com': 'gmail.com',
      'gmial.com': 'gmail.com',
      'gmaill.com': 'gmail.com',
      'gmail.con': 'gmail.com',
      'gmail.om': 'gmail.com',
      'gmail.cm': 'gmail.com',
      'gmail.cpm': 'gmail.com',
      'gmail.vom': 'gmail.com',
      'gmail.comm': 'gmail.com',
      'gmailcom': 'gmail.com',
      // Yahoo typos
      'yaho.com': 'yahoo.com',
      'yahooo.com': 'yahoo.com',
      'yahoo.con': 'yahoo.com',
      'yahoo.comm': 'yahoo.com',
      // Hotmail typos
      'hotmal.com': 'hotmail.com',
      'hotmai.com': 'hotmail.com',
      'hotmail.con': 'hotmail.com',
      'hotmail.comm': 'hotmail.com',
      // Outlook typos
      'outlok.com': 'outlook.com',
      'outloo.com': 'outlook.com',
      'outlook.con': 'outlook.com',
      'outlook.comm': 'outlook.com',
      // iCloud typos
      'icoud.com': 'icloud.com',
      'iclod.com': 'icloud.com',
      'icloud.con': 'icloud.com',
      'icloud.comm': 'icloud.com',
      'icloudd.com': 'icloud.com',
    };
    
    // Check exact domain match for typos
    if (domainTypos.containsKey(domain)) {
      final correctDomain = domainTypos[domain]!;
      final suggestion = '${parts[0]}@$correctDomain';
      return 'Did you mean $suggestion?';
    }
    
    // Check for TLD-only typos (ending patterns)
    final tldTypos = {
      '.con': '.com',
      '.cim': '.com',
      '.vom': '.com',
      '.comm': '.com',
      '.coom': '.com',
      '.comn': '.com',
      '.comj': '.com',
      '.ner': '.net',
      '.ney': '.net',
      '.nett': '.net',
      '.ogr': '.org',
      '.orgg': '.org',
    };
    
    for (final typo in tldTypos.entries) {
      if (domain.endsWith(typo.key)) {
        final fixedDomain = domain.substring(0, domain.length - typo.key.length) + typo.value;
        final suggestion = '${parts[0]}@$fixedDomain';
        return 'Did you mean $suggestion?';
      }
    }
    
    // Check domain has at least 2 chars after the dot
    final domainParts = domain.split('.');
    if (domainParts.isNotEmpty && domainParts.last.length < 2) {
      return 'Please check your email domain';
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
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background image - fixed position, fills entire screen
          SizedBox.expand(
            child: Image.asset(
              'assets/welcome_background.png',
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
          ),
          // Scrollable content on top
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: ResponsiveUtils.getResponsiveSpacing(context, mobile: 16, tablet: 24, desktop: 32),
                right: ResponsiveUtils.getResponsiveSpacing(context, mobile: 16, tablet: 24, desktop: 32),
                top: ResponsiveUtils.getResponsiveSpacing(context, mobile: 16, tablet: 20, desktop: 24),
                bottom: ResponsiveUtils.getResponsiveSpacing(context, mobile: 16, tablet: 20, desktop: 24),
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom - 40,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                  Image.asset(
                    'assets/dissonantlogotext.png',
                    height: ResponsiveUtils.isMobile(context) ? 50 : 60,
                  ),
                  SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, mobile: 12, tablet: 16, desktop: 20)),
                  isLoading
                      ? CircularProgressIndicator()
                      : ResponsiveFormContainer(
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (errorMessage.isNotEmpty)
                                  Padding(
                                    padding: EdgeInsets.only(
                                      bottom: ResponsiveUtils.getResponsiveSpacing(context, mobile: 6, tablet: 8, desktop: 10)
                                    ),
                                    child: Text(
                                      errorMessage,
                                      style: TextStyle(
                                        color: Colors.red, 
                                        fontSize: ResponsiveUtils.getResponsiveFontSize(context, mobile: 13, tablet: 14, desktop: 15)
                                      ),
                                    ),
                                  ),
                                ResponsiveTextField(
                                  labelText: "Username",
                                  textColor: Colors.black,
                                  onChanged: (value) {
                                    setState(() {
                                      username = value.trim();
                                    });
                                  },
                                  validator: _validateUsername,
                                  isFlat: true,
                                  isCompact: true,
                                ),
                                ResponsiveTextField(
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
                                  keyboardType: TextInputType.emailAddress,
                                ),
                                ResponsiveTextField(
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
                                ResponsiveTextField(
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
                                ResponsiveTextField(
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
                                SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, mobile: 4, tablet: 6, desktop: 8)),
                                Text(
                                  'Have a friend already using DISSONANT? Enter their referral code to earn them a credit!',
                                  style: TextStyle(
                                    fontSize: ResponsiveUtils.getResponsiveFontSize(context, mobile: 10, tablet: 11, desktop: 12), 
                                    color: Colors.grey
                                  ),
                                ),
                                SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, mobile: 12, tablet: 16, desktop: 20)),
                                ResponsiveRetroButton(
                                  text: 'Sign Up',
                                  onPressed: isLoading ? null : _register,
                                ),
                              ],
                            ),
                          ),
                        ),
                    SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, mobile: 80, tablet: 100, desktop: 120)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
