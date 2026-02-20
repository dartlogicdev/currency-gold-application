import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum HapticLevel {
  all,      // Alle Aktionen
  important, // Nur wichtige Aktionen
  off       // Kein Haptic
}

class HapticService {
  static final HapticService _instance = HapticService._internal();
  factory HapticService() => _instance;
  HapticService._internal();

  HapticLevel _level = HapticLevel.all;
  
  static const String _key = 'haptic_level';

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final levelStr = prefs.getString(_key);
    if (levelStr != null) {
      _level = HapticLevel.values.firstWhere(
        (e) => e.name == levelStr,
        orElse: () => HapticLevel.all,
      );
    }
  }

  Future<void> setLevel(HapticLevel level) async {
    _level = level;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, level.name);
  }

  HapticLevel getLevel() => _level;

  // Light Haptic - für alle kleinen Aktionen
  void light() {
    if (_level != HapticLevel.off) {
      HapticFeedback.lightImpact();
    }
  }

  // Medium Haptic - für wichtige Aktionen
  void medium() {
    if (_level == HapticLevel.all || _level == HapticLevel.important) {
      HapticFeedback.mediumImpact();
    }
  }

  // Heavy Haptic - nur für sehr wichtige Aktionen
  void heavy() {
    if (_level == HapticLevel.all || _level == HapticLevel.important) {
      HapticFeedback.heavyImpact();
    }
  }

  // Selection - für Toggles/Switches
  void selection() {
    if (_level != HapticLevel.off) {
      HapticFeedback.selectionClick();
    }
  }
}
