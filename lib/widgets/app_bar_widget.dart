import 'package:flutter/material.dart';
import '../screens/how_it_works_screen.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;

  const CustomAppBar({Key? key, required this.title}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Container(
        // Outer 1px white border
        decoration: const BoxDecoration(
          color: Color(0xFFE46A14), // Main orange color
          border: Border.fromBorderSide(
            BorderSide(color: Colors.white, width: 1),
          ),
        ),
        padding: const EdgeInsets.all(1),
        child: Container(
          // Inner 2px lighter-orange border
          decoration: const BoxDecoration(
            border: Border.fromBorderSide(
              BorderSide(color: Color(0xFFFF9D4D), width: 1), // softer light-orange border
            ),
          ),
          child: AppBar(
            backgroundColor: const Color(0xFFE46A14),
            elevation: 0,
            centerTitle: false,
            titleSpacing: 0,
            title: Padding(
              padding: const EdgeInsets.only(left: 12), // slight indent to the logo/title
              child: Row(
                children: [
                  Image.asset(
                    'assets/dissonantlogo.png',
                    height: 32,
                  ),
                  const SizedBox(width: 8),
                  Text(title),
                ],
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => HowItWorksPage(showExitButton: true),
                    ),
                  ),
                  child: Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE46A14),
                      border: Border.all(
                        color: Colors.white,
                        width: 2,
                      ),
                    ),
                    child: const Text(
                      '?',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.white, // NOW white, not black
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
