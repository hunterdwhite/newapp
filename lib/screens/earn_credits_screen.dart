import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/grainy_background_widget.dart';
import '../widgets/retro_button_widget.dart';
import '../services/referral_service.dart';
import 'home_screen.dart';

class EarnCreditsScreen extends StatefulWidget {
  const EarnCreditsScreen({Key? key}) : super(key: key);

  @override
  _EarnCreditsScreenState createState() => _EarnCreditsScreenState();
}

class _EarnCreditsScreenState extends State<EarnCreditsScreen> {
  int _freeOrderCredits = 0;
  int _freeOrdersAvailable = 0;
  bool _creditsLoading = true;
  bool _hasReviewed = false;
  bool _hasFollowedInstagram = false;
  bool _hasEverOrdered = false;
  
  // Referral related state
  String _referralCode = '';
  int _referralCount = 0;
  bool _referralLoading = true;
  
  // First order referral state
  int _firstOrderReferralCount = 0;
  int _firstOrderReferralCredits = 0;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadReferralData();
  }

  Future<void> _loadUserData() async {
    if (!mounted) return;
    setState(() => _creditsLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Force fresh data from server to immediately show new credits
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get(const GetOptions(source: Source.server));

        if (userDoc.exists) {
          final data = userDoc.data() ?? {};
          
          // Check if user has ever placed an order
          final ordersQuery = await FirebaseFirestore.instance
              .collection('orders')
              .where('userId', isEqualTo: user.uid)
              .limit(1)
              .get();
          
          setState(() {
            _freeOrderCredits = data['freeOrderCredits'] ?? 0;
            _freeOrdersAvailable = data['freeOrdersAvailable'] ?? 0;
            _hasReviewed = data['hasLeftAppStoreReview'] ?? false;
            _hasFollowedInstagram = data['hasFollowedInstagram'] ?? false;
            _hasEverOrdered = ordersQuery.docs.isNotEmpty;
            _creditsLoading = false;
          });
        } else {
          setState(() {
            _freeOrderCredits = 0;
            _freeOrdersAvailable = 0;
            _hasReviewed = false;
            _hasFollowedInstagram = false;
            _hasEverOrdered = false;
            _creditsLoading = false;
          });
        }
      } else {
        setState(() {
          _freeOrderCredits = 0;
          _freeOrdersAvailable = 0;
          _hasReviewed = false;
          _hasFollowedInstagram = false;
          _hasEverOrdered = false;
          _creditsLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
      setState(() {
        _freeOrderCredits = 0;
        _freeOrdersAvailable = 0;
        _hasReviewed = false;
        _hasFollowedInstagram = false;
        _hasEverOrdered = false;
        _creditsLoading = false;
      });
    }
  }

  Future<void> _leaveAppStoreReview() async {
    try {
      final InAppReview inAppReview = InAppReview.instance;
      
      if (await inAppReview.isAvailable()) {
        // Show the review prompt
        await inAppReview.requestReview();
        
        // Show a fun dialog about the review
        if (mounted) {
          final bool? userLeftReview = await _showReviewDialog();

          if (userLeftReview == true) {
            // User confirmed they left a review
            final user = FirebaseAuth.instance.currentUser;
            if (user != null) {
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .update({
                'hasLeftAppStoreReview': true,
                'reviewCompletedAt': FieldValue.serverTimestamp(),
              });
              
              // Add the credit
              await HomeScreen.addFreeOrderCredits(user.uid, 1);
              
              // Refresh the data
              await _loadUserData();
              
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Thank you for your review! You earned 1 credit.'),
                    backgroundColor: Color(0xFFFFA500),
                  ),
                );
              }
            }
          } else {
            // User didn't complete the review
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('No worries! You can try again later to earn your credit.'),
                  backgroundColor: Colors.grey,
                ),
              );
            }
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('App store review not available on this device.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error requesting app store review: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to open app store review. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _followInstagram() async {
    try {
      final String instagramUrl = 'https://instagram.com/dissonant.ig';
      
      if (await canLaunchUrl(Uri.parse(instagramUrl))) {
        // Open Instagram
        await launchUrl(Uri.parse(instagramUrl), mode: LaunchMode.externalApplication);
        
        // Automatically award the credit when they return
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update({
            'hasFollowedInstagram': true,
            'instagramFollowCompletedAt': FieldValue.serverTimestamp(),
          });
          
          // Add the credit
          await HomeScreen.addFreeOrderCredits(user.uid, 1);
          
          // Refresh the data
          await _loadUserData();
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Thank you for checking out our Instagram! You earned 1 credit.'),
                backgroundColor: Color(0xFFFFA500),
              ),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to open Instagram. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error opening Instagram: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to open Instagram. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }



  Future<void> _loadReferralData() async {
    if (!mounted) return;
    setState(() => _referralLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Ensure user has a referral code
        final referralCode = await ReferralService.getOrCreateReferralCode(user.uid);
        
        // Get referral stats
        final stats = await ReferralService.getReferralStats(user.uid);
        
        setState(() {
          _referralCode = referralCode;
          _referralCount = stats['referralCount'] ?? 0;
          _firstOrderReferralCount = stats['firstOrderReferralCount'] ?? 0;
          _firstOrderReferralCredits = stats['firstOrderReferralCredits'] ?? 0;
          _referralLoading = false;
        });
        
        debugPrint('DEBUG: EarnCreditsScreen - stats received: $stats');
        debugPrint('DEBUG: EarnCreditsScreen - setting _referralCount to: ${stats['referralCount']}');
      } else {
        setState(() {
          _referralCode = '';
          _referralCount = 0;
          _firstOrderReferralCount = 0;
          _firstOrderReferralCredits = 0;
          _referralLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading referral data: $e');
      setState(() {
        _referralCode = '';
        _referralCount = 0;
        _firstOrderReferralCount = 0;
        _firstOrderReferralCredits = 0;
        _referralLoading = false;
      });
    }
  }

  Future<void> _shareReferralCode() async {
    if (_referralCode.isNotEmpty) {
      await ReferralService.shareReferralCode(_referralCode);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to load your referral code. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showReferredUsersDialog() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Show dialog immediately with loading state, then update with data
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return _ReferredUsersDialog(
          userId: user.uid,
          firstOrderReferralCount: _firstOrderReferralCount,
          firstOrderReferralCredits: _firstOrderReferralCredits,
        );
      },
    );
  }

  Future<bool?> _showReviewDialog() async {
    // First dialog: "Was the review nice?"
    final bool? wasNice = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF151515),
          title: const Text(
            'Was the review nice?',
            style: TextStyle(color: Colors.white),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                'No',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(
                'Yes',
                style: TextStyle(color: Color(0xFFFFA500)),
              ),
            ),
          ],
        );
      },
    );

    if (wasNice == false) {
      // Second dialog: "It's fine I don't care"
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: const Color(0xFF151515),
            content: const Text(
              'It\'s fine I don\'t care',
              style: TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  '...',
                  style: TextStyle(color: Color(0xFFFFA500), fontSize: 18),
                ),
              ),
            ],
          );
        },
      );
    }

    // Everyone gets credit regardless!
    return true;
  }



  Widget _buildFreeOrderBar() {
    if (_creditsLoading) {
      return const SizedBox(
        height: 150,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final int creditsNeeded = 5 - _freeOrderCredits;
    final int filledPartitions = _freeOrderCredits;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black, width: 0.5),
        ),
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  height: 36,
                  color: const Color(0xFFFFA12C),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  alignment: Alignment.centerLeft,
                  child: const Text(
                    'Free Order Credits',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black,
                      fontWeight: FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 3, color: Color(0xFFFFC278)),
                ),
                Positioned(
                  top: 0,
                  bottom: 0,
                  left: 0,
                  child: Container(
                    width: 3, color: Color(0xFFFFC278)),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: Color(0xFFCBCACB),
                      border: Border(
                        top: BorderSide(color: Colors.white, width: 2),
                        left: BorderSide(color: Colors.white, width: 2),
                        bottom: BorderSide(color: Color(0xFF5E5E5E), width: 2),
                        right: BorderSide(color: Color(0xFF5E5E5E), width: 2),
                      ),
                    ),
                    child: const Text(
                      'X',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Container(height: 1, color: Colors.black),
            Container(
              color: const Color(0xFFE0E0E0),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_freeOrdersAvailable > 0) ...[
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFA500),
                        border: Border.all(color: Colors.white, width: 1),
                      ),
                      child: Text(
                        _freeOrdersAvailable == 1
                            ? 'You have 1 free order available!'
                            : 'You have $_freeOrdersAvailable free orders available!',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Text(
                    '$creditsNeeded credits until next free order',
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: 24,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black, width: 1),
                    ),
                    child: Row(
                      children: List.generate(5, (index) {
                        final bool isFilled = index < filledPartitions;
                        return Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: isFilled ? const Color(0xFFFFA500) : Colors.transparent,
                              border: index < 4
                                  ? const Border(right: BorderSide(color: Colors.black, width: 1))
                                  : null,
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReferralOption() {
    if (_referralLoading) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF151515),
          border: Border.all(color: Colors.white, width: 1),
        ),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        border: Border.all(color: Colors.white, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _shareReferralCode,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Credit value indicator
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                  child: const Center(
                    child: Text(
                      '+1',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Refer a Friend',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Share your referral code: ${_referralCode}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Successful referrals: $_referralCount',
                        style: const TextStyle(
                          color: Color(0xFFFFA500),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Tap to share your code',
                        style: TextStyle(
                          color: Color(0xFFFFA500),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Arrow
                const Icon(
                  Icons.share,
                  color: Colors.white70,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDonationCreditOption() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        border: Border.all(color: Colors.white, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Credit value indicator with "?"
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.transparent,
                border: Border.all(color: Colors.white, width: 1),
              ),
              child: const Center(
                child: Text(
                  '?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Donate CD(s)',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Want to donate some CDs? Email us at dissonant.helpdesk@gmail.com with any albums you want to donate and we\'ll quote you credits',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedCreditOption({
    required String title,
    required String description,
    required int creditValue,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A), // Darker, grayed out background
        border: Border.all(color: Colors.white38, width: 1), // More transparent border
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Credit value indicator - completed
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white38, // Grayed out background
                border: Border.all(color: Colors.white38, width: 1),
              ),
              child: const Center(
                child: Text(
                  '✓',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white54, // Grayed out text
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      color: Colors.white38, // More grayed out text
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Completed',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            
            // Completion indicator
            const Icon(
              Icons.check_circle,
              color: Colors.white38,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreditEarningOption({
    required String title,
    required String description,
    required String actionText,
    required VoidCallback onTap,
    required bool isCompleted,
    required int creditValue,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        border: Border.all(
          color: isCompleted ? const Color(0xFFFFA500) : Colors.white, 
          width: 1
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isCompleted ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Credit value indicator
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isCompleted ? const Color(0xFFFFA500) : Colors.transparent,
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                  child: Center(
                    child: Text(
                      isCompleted ? '✓' : '+$creditValue',
                      style: TextStyle(
                        color: isCompleted ? Colors.black : Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: isCompleted ? const Color(0xFFFFA500) : Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      if (!isCompleted) ...[
                        const SizedBox(height: 8),
                        Text(
                          actionText,
                          style: const TextStyle(
                            color: Color(0xFFFFA500),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                
                // Arrow or completion indicator
                Icon(
                  isCompleted ? Icons.check_circle : Icons.arrow_forward_ios,
                  color: isCompleted ? const Color(0xFFFFA500) : Colors.white70,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: null,
      body: GrainyBackgroundWidget(
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 24),
              // Progress bar at top
              _buildFreeOrderBar(),
              
              // Instructions
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Complete activities below to earn credits toward your next free order:',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              
              // Refresh button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF151515),
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                  child: Material(
                    color: Colors.transparent,
                                    child: InkWell(
                  onTap: () async {
                    await _loadUserData();
                    await _loadReferralData();
                    
                    // TEMPORARY: Manual check for debugging - REMOVE LATER
                    final user = FirebaseAuth.instance.currentUser;
                    if (user != null) {
                      try {
                        await ReferralService.manuallyCheckAndAwardFirstOrderCredits(user.uid);
                      } catch (e) {
                        debugPrint('Manual check error: $e');
                      }
                    }
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Credits refreshed!'),
                        backgroundColor: Color(0xFFFFA500),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(
                              Icons.refresh,
                              color: Colors.white70,
                              size: 16,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Refresh Credits',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // List of earning activities
              Expanded(
                child: ListView(
                  children: [
                    // Active/incomplete credit earning options
                    // Only show if user hasn't made their first order yet
                    if (!_hasEverOrdered)
                      _buildCreditEarningOption(
                        title: 'Complete Your First Order',
                        description: 'Place and complete your first music order to earn credits.',
                        actionText: 'Place your first order!',
                        creditValue: 2,
                        isCompleted: false,
                        onTap: () {
                          Navigator.pop(context); // Close earn credits screen
                          // Navigate to order screen - assuming it's in the main navigation
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Navigate to the Order tab to place your first order!'),
                              backgroundColor: Color(0xFFFFA500),
                            ),
                          );
                        },
                      ),
                    
                    // Only show if not completed
                    if (!_hasReviewed)
                      _buildCreditEarningOption(
                        title: 'Leave an App Store Review',
                        description: 'Help other music lovers discover DISSONANT by leaving a review on the app store.',
                        actionText: 'Tap to open app store',
                        creditValue: 1,
                        isCompleted: false,
                        onTap: _leaveAppStoreReview,
                      ),
                    
                    // Only show if not completed
                    if (!_hasFollowedInstagram)
                      _buildCreditEarningOption(
                        title: 'Follow us on Instagram',
                        description: 'Follow @dissonant.ig on Instagram to stay in the loop.',
                        actionText: 'Tap to open Instagram',
                        creditValue: 1,
                        isCompleted: false,
                        onTap: _followInstagram,
                      ),
                    
                    _buildReferralOption(),
                    
                    // First order referral option
                    _buildCreditEarningOption(
                      title: 'Friend\'s First Order Bonus',
                      description: 'Earn 2 credits when someone you referred places their first order.',
                      actionText: 'View your referred users',
                      creditValue: 2,
                      isCompleted: false, // This is always available as an ongoing earning method
                      onTap: _showReferredUsersDialog,
                    ),
                    
                    // Order credit earning
                    _buildCreditEarningOption(
                      title: 'Place an Order',
                      description: 'Earn 1 credit every time you place an order.',
                      actionText: 'Ongoing earning method',
                      creditValue: 1,
                      isCompleted: false, // This is always available as an ongoing earning method
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('You earn 1 credit automatically with each order you place!'),
                            backgroundColor: Color(0xFFFFA500),
                          ),
                        );
                      },
                    ),
                    
                    // CD donation option
                    _buildDonationCreditOption(),
                    
                    // Completed items at the bottom (grayed out)
                    if (_hasEverOrdered)
                      _buildCompletedCreditOption(
                        title: 'Complete Your First Order',
                        description: 'Place and complete your first music order to earn credits.',
                        creditValue: 2,
                      ),
                    
                    if (_hasReviewed)
                      _buildCompletedCreditOption(
                        title: 'Leave an App Store Review',
                        description: 'Help other music lovers discover DISSONANT by leaving a review on the app store.',
                        creditValue: 1,
                      ),
                    
                    if (_hasFollowedInstagram)
                      _buildCompletedCreditOption(
                        title: 'Follow us on Instagram',
                        description: 'Follow @dissonant.ig on Instagram to stay in the loop.',
                        creditValue: 1,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReferredUsersDialog extends StatefulWidget {
  final String userId;
  final int firstOrderReferralCount;
  final int firstOrderReferralCredits;

  const _ReferredUsersDialog({
    Key? key,
    required this.userId,
    required this.firstOrderReferralCount,
    required this.firstOrderReferralCredits,
  }) : super(key: key);

  @override
  _ReferredUsersDialogState createState() => _ReferredUsersDialogState();
}

class _ReferredUsersDialogState extends State<_ReferredUsersDialog> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _referredUsers = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadReferredUsers();
  }

  Future<void> _loadReferredUsers() async {
    try {
      debugPrint('DEBUG: Dialog - Loading referred users for userId: ${widget.userId}');
      final referredUsers = await ReferralService.getReferredUsers(widget.userId);
      debugPrint('DEBUG: Dialog - Received ${referredUsers.length} referred users');
      if (mounted) {
        setState(() {
          _referredUsers = referredUsers;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('DEBUG: Dialog - Error loading referred users: $e');
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF151515),
      title: Row(
        children: [
          const Text(
            'Your Referred Users',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          const Spacer(),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.white70),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: _isLoading
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Color(0xFFFFA500)),
                    SizedBox(height: 16),
                    Text(
                      'Loading your referred users...',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              )
            : _errorMessage != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Failed to load referred users',
                          style: TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : _referredUsers.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.group_outlined,
                              size: 64,
                              color: Colors.white38,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No referred users yet',
                              style: TextStyle(color: Colors.white70, fontSize: 16),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Share your referral code to start earning!',
                              style: TextStyle(color: Colors.white54, fontSize: 14),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : Column(
                        children: [
                          // Header with stats (calculated from actual user list)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2A2A2A),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Column(
                                  children: [
                                    Text(
                                      '${_referredUsers.length}',
                                      style: const TextStyle(
                                        color: Color(0xFFFFA500),
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const Text(
                                      'Total Referred',
                                      style: TextStyle(color: Colors.white70, fontSize: 12),
                                    ),
                                  ],
                                ),
                                Column(
                                  children: [
                                    Text(
                                      '${_referredUsers.where((user) => user['hasPlacedFirstOrder'] as bool).length}',
                                      style: const TextStyle(
                                        color: Color(0xFFFFA500),
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const Text(
                                      'Placed Orders',
                                      style: TextStyle(color: Colors.white70, fontSize: 12),
                                    ),
                                  ],
                                ),
                                Column(
                                  children: [
                                    Text(
                                      '${_referredUsers.where((user) => user['firstOrderCreditAwarded'] as bool).length * 2}',
                                      style: const TextStyle(
                                        color: Color(0xFFFFA500),
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const Text(
                                      'Credits Earned',
                                      style: TextStyle(color: Colors.white70, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // List of referred users
                          Expanded(
                            child: ListView.builder(
                              itemCount: _referredUsers.length,
                              itemBuilder: (context, index) {
                                final user = _referredUsers[index];
                                final hasPlacedOrder = user['hasPlacedFirstOrder'] as bool;
                                final creditAwarded = user['firstOrderCreditAwarded'] as bool;
                                
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2A2A2A),
                                    border: Border.all(
                                      color: hasPlacedOrder 
                                          ? const Color(0xFFFFA500) 
                                          : Colors.white24,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      // Status indicator
                                      Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: hasPlacedOrder 
                                              ? const Color(0xFFFFA500) 
                                              : Colors.white38,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      
                                      // User info
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              user['referredUserDisplayName'] ?? 'Unknown User',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            Text(
                                              hasPlacedOrder 
                                                  ? 'Has placed first order ✓' 
                                                  : 'No orders yet',
                                              style: TextStyle(
                                                color: hasPlacedOrder 
                                                    ? const Color(0xFFFFA500) 
                                                    : Colors.white54,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      
                                      // Credit indicator
                                      if (hasPlacedOrder && creditAwarded)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFFA500),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text(
                                            '+2',
                                            style: TextStyle(
                                              color: Colors.black,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Close',
            style: TextStyle(color: Color(0xFFFFA500)),
          ),
        ),
      ],
    );
  }
}