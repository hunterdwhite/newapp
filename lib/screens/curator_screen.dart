import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/grainy_background_widget.dart';
import '../widgets/retro_button_widget.dart';
import '../services/firestore_service.dart';
import '../services/push_notification_service.dart';

class CuratorScreen extends StatefulWidget {
  const CuratorScreen({Key? key}) : super(key: key);

  @override
  _CuratorScreenState createState() => _CuratorScreenState();
}

class _CuratorScreenState extends State<CuratorScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final PushNotificationService _notificationService = PushNotificationService();
  
  bool _isLoading = true;
  bool _isCurator = false;
  bool _isSigningUp = false;

  @override
  void initState() {
    super.initState();
    _checkCuratorStatus();
    _initializeNotifications();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _initializeNotifications() async {
    await _notificationService.initialize();
    await _notificationService.requestPermissions();
  }

  Future<void> _checkCuratorStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = await _firestoreService.getUserDoc(user.uid);
      if (userDoc != null && userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final isCurator = userData['isCurator'] ?? false;
        
        if (mounted) {
          setState(() {
            _isCurator = isCurator;
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _becomeCurator() async {
    setState(() {
      _isSigningUp = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // First, request and verify push notification permissions
        final hasPermission = await _notificationService.requestPermissions();
        
        if (!hasPermission) {
          setState(() {
            _isSigningUp = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Push notifications are required to become a curator. Please enable notifications in your device settings and try again.'),
              duration: Duration(seconds: 5),
            ),
          );
          return;
        }

        // Get and store FCM token
        final token = await _notificationService.getToken();
        if (token == null) {
          setState(() {
            _isSigningUp = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to set up notifications. Please check your connection and try again.'),
            ),
          );
          return;
        }

        // Mark user as curator
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'isCurator': true,
          'curatorJoinedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Subscribe to curator notifications
        await _notificationService.subscribeToTopic('curator_${user.uid}');

        if (mounted) {
          setState(() {
            _isCurator = true;
            _isSigningUp = false;
          });
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Welcome to the curator community! You\'ll receive notifications for new orders.')),
        );
      }
    } catch (e) {
      setState(() {
        _isSigningUp = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error becoming curator: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GrainyBackgroundWidget(
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _isCurator
                  ? _buildCuratorSuccess()
                  : _buildSignupScreen(),
        ),
      ),
    );
  }

  Widget _buildSignupScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          Image.asset(
            'assets/curateicon.png',
            width: 100,
            height: 100,
          ),
          const SizedBox(height: 24),
          const Text(
            'Become a Community Curator',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF151515),
              border: Border.all(color: Colors.white, width: 1),
            ),
            child: const Text(
              'Pick albums from our library for users\n\nProvide great recommendations and earn positive reviews!\n\nEach curation gives you a credit towards a new order.\n\nNote: Push notifications are required to receive new order alerts.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          RetroButtonWidget(
            text: _isSigningUp ? 'Signing Up...' : 'Become Curator',
            onPressed: _isSigningUp ? null : _becomeCurator,
            style: RetroButtonStyle.light,
            fixedHeight: true,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildCuratorSuccess() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/curateicon.png',
            width: 120,
            height: 120,
          ),
          const SizedBox(height: 32),
          const Text(
            'You\'re Now a Curator!',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const Text(
            'Your profile now shows your curator status. Users can favorite you and request your curation services.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF151515),
              border: Border.all(color: Colors.orangeAccent, width: 1),
            ),
            child: const Text(
              'What\'s Next:\n\n• Your profile shows a curator badge\n• Users can favorite you as a curator\n• You\'ll receive notifications for new orders\n• Album selection feature coming soon',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
} 