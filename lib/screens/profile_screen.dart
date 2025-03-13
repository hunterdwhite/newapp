import 'package:dissonantapp2/screens/welcome_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import 'admin_dashboard_screen.dart';
import '../widgets/grainy_background_widget.dart'; 
import '../widgets/stats_bar_widget.dart'; 
import '../widgets/retro_button_widget.dart'; 
import '../widgets/retro_form_container_widget.dart';
import 'wishlist_screen.dart'; 
import 'options_screen.dart'; 

// <-- Import your new PersonalProfileScreen here.
import 'personal_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  User? _user;
  bool _isAdmin = false;
  int _albumsSentBack = 0;
  int _albumsKept = 0;
  bool _isLoading = true;
  bool _isUpdatingOrders = false; // State for the update button
  String? _userName;

  @override
  void initState() {
    super.initState();
    _user = FirebaseAuth.instance.currentUser;
    _checkAdminStatus();
    _fetchUserStats();
    _fetchUserName();
  }

  Future<void> _checkAdminStatus() async {
    if (_user != null) {
      bool isAdmin = await _firestoreService.isAdmin(_user!.uid);
      setState(() {
        _isAdmin = isAdmin;
      });
    }
  }

  Future<void> _fetchUserStats() async {
    if (_user != null) {
      final stats = await _firestoreService.getUserAlbumStats(_user!.uid);
      setState(() {
        _albumsSentBack = stats['albumsSentBack'] ?? 0;
        _albumsKept = stats['albumsKept'] ?? 0;
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchUserName() async {
    if (_user != null) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_user!.uid)
          .get();
      setState(() {
        _userName = userDoc['username'];
      });
    }
  }

  /// Admin function to update orders with missing `updatedAt`
  Future<void> _updateOrdersWithTimestamps() async {
    setState(() {
      _isUpdatingOrders = true;
    });

    try {
      final QuerySnapshot ordersSnapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('updatedAt', isEqualTo: null)
          .get();

      if (ordersSnapshot.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No orders found without updatedAt!')),
        );
        setState(() {
          _isUpdatingOrders = false;
        });
        return;
      }

      final WriteBatch batch = FirebaseFirestore.instance.batch();

      for (final doc in ordersSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final Timestamp? existingTimestamp = data['timestamp'] as Timestamp?;

        if (existingTimestamp != null) {
          print('Updating order ${doc.id} with timestamp: $existingTimestamp');
          batch.update(doc.reference, {'updatedAt': existingTimestamp});
        } else {
          print('Updating order ${doc.id} with serverTimestamp');
          batch.update(doc.reference, {'updatedAt': FieldValue.serverTimestamp()});
        }
      }

      await batch.commit();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Updated ${ordersSnapshot.docs.length} orders!')),
      );
    } catch (error) {
      print('Error updating orders: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating orders: $error')),
      );
    } finally {
      setState(() {
        _isUpdatingOrders = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BackgroundWidget(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 20),
              Text(
                'Welcome, ${_userName ?? 'User'}!',
                style: TextStyle(fontSize: 32, color: Colors.white),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20),
              if (_isLoading)
                Center(child: CircularProgressIndicator())
              else
                RetroFormContainerWidget(
                  width: double.infinity,
                  child: StatsBar(
                    albumsSentBack: _albumsSentBack,
                    albumsKept: _albumsKept,
                  ),
                ),
              SizedBox(height: 20),
              RetroButton(
                text: 'Wishlist',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => WishlistScreen()),
                  );
                },
                color: Color(0xFFFFA500),
                fixedHeight: true,
              ),
              SizedBox(height: 20),
              RetroButton(
                text: 'Options',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => OptionsScreen()),
                  );
                },
                color: Color(0xFFFFA500),
                fixedHeight: true,
              ),

              // Only admins see these buttons
              if (_isAdmin) ...[
                SizedBox(height: 20),
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
                // -------------- NEW BUTTON FOR ADMINS ONLY --------------
                RetroButton(
                  text: 'View New Profile Screen',
                  onPressed: () {
                    // Navigate to your new personal profile, passing the admin's userId
                    // or the user ID you'd like to inspect
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PersonalProfileScreen(userId: _user!.uid),
                      ),
                    );
                  },
                  color: Color(0xFFFFA500),
                  fixedHeight: true,
                ),
                // --------------------------------------------------------
              ],

              Spacer(),
              Padding(
                padding: EdgeInsets.symmetric(vertical: 20.0),
                child: Text(
                  "Have questions or having issues with Dissonant? Email dissonant.helpdesk@gmail.com and we'll get right back to you!",
                  style: TextStyle(fontSize: 16, color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
              if (_isAdmin)
                RetroButton(
                  text: 'Logout',
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => WelcomeScreen()),
                    );
                  },
                  color: Colors.red,
                  fixedHeight: true,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
