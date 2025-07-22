import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/grainy_background_widget.dart';
import '../widgets/retro_button_widget.dart';
import '../services/firestore_service.dart';

class CuratorScreen extends StatefulWidget {
  const CuratorScreen({Key? key}) : super(key: key);

  @override
  _CuratorScreenState createState() => _CuratorScreenState();
}

class _CuratorScreenState extends State<CuratorScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  bool _canBecomeCurator = false;
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _checkCuratorEligibility();
  }
  
  Future<void> _checkCuratorEligibility() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _isLoading = false;
        _canBecomeCurator = false;
      });
      return;
    }
    
    try {
      // Get user's album stats to check if they have completed any orders
      final stats = await _firestoreService.getUserAlbumStats(user.uid);
      final albumsKept = stats['albumsKept'] ?? 0;
      final albumsSentBack = stats['albumsSentBack'] ?? 0;
      
      setState(() {
        _canBecomeCurator = (albumsKept + albumsSentBack) > 0;
        _isLoading = false;
      });
    } catch (e) {
      print('Error checking curator eligibility: $e');
      setState(() {
        _isLoading = false;
        _canBecomeCurator = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BackgroundWidget(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/communitycuratoricon.png',
                  width: 120,
                  height: 120,
                ),
                const SizedBox(height: 32),
                const Text(
                  'Community Curator',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Curate music for the community',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white70,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                if (_isLoading)
                  const CircularProgressIndicator()
                else ...[
                  RetroButton(
                    text: 'Become Curator',
                    onPressed: _canBecomeCurator ? _becomeCurator : null,
                    style: _canBecomeCurator 
                        ? RetroButtonStyle.light 
                        : RetroButtonStyle.dark,
                    fixedHeight: true,
                  ),
                  const SizedBox(height: 16),
                  if (!_canBecomeCurator)
                    const Text(
                      'To Become a Curator you Must Complete at Least 1 Order',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF151515),
                      border: Border.all(color: Colors.white, width: 1),
                    ),
                    child: const Text(
                      'Community Curators will be able to:\n\n• Choose albums to send to other users\n• Earn free orders\n• Build a following within the community',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  void _becomeCurator() {
    // TODO: Implement curator application/setup flow
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Curator application coming soon!'),
        backgroundColor: Color(0xFFFFA500),
      ),
    );
  }
} 