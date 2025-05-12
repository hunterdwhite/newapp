import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/grainy_background_widget.dart'; // Import the BackgroundWidget
import '../widgets/retro_button_widget.dart'; // Import the RetroButtonWidget

class ChangePasswordScreen extends StatefulWidget {
  @override
  _ChangePasswordScreenState createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers for form fields
  final TextEditingController _currentPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();

  // Firebase Auth instance
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // To show loading indicator
  bool _isLoading = false;

  // For password visibility toggle
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  // Function to update password
  Future<void> _updatePassword() async {
    if (_formKey.currentState?.validate() ?? false) {
      try {
        setState(() {
          _isLoading = true;
        });

        User? user = _auth.currentUser;

        // Re-authenticate the user
        await _reAuthenticate();

        // Update password
        await user?.updatePassword(_newPasswordController.text.trim());

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Password updated successfully')),
        );

        // Clear the form
        _currentPasswordController.clear();
        _newPasswordController.clear();
      } on FirebaseAuthException catch (e) {
        _showError(e.message ?? 'An error occurred while updating password');
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Function to re-authenticate the user
  Future<void> _reAuthenticate() async {
    User? user = _auth.currentUser;
    String email = user?.email ?? '';

    AuthCredential credential = EmailAuthProvider.credential(
      email: email,
      password: _currentPasswordController.text.trim(),
    );

    await user?.reauthenticateWithCredential(credential);
  }

  // Function to show error messages
  void _showError(String errorMessage) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(errorMessage)),
    );
  }

  // Main build method
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Change Password'),
        backgroundColor: Colors.black87,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : BackgroundWidget(
              child: _buildChangePasswordForm(),
            ),
    );
  }

  // Widget for the form
  Widget _buildChangePasswordForm() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            // Current Password Field
            TextFormField(
              controller: _currentPasswordController,
              decoration: InputDecoration(
                labelText: 'Current Password',
                labelStyle: TextStyle(color: Colors.white70),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureCurrentPassword ? Icons.visibility_off : Icons.visibility,
                    color: Colors.white70,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureCurrentPassword = !_obscureCurrentPassword;
                    });
                  },
                ),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white38),
                ),
              ),
              style: TextStyle(color: Colors.white),
              obscureText: _obscureCurrentPassword,
              validator: _validateCurrentPassword,
            ),
            SizedBox(height: 20),
            // New Password Field
            TextFormField(
              controller: _newPasswordController,
              decoration: InputDecoration(
                labelText: 'New Password',
                labelStyle: TextStyle(color: Colors.white70),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureNewPassword ? Icons.visibility_off : Icons.visibility,
                    color: Colors.white70,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureNewPassword = !_obscureNewPassword;
                    });
                  },
                ),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white38),
                ),
              ),
              style: TextStyle(color: Colors.white),
              obscureText: _obscureNewPassword,
              validator: _validateNewPassword,
            ),
            SizedBox(height: 40),
            // Update Password Button
            RetroButton(
              text: 'Update Password',
              onPressed: _updatePassword,
              style: RetroButtonStyle.light,
            ),
          ],
        ),
      ),
    );
  }

  // Current Password validator
  String? _validateCurrentPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your current password';
    }
    return null;
  }

  // New Password validator
  String? _validateNewPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a new password';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }
}