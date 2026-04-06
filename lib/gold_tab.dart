import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'config.dart';
import 'analytics_service.dart';
import 'haptic_service.dart';
import 'language_service.dart';

class GoldItem {
  String coinName;
  double quantity;

  GoldItem({required this.coinName, required this.quantity});

  Map<String, dynamic> toJson() => {'coinName': coinName, 'quantity': quantity};

  factory GoldItem.fromJson(Map<String, dynamic> json) =>
      GoldItem(coinName: json['coinName'], quantity: (json['quantity'] as num).toDouble());
}

class GoldTab extends StatefulWidget {
  final String langCode;
  final bool zakatEnabled;
  final double dealerMarkup;
  final bool dealerMarkupEnabled;
  const GoldTab({super.key, required this.langCode, required this.zakatEnabled, required this.dealerMarkup, required this.dealerMarkupEnabled});

  @override
  State<GoldTab> createState() => _GoldTabState();
}

class _GoldTabState extends State<GoldTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Map<String, dynamic> coins = {};
  String selectedCoin = '';
  String selectedCurrency = 'USD';
  final currencies = ['USD', 'EUR', 'TRY', 'GBP', 'CHF', 'JPY', 'AUD', 'CAD', 'INR', 'SAR', 'AED'];
  bool loading = true;

  // Cache-Metadaten
  bool? isCached;
  int? cacheAge;
  String? lastFetchTime;
  bool isOffline = false; // Neue Variable: Offline-Status

  final TextEditingController quantityController = TextEditingController(
    text: '1',
  );

  // Bilezik-spezifisch
  int bilezikKarat = 22;
  final TextEditingController bilezikWeightController = TextEditingController(text: '1');

  List<GoldItem> cart = [];

  // Undo Snapshot (kompletter Zustand)
  List<GoldItem> undoSnapshot = [];

  // Toast Overlay
  OverlayEntry? _currentToast;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _currentToast?.remove();
    bilezikWeightController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    await loadCart();
    await loadGoldFromCache();
    fetchGold();
  }

  /* ------------------ API & Cache ------------------ */

  Future<void> loadGoldFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedData = prefs.getString('gold_data');
    final cachedTime = prefs.getString('gold_cache_time');
    
    if (cachedData != null) {
      try {
        final data = jsonDecode(cachedData);
        setState(() {
          coins = Map<String, dynamic>.from(data['coins']);
          if (coins.isNotEmpty) {
            selectedCoin = coins.keys.first;
          }
          lastFetchTime = cachedTime;
          loading = false;
        });
        debugPrint('[GoldTab] Gecachte Daten geladen');
      } catch (e) {
        debugPrint('[GoldTab] Fehler beim Laden gecachter Daten: $e');
      }
    }
  }

  Future<void> saveGoldToCache(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('gold_data', jsonEncode(data));
    await prefs.setString('gold_cache_time', DateTime.now().toString().substring(0, 19));
    debugPrint('[GoldTab] Daten im Cache gespeichert');
  }

  Future<void> fetchGold() async {
    // Reset offline status beim Start des Fetch
    setState(() {
      loading = true;
      if (isOffline) isOffline = false; // Offline-Banner sofort ausblenden
    });
    
    try {
      final res = await http
          .get(Uri.parse(Config.goldEndpoint))
          .timeout(Config.requestTimeout);
      final data = jsonDecode(res.body);
      
      // Cache aktualisieren
      await saveGoldToCache(data);
      
      setState(() {
        coins = Map<String, dynamic>.from(data['coins']);
        selectedCoin = coins.keys.first;
        
        // Cache-Metadaten extrahieren
        isCached = data['cached'] as bool?;
        cacheAge = data['cacheAge'] as int?;
        lastFetchTime = DateTime.now().toString().substring(0, 19);
        
        isOffline = false; // Online-Modus bestätigen
        loading = false;
      });
    } catch (e) {
      debugPrint('Gold Fetch Fehler: $e');
      setState(() {
        loading = false;
        // Wenn Daten vorhanden sind (aus Cache), setze Offline-Modus
        if (coins.isNotEmpty) {
          isOffline = true;
        }
      });

      // Zeige user-freundliche Fehlermeldung nur wenn keine gecachten Daten vorhanden
      if (mounted && coins.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(LanguageService().t('gold_no_connection')),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: LanguageService().t('gold_retry'),
              onPressed: () {
                fetchGold();
              },
            ),
          ),
        );
      }
    }
  }

  /* ------------------ Persistenz ------------------ */

  Future<void> saveCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Speichere komplette Cart-Liste als einzelnen JSON-String
      final cartJson = jsonEncode(cart.map((e) => e.toJson()).toList());
      final success = await prefs.setString('gold_cart', cartJson);
      debugPrint('[GoldTab] Warenkorb gespeichert: ${cart.length} Items, success: $success');
      debugPrint('[GoldTab] Gespeicherte Daten: $cartJson');
      
      // Verifikation: Sofort wieder lesen
      final verification = prefs.getString('gold_cart');
      debugPrint('[GoldTab] Verifikation gelesen: ${verification?.length ?? 0} Zeichen');
    } catch (e) {
      debugPrint('[GoldTab] Fehler beim Speichern des Warenkorbs: $e');
    }
  }

  Future<void> loadCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartJson = prefs.getString('gold_cart');
      
      debugPrint('[GoldTab] Lade Warenkorb... Daten vorhanden: ${cartJson != null}');
      debugPrint('[GoldTab] Raw JSON: $cartJson');
      
      if (cartJson != null && cartJson.isNotEmpty) {
        try {
          final List<dynamic> decoded = jsonDecode(cartJson);
          final loadedCart = decoded.map((e) => GoldItem.fromJson(e as Map<String, dynamic>)).toList();
          
          // Wichtig: Direkt den cart setzen, nicht in setState
          cart = loadedCart;
          
          debugPrint('[GoldTab] Warenkorb erfolgreich geladen: ${loadedCart.length} Items');
          for (var item in loadedCart) {
            debugPrint('[GoldTab]   - ${item.coinName}: ${item.quantity}x');
          }
        } catch (e) {
          debugPrint('[GoldTab] Fehler beim Laden des Warenkorbs: $e');
          debugPrint('[GoldTab] Fehlerhafte Daten: $cartJson');
          // Bei Fehler: Warenkorb zurücksetzen
          await prefs.remove('gold_cart');
        }
      } else {
        debugPrint('[GoldTab] Kein gespeicherter Warenkorb gefunden');
      }
    } catch (e) {
      debugPrint('[GoldTab] Fehler beim Zugriff auf SharedPreferences: $e');
    }
  }

  /* ------------------ Logik ------------------ */

  bool get _isBilezikSelected =>
      selectedCoin == 'Altın Bilezik' || selectedCoin == '22 Ayar Bilezik';

  bool _isBilezikCoin(String coin) =>
      coin == 'Altın Bilezik' || coin == '22 Ayar Bilezik';

  // Berechnet spotPerPiece und grams für normale Münzen und Bilezik-Einträge
  Map<String, double> _resolveCartItem(GoldItem item) {
    if (item.coinName.startsWith('Bilezik|')) {
      final parts = item.coinName.split('|');
      final karat = int.tryParse(parts.length > 1 ? parts[1] : '22') ?? 22;
      final weight = double.tryParse(parts.length > 2 ? parts[2] : '1') ?? 1.0;
      final data = (coins['Gold (1g)']?[selectedCurrency] ?? {}) as Map;
      final goldSpot = ((data['spot'] ?? 0.0) as num).toDouble();
      return {'spotPerPiece': goldSpot * (karat / 24) * weight, 'grams': weight};
    }
    final coinData = coins[item.coinName];
    final w = ((coinData?['weight'] ?? 1.0) as num).toDouble();
    final data = (coinData?[selectedCurrency] ?? {}) as Map;
    final spot = ((data['spot'] ?? 0.0) as num).toDouble();
    return {'spotPerPiece': spot, 'grams': w};
  }

  String _displayCoinName(GoldItem item) {
    if (item.coinName.startsWith('Bilezik|')) {
      final parts = item.coinName.split('|');
      final karat = parts.length > 1 ? parts[1] : '22';
      final weight = parts.length > 2 ? parts[2] : '1';
      return 'Bilezik (${karat}K, ${weight}g)';
    }
    return LanguageService().translateCoin(item.coinName);
  }

  void addToCart() {
    final qty = double.tryParse(quantityController.text) ?? 1.0;

    if (_isBilezikSelected) {
      final w = double.tryParse(bilezikWeightController.text) ?? 1.0;
      final encodedName = 'Bilezik|$bilezikKarat|$w';
      setState(() {
        final existing = cart.where((e) => e.coinName == encodedName).toList();
        if (existing.isNotEmpty) {
          existing.first.quantity += qty;
        } else {
          cart.add(GoldItem(coinName: encodedName, quantity: qty));
        }
      });
      AnalyticsService().trackCartItemAdded(qty * w, selectedCurrency);
      saveCart();
      quantityController.text = '1';
      HapticService().medium();
      _showToast('Bilezik (${bilezikKarat}K, ${w}g) ${LanguageService().t('gold_added_to_cart')}');
      return;
    }

    setState(() {
      final existing = cart.where((e) => e.coinName == selectedCoin).toList();
      if (existing.isNotEmpty) {
        existing.first.quantity += qty;
      } else {
        cart.add(GoldItem(coinName: selectedCoin, quantity: qty));
      }
    });

    // Tracke Warenkorb-Hinzufügung
    final coinData = coins[selectedCoin];
    final weight = ((coinData?['weight'] ?? 1.0) as num).toDouble();
    final grams = qty * weight;
    AnalyticsService().trackCartItemAdded(grams, selectedCurrency);

    saveCart();
    quantityController.text = '1';
    
    // Haptic Feedback
    HapticService().medium();
    
    // Feedback Toast
    _showToast('${LanguageService().translateCoin(selectedCoin)} ${LanguageService().t('gold_added_to_cart')}');
  }

  void removeItem(int index) {
    ScaffoldMessenger.of(context).removeCurrentSnackBar();

    setState(() {
      undoSnapshot = List.from(
        cart.map((e) => GoldItem(coinName: e.coinName, quantity: e.quantity)),
      );
      cart.removeAt(index);
    });

    // Haptic Feedback
    HapticService().light();

    // Tracke Entfernung
    AnalyticsService().trackCartItemRemoved(index);

    saveCart();
    showUndoSnackBar(LanguageService().t('gold_removed'));
  }

  void clearCart() {
    if (cart.isEmpty) return;

    // Bestätigungsdialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(LanguageService().t('gold_clear_title')),
        content: Text('${LanguageService().t('gold_clear_confirm')} ${cart.length} ${LanguageService().t('gold_clear_confirm2')}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(LanguageService().t('gold_cancel')),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              
              // Haptic Feedback - wichtige Aktion
              HapticService().heavy();
              
              ScaffoldMessenger.of(context).removeCurrentSnackBar();

              setState(() {
                undoSnapshot = List.from(
                  cart.map((e) => GoldItem(coinName: e.coinName, quantity: e.quantity)),
                );
                cart.clear();
              });

              saveCart();
              showUndoSnackBar(LanguageService().t('gold_all_removed'));
            },
              child: Text(LanguageService().t('gold_clear'), style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void shareCart() {
    if (cart.isEmpty) return;

    // Warenkorb als Text formatieren
    final buffer = StringBuffer();
    buffer.writeln("🛒 ${LanguageService().t('gold_cart_title')}\n");

    double totalSpot = 0;
    double totalDealer = 0;

    for (var item in cart) {
      final resolved = _resolveCartItem(item);
      final spotTotal = resolved['spotPerPiece']! * item.quantity;
      final dealerTotal = spotTotal * 1.04;

      totalSpot += spotTotal;
      totalDealer += dealerTotal;

      final quantityStr = item.quantity % 1 == 0 
          ? item.quantity.toInt().toString() 
          : item.quantity.toStringAsFixed(2);

      buffer.writeln('• ${_displayCoinName(item)}: ${quantityStr}x');
      buffer.writeln("  ${LanguageService().t('gold_spot')}: ${LanguageService().formatAmount(spotTotal)} $selectedCurrency");
      buffer.writeln("  ${LanguageService().t('gold_dealer')}: ${LanguageService().formatAmount(dealerTotal)} $selectedCurrency\n");
    }

    buffer.writeln('━━━━━━━━━━━━━━━━');
    buffer.writeln("${LanguageService().t('gold_total_spot')}: ${LanguageService().formatAmount(totalSpot)} $selectedCurrency");
    buffer.writeln("${LanguageService().t('gold_total_dealer')}: ${LanguageService().formatAmount(totalDealer)} $selectedCurrency");
    buffer.writeln("\n📱 ${LanguageService().t('gold_created_with')}");

    // Haptic Feedback
    HapticService().selection();

    // Share
    Share.share(buffer.toString(), subject: LanguageService().t('gold_cart_title'));

    // Feedback Toast
    _showToast(LanguageService().t('gold_cart_shared'));
  }

  void showZakatDialog() {
    if (cart.isEmpty) return;
    final l = LanguageService();

    double totalZakat = 0;
    final List<Map<String, dynamic>> zakatItems = [];

    for (final item in cart) {
      final resolved = _resolveCartItem(item);
      final spotTotal = resolved['spotPerPiece']! * item.quantity;
      final dealerTotal = spotTotal * (widget.dealerMarkupEnabled ? (1 + widget.dealerMarkup / 100) : 1.0);
      final zakat = dealerTotal / 40;
      totalZakat += zakat;
      zakatItems.add({'item': item, 'dealerTotal': dealerTotal, 'zakat': zakat});
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Text(
                  l.t('zakat_title'),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text(
                  l.t('zakat_subtitle'),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ),
              const Divider(height: 24),
              ...zakatItems.map((e) {
                final item = e['item'] as GoldItem;
                final zakat = e['zakat'] as double;
                final dealer = e['dealerTotal'] as double;
                final qty = item.quantity % 1 == 0
                    ? item.quantity.toInt().toString()
                    : item.quantity.toStringAsFixed(2);
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text('${qty}× ${_displayCoinName(item)}'),
                  subtitle: Text(
                    '${l.t('zakat_basis')}: ${l.formatAmount(dealer)} $selectedCurrency',
                    style: const TextStyle(fontSize: 11),
                  ),
                  trailing: Text(
                    '${l.formatAmount(zakat)} $selectedCurrency',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                );
              }),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l.t('zakat_total'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${l.formatAmount(totalZakat)} $selectedCurrency',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(l.t('zakat_close')),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void undo() {
    if (undoSnapshot.isEmpty) return;

    setState(() {
      cart = undoSnapshot
          .map((e) => GoldItem(coinName: e.coinName, quantity: e.quantity))
          .toList();
      undoSnapshot = [];
    });

    saveCart();
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

  void showUndoSnackBar(String text) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(label: LanguageService().t('gold_undo'), onPressed: undo),
      ),
    );
  }

  /* ------------------ UI ------------------ */

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    final l = LanguageService();
    if (loading) return const Center(child: CircularProgressIndicator());

    double totalSpot = 0;
    double totalDealer = 0;

    for (var item in cart) {
      final resolved = _resolveCartItem(item);
      final spotTotal = resolved['spotPerPiece']! * item.quantity;
      totalSpot += spotTotal;
      totalDealer += spotTotal * (widget.dealerMarkupEnabled ? (1 + widget.dealerMarkup / 100) : 1.0);
    }

    return RefreshIndicator(
      onRefresh: fetchGold,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
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
                              l.t('gold_offline'),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.orange.shade900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              l.t('gold_offline_sub'),
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
          // --- Münz-Dropdown: zweizeilig mit Preis ---
          DropdownButtonFormField<String>(
            value: selectedCoin.isEmpty ? null : selectedCoin,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: l.t('gold_coin'),
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.monetization_on_outlined, color: Colors.amber),
            ),
            selectedItemBuilder: (context) => coins.keys.map((coin) {
              final w = ((coins[coin]['weight']) as num).toDouble();
              final k = coins[coin]['karat'];
              final isBilezik = _isBilezikCoin(coin);
              return Text(
                isBilezik
                    ? '${l.translateCoin(coin)}  •  ${w.toStringAsFixed(2)}g  ✎ Karat'
                    : '${l.translateCoin(coin)}  •  ${w.toStringAsFixed(2)}g ${k}K',
                style: const TextStyle(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              );
            }).toList(),
            items: coins.keys.map((coin) {
              final w = ((coins[coin]['weight']) as num).toDouble();
              final k = coins[coin]['karat'];
              final data = coins[coin][selectedCurrency] ?? {};
              final spot = ((data['spot'] ?? 0.0) as num).toDouble();
              final isBilezik = _isBilezikCoin(coin);
              final karatColor = k >= 24
                  ? Colors.amber.shade700
                  : k >= 22
                      ? Colors.amber.shade600
                      : k >= 18
                          ? Colors.orange.shade400
                          : Colors.grey.shade500;
              final badgeColor = isBilezik ? Colors.teal.shade400 : karatColor;
              return DropdownMenuItem(
                value: coin,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
                        ),
                        child: Center(
                          child: isBilezik
                              ? Icon(Icons.edit, size: 16, color: badgeColor)
                              : Text(
                                  '${k}K',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: karatColor,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(l.translateCoin(coin),
                                style: const TextStyle(fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis),
                            Text(
                              '${w.toStringAsFixed(2)}g • ${l.formatAmount(spot)} $selectedCurrency',
                              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
            onChanged: (v) => setState(() => selectedCoin = v!),
          ),

          // --- Bilezik: Karat + Gewicht ---
          if (_isBilezikSelected) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Karat', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [8, 14, 18, 21, 22].map((k) {
                        final isSel = k == bilezikKarat;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text('${k}K',
                                style: TextStyle(
                                    fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
                            selected: isSel,
                            onSelected: (_) => setState(() => bilezikKarat = k),
                            selectedColor: Colors.amber.shade600,
                            labelStyle: TextStyle(color: isSel ? Colors.white : null),
                            side: BorderSide(
                                color: isSel ? Colors.amber.shade600 : Colors.grey.shade300),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: 150,
                    child: TextField(
                      controller: bilezikWeightController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Gewicht pro Stück',
                        suffixText: 'g',
                        border: const OutlineInputBorder(),
                        isDense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          // --- Währungs-Chips: horizontal scrollbar ---
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              l.t('gold_currency'),
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: currencies.map((c) {
                final isSelected = c == selectedCurrency;
                const currencySymbols = {
                  'USD': '\$', 'EUR': '€', 'TRY': '₺', 'GBP': '£',
                  'CHF': '₣', 'JPY': '¥', 'AUD': 'A\$', 'CAD': 'C\$',
                  'INR': '₹', 'SAR': '﷼', 'AED': 'د.إ',
                };
                final symbol = currencySymbols[c] ?? c;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(
                      '$c $symbol',
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 13,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (_) => setState(() => selectedCurrency = c),
                    selectedColor: Theme.of(context).colorScheme.primary,
                    labelStyle: TextStyle(
                      color: isSelected
                          ? Theme.of(context).colorScheme.onPrimary
                          : null,
                    ),
                    side: BorderSide(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey.shade300,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              SizedBox(
                width: 120,
                child: TextField(
                  controller: quantityController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: l.t('gold_quantity'),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: addToCart,
                child: Text(l.t('gold_add')),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.delete_forever),
                onPressed: clearCart,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Warenkorb-Liste (mit ShrinkWrap für ScrollView-Kompatibilität)
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: cart.length,
            itemBuilder: (context, index) {
              final item = cart[index];
              final resolved = _resolveCartItem(item);
              final spotTotal = resolved['spotPerPiece']! * item.quantity;
              final dealerTotal = spotTotal * (widget.dealerMarkupEnabled ? (1 + widget.dealerMarkup / 100) : 1.0);

                return Dismissible(
                  key: ValueKey(item.coinName),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) => removeItem(index),
                  child: Card(
                    child: ListTile(
                      title: Text(_displayCoinName(item)),
                      subtitle: Text('${l.t('gold_quantity')}: ${item.quantity % 1 == 0 ? item.quantity.toInt() : item.quantity}'),
                      trailing: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${l.t('gold_spot')}: ${l.formatAmount(spotTotal)} $selectedCurrency',
                          ),
                          Text(
                            '${l.t('gold_dealer')}: ${l.formatAmount(dealerTotal)} $selectedCurrency',
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          
          const SizedBox(height: 16),

          Text(
            '${l.t('gold_total_spot')}: ${l.formatAmount(totalSpot)} $selectedCurrency',
            style: const TextStyle(fontSize: 16),
          ),
          Text(
            '${l.t('gold_total_dealer')}: ${l.formatAmount(totalDealer)} $selectedCurrency',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          if (lastFetchTime != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Icon(Icons.access_time, size: 11, color: Colors.grey.shade400),
                  const SizedBox(width: 4),
                  Text(
                    lastFetchTime!.substring(0, 16).replaceAll('-', '.').replaceAll('T', ' '),
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: Icon(Icons.refresh, size: 14, color: Colors.grey.shade400),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () async {
                      setState(() => loading = true);
                      await fetchGold();
                    },
                  ),
                ],
              ),
            ),
          
          const SizedBox(height: 16),
          
          // "Alle entfernen" Button
          if (cart.isNotEmpty)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: clearCart,
                icon: const Icon(Icons.delete_sweep, color: Colors.red),
                label: Text(
                  l.t('gold_remove_all'),
                  style: const TextStyle(color: Colors.red),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                ),
              ),
            ),
          
          const SizedBox(height: 12),
          
          // "Teilen" Button
          if (cart.isNotEmpty)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: shareCart,
                icon: const Icon(Icons.share),
                label: Text(LanguageService().t('gold_share')),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Theme.of(context).primaryColor),
                ),
              ),
            ),

          // Zakat Button
          if (cart.isNotEmpty && widget.zakatEnabled) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  HapticService().light();
                  showZakatDialog();
                },
                icon: const Icon(Icons.calculate_outlined),
                label: Text(LanguageService().t('zakat_button')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber.shade700,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
        ),
      ),
    );
  }
}
