import 'package:flutter/material.dart';

class BackgroundWidget extends StatelessWidget {
  final Widget child;

  const BackgroundWidget({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Paints the dark off-grey across the entire viewport
        const Positioned.fill(
          child: ColoredBox(color: Color(0xFF2B2B2B)), // tweak hex if needed
        ),
        // Your page content
        Positioned.fill(child: child),
      ],
    );
  }
}
