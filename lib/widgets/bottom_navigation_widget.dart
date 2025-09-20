import 'package:flutter/material.dart';

class BottomNavigationWidget extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool hasNewCuratorOrders;

  const BottomNavigationWidget({
    Key? key,
    required this.currentIndex,
    required this.onTap,
    this.hasNewCuratorOrders = false,
  }) : super(key: key);

  @override
  State<BottomNavigationWidget> createState() => _BottomNavigationWidgetState();
}

class _BottomNavigationWidgetState extends State<BottomNavigationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _bounceAnimation = Tween<double>(
      begin: 1.0,
      end: 1.3,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    // Start animation if there are new orders
    if (widget.hasNewCuratorOrders) {
      _startBounceAnimation();
    }
  }

  @override
  void didUpdateWidget(BottomNavigationWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Start or stop animation based on new curator orders status
    if (widget.hasNewCuratorOrders && !oldWidget.hasNewCuratorOrders) {
      _startBounceAnimation();
    } else if (!widget.hasNewCuratorOrders && oldWidget.hasNewCuratorOrders) {
      _stopBounceAnimation();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _startBounceAnimation() {
    _animationController.repeat(reverse: true);
  }

  void _stopBounceAnimation() {
    _animationController.stop();
    _animationController.reset();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        // 1-px white outline
        decoration: const BoxDecoration(
          color: Colors.black,
          border: Border.fromBorderSide(
            BorderSide(color: Colors.white, width: 1),
          ),
        ),
        padding: const EdgeInsets.all(1), // space for white border
        child: Container(
          // 2-px gray outline
          decoration: const BoxDecoration(
            border: Border.fromBorderSide(
              BorderSide(color: Color(0xFF808080), width: 1),
            ),
          ),
          child: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            currentIndex: widget.currentIndex,
            onTap: widget.onTap,
            backgroundColor: Colors.black,
            // no selectedItemColor / unselectedItemColor → icons keep original colors
            items: [
              BottomNavigationBarItem(
                icon: Image.asset('assets/homeicon.png', width: 28, height: 32),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Image.asset('assets/ordericon.png', width: 32, height: 32),
                label: 'Order',
              ),
              BottomNavigationBarItem(
                icon: AnimatedBuilder(
                  animation: _bounceAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: widget.hasNewCuratorOrders ? _bounceAnimation.value : 1.0,
                      child: Image.asset('assets/curateicon.png', width: 32, height: 32),
                    );
                  },
                ),
                label: 'Curate',
              ),
              BottomNavigationBarItem(
                icon: Image.asset('assets/mymusicicon.png', width: 32, height: 32),
                label: 'My Music',
              ),
              BottomNavigationBarItem(
                icon: Image.asset('assets/profileicon.png', width: 32, height: 32),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
