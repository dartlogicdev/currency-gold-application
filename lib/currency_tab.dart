import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config.dart';
import 'haptic_service.dart';
import 'language_service.dart';

// Währungsnamen werden lokalisiert aus LanguageService.getCurrencyName() bezogen.

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
  final String langCode;
  const CurrencyTab({super.key, required this.langCode});

  @override
  State<CurrencyTab> createState() => _CurrencyTabState();
}

class _CurrencyTabState extends State<CurrencyTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

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
  final TextEditingController searchController = TextEditingController();
  String searchQuery = '';

  // Toast Overlay
  OverlayEntry? _currentToast;

  @override
  void initState() {
    super.initState();
    loadFavorites();
    loadRates();
    updateTimer = Timer.periodic(
      const Duration(hours: 2), // Auf 2h erhöht - Server cached dynamisch
      (_) => fetchRates(),
    );
    searchController.addListener(() {
      setState(() {
        searchQuery = searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _currentToast?.remove();
    updateTimer?.cancel();
    searchController.dispose();
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
    
    // Haptic Feedback
    HapticService().light();
    
    // Feedback Toast
    final currencyName = LanguageService().getCurrencyName(currency);
    _showToast(wasInFavorites
        ? '$currencyName ${LanguageService().t('currency_fav_removed')}'
        : '$currencyName ${LanguageService().t('currency_fav_added')}');
  }

  void _showToast(String message) {
    _currentToast?.remove();
    _currentToast = null;
    if (!mounted) return;
    final overlay = Overlay.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    _currentToast = OverlayEntry(
      builder: (ctx) => Positioned(
        top: MediaQuery.of(ctx).padding.top + 60,
        left: 24,
        right: 24,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: colorScheme.inverseSurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.onInverseSurface),
            ),
          ),
        ),
      ),
    );
    overlay.insert(_currentToast!);
    Future.delayed(const Duration(milliseconds: 1800), () {
      _currentToast?.remove();
      _currentToast = null;
    });
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
        if (!rates.containsKey(base) && rates.isNotEmpty) {
          base = rates.keys.first;
        }
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
          SnackBar(
            content: Text(LanguageService().t('gold_no_connection')),
            duration: const Duration(seconds: 5),
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
    final fullName = LanguageService().getCurrencyName(currency);

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
            tooltip: isFavorite ? LanguageService().t('currency_fav_remove') : LanguageService().t('currency_fav_add'),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
      title: Text(
        '$currency - $fullName',
        style: TextStyle(
          fontSize: 15,
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
                  fontSize: 17,
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
              _showToast('$currency ${LanguageService().t('currency_copied')}');
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    
    if (loading) return const Center(child: CircularProgressIndicator());
    if (rates.isEmpty) {
      return Center(child: Text(LanguageService().t('currency_no_rates')));
    }

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
    
    // Suchfilter: Code + lokalisierter Name + Länderkeywords
    bool _matchesCurrency(String currency) {
      final query = searchQuery.toLowerCase();
      if (currency.toLowerCase().contains(query)) return true;
      if (LanguageService().getCurrencyName(currency).toLowerCase().contains(query)) return true;
      final keywords = LanguageService.currencyCountryKeywords[currency] ?? [];
      return keywords.any((k) => k.contains(query));
    }

    final filteredFavorites = searchQuery.isEmpty
        ? displayFavorites
        : displayFavorites.where(_matchesCurrency).toList();
    
    final filteredOtherRates = searchQuery.isEmpty
        ? otherRates
        : otherRates.where(_matchesCurrency).toList();

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
                          LanguageService().t('gold_offline'),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.orange.shade900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          LanguageService().t('gold_offline_sub'),
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
          // Daten-Status Info
          if (lastUpdateDate != null || isCached != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(Icons.access_time, size: 11, color: Colors.grey.shade400),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'EZB ${lastUpdateDate ?? ""}${isCached == true ? " (Cache)" : ""}',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.refresh, size: 14, color: Colors.grey.shade400),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () async {
                      setState(() => loading = true);
                      await fetchRates();
                      if (mounted) {
                        _showToast(lastUpdateDate != null
                            ? '${LanguageService().t('currency_updated')}: $lastUpdateDate'
                            : LanguageService().t('currency_updated'));
                      }
                    },
                  ),
                ],
              ),
            ),
          
          // Suchfeld
          TextField(
            controller: searchController,
            decoration: InputDecoration(
              labelText: LanguageService().t('currency_search'),
              prefixIcon: const Icon(Icons.search),
              suffixIcon: searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        searchController.clear();
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Dropdown Basiswährung
          Row(
            children: [
              Text('${LanguageService().t('currency_base')}: '),
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
              labelText: '${LanguageService().t('currency_amount')} $base',
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),

          // Favoriten anzeigen
          ...filteredFavorites.map((c) => rateRow(c)),
          if (filteredFavorites.isNotEmpty && filteredOtherRates.isNotEmpty) const Divider(height: 24),

          // Restliche Währungen
          ...filteredOtherRates.map((c) => rateRow(c)),
        ],
      ),
    );
  }
}
