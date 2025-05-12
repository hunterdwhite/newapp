import 'package:flutter/material.dart';
import 'package:dissonantapp2/widgets/retro_button_widget.dart';
import 'package:dissonantapp2/main.dart'; // Assuming MyHomePage is here

// Import your BackgroundWidget
import 'package:dissonantapp2/widgets/grainy_background_widget.dart';

import 'taste_profile_screen.dart';

class HowItWorksPage extends StatefulWidget {
  final bool showExitButton; // Determines whether to show the 'X' button

  HowItWorksPage({this.showExitButton = false});

  @override
  _HowItWorksPageState createState() => _HowItWorksPageState();
}

class _HowItWorksPageState extends State<HowItWorksPage> {
  PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> steps = [
    {
      'icon': Icons.person,
      'title': 'Tell Us About Yourself',
      'description':
          'Fill out a quick form about your musical preferences-your favorite genres and how adventurous you want your discovery to be.',
    },
    {
      'icon': Icons.local_shipping,
      'title': 'Receive a Handpicked CD',
      'description':
          'Make an order and our music lover curators select a CD tailored just for you and send it straight to your door.',
    },
    {
      'icon': Icons.headset,
      'title': 'Immerse Yourself in the Music',
      'description':
          'Hold the CD, explore the artwork, read the liner notes, truly live with the music.',
    },
    {
      'icon': Icons.swap_horiz,
      'title': 'Keep It or Return It',
      'description':
          'Love it? Keep it! If not, use the prepaid shipping label to send it back, and your next order will be free!',
    },
  ];

  void _onPageChanged(int index) {
    setState(() {
      _currentPage = index;
    });
  }

  void _enterHomePage() {
    if (widget.showExitButton) {
      // When showExitButton is true, navigate to the home screen
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => MyHomePage()),
        (Route<dynamic> route) => false,
      );
    } else {
      // When showExitButton is false, navigate to the taste profile screen
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => TasteProfileScreen()),
        (Route<dynamic> route) => false,
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose(); // Dispose the controller when the widget is disposed
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.showExitButton
          ? AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              automaticallyImplyLeading: false, // Removes the back arrow
              actions: [
                IconButton(
                  icon: Icon(Icons.close, color: Colors.white), // White 'X' icon
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            )
          : null,
      body: BackgroundWidget(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: steps.length,
                onPageChanged: _onPageChanged,
                itemBuilder: (context, index) {
                  return _buildStepContent(steps[index], index);
                },
              ),
            ),
            _buildPageIndicator(),
            SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildStepContent(Map<String, dynamic> step, int index) {
    return Container(
      padding: EdgeInsets.all(20.0),
      constraints: BoxConstraints(maxWidth: 600), // Limit max width for readability
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            step['icon'],
            size: MediaQuery.of(context).size.width * 0.3, // Adjust icon size relative to screen width
            color: Colors.orange, // Set icon color to orange
          ),
          SizedBox(height: 40),
          Text(
            step['title'],
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 32, // Increased font size
              fontWeight: FontWeight.bold,
              color: Colors.white, // Set title text color to white
            ),
          ),
          SizedBox(height: 20),
          Text(
            step['description'],
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22, // Increased font size
              color: Colors.white, // Set description text color to white
            ),
          ),
          if (index == steps.length - 1) ...[
            SizedBox(height: 40),
            RetroButton(
              onPressed: _enterHomePage,
              text: 'Enter Dissonant',
              style: RetroButtonStyle.light,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPageIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(steps.length, (index) {
        return AnimatedContainer(
          duration: Duration(milliseconds: 300),
          margin: EdgeInsets.symmetric(horizontal: 5),
          width: _currentPage == index ? 12 : 8,
          height: _currentPage == index ? 12 : 8,
          decoration: BoxDecoration(
            color: _currentPage == index ? Colors.orange : Colors.grey,
            shape: BoxShape.circle,
          ),
        );
      }),
    );
  }
}
