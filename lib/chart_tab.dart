import 'dart:convert';
import 'dart:math' show Random;
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Für Asset-Loading
import 'package:currency_gold_application/chart_point.dart';
import 'package:currency_gold_application/price_chart.dart';
import 'package:currency_gold_application/config.dart';
import 'package:currency_gold_application/analytics_service.dart';

class ChartTab extends StatefulWidget {
  const ChartTab({super.key});

  @override
  State<ChartTab> createState() => _ChartTabState();
}

class _ChartTabState extends State<ChartTab> {
  String selectedRange = '7T';
  String selectedCurrency = 'USD';
  final currencies = ['USD', 'EUR', 'TRY'];

  // Erweiterte Zeiträume inkl. mehrjährige Ansichten
  final Map<String, int> ranges = {
    '7T': 7,
    '1M': 30,
    '3M': 90,
    '1J': 365,
    '3J': 1095,
    '5J': 1825,
    '10J': 3650,
  };

  List<ChartPoint> chartData = [];
  bool loading = true;
  String? errorMessage;
  int? availableDays;
  bool usingFallbackData = false; // Zeigt an, ob Fallback-Daten verwendet werden

  @override
  void initState() {
    super.initState();
    fetchHistory(ranges[selectedRange]!);
  }

  // Lade historische Daten aus Assets (Fallback)
  Future<List<ChartPoint>> loadFallbackData(int requestedDays) async {
    try {
      final jsonString = await rootBundle.loadString('assets/gold_history_fallback.json');
      final List data = jsonDecode(jsonString);
      
      // Berechne Startdatum basierend auf requestedDays
      final now = DateTime.now();
      final startDate = now.subtract(Duration(days: requestedDays));
      
      // Filtere nach tatsächlichem Zeitraum (nicht nach Anzahl!)
      final filtered = data.where((e) {
        final date = DateTime.parse(e['date']);
        return date.isAfter(startDate) || date.isAtSameMomentAs(startDate);
      }).toList();
      
      if (filtered.isEmpty) return [];
      
      // Konvertiere zu ChartPoints
      final monthlyPoints = filtered.map((e) {
        final priceKey = 'price$selectedCurrency';
        final price = e[priceKey] ?? e['priceUSD'];
        
        return ChartPoint(
          date: DateTime.parse(e['date']),
          value: (price as num).toDouble(),
        );
      }).toList();
      
      // Interpoliere tägliche Werte mit realistischer Volatilität
      final List<ChartPoint> interpolatedPoints = [];
      final random = Random(42); // Seeded für Konsistenz
      
      for (int i = 0; i < monthlyPoints.length - 1; i++) {
        final currentPoint = monthlyPoints[i];
        final nextPoint = monthlyPoints[i + 1];
        
        // Füge aktuellen Punkt hinzu
        interpolatedPoints.add(currentPoint);
        
        // Berechne Anzahl Tage zwischen den Punkten
        final daysBetween = nextPoint.date.difference(currentPoint.date).inDays;
        
        if (daysBetween <= 1) continue;
        
        // Basis-Trend (lineare Interpolation)
        final dailyTrend = (nextPoint.value - currentPoint.value) / daysBetween;
        
        // Realistische Volatilität: 0.8% täglich (historischer Gold-Durchschnitt)
        final avgPrice = (currentPoint.value + nextPoint.value) / 2;
        final dailyVolatility = avgPrice * 0.008;
        
        double currentValue = currentPoint.value;
        
        // Random Walk mit Volatilität
        for (int day = 1; day < daysBetween; day++) {
          final interpolatedDate = currentPoint.date.add(Duration(days: day));
          
          // Trend + zufällige Schwankung
          final randomChange = (random.nextDouble() - 0.5) * 2 * dailyVolatility;
          currentValue = currentValue + dailyTrend + randomChange;
          
          // Sanfte Korrektur zum Zielwert (damit wir ankommen)
          final expectedValue = currentPoint.value + dailyTrend * day;
          final correction = (expectedValue - currentValue) * 0.1;
          currentValue += correction;
          
          // Verhindere negative Preise
          currentValue = currentValue.abs();
          
          interpolatedPoints.add(ChartPoint(
            date: interpolatedDate,
            value: currentValue,
          ));
        }
      }
      
      // Füge letzten Punkt hinzu
      interpolatedPoints.add(monthlyPoints.last);
      
      return interpolatedPoints;
    } catch (e) {
      debugPrint('Fehler beim Laden der Fallback-Daten: $e');
      return [];
    }
  }

  Future<void> fetchHistory(int days) async {
    setState(() {
      loading = true;
      errorMessage = null;
      usingFallbackData = false;
    });

    try {
      final response = await http
          .get(Uri.parse(Config.goldHistoryEndpoint(days)))
          .timeout(Config.requestTimeout);

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);

        // Wenn Server zu wenig Daten hat UND mehr als 30 Tage angefordert, nutze Fallback
        if (data.length < days && days > 30) {
          debugPrint('Server hat nur ${data.length} Tage, lade Fallback-Daten für $days Tage');
          final fallbackData = await loadFallbackData(days);
          
          if (fallbackData.isNotEmpty) {
            setState(() {
              chartData = fallbackData;
              availableDays = fallbackData.length;
              usingFallbackData = true;
              loading = false;
            });
            return;
          }
        }

        setState(() {
          chartData = data.map((e) {
            // Preis je nach gewählter Währung
            final priceKey = 'price$selectedCurrency';
            final price = e[priceKey] ?? e['priceUSD'];

            return ChartPoint(
              date: DateTime.parse(e['date']),
              value: (price as num).toDouble(),
            );
          }).toList();

          // Speichere verfügbare Datenpunkte
          availableDays = data.length;
          loading = false;
          usingFallbackData = false;

          // Warnung wenn weniger Daten als angefordert
          if (data.length < days) {
            errorMessage =
                'Hinweis: Nur ${data.length} Tage verfügbar ($days angefordert)';
          }
        });
      } else {
        throw Exception('Server Fehler: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('History Fetch Fehler: $e');

      // Bei Fehler: Versuche Fallback-Daten zu laden
      final fallbackData = await loadFallbackData(days);

      if (fallbackData.isNotEmpty) {
        setState(() {
          chartData = fallbackData;
          availableDays = fallbackData.length;
          usingFallbackData = true;
          loading = false;
          errorMessage =
              'Server nicht erreichbar - Historische Daten werden angezeigt';
        });
      } else {
        setState(() {
          loading = false;
          errorMessage = 'Fehler beim Laden der Daten: ${e.toString()}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info-Box für Fallback-Daten
          if (usingFallbackData)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.history, color: Colors.blue.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Historische Daten (2016-2026) - Monatliche Referenzwerte',
                          style: TextStyle(
                            fontSize: 12, 
                            color: Colors.blue.shade900,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '📊 Tägliche Schwankungen mit realistischer Volatilität (~0.8%) simuliert',
                          style: TextStyle(
                            fontSize: 10, 
                            color: Colors.blue.shade700,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Info-Box bei eingeschraenkten Daten (nur wenn NICHT Fallback)
          if (!usingFallbackData && availableDays != null && availableDays! < ranges[selectedRange]!)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      color: Colors.orange.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Nur $availableDays Tage Daten verfügbar. Server sammelt täglich neue Daten.',
                      style: TextStyle(
                          fontSize: 12, color: Colors.orange.shade900),
                    ),
                  ),
                ],
              ),
            ),

          // Zeitraum-Auswahl
          const Text(
            'Zeitraum:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: ranges.keys.map((key) {
              return ChoiceChip(
                label: Text(key),
                selected: selectedRange == key,
                onSelected: (_) {
                  setState(() => selectedRange = key);
                  AnalyticsService().trackChartRangeSelected(key, selectedCurrency);
                  fetchHistory(ranges[key]!);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Währungs-Auswahl
          Row(
            children: [
              const Text(
                'Währung: ',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              DropdownButton<String>(
                value: selectedCurrency,
                items: currencies
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => selectedCurrency = value);
                    AnalyticsService().trackChartRangeSelected(selectedRange, value);
                    fetchHistory(ranges[selectedRange]!);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Chart oder Error
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : errorMessage != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 16),
                        Text(errorMessage!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => fetchHistory(ranges[selectedRange]!),
                          child: const Text('Erneut versuchen'),
                        ),
                      ],
                    ),
                  )
                : chartData.isEmpty
                ? const Center(child: Text('Keine Daten verfügbar'))
                : PriceChart(data: chartData, currency: selectedCurrency),
          ),
        ],
      ),
    );
  }
}
