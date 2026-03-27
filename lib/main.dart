import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:window_manager/window_manager.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'screens/signup_screen.dart';
import 'screens/login_screen.dart';
import 'screens/profile_setup_screen.dart';
import 'screens/home_screen.dart';
import 'package:oktoast/oktoast.dart';
import 'widgets/windows_frame.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows) {
    try {
      await windowManager.ensureInitialized();
      const windowOptions = WindowOptions(
        size: Size(960, 720),
        minimumSize: Size(960, 720),
        maximumSize: Size(960, 720),
        center: true,
        title: 'TrueMark',
      );
      windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.setResizable(false);
        await windowManager.setMaximizable(false);
        await windowManager.show();
        await windowManager.focus();
      });
    } catch (_) {
      // Plugin may not be registered on hot restart; ignore and continue.
    }
  }

  runApp(const AppInitializer());
}

class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  Future<void>? _initFuture;

  @override
  void initState() {
    super.initState();
    _initFuture = _initFirebase();
  }

  Future<void> _initFirebase() async {
    if (Firebase.apps.isNotEmpty) {
      return;
    }
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e) {
      if (e.toString().contains('duplicate-app')) {
        return;
      }
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(body: Center(child: CircularProgressIndicator())),
          );
        }
        if (snapshot.hasError) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, color: Colors.red, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        'Firebase Init Error:\n${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
        return const TrueMarkApp();
      },
    );
  }
}

class TrueMarkApp extends StatelessWidget {
  const TrueMarkApp({super.key});

  @override
  Widget build(BuildContext context) {
    final isWindows = Platform.isWindows;
    return OKToast(
      child: MaterialApp(
        title: 'TrueMark',
        themeMode: ThemeMode.dark,
        darkTheme: ThemeData(
          brightness: Brightness.dark,
          primarySwatch: Colors.indigo,
          scaffoldBackgroundColor: Colors.black,
          fontFamily: 'Montserrat',
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.indigo,
            brightness: Brightness.dark,
            surface: Colors.black,
            onSurface: Colors.white,
          ),
          visualDensity: isWindows ? VisualDensity.compact : VisualDensity.standard,
        ),
        debugShowCheckedModeBanner: false,
        scrollBehavior: const _AppScrollBehavior(),
        builder: (context, child) {
          if (!isWindows || child == null) return child ?? const SizedBox.shrink();
          final base = Theme.of(context);
          final windowsTheme = base.copyWith(
            textTheme: base.textTheme.apply(fontSizeFactor: 0.92, heightFactor: 0.98),
            inputDecorationTheme: base.inputDecorationTheme.copyWith(
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            appBarTheme: base.appBarTheme.copyWith(
              toolbarHeight: 48,
              titleSpacing: 12,
              centerTitle: false,
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(240, 44),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            listTileTheme: base.listTileTheme.copyWith(
              dense: true,
              minVerticalPadding: 8,
              horizontalTitleGap: 12,
            ),
            dividerTheme: base.dividerTheme.copyWith(
              thickness: 0.6,
              space: 24,
              color: Colors.white12,
            ),
            dialogTheme: base.dialogTheme.copyWith(
              insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            scrollbarTheme: base.scrollbarTheme.copyWith(
              thickness: WidgetStateProperty.all(6),
              radius: const Radius.circular(6),
              thumbColor: WidgetStateProperty.all(Colors.white24),
            ),
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(220, 40),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            cardTheme: base.cardTheme.copyWith(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
              elevation: 2,
            ),
          );
          return Theme(
            data: windowsTheme,
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(0.92)),
              child: WindowsFrame(child: child),
            ),
          );
        },
        home: const AuthWrapper(),
        routes: {
          '/login': (_) => const LoginScreen(),
          '/signup': (_) => const SignupScreen(),
          '/setup': (_) => const ProfileSetupScreen(),
          '/home': (_) => const HomeScreen(),
        },
      ),
    );
  }
}

class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
      };
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  Future<Widget> getInitialScreen() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const LoginScreen();
    }

    try {
      // Check Firestore for user profile
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = doc.data();
      if (data == null || data['name'] == null) {
        return ProfileSetupScreen();
      }

      return const HomeScreen();
    } on FirebaseException catch (e) {
      // Return a friendly retry screen that shows the Firestore error message
      final msg = e.message ?? 'Firestore error';
      return _ErrorRetryScreen(message: 'Firestore error: $msg');
    } catch (e) {
      return _ErrorRetryScreen(message: 'Unexpected error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: getInitialScreen(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(child: Text('Something went wrong')),
          );
        }

        return snapshot.data!;
      },
    );
  }
}

class _ErrorRetryScreen extends StatelessWidget {
  final String message;
  const _ErrorRetryScreen({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connection error')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  // Retry by rebuilding the AuthWrapper
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const AuthWrapper()),
                  );
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}