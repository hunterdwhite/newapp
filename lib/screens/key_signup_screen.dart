import 'package:flutter/material.dart';
import 'registration_screen.dart';
import '../services/waitlist_service.dart';
import '../widgets/retro_button_widget.dart';
import '../widgets/responsive_form_container.dart';
import '../constants/responsive_utils.dart';


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
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/welcome_background.png',
              fit: BoxFit.cover,
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: ResponsiveUtils.getResponsiveHorizontalPadding(context),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/dissonantlogotext.png',
                    height: ResponsiveUtils.isMobile(context) ? 70 : 80,
                  ),
                  SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, mobile: 16, tablet: 20, desktop: 24)),
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
                                      bottom: ResponsiveUtils.getResponsiveSpacing(context, mobile: 8, tablet: 10, desktop: 12)
                                    ),
                                    child: Text(
                                      errorMessage,
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontSize: ResponsiveUtils.getResponsiveFontSize(context, mobile: 14, tablet: 15, desktop: 16),
                                      ),
                                    ),
                                  ),
                                                                 ResponsiveTextField(
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
                                SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, mobile: 16, tablet: 20, desktop: 24)),
                                RetroButtonWidget(
                                  text: 'Verify Key',
                                  onPressed: _verifyKey,
                                  style: RetroButtonStyle.dark,
                                  fixedHeight: true,
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
