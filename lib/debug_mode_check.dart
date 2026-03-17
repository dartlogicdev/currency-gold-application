import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'config.dart';
import 'analytics_service.dart';

class DebugModeCheck extends StatefulWidget {
  const DebugModeCheck({super.key});

  @override
  State<DebugModeCheck> createState() => _DebugModeCheckState();
}

class _DebugModeCheckState extends State<DebugModeCheck> {
  String _testResult = '';
  bool _testing = false;

  Future<void> _testConnection() async {
    setState(() {
      _testing = true;
      _testResult = 'Testing...';
    });

    try {
      // Test 1: Health Endpoint
      final healthResponse = await http
          .get(Uri.parse(Config.healthEndpoint))
          .timeout(const Duration(seconds: 15));

      AnalyticsService().trackConnectionTest('health', healthResponse.statusCode == 200);

      setState(() {
        _testResult = '✅ Health: ${healthResponse.statusCode}\n';
      });

      // Test 2: Gold Endpoint
      final goldResponse = await http
          .get(Uri.parse(Config.goldEndpoint))
          .timeout(const Duration(seconds: 15));

      final goldData = json.decode(goldResponse.body);
      
      AnalyticsService().trackConnectionTest('gold', goldResponse.statusCode == 200);
      
      setState(() {
        _testResult += '✅ Gold: ${goldResponse.statusCode}\n';
        _testResult += 'Coins: ${goldData['coins']?.keys.length ?? 0} types\n';
        _testResult += 'Cached: ${goldData['cached'] ?? false}\n';
      });

      // Test 3: Rates Endpoint
      final ratesResponse = await http
          .get(Uri.parse(Config.ratesEndpoint))
          .timeout(const Duration(seconds: 15));

      final ratesData = json.decode(ratesResponse.body);

      AnalyticsService().trackConnectionTest('rates', ratesResponse.statusCode == 200);

      setState(() {
        _testResult += '✅ Rates: ${ratesResponse.statusCode}\n';
        _testResult += 'Currencies: ${ratesData['rates']?.keys.length ?? 0}\n';
        _testResult += '\n🎉 Alle Tests erfolgreich!';
      });
    } catch (e) {
      AnalyticsService().trackConnectionTest('all', false);
      setState(() {
        _testResult = '❌ Fehler:\n$e';
      });
    } finally {
      setState(() {
        _testing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Environment Check'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Modus: ${Config.isDevelopment ? 'DEVELOPMENT' : 'PRODUCTION'}',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            const Text(
              'Server URL:',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 10),
            SelectableText(
              Config.apiBaseUrl,
              style: const TextStyle(fontSize: 14, color: Colors.blue),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _testing ? null : _testConnection,
              child: _testing
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Test Server Connection'),
            ),
            const SizedBox(height: 20),
            if (_testResult.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  _testResult,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 14,
                  ),
                ),
              ),
            
            const SizedBox(height: 40),
            
            // Analytics Section
            const Divider(thickness: 2),
            const SizedBox(height: 20),
            
            const Text(
              '📊 Analytics',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            FutureBuilder<Map<String, dynamic>>(
              future: AnalyticsService().getStatistics(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const CircularProgressIndicator();
                }
                
                final stats = snapshot.data!;
                final eventCounts = stats['event_counts'] as Map<String, int>? ?? {};
                
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Summary Cards
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            '📱 Sessions',
                            '${stats['total_sessions'] ?? 0}',
                            Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            '🎯 Events',
                            '${stats['total_events'] ?? 0}',
                            Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            '📅 Last 7 Days',
                            '${stats['last_7_days_events'] ?? 0}',
                            Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Event Breakdown
                    const Text(
                      'Top Events:',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    
                    if (eventCounts.isEmpty)
                      const Text('Keine Events aufgezeichnet'),
                    
                    ...eventCounts.entries.take(10).map((entry) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                _formatEventName(entry.key),
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${entry.value}x',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    
                    const SizedBox(height: 24),
                    
                    // Clear Analytics Button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Analytics löschen?'),
                              content: const Text(
                                'Alle aufgezeichneten Analytics-Daten werden unwiderruflich gelöscht.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('Abbrechen'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Löschen'),
                                ),
                              ],
                            ),
                          );
                          
                          if (confirm == true) {
                            await AnalyticsService().clearAllData();
                            setState(() {}); // Refresh
                          }
                        },
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Analytics Daten löschen'),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
  
  String _formatEventName(String eventName) {
    final Map<String, String> eventLabels = {
      'app_opened': '🚀 App geöffnet',
      'tab_viewed': '👁️ Tab angesehen',
      'cart_item_added': '➕ Warenkorb hinzugefügt',
      'cart_item_removed': '➖ Warenkorb entfernt',
      'chart_range_selected': '📊 Chart-Zeitraum',
      'currency_selected': '💱 Währung gewählt',
      'connection_test': '🔌 Connection Test',
    };
    
    return eventLabels[eventName] ?? eventName;
  }
}
