import 'package:flutter/material.dart';

class GrainyBackgroundWidget extends StatelessWidget {
  final Widget child;

  const GrainyBackgroundWidget({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Only the grain overlay as background
        const Positioned.fill(
          child: Image(
            image: AssetImage('assets/grainoverlay.png'),
            fit: BoxFit.cover,
            repeat: ImageRepeat.repeat,
          ),
        ),
        // Main content on top
        Positioned.fill(child: child),
      ],
    );
  }
}
