import 'package:dissonantapp2/screens/login_screen.dart';
import 'package:flutter/material.dart';
import '../services/waitlist_service.dart';


class WaitlistSignUpScreen extends StatefulWidget {
  @override
  _WaitlistSignUpScreenState createState() => _WaitlistSignUpScreenState();
}

class _WaitlistSignUpScreenState extends State<WaitlistSignUpScreen> {
  final _formKey = GlobalKey<FormState>();

  bool isLoading = false;
  String errorMessage = '';
  String successMessage = '';
  String email = '';

  Future<void> _submitWaitlist() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    FocusScope.of(context).unfocus();

    setState(() {
      isLoading = true;
      errorMessage = '';
      successMessage = '';
    });

    try {
      await WaitlistService.addEmailToWaitlist(email);
      setState(() {
        successMessage = 'You have been added to the waitlist!';
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter an email address';
    }
    // Basic email regex
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value.trim())) {
      return 'Please enter a valid email';
    }
    return null; // Valid
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
                              if (successMessage.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: Text(
                                    successMessage,
                                    style: TextStyle(color: Colors.green),
                                  ),
                                ),
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
                              ),
                              SizedBox(height: 16.0),
                              CustomRetroButtonWidget(
                                text: 'Join Waitlist',
                                onPressed: _submitWaitlist,
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
