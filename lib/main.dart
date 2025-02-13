import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'services/auth_service.dart';
import 'services/theme_service.dart';
import 'services/achievement_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/auth/auth_wrapper.dart';
import 'config/routes.dart';
import 'package:media_kit/media_kit.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  print('[Main] Flutter binding initialized');
  
  await dotenv.load(fileName: ".env");
  print('[Main] Environment variables loaded');
  
  await Firebase.initializeApp();
  print('[Main] Firebase core initialized');
  
  // Initialize App Check with debug token
  try {
    print('[Main] Initializing App Check');
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.debug,
      // Debug token will be printed to console on first run
      appleProvider: AppleProvider.debug,
      webProvider: ReCaptchaV3Provider('6LeOttUqAAAAAMco_cLsCmPt-w0ixUAoX8dUTQcq'),
    );
    print('[Main] App Check initialized successfully');
  } catch (e) {
    print('[Main] Error initializing App Check: $e');
  }
  
  print('[Main] Starting app');
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeService()),
        Provider<AchievementService>(create: (_) => AchievementService()),
        ProxyProvider<AchievementService, AuthService>(
          update: (_, achievementService, __) => AuthService(achievementService: achievementService),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        return MaterialApp(
          title: 'OHFtok',
          theme: ThemeData(
            colorScheme: themeService.currentTheme.colorScheme,
            useMaterial3: true,
            pageTransitionsTheme: const PageTransitionsTheme(
              builders: {
                TargetPlatform.android: CupertinoPageTransitionsBuilder(),
                TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
              },
            ),
          ),
          initialRoute: Routes.login,
          routes: {
            ...Routes.routes,
            Routes.initial: (context) => const AuthWrapper(),
          },
        );
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: Provider.of<AuthService>(context).authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasData) {
          return FutureBuilder<bool>(
            future: Provider.of<AuthService>(context, listen: false)
                .hasCompletedOnboarding(snapshot.data!.uid),
            builder: (context, onboardingSnapshot) {
              if (onboardingSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (onboardingSnapshot.data == true) {
                return const HomePage();
              } else {
                return const OnboardingScreen();
              }
            },
          );
        }
        
        return const LoginScreen();
      },
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('OHFtok'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await authService.signOut();
              if (context.mounted) {
                Navigator.of(context).pushReplacementNamed('/login');
              }
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Welcome to OHFtok!'),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
