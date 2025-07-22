import 'package:flutter/material.dart';
import 'registration_screen.dart';
import '../services/waitlist_service.dart';


class KeySignUpScreen extends StatefulWidget {
  @override
  _KeySignUpScreenState createState() => _KeySignUpScreenState();
}

class _KeySignUpScreenState extends State<KeySignUpScreen> {
  final _formKey = GlobalKey<FormState>();

  bool isLoading = false;
  String errorMessage = '';
  String inviteKey = '';

  Future<void> _verifyKey() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    FocusScope.of(context).unfocus();

    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      // Check Firestore for a doc in 'waitlist' with this inviteKey && status='approved'
      final bool isValid = await WaitlistService.verifyInviteKey(inviteKey);

      if (isValid) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => RegistrationScreen()),
        );
      } else {
        setState(() {
          errorMessage = 'Invalid or inactive key. Please try again later.';
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error verifying key: $e';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  String? _validateKey(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your invite key';
    }
    return null; // pass
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double formWidth = screenWidth * 0.85;
    formWidth = formWidth > 350 ? 350 : formWidth;

    return Scaffold(
      body: Stack(
        children: [
          // Background
          Positioned.fill(
            child: Image.asset(
              'assets/welcome_background.png',
              fit: BoxFit.cover,
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  // Optional Logo
                  Image.asset(
                    'assets/dissonantlogotext.png',
                    height: 80,
                  ),
                  SizedBox(height: 16.0),

                  if (isLoading)
                    CircularProgressIndicator()
                  else
                    CustomFormContainer(
                      width: formWidth,
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (errorMessage.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: Text(
                                    errorMessage,
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              CustomTextField(
                                labelText: "Invite Key",
                                textColor: Colors.black,
                                onChanged: (value) {
                                  setState(() {
                                    inviteKey = value.trim();
                                  });
                                },
                                validator: _validateKey,
                                isFlat: true,
                              ),
                              SizedBox(height: 16.0),
                              CustomRetroButtonWidget(
                                text: 'Verify Key',
                                onPressed: _verifyKey,
                                color: Color(0xFFD24407),
                                fixedHeight: true,
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
