import 'package:flutter/material.dart';
import '../widgets/retro_button_widget.dart';
import '../widgets/grainy_background_widget.dart';
import '../widgets/retro_form_container_widget.dart';
import 'link_discogs_screen.dart';
import 'taste_profile_screen.dart';
import 'change_password_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Add this import

import 'admin_dashboard_screen.dart'; // <-- For Admin Dashboard
import 'welcome_screen.dart';         // <-- For Logout

class OptionsScreen extends StatefulWidget {
  @override
  _OptionsScreenState createState() => _OptionsScreenState();
}

class _OptionsScreenState extends State<OptionsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  User? _user;
  bool _isAdmin = false; // <-- Track admin status

  @override
  void initState() {
    super.initState();
    _user = FirebaseAuth.instance.currentUser;
    _checkAdminStatus();
  }

  Future<void> _checkAdminStatus() async {
    if (_user != null) {
      bool isAdmin = await _firestoreService.isAdmin(_user!.uid);
      setState(() {
        _isAdmin = isAdmin;
      });
    }
  }

  Future<void> _deleteAccount() async {
    // Check for outstanding orders
    bool hasOutstanding = await _firestoreService.hasOutstandingOrders(_user!.uid);

    if (hasOutstanding) {
      // Show message that the user must resolve outstanding orders
      await showDialog<void>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Cannot Delete Account'),
            content: Text(
              'You must choose to keep or return any outstanding orders before you can delete your account.',
            ),
            actions: [
              TextButton(
                child: Text('OK'),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          );
        },
      );
      return; // Do not proceed further
    }

    // Proceed with account deletion
    bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Are you absolutely sure?'),
          content: Text('This action cannot be undone.'),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: Text('Delete Account'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmDelete == true) {
      // Re-authenticate the user
      try {
        User? user = FirebaseAuth.instance.currentUser;

        // Prompt user to re-enter their password
        String? password = await _showPasswordPrompt();

        if (password == null) {
          // User canceled the re-authentication
          return;
        }

        AuthCredential credential = EmailAuthProvider.credential(
          email: user!.email!,
          password: password,
        );

        await user.reauthenticateWithCredential(credential);

        String userId = user.uid;

        // Delete user data from Firestore
        await _firestoreService.deleteUserData(userId);

        // Delete Firebase user
        await user.delete();

        // Navigate to Welcome Screen
        Navigator.pushNamedAndRemoveUntil(context, '/welcome', (route) => false);
      } catch (e) {
        print('Error deleting account: $e');
        // Handle error, e.g., show a message to the user
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete account: $e')),
        );
      }
    }
  }

  Future<String?> _showPasswordPrompt() async {
    TextEditingController _passwordController = TextEditingController();

    return await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Re-enter Password'),
          content: TextField(
            controller: _passwordController,
            decoration: InputDecoration(
              labelText: 'Password',
            ),
            obscureText: true,
          ),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(null),
            ),
            TextButton(
              child: Text('Confirm'),
              onPressed: () => Navigator.of(context).pop(_passwordController.text),
            ),
          ],
        );
      },
    );
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => WelcomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Added AppBar with back button
      appBar: AppBar(
        title: Text('Options'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: BackgroundWidget(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Stack(
              children: [
                // Centered Column for the main buttons
                Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min, // Shrink to fit children
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(height: 20),
                        // Edit Taste Profile
                        RetroButton(
                          text: 'Edit Taste Profile',
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => TasteProfileScreen()),
                            );
                          },
                          color: Color(0xFFFFA500),
                          fixedHeight: true,
                        ),
                        SizedBox(height: 20),
                        // Change Password
                        RetroButton(
                          text: 'Change Password',
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => ChangePasswordScreen()),
                            );
                          },
                          color: Color(0xFFFFA500),
                          fixedHeight: true,
                        ),
                        SizedBox(height: 20),
                        RetroButton(
                          text: 'Link Discogs',
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => LinkDiscogsScreen()),
                            );
                          },
                          color: Color(0xFF333333), // Discogs grey
                          fixedHeight: true,
                          leading: Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: Image.asset(
                              'assets/discogs_logo.png',
                              width: 24,
                              height: 24,
                            ),
                          ),
                        ),
                        SizedBox(height: 20),
                        // If admin, show Admin Dashboard button
                        if (_isAdmin) ...[
                          RetroButton(
                            text: 'Admin Dashboard',
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => AdminDashboardScreen()),
                              );
                            },
                            color: Color(0xFFFFA500),
                            fixedHeight: true,
                          ),
                          SizedBox(height: 20),
                        ],
                        // Logout button for everyone
                        RetroButton(
                          text: 'Logout',
                          onPressed: _logout,
                          color: Colors.red,
                          fixedHeight: true,
                        ),
                      ],
                    ),
                  ),
                ),
                // Positioned Delete Account button
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: SizedBox(
                    width: 150,
                    child: ElevatedButton(
                      onPressed: _deleteAccount,
                      child: Text(
                        'Delete My Account',
                        style: TextStyle(color: Colors.white), // White text
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red, // Red color for delete button
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
