import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config.dart';

// Währungsnamen
const Map<String, String> currencyNames = {
  'EUR': 'Euro',
  'USD': 'US-Dollar',
  'GBP': 'Britisches Pfund',
  'CHF': 'Schweizer Franken',
  'JPY': 'Japanischer Yen',
  'CNY': 'Chinesischer Yuan',
  'TRY': 'Türkische Lira',
  'RUB': 'Russischer Rubel',
  'INR': 'Indische Rupie',
  'BRL': 'Brasilianischer Real',
  'ZAR': 'Südafrikanischer Rand',
  'AUD': 'Australischer Dollar',
  'CAD': 'Kanadischer Dollar',
  'NZD': 'Neuseeland-Dollar',
  'SGD': 'Singapur-Dollar',
  'HKD': 'Hongkong-Dollar',
  'KRW': 'Südkoreanischer Won',
  'MXN': 'Mexikanischer Peso',
  'SEK': 'Schwedische Krone',
  'NOK': 'Norwegische Krone',
  'DKK': 'Dänische Krone',
  'PLN': 'Polnischer Złoty',
  'CZK': 'Tschechische Krone',
  'HUF': 'Ungarischer Forint',
  'RON': 'Rumänischer Leu',
  'BGN': 'Bulgarischer Lew',
  'HRK': 'Kroatische Kuna',
  'ISK': 'Isländische Krone',
  'THB': 'Thailändischer Baht',
  'MYR': 'Malaysischer Ringgit',
  'IDR': 'Indonesische Rupiah',
  'PHP': 'Philippinischer Peso',
  'ILS': 'Israelischer Schekel',
  'AED': 'VAE-Dirham',
  'SAR': 'Saudi-Riyal',
  'EGP': 'Ägyptisches Pfund',
  'ARS': 'Argentinischer Peso',
  'CLP': 'Chilenischer Peso',
  'COP': 'Kolumbianischer Peso',
  'PEN': 'Peruanischer Sol',
};

// Währungsflaggen (Unicode Regional Indicator Symbols)
const Map<String, String> currencyFlags = {
  'EUR': '🇪🇺',
  'USD': '🇺🇸',
  'GBP': '🇬🇧',
  'CHF': '🇨🇭',
  'JPY': '🇯🇵',
  'CNY': '🇨🇳',
  'TRY': '🇹🇷',
  'RUB': '🇷🇺',
  'INR': '🇮🇳',
  'BRL': '🇧🇷',
  'ZAR': '🇿🇦',
  'AUD': '🇦🇺',
  'CAD': '🇨🇦',
  'NZD': '🇳🇿',
  'SGD': '🇸🇬',
  'HKD': '🇭🇰',
  'KRW': '🇰🇷',
  'MXN': '🇲🇽',
  'SEK': '🇸🇪',
  'NOK': '🇳🇴',
  'DKK': '🇩🇰',
  'PLN': '🇵🇱',
  'CZK': '🇨🇿',
  'HUF': '🇭🇺',
  'RON': '🇷🇴',
  'BGN': '🇧🇬',
  'HRK': '🇭🇷',
  'ISK': '🇮🇸',
  'THB': '🇹🇭',
  'MYR': '🇲🇾',
  'IDR': '🇮🇩',
  'PHP': '🇵🇭',
  'ILS': '🇮🇱',
  'AED': '🇦🇪',
  'SAR': '🇸🇦',
  'EGP': '🇪🇬',
  'ARS': '🇦🇷',
  'CLP': '🇨🇱',
  'COP': '🇨🇴',
  'PEN': '🇵🇪',
};

class CurrencyTab extends StatefulWidget {
  const CurrencyTab({super.key});

  @override
  State<CurrencyTab> createState() => _CurrencyTabState();
}

class _CurrencyTabState extends State<CurrencyTab> {
  Map<String, double> rates = {};
  Map<String, double> previousRates = {};
  String base = 'EUR';
  bool loading = true;
  Timer? updateTimer;
  
  // Neue Variablen für Cache-Metadaten
  String? lastUpdateDate;
  bool? isCached;
  int? cacheAge;
  bool isOffline = false; // Neue Variable: Offline-Status

  // Favoriten (dynamisch, persistent)
  Set<String> favorites = {'EUR', 'TRY', 'USD', 'GBP', 'CHF'};
  final TextEditingController amountController = TextEditingController(
    text: '1',
  );

  @override
  void initState() {
    super.initState();
    loadFavorites();
    loadRates();
    updateTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => fetchRates(),
    );
  }

  @override
  void dispose() {
    updateTimer?.cancel();
    super.dispose();
  }

  Future<void> loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList('currency_favorites');
    if (stored != null && stored.isNotEmpty) {
      setState(() {
        favorites = Set.from(stored);
      });
    }
  }

  Future<void> saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('currency_favorites', favorites.toList());
  }

  void toggleFavorite(String currency) {
    final wasInFavorites = favorites.contains(currency);
    
    setState(() {
      if (wasInFavorites) {
        favorites.remove(currency);
      } else {
        favorites.add(currency);
      }
    });
    saveFavorites();
    
    // Feedback SnackBar
    final currencyName = currencyNames[currency] ?? currency;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          wasInFavorites 
            ? '$currencyName aus Favoriten entfernt' 
            : '$currencyName zu Favoriten hinzugefügt'
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> loadRates() async {
    final prefs = await SharedPreferences.getInstance();
    final storedRates = prefs.getString('rates');
    if (storedRates != null) {
      final decoded = jsonDecode(storedRates) as Map<String, dynamic>;
      setState(() {
        rates = decoded.map((k, v) => MapEntry(k, (v as num).toDouble()));
        // EUR manuell hinzufügen, falls nicht vorhanden
        if (!rates.containsKey('EUR')) rates['EUR'] = 1.0;

        loading = false;
        if (!rates.containsKey(base) && rates.isNotEmpty)
          base = rates.keys.first;
      });
    }
    fetchRates();
  }

  Future<void> fetchRates() async {
    // Reset offline status beim Start des Fetch
    if (isOffline) {
      setState(() {
        isOffline = false; // Offline-Banner sofort ausblenden
      });
    }
    
    try {
      final response = await http
          .get(Uri.parse(Config.ratesEndpoint))
          .timeout(Config.requestTimeout);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final rawRates = Map<String, dynamic>.from(data['rates']);
        setState(() {
          previousRates = Map.from(rates);
          rates = rawRates.map((k, v) => MapEntry(k, (v as num).toDouble()));

          // EUR immer hinzufügen
          rates['EUR'] = 1.0;

          // Metadaten speichern
          lastUpdateDate = data['date'] as String?;
          isCached = data['cached'] as bool?;
          cacheAge = data['cacheAge'] as int?;

          base = rates.containsKey(base)
              ? base
              : (rates.keys.isNotEmpty ? rates.keys.first : 'EUR');
          
          isOffline = false; // Online-Modus bestätigen
          loading = false;
        });

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('rates', jsonEncode(rates));
      }
    } catch (e) {
      debugPrint('Currency Fetch Fehler: $e');
      setState(() {
        loading = false;
        // Wenn Daten vorhanden sind (aus Cache), setze Offline-Modus
        if (rates.isNotEmpty) {
          isOffline = true;
        }
      });
      
      // Zeige user-freundliche Fehlermeldung nur wenn keine gecachten Daten vorhanden
      if (mounted && rates.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Keine Internetverbindung. Bitte prüfe deine Verbindung.'),
            duration: Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Widget rateRow(String currency) {
    final rate = currency == base ? 1.0 : (rates[currency] ?? 0.0);
    final prev = currency == base ? 1.0 : (previousRates[currency] ?? rate);
    final trend = rate > prev
        ? '↑'
        : rate < prev
        ? '↓'
        : '';
    final trendColor = trend == '↑'
        ? Colors.green
        : trend == '↓'
        ? Colors.red
        : Colors.grey;

    final inputAmount = double.tryParse(amountController.text) ?? 1.0;
    final converted = currency == base
        ? inputAmount
        : inputAmount * (rate / (rates[base] ?? 1.0));

    final isFavorite = favorites.contains(currency);
    final flag = currencyFlags[currency] ?? '🏳️';
    final fullName = currencyNames[currency] ?? currency;

    return ListTile(
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            flag,
            style: const TextStyle(fontSize: 32),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(
              isFavorite ? Icons.star : Icons.star_border,
              color: isFavorite ? Colors.amber : Colors.grey,
              size: 24,
            ),
            onPressed: () => toggleFavorite(currency),
            tooltip: isFavorite ? 'Aus Favoriten entfernen' : 'Zu Favoriten hinzufügen',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
      title: Text(
        '$currency - $fullName',
        style: TextStyle(
          fontWeight: isFavorite ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: Text('$base → $currency'),
      isThreeLine: false,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                converted.toStringAsFixed(2),
                style: TextStyle(
                  fontWeight: isFavorite ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              Text(trend, style: TextStyle(color: trendColor)),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 18),
            onPressed: () {
              Clipboard.setData(
                ClipboardData(text: converted.toStringAsFixed(2)),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$currency Betrag kopiert')),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (rates.isEmpty)
      return const Center(child: Text("Keine Währungen verfügbar"));

    // Favoriten: Basis zuerst, dann restliche Favoriten, dann andere
    final List<String> displayFavorites = [];

    // Basis immer zuerst
    displayFavorites.add(base);

    // Restliche Favoriten (nur wenn vorhanden in rates)
    for (var f in favorites) {
      if (f != base && rates.containsKey(f)) displayFavorites.add(f);
    }

    // Restliche Währungen alphabetisch
    final otherRates =
        rates.keys.where((c) => !displayFavorites.contains(c)).toList()..sort();

    // Alle Items für Dropdown
    final allItems = [...displayFavorites, ...otherRates];

    // Sicherstellen, dass Dropdown value in Items enthalten ist
    final dropdownValue = allItems.contains(base) ? base : allItems.first;

    return RefreshIndicator(
      onRefresh: fetchRates,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Offline-Warning Banner
          if (isOffline)
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade300, width: 2),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.cloud_off,
                    color: Colors.orange.shade900,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Offline-Modus',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.orange.shade900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Keine Verbindung zum Server. Es werden gespeicherte Daten angezeigt, die möglicherweise veraltet sind.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.orange.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          // Daten-Status Info (neu!)
          if (lastUpdateDate != null || isCached != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isCached == true ? Icons.cached : Icons.cloud_done,
                        size: 16,
                        color: Colors.blue.shade700,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isCached == true
                              ? 'Daten aus Cache (aktualisiert in ${(300 - (cacheAge ?? 0))}s)'
                              : 'Frische Daten vom Server',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      // Refresh Button
                      IconButton(
                        icon: Icon(Icons.refresh, size: 20, color: Colors.blue.shade700),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () async {
                          setState(() => loading = true);
                          await fetchRates();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(lastUpdateDate != null 
                                    ? 'Aktualisiert: Daten vom $lastUpdateDate'
                                    : 'Aktualisiert'),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                  if (lastUpdateDate != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 12, color: Colors.blue.shade600),
                        const SizedBox(width: 6),
                        Text(
                          'EZB-Referenzkurse vom: $lastUpdateDate',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.blue.shade800,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '💡 EZB publiziert neue Kurse werktags ~15:00-16:00 CET',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade700,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '↓ Ziehen zum Aktualisieren oder Refresh-Button nutzen',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          
          // Dropdown Basiswährung
          Row(
            children: [
              const Text('Basiswährung: '),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: dropdownValue,
                items: allItems
                    .map((c) => DropdownMenuItem(
                          value: c,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                currencyFlags[c] ?? '🏳️',
                                style: const TextStyle(fontSize: 20),
                              ),
                              const SizedBox(width: 8),
                              Text(c),
                            ],
                          ),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => base = value);
                },
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Betrag-Eingabe
          TextField(
            controller: amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Betrag in $base',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),

          // Favoriten anzeigen
          ...displayFavorites.map((c) => rateRow(c)),
          if (displayFavorites.isNotEmpty) const Divider(height: 24),

          // Restliche Währungen
          ...otherRates.map((c) => rateRow(c)),
        ],
      ),
    );
  }
}
