import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'routes.dart';
import 'screens/home_screen.dart';
import 'screens/mymusic_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/curator_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/email_verification_screen.dart';
import 'models/order_model.dart';
import 'widgets/app_bar_widget.dart';
import 'widgets/bottom_navigation_widget.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'screens/order_selection_screen.dart';
import 'services/firestore_service.dart';

// Global navigator key for push notifications
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();

  // Preserve the splash screen
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Performance optimizations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // Optimize memory usage
  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.manual,
    overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
  );

  try {
    // Initialize Firebase with offline persistence
    await Firebase.initializeApp();
    
    // Configure Firebase settings for better performance
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );

    // Initialize Crashlytics with custom settings
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    };

    // Handle async errors
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };

  } catch (e) {
    debugPrint('Firebase initialization error: $e');
  }

  // Remove the splash screen after initialization is complete
  FlutterNativeSplash.remove();

  // Run the app with performance monitoring
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  static const String _stripePublishableKey = 'pk_live_51ODzOACnvJAFsDZ0COKFc7cuwsL2eAijLCxdMETnP8pGsydvkB221bJFeGKuynxSgzUQ0d9T7bDIxcCwcDcmqgDn004VZLJQio';
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeStripe();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // Optimize based on app lifecycle
    switch (state) {
      case AppLifecycleState.paused:
        // Clear image cache when app is paused to free memory
        imageCache.clear();
        break;
      case AppLifecycleState.resumed:
        // Preload critical images when app resumes
        _preloadCriticalAssets();
        break;
      default:
        break;
    }
  }

  Future<void> _initializeStripe() async {
    try {
      Stripe.publishableKey = _stripePublishableKey;
      await Stripe.instance.applySettings();
    } catch (e) {
      debugPrint('Stripe initialization error: $e');
    }
  }

  void _preloadCriticalAssets() {
    // Preload commonly used assets
    const criticalAssets = [
      'assets/dissonantlogo.png',
      'assets/blank_cd.png',
      'assets/homeicon.png',
      'assets/mymusicicon.png',
      'assets/ordericon.png',
      'assets/profileicon.png',
    ];

    for (final asset in criticalAssets) {
      precacheImage(AssetImage(asset), context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => OrderModel()),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'DISSONANT',
        debugShowCheckedModeBanner: false,
        
        // Performance optimizations
        scrollBehavior: const MaterialScrollBehavior().copyWith(
          scrollbars: false, // Disable scrollbars for better performance
        ),
        
        theme: ThemeData(
          brightness: Brightness.dark,
          primaryColor: const Color(0xFFFFA500), // Orange
          scaffoldBackgroundColor: Colors.black,
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFFFFA500),
            primaryContainer: Color(0xFFE59400),
            secondary: Color(0xFFFF4500),
            secondaryContainer: Color(0xFFCC3700),
            surface: Colors.black,
            error: Colors.red,
            onPrimary: Colors.white,
            onSecondary: Colors.white,
            onSurface: Colors.white,
            onError: Colors.white,
          ),
          textTheme: GoogleFonts.figtreeTextTheme(
            ThemeData.dark().textTheme,
          ).apply(
            bodyColor: Colors.white,
            displayColor: Colors.white,
          ),
          appBarTheme: const AppBarTheme(
            color: Color(0xFF1E1E1E), // A slightly lighter off-black
          ),
          
          // Optimize visual density for performance
          visualDensity: VisualDensity.adaptivePlatformDensity,
          
          // Disable animations on low-end devices
          pageTransitionsTheme: const PageTransitionsTheme(
            builders: {
              TargetPlatform.android: CupertinoPageTransitionsBuilder(),
              TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            },
          ),
        ),
        routes: {
          welcomeRoute: (context) => WelcomeScreen(),
          homeRoute: (context) => HomeScreen(),
          emailVerificationRoute: (context) => const EmailVerificationScreen(),
        },
        home: const AuthenticationWrapper(),

        // Optimize text scaling for performance and consistency
        builder: (BuildContext context, Widget? child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaleFactor: 1.0,
              // Reduce overdraw by limiting window insets
              viewInsets: EdgeInsets.zero,
            ),
            child: child!,
          );
        },
      ),
    );
  }
}

class AuthenticationWrapper extends StatelessWidget {
  const AuthenticationWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                ),
              ),
            ),
          );
        } else if (snapshot.hasData) {
          User? user = snapshot.data;
          if (user != null && user.emailVerified) {
            return const MyHomePage();
          } else {
            return const EmailVerificationScreen();
          }
        } else {
          return WelcomeScreen();
        }
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
    const MyHomePage({Key? key}) : super(key: key);

  /// ⬇️  add this static helper HERE (not in the State class)
  static _MyHomePageState? of(BuildContext context) =>
      context.findAncestorStateOfType<_MyHomePageState>();

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late final PageController _pageController;
  final FirestoreService _firestoreService = FirestoreService();
  bool _hasNewCuratorOrders = false;

  // ─── Navigators for tabs that need sub-navigation ────────────────
  final GlobalKey<NavigatorState> _homeNavigatorKey =
      GlobalKey<NavigatorState>();
  final GlobalKey<NavigatorState> _orderNavigatorKey =
      GlobalKey<NavigatorState>();

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    
    // Initialize pages with const constructors where possible
    _pages = [
      const CuratorScreen(),
      MyMusicScreen(),
      ProfileScreen(),
    ];
    
    // Listen for new curator orders
    _listenForNewCuratorOrders();
  }
  
  void _listenForNewCuratorOrders() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _firestoreService.hasNewCuratorOrders(user.uid).listen((hasNewOrders) {
        if (mounted) {
          setState(() {
            _hasNewCuratorOrders = hasNewOrders;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // ─── Helpers for tab navigation ─
  Future<T?> pushInHomeTab<T>(Route<T> route) {
    return _homeNavigatorKey.currentState!.push(route);
  }

  Future<T?> pushInOrderTab<T>(Route<T> route) {
    return _orderNavigatorKey.currentState!.push(route);
  }

  void _onItemTapped(int index) {
    if (index == _selectedIndex) {
      // ▸ already on that tab
      if (index == 0) {
        // ▸ and it's the Home tab → pop to its first route
        _homeNavigatorKey.currentState
            ?.popUntil((route) => route.isFirst);
      } else if (index == 1) {
        // ▸ Order tab → pop to its first route
        _orderNavigatorKey.currentState
            ?.popUntil((route) => route.isFirst);
      }
      // ▸ for other tabs we do nothing (leave as‑is)
    } else {
      // ▸ switching to a different tab
      setState(() => _selectedIndex = index);
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBarWidget(title: 'DISSONANT'),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(), // Disable swipe navigation
        onPageChanged: (index) {
          setState(() => _selectedIndex = index);
        },
        children: [
          // ── index 0: Home tab now owns its own Navigator ──
          Navigator(
            key: _homeNavigatorKey,
            onGenerateRoute: (_) =>
                MaterialPageRoute(builder: (_) => const HomeScreen()),
          ),
          // ── index 1: Order tab with its own Navigator ──
          Navigator(
            key: _orderNavigatorKey,
            onGenerateRoute: (_) =>
                MaterialPageRoute(builder: (_) => OrderSelectionScreen()),
          ),
          // ── remaining tabs unchanged ────────────────────────
          ..._pages,
        ],
      ),
      bottomNavigationBar: BottomNavigationWidget(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        hasNewCuratorOrders: _hasNewCuratorOrders,
      ),
    );
  }
}


