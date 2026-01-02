import 'package:flutter/material.dart';
import '../services/waitlist_service.dart';
import '../widgets/retro_button_widget.dart';
import '../widgets/responsive_form_container.dart';
import '../constants/responsive_utils.dart';


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
                                 if (successMessage.isNotEmpty)
                                   Padding(
                                     padding: EdgeInsets.only(
                                       bottom: ResponsiveUtils.getResponsiveSpacing(context, mobile: 8, tablet: 10, desktop: 12)
                                     ),
                                     child: Text(
                                       successMessage,
                                       style: TextStyle(
                                         color: Colors.green,
                                         fontSize: ResponsiveUtils.getResponsiveFontSize(context, mobile: 14, tablet: 15, desktop: 16),
                                       ),
                                     ),
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
                                   keyboardType: TextInputType.emailAddress,
                                 ),
                                 SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, mobile: 16, tablet: 20, desktop: 24)),
                                 RetroButtonWidget(
                                   text: 'Join Waitlist',
                                   onPressed: _submitWaitlist,
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
