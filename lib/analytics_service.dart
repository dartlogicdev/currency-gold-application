import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Lokaler Analytics Service - DSGVO-konform, keine externen Services
/// Speichert Events lokal in SharedPreferences für spätere Analyse
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  static const String _eventsKey = 'analytics_events';
  static const String _sessionCountKey = 'analytics_session_count';
  static const int _maxEvents = 1000; // Limitiere Speicher

  /// Tracke ein Event mit optionalen Properties
  Future<void> trackEvent(String eventName, [Map<String, dynamic>? properties]) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Lade existierende Events
      final eventsJson = prefs.getString(_eventsKey) ?? '[]';
      final List<dynamic> events = jsonDecode(eventsJson);
      
      // Erstelle neues Event
      final event = {
        'name': eventName,
        'timestamp': DateTime.now().toIso8601String(),
        'properties': properties ?? {},
      };
      
      // Füge Event hinzu (FIFO wenn zu viele)
      events.add(event);
      if (events.length > _maxEvents) {
        events.removeAt(0); // Ältestes Event entfernen
      }
      
      // Speichere zurück
      await prefs.setString(_eventsKey, jsonEncode(events));
      
      debugPrint('[Analytics] Event: $eventName ${properties ?? ""}');
    } catch (e) {
      debugPrint('[Analytics] Fehler beim Tracking: $e');
    }
  }

  /// Erhöhe Session-Counter (App-Start)
  Future<void> incrementSessionCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final count = prefs.getInt(_sessionCountKey) ?? 0;
      await prefs.setInt(_sessionCountKey, count + 1);
      await trackEvent('app_opened', {'session_number': count + 1});
    } catch (e) {
      debugPrint('[Analytics] Fehler beim Session-Tracking: $e');
    }
  }

  /// Hole alle Events
  Future<List<Map<String, dynamic>>> getAllEvents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final eventsJson = prefs.getString(_eventsKey) ?? '[]';
      final List<dynamic> events = jsonDecode(eventsJson);
      return events.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('[Analytics] Fehler beim Laden der Events: $e');
      return [];
    }
  }

  /// Hole Event-Statistiken
  Future<Map<String, dynamic>> getStatistics() async {
    try {
      final events = await getAllEvents();
      final prefs = await SharedPreferences.getInstance();
      final sessionCount = prefs.getInt(_sessionCountKey) ?? 0;

      // Zähle Event-Types
      final Map<String, int> eventCounts = {};
      for (final event in events) {
        final name = event['name'] as String;
        eventCounts[name] = (eventCounts[name] ?? 0) + 1;
      }

      // Sortiere nach Häufigkeit
      final sortedEvents = eventCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      // Letzte 7 Tage Events
      final now = DateTime.now();
      final last7Days = events.where((event) {
        final timestamp = DateTime.parse(event['timestamp'] as String);
        return now.difference(timestamp).inDays <= 7;
      }).length;

      return {
        'total_events': events.length,
        'total_sessions': sessionCount,
        'event_counts': Map.fromEntries(sortedEvents),
        'last_7_days_events': last7Days,
        'first_event': events.isNotEmpty ? events.first['timestamp'] : null,
        'last_event': events.isNotEmpty ? events.last['timestamp'] : null,
      };
    } catch (e) {
      debugPrint('[Analytics] Fehler bei Statistiken: $e');
      return {};
    }
  }

  /// Lösche alle Analytics-Daten (für DSGVO-Compliance)
  Future<void> clearAllData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_eventsKey);
      await prefs.remove(_sessionCountKey);
      debugPrint('[Analytics] Alle Daten gelöscht');
    } catch (e) {
      debugPrint('[Analytics] Fehler beim Löschen: $e');
    }
  }

  // ===== Event-Helper-Methoden =====

  /// Tab wurde geöffnet
  Future<void> trackTabView(String tabName) async {
    await trackEvent('tab_viewed', {'tab_name': tabName});
  }

  /// Gold wurde gekauft
  Future<void> trackGoldPurchase(double gramm, String currency, double price) async {
    await trackEvent('gold_purchased', {
      'gramm': gramm,
      'currency': currency,
      'price': price,
      'total_value': gramm * price,
    });
  }

  /// Chart-Zeitraum gewählt
  Future<void> trackChartRangeSelected(String range, String currency) async {
    await trackEvent('chart_range_selected', {
      'range': range,
      'currency': currency,
    });
  }

  /// Currency ausgewählt
  Future<void> trackCurrencySelected(String fromCurrency, String toCurrency, double amount) async {
    await trackEvent('currency_selected', {
      'from': fromCurrency,
      'to': toCurrency,
      'amount': amount,
    });
  }

  /// Warenkorb-Item hinzugefügt
  Future<void> trackCartItemAdded(double gramm, String currency) async {
    await trackEvent('cart_item_added', {
      'gramm': gramm,
      'currency': currency,
    });
  }

  /// Warenkorb-Item entfernt
  Future<void> trackCartItemRemoved(int index) async {
    await trackEvent('cart_item_removed', {'index': index});
  }

  /// Connection Test durchgeführt
  Future<void> trackConnectionTest(String endpoint, bool success) async {
    await trackEvent('connection_test', {
      'endpoint': endpoint,
      'success': success,
    });
  }
}
