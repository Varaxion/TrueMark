import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const _key = 'is_dark_mode';
  bool _isDark = false;

  bool get isDark => _isDark;
  ThemeMode get themeMode => _isDark ? ThemeMode.dark : ThemeMode.light;

  ThemeProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _isDark = prefs.getBool(_key) ?? false;
    notifyListeners();
  }

  Future<void> toggleTheme(bool value) async {
    _isDark = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }

  // ── PREMIUM LIGHT MODE ───────────────────────────────────────────────────
  static ThemeData get lightTheme => ThemeData(
    brightness: Brightness.light,
    primarySwatch: Colors.indigo,
    scaffoldBackgroundColor: const Color(0xFFF8F9FA),
    fontFamily: 'Montserrat',
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.indigo,
      brightness: Brightness.light,
      surface: Colors.white,
      onSurface: const Color(0xFF1A1A1A),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      iconTheme: IconThemeData(color: Color(0xFF303F9F)), // Stronger Indigo
      titleTextStyle: TextStyle(color: Color(0xFF303F9F), fontSize: 20, fontWeight: FontWeight.bold),
    ),
  );

  // ── MIDNIGHT AMOLED (Dark Mode) ──────────────────────────────────────────
  static ThemeData get darkTheme => ThemeData(
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
      onSecondary: Colors.white70, // Brighter sub-text
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFF121212),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    cardColor: const Color(0xFF0D0D0D),
    drawerTheme: const DrawerThemeData(backgroundColor: Color(0xFF050505)),
    dialogTheme: const DialogThemeData(backgroundColor: Color(0xFF0D0D0D)),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white24)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white24)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white70)),
      labelStyle: const TextStyle(color: Colors.white60),
      hintStyle: const TextStyle(color: Colors.white30),
      fillColor: Colors.white10,
      filled: true,
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Colors.white),
      bodyMedium: TextStyle(color: Colors.white), // Full white for body in dark
      titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
    ),
    dividerColor: Colors.white12,
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) =>
        s.contains(WidgetState.selected) ? Colors.indigoAccent : Colors.white38),
      trackColor: WidgetStateProperty.resolveWith((s) =>
        s.contains(WidgetState.selected) ? Colors.indigo.withOpacity(0.5) : Colors.white12),
    ),
    bottomSheetTheme: const BottomSheetThemeData(backgroundColor: Color(0xFF0D0D0D)),
    popupMenuTheme: const PopupMenuThemeData(color: Color(0xFF0D0D0D)),
  );
}
