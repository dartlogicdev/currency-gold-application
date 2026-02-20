import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService {
  static const String _themeKey = 'app_theme_mode';
  
  // Singleton Pattern
  static final ThemeService _instance = ThemeService._internal();
  factory ThemeService() => _instance;
  ThemeService._internal();

  // Theme Mode Speichern
  Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, mode.toString());
  }

  // Theme Mode Laden
  Future<ThemeMode> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final themeName = prefs.getString(_themeKey);
    
    if (themeName == null) return ThemeMode.system;
    
    switch (themeName) {
      case 'ThemeMode.light':
        return ThemeMode.light;
      case 'ThemeMode.dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }
}
