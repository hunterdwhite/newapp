import 'package:flutter/material.dart';

class NavigatorService {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static void pushNamed(String routeName, {Object? arguments}) {
    navigatorKey.currentState!.pushNamed(routeName, arguments: arguments);
  }

  static void pop() {
    navigatorKey.currentState!.pop();
  }
}