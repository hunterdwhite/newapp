import 'package:flutter/material.dart';
import 'dart:math' as math;

class SpinningCDWidget extends StatefulWidget {
  final double size;

  const SpinningCDWidget({Key? key, this.size = 300.0}) : super(key: key);

  @override
  _SpinningCDWidgetState createState() => _SpinningCDWidgetState();
}

class _SpinningCDWidgetState extends State<SpinningCDWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(); // Repeat the animation indefinitely
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: Image.asset(
        'assets/blank_cd_disc.png', // This should be your spinning blank CD image
        height: widget.size,
        width: widget.size,
      ),
      builder: (context, child) {
        return Transform.rotate(
          angle: _controller.value * 2.0 * math.pi,
          child: child,
        );
      },
    );
  }
}