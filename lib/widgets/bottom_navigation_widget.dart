import 'package:flutter/material.dart';

class BottomNavigationWidget extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const BottomNavigationWidget({
    Key? key,
    required this.currentIndex,
    required this.onTap,
  }) : super(key: key);

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
            currentIndex: currentIndex,
            onTap: onTap,
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
