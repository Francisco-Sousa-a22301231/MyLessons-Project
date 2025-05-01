import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mylessons_frontend/pages/register_landing_page.dart';
import 'package:mylessons_frontend/providers/home_page_provider.dart';
import 'package:mylessons_frontend/providers/lessons_modal_provider.dart';
import 'package:mylessons_frontend/providers/pack_details_provider.dart';
import 'package:mylessons_frontend/providers/school_data_provider.dart';
import 'package:mylessons_frontend/providers/school_provider.dart';
import 'package:provider/provider.dart';
import 'pages/email_login_page.dart';
import 'pages/landing_page.dart';
import 'pages/login_page.dart';
import 'pages/register_page.dart';
import 'main_layout.dart'; // Import MainScreen
import 'pages/payment_success_page.dart';
import 'pages/payment_fail_page.dart';
import 'package:flutter/rendering.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:app_links/app_links.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

// Create a global RouteObserver instance.
final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

// Global navigator key for all navigation actions.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize Stripe with your publishable key
  Stripe.publishableKey =
      'pk_test_51QmkhlJwT5CCGmgeZvrzwLxdAQm0Y9vGukn6KVLEsNDHWuJvZYKY49Ve8Kg6U2pWnAAVQRzadpKLiPXTQpYrPJYL005oFEcVGR';
  // ... Initialize Firebase if needed, etc.
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  debugPaintSizeEnabled = false;
 
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SchoolProvider()),
        ChangeNotifierProvider(create: (_) => LessonModalProvider()),
        ChangeNotifierProvider(create: (_) => PackDetailsProvider()),
        ChangeNotifierProvider(create: (_) => HomePageProvider()),
        ChangeNotifierProvider(create: (_) => SchoolDataProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  StreamSubscription<Uri?>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MyLessons App',
      navigatorKey: navigatorKey,
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        toggleButtonsTheme: ToggleButtonsThemeData(
          fillColor: Colors.orange,
          selectedColor: Colors.white,
          color: Colors.orange, // unselected text color
          borderColor: Colors.orange,
          borderWidth: 2.0, // thicker border
          borderRadius: BorderRadius.circular(32.0),
          selectedBorderColor: Colors.orange,
        ),
        bottomSheetTheme: BottomSheetThemeData(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
        ),
        dialogTheme: DialogTheme(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: Colors.orange,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.black),
          titleTextStyle: TextStyle(color: Colors.black, fontSize: 20),
        ),
        cardTheme: CardTheme(
          color: Colors.grey[50],
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: Colors.orange,
          contentTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
          actionTextColor: Colors.white,
        ),
        primarySwatch: Colors.orange,
        timePickerTheme: TimePickerThemeData(),
        datePickerTheme: DatePickerThemeData(
          headerBackgroundColor: Colors.orange,
          headerForegroundColor: Colors.white,
          backgroundColor: Colors.white,
          todayBorder: const BorderSide(color: Colors.orange, width: 1.5),
          dayForegroundColor:
              MaterialStateProperty.resolveWith<Color?>((states) {
            if (states.contains(MaterialState.selected)) {
              return Colors.white;
            }
            return null;
          }),
          dayBackgroundColor:
              MaterialStateProperty.resolveWith<Color?>((states) {
            if (states.contains(MaterialState.selected)) {
              return Colors.orange;
            }
            return null;
          }),
          todayForegroundColor:
              MaterialStateProperty.resolveWith<Color?>((states) {
            if (states.contains(MaterialState.selected)) {
              return Colors.white;
            }
            return Colors.orange;
          }),
          todayBackgroundColor:
              MaterialStateProperty.resolveWith<Color?>((states) {
            if (states.contains(MaterialState.selected)) {
              return Colors.orange;
            }
            return null;
          }),
          dayOverlayColor: MaterialStateProperty.all(Colors.transparent),
        ),
        checkboxTheme: CheckboxThemeData(
          fillColor: MaterialStateProperty.resolveWith<Color?>((states) {
            if (states.contains(MaterialState.selected)) {
              return Colors.orange; // Fill orange when checked.
            }
            return Colors.transparent; // Transparent when unchecked.
          }),
          side: MaterialStateBorderSide.resolveWith((states) {
            return BorderSide(
                color: Colors.orange, width: 2.0); // Thicker border.
          }),
        ),
        tabBarTheme: const TabBarTheme(
          labelColor: Colors.orange,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.orange,
          labelStyle: TextStyle(
            fontSize: 16.0,
            fontWeight: FontWeight.bold,
          ),
          unselectedLabelStyle: TextStyle(
            fontSize: 16.0,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.black,
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: Colors.black,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.black,
            side: const BorderSide(color: Colors.orange),
          ),
        ),
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: Colors.orange,
          selectionColor: Colors.orange.withOpacity(0.3),
          selectionHandleColor: Colors.orange,
        ),
        inputDecorationTheme: InputDecorationTheme(
          hintStyle: const TextStyle(color: Colors.black),
          labelStyle: const TextStyle(color: Colors.black),
          floatingLabelStyle: const TextStyle(color: Colors.black),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(32.0),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(32.0),
            borderSide: const BorderSide(color: Colors.orange, width: 2.0),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(32.0),
            borderSide: const BorderSide(color: Colors.orange, width: 2.0),
          ),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => LandingPage(),
        '/main': (context) {
          final args = ModalRoute.of(context)?.settings.arguments
                  as Map<String, dynamic>? ??
              {};
          return MainScreen(
            newBookedPacks: args['newBookedPacks'] ?? [],
            initialIndex: args['initialIndex'] ?? 0,
          );
        },
        '/login': (context) => const LoginPage(),
        '/register_landing_page': (context) => const RegisterLandingPage(),
        '/register_page': (context) => const RegisterPage(),
        '/email_login': (context) => const EmailLoginPage(),
      },
      navigatorObservers: [routeObserver],
    );
  }
}
