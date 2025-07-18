import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'navigator_service.dart';
import 'routes.dart';
import 'screens/home_screen.dart';
import 'screens/mymusic_screen.dart';
import 'screens/order_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/emailverification_screen.dart';
import 'models/order_model.dart';
import 'widgets/app_bar_widget.dart';
import 'widgets/bottom_navigation_widget.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'screens/order_selection_screen.dart';

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();

  // Preserve the splash screen
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Set the app to portrait mode only
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // Initialize Firebase
  await Firebase.initializeApp();

  // Initialize Crashlytics
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

  // Remove the splash screen after initialization is complete
  FlutterNativeSplash.remove();

  // Run the app
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // Asynchronous initialization can be handled here
  @override
  void initState() {
    super.initState();
    _initializeStripe();
  }

  Future<void> _initializeStripe() async {
    // Set your Stripe publishable key
    Stripe.publishableKey = 'pk_live_51ODzOACnvJAFsDZ0COKFc7cuwsL2eAijLCxdMETnP8pGsydvkB221bJFeGKuynxSgzUQ0d9T7bDIxcCwcDcmqgDn004VZLJQio'; // Replace with your actual key

    // Optionally, set the Stripe merchant identifier and other settings
    await Stripe.instance.applySettings();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => OrderModel()),
      ],
      child: MaterialApp(
        title: 'DISSONANT',
        theme: ThemeData(
          brightness: Brightness.dark,
          primaryColor: Color(0xFFFFA500), // Orange
          scaffoldBackgroundColor: Colors.black,
          colorScheme: ColorScheme.dark(
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
          appBarTheme: AppBarTheme(
            color: Color(0xFF1E1E1E), // A slightly lighter off-black
          ),
        ),
        navigatorKey: NavigatorService.navigatorKey,
        routes: {
          welcomeRoute: (context) => WelcomeScreen(),
          homeRoute: (context) => HomeScreen(),
          emailVerificationRoute: (context) => EmailVerificationScreen(),

          // Add other routes here
        },
        home: AuthenticationWrapper(),

        // Added builder to override textScaleFactor
        builder: (BuildContext context, Widget? child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaleFactor: 1.0),
            child: child!,
          );
        },
      ),
    );
  }
}

class AuthenticationWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: Colors.black, // Match your app's background color
            body: Center(child: CircularProgressIndicator()),
          );
        } else if (snapshot.hasData) {
          User? user = snapshot.data;
          if (user != null && user.emailVerified) {
            return MyHomePage();
          } else {
            return EmailVerificationScreen();
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
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _selectedIndex = 0;

  // ─── NEW: navigator dedicated to the Home tab ────────────────
  final GlobalKey<NavigatorState> _homeNavigatorKey =
      GlobalKey<NavigatorState>();

  final List<Widget> _plainPages = [
    OrderSelectionScreen(),
    MyMusicScreen(),
    ProfileScreen(),
  ];

  // ─── NEW: helper so HomeScreen can push while keeping the bar ─
  Future<T?> pushInHomeTab<T>(Route<T> route) {
    return _homeNavigatorKey.currentState!.push(route);
  }

  static _MyHomePageState? of(BuildContext context) =>
      context.findAncestorStateOfType<_MyHomePageState>();

  void _onItemTapped(int index) {
    if (index == _selectedIndex) {
      // ▸ already on that tab
      if (index == 0) {
        // ▸ and it’s the Home tab → pop to its first route
        _homeNavigatorKey.currentState
            ?.popUntil((route) => route.isFirst);
      }
      // ▸ for other tabs we do nothing (leave as‑is)
    } else {
      // ▸ switching to a different tab
      setState(() => _selectedIndex = index);
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: 'DISSONANT'),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          // ── index 0: Home tab now owns its own Navigator ──
          Navigator(
            key: _homeNavigatorKey,
            onGenerateRoute: (_) =>
                MaterialPageRoute(builder: (_) => const HomeScreen()),
          ),
          // ── remaining tabs unchanged ────────────────────────
          ..._plainPages,
        ],
      ),
      bottomNavigationBar: BottomNavigationWidget(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}


