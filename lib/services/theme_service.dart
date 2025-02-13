import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService extends ChangeNotifier {
  final String key = "theme";
  SharedPreferences? _prefs;
  bool _isDarkMode = false;

  // Custom color schemes
  static const List<ColorScheme> _availableColorSchemes = [
    ColorScheme.light(
      primary: Color(0xFF6200EE),
      secondary: Color(0xFF03DAC6),
      surface: Colors.white,
      background: Colors.white,
      error: Colors.red,
    ),
    ColorScheme.dark(
      primary: Color(0xFFBB86FC),
      secondary: Color(0xFF03DAC6),
      surface: Color(0xFF121212),
      background: Color(0xFF121212),
      error: Colors.red,
    ),
  ];

  // Animation durations
  static const Duration defaultAnimationDuration = Duration(milliseconds: 300);
  static const Duration longAnimationDuration = Duration(milliseconds: 500);

  // Curve for psychedelic animations
  static const Curve psychedelicCurve = Curves.easeInOutBack;

  bool get isDarkMode => _isDarkMode;
  
  ThemeService() {
    _loadFromPrefs();
  }

  _initPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  _loadFromPrefs() async {
    await _initPrefs();
    _isDarkMode = _prefs?.getBool(key) ?? false;
    notifyListeners();
  }

  _saveToPrefs() async {
    await _initPrefs();
    _prefs?.setBool(key, _isDarkMode);
  }

  ThemeData get currentTheme {
    final colorScheme = _availableColorSchemes[_isDarkMode ? 1 : 0];
    
    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      // Custom theme properties
      cardTheme: CardTheme(
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      buttonTheme: ButtonThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      // Custom text themes
      textTheme: TextTheme(
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: _isDarkMode ? Colors.white : Colors.black,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          color: _isDarkMode ? Colors.white70 : Colors.black87,
        ),
      ),
      // Custom input decoration
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: _isDarkMode ? Colors.grey[800] : Colors.grey[100],
      ),
    );
  }

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    _saveToPrefs();
    notifyListeners();
  }

  // Animation builders
  static Widget buildPageTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.0, 0.3),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: animation,
            curve: psychedelicCurve,
          ),
        ),
        child: child,
      ),
    );
  }

  // Custom animations for specific widgets
  static Animation<double> buildPulseAnimation(AnimationController controller) {
    return Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: controller,
        curve: psychedelicCurve,
      ),
    );
  }
} 