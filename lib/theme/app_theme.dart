import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeNotifier extends ChangeNotifier {
  bool _isDarkMode = false;
  
  bool get isDarkMode => _isDarkMode;
  
  ThemeNotifier() {
    _loadThemeFromPrefs();
  }
  
  void _loadThemeFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('isDarkTheme') ?? false;
    notifyListeners();
  }
  
  void toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkTheme', _isDarkMode);
    notifyListeners();
  }
  
  void setTheme(bool isDark) async {
    if (_isDarkMode != isDark) {
      _isDarkMode = isDark;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isDarkTheme', _isDarkMode);
      notifyListeners();
    }
  }
}

class AppTheme {
  // Remove hardcoded theme mode - let ThemeNotifier handle it
  
  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      primarySwatch: Colors.blue,
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
      ),
      cardColor: Colors.white,
      iconTheme: const IconThemeData(
        color: Colors.black,
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Colors.black),
        bodyMedium: TextStyle(color: Colors.black),
        titleLarge: TextStyle(color: Colors.black),
      ),
      colorScheme: ColorScheme.light(
        primary: const Color(0xFF232228),
        secondary: Colors.grey[300]!,
        surface: Colors.white,
        background: Colors.white,
        onPrimary: Colors.white,
        onSecondary: Colors.black,
        onSurface: Colors.black,
        onBackground: Colors.black,
        outline: Colors.grey[400]!, // Added outline color for borders
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primarySwatch: Colors.blue,
      scaffoldBackgroundColor: const Color(0xFF121212),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF121212),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Color(0xFF1E1E1E),
      ),
      cardColor: const Color(0xFF1E1E1E),
      iconTheme: const IconThemeData(
        color: Colors.white,
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Colors.white),
        bodyMedium: TextStyle(color: Colors.white),
        titleLarge: TextStyle(color: Colors.white),
      ),
      colorScheme: ColorScheme.dark(
        primary: const Color(0xFF232228),
        secondary: Colors.grey[700]!,
        surface: const Color(0xFF1E1E1E),
        background: const Color(0xFF121212),
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: Colors.white,
        onBackground: Colors.white,
        outline: Colors.grey[600]!, // Added outline color for borders
      ),
    );
  }
} 