import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:currency_gold_application/chart_point.dart';
import 'package:intl/intl.dart';

class PriceChart extends StatelessWidget {
  final List<ChartPoint> data;
  final String currency;

  const PriceChart({super.key, required this.data, required this.currency});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Center(child: Text('Keine Daten'));
    }

    // Min/Max für Y-Achse berechnen
    final prices = data.map((e) => e.value).toList();
    final minY = prices.reduce((a, b) => a < b ? a : b);
    final maxY = prices.reduce((a, b) => a > b ? a : b);
    final padding = (maxY - minY) * 0.1; // 10% Padding

    return LineChart(
      LineChartData(
        minY: minY - padding,
        maxY: maxY + padding,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: (maxY - minY) / 5,
          verticalInterval: data.length > 10 ? data.length / 5.0 : 1,
          getDrawingHorizontalLine: (value) {
            return FlLine(color: Colors.grey.withValues(alpha: 0.2), strokeWidth: 1);
          },
          getDrawingVerticalLine: (value) {
            return FlLine(color: Colors.grey.withValues(alpha: 0.2), strokeWidth: 1);
          },
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
        ),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),

          // Y-Achse: Preis
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 60,
              getTitlesWidget: (value, meta) {
                return Text(
                  '${value.toStringAsFixed(0)} $currency',
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),

          // X-Achse: Datum
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: _calculateInterval(data.length),
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= data.length) return const Text('');

                final date = data[index].date;
                final format = _getDateFormat(data.length);

                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Transform.rotate(
                    angle: -0.5, // Leicht gedreht für bessere Lesbarkeit
                    child: Text(
                      DateFormat(format).format(date),
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: data
                .asMap()
                .entries
                .map((e) => FlSpot(e.key.toDouble(), e.value.value))
                .toList(),
            isCurved: true,
            curveSmoothness: 0.3,
            barWidth: 3,
            dotData: FlDotData(
              show: data.length <= 31, // Punkte nur bei wenig Daten zeigen
            ),
            color: Theme.of(context).colorScheme.primary,
            belowBarData: BarAreaData(
              show: true,
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final date = data[spot.x.toInt()].date;
                final price = spot.y;
                return LineTooltipItem(
                  '${DateFormat('dd.MM.yyyy').format(date)}\n${price.toStringAsFixed(2)} $currency',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  // Berechne Intervall für X-Achse Labels
  double _calculateInterval(int dataPoints) {
    if (dataPoints <= 7) return 1; // Jeden Tag zeigen
    if (dataPoints <= 31) return 5; // Jeden 5. Tag
    if (dataPoints <= 90) return 15; // Alle 2 Wochen
    if (dataPoints <= 365) return 60; // Alle 2 Monate
    return 180; // Alle 6 Monate
  }

  // Datum-Format je nach Zeitraum
  String _getDateFormat(int dataPoints) {
    if (dataPoints <= 31) return 'dd.MM'; // Tag.Monat
    if (dataPoints <= 365) return 'MMM yy'; // Monat Jahr
    return 'MM/yy'; // Monat/Jahr
  }
}
