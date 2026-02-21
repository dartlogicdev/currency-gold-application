import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'config.dart';
import 'analytics_service.dart';
import 'haptic_service.dart';

class GoldItem {
  String coinName;
  double quantity;

  GoldItem({required this.coinName, required this.quantity});

  Map<String, dynamic> toJson() => {'coinName': coinName, 'quantity': quantity};

  factory GoldItem.fromJson(Map<String, dynamic> json) =>
      GoldItem(coinName: json['coinName'], quantity: (json['quantity'] as num).toDouble());
}

class GoldTab extends StatefulWidget {
  const GoldTab({super.key});

  @override
  State<GoldTab> createState() => _GoldTabState();
}

class _GoldTabState extends State<GoldTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Map<String, dynamic> coins = {};
  String selectedCoin = '';
  String selectedCurrency = 'USD';
  final currencies = ['USD', 'EUR', 'TRY'];
  bool loading = true;

  // Cache-Metadaten
  bool? isCached;
  int? cacheAge;
  String? lastFetchTime;
  bool isOffline = false; // Neue Variable: Offline-Status

  final TextEditingController quantityController = TextEditingController(
    text: '1',
  );

  List<GoldItem> cart = [];

  // Undo Snapshot (kompletter Zustand)
  List<GoldItem> undoSnapshot = [];

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await loadCart(); // Muss VOR fetchGold() aufgerufen werden
    await loadGoldFromCache(); // Gecachte Daten laden
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
            content: const Text('Keine Internetverbindung. Bitte prüfe deine Verbindung.'),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Erneut versuchen',
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

  void addToCart() {
    final qty = double.tryParse(quantityController.text) ?? 1.0;

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
    final weight = (coinData?['weight'] ?? 1.0) as double;
    final grams = qty * weight;
    AnalyticsService().trackCartItemAdded(grams, selectedCurrency);

    saveCart();
    quantityController.text = '1';
    
    // Haptic Feedback
    HapticService().medium();
    
    // Feedback SnackBar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$selectedCoin zum Warenkorb hinzugefügt'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
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
    showUndoSnackBar('Eintrag entfernt');
  }

  void clearCart() {
    if (cart.isEmpty) return;

    // Bestätigungsdialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Warenkorb leeren?'),
        content: Text('Möchtest du wirklich alle ${cart.length} Einträge entfernen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
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
              showUndoSnackBar('Alle Einträge entfernt');
            },
            child: const Text('Leeren', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void shareCart() {
    if (cart.isEmpty) return;

    // Warenkorb als Text formatieren
    final buffer = StringBuffer();
    buffer.writeln('🛒 Mein Gold-Kauf:\n');

    double totalSpot = 0;
    double totalDealer = 0;

    for (var item in cart) {
      final coinData = coins[item.coinName];
      final weight = coinData?['weight'] ?? 1.0;
      final data = coinData?[selectedCurrency] ?? {};
      final spot = data['spot'] ?? 0.0;

      final grams = item.quantity * weight;
      final spotTotal = (spot / weight) * grams;
      final dealerTotal = spotTotal * 1.04;

      totalSpot += spotTotal;
      totalDealer += dealerTotal;

      final quantityStr = item.quantity % 1 == 0 
          ? item.quantity.toInt().toString() 
          : item.quantity.toStringAsFixed(2);

      buffer.writeln('• ${item.coinName}: ${quantityStr}x');
      buffer.writeln('  Spot: ${spotTotal.toStringAsFixed(2)} $selectedCurrency');
      buffer.writeln('  Händler: ${dealerTotal.toStringAsFixed(2)} $selectedCurrency\n');
    }

    buffer.writeln('━━━━━━━━━━━━━━━━');
    buffer.writeln('Gesamt Spot: ${totalSpot.toStringAsFixed(2)} $selectedCurrency');
    buffer.writeln('Gesamt Händler: ${totalDealer.toStringAsFixed(2)} $selectedCurrency');
    buffer.writeln('\n📱 Erstellt mit Currency Gold App');

    // Haptic Feedback
    HapticService().selection();

    // Share
    Share.share(buffer.toString(), subject: 'Mein Gold-Warenkorb');

    // Feedback
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Warenkorb geteilt'),
        duration: Duration(seconds: 2),
      ),
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

  void showUndoSnackBar(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(label: 'Rückgängig', onPressed: undo),
      ),
    );
  }

  /* ------------------ UI ------------------ */

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    
    if (loading) return const Center(child: CircularProgressIndicator());

    double totalSpot = 0;
    double totalDealer = 0;

    for (var item in cart) {
      final coinData = coins[item.coinName];
      final weight = coinData?['weight'] ?? 1.0;
      final data = coinData?[selectedCurrency] ?? {};
      final spot = data['spot'] ?? 0.0;

      final grams = item.quantity * weight;
      final spotTotal = (spot / weight) * grams;
      totalSpot += spotTotal;
      totalDealer += spotTotal * 1.04;
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
              // Daten-Status Info (wie bei Currency-Tab)
          if (isCached != null || lastFetchTime != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isCached == true ? Icons.cached : Icons.cloud_done,
                        size: 16,
                        color: Colors.amber.shade700,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isCached == true
                              ? 'Cache (update in ${(600 - (cacheAge ?? 0))}s)'
                              : 'Server-Daten (Spot + Händler)',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.amber.shade700,
                          ),
                        ),
                      ),
                      // Refresh Button
                      IconButton(
                        icon: Icon(Icons.refresh, size: 20, color: Colors.amber.shade700),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () async {
                          setState(() => loading = true);
                          await fetchGold();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Goldpreise aktualisiert'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          
          DropdownButtonFormField<String>(
            value: selectedCoin,
            decoration: const InputDecoration(
              labelText: 'Münze',
              border: OutlineInputBorder(),
            ),
            items: coins.keys.map((coin) {
              final w = coins[coin]['weight'];
              final k = coins[coin]['karat'];
              return DropdownMenuItem(
                value: coin,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(coin),
                    Text(
                      '${w.toStringAsFixed(2)}g • $k K',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              );
            }).toList(),
            onChanged: (v) => setState(() => selectedCoin = v!),
          ),
          const SizedBox(height: 12),

          DropdownButtonFormField<String>(
            value: selectedCurrency,
            decoration: const InputDecoration(
              labelText: 'Währung',
              border: OutlineInputBorder(),
            ),
            items: currencies
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (v) => setState(() => selectedCurrency = v!),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              SizedBox(
                width: 120,
                child: TextField(
                  controller: quantityController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Anzahl',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: addToCart,
                child: const Text('Hinzufügen'),
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
              final coinData = coins[item.coinName];
              final weight = coinData?['weight'] ?? 1.0;
              final data = coinData?[selectedCurrency] ?? {};
              final spot = data['spot'] ?? 0.0;

              final grams = item.quantity * weight;
              final spotTotal = (spot / weight) * grams;
              final dealerTotal = spotTotal * 1.04;

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
                      title: Text(item.coinName),
                      subtitle: Text('Anzahl: ${item.quantity % 1 == 0 ? item.quantity.toInt() : item.quantity}'),
                      trailing: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Spot: ${spotTotal.toStringAsFixed(2)} $selectedCurrency',
                          ),
                          Text(
                            'Händler: ${dealerTotal.toStringAsFixed(2)} $selectedCurrency',
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
            'Gesamt Spot: ${totalSpot.toStringAsFixed(2)} $selectedCurrency',
            style: const TextStyle(fontSize: 16),
          ),
          Text(
            'Gesamt Händler: ${totalDealer.toStringAsFixed(2)} $selectedCurrency',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          
          const SizedBox(height: 16),
          
          // "Alle entfernen" Button
          if (cart.isNotEmpty)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: clearCart,
                icon: const Icon(Icons.delete_sweep, color: Colors.red),
                label: const Text(
                  'Alle entfernen',
                  style: TextStyle(color: Colors.red),
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
                label: const Text('Warenkorb teilen'),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Theme.of(context).primaryColor),
                ),
              ),
            ),
        ],
      ),
        ),
      ),
    );
  }
}
