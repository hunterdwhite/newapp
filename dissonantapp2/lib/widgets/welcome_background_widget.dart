import 'package:flutter/material.dart';

class WelcomeBackgroundWidget extends StatelessWidget {
  final Widget child;

  WelcomeBackgroundWidget({required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            'assets/welcome_background.png',
            fit: BoxFit.cover,
          ),
        ),
        Positioned.fill(
          child: child,
        ),
      ],
    );
  }
}