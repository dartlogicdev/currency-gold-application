import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config.dart';
import 'language_service.dart';

class GoldScannerTab extends StatefulWidget {
  const GoldScannerTab({super.key});

  @override
  State<GoldScannerTab> createState() => _GoldScannerTabState();
}

class _GoldScannerTabState extends State<GoldScannerTab> {
  static const int _dailyScanLimit = 5;
  static const String _scanCountKey = 'scanner_scan_count';
  static const String _scanDateKey = 'scanner_scan_date';

  File? _selectedImage;
  bool _isAnalyzing = false;
  ScanResult? _result;
  String? _errorMessage;
  int _scansUsedToday = 0;
  double _goldPricePerGram = 0.0;

  @override
  void initState() {
    super.initState();
    _loadScanCount();
    _loadGoldPrice();
  }

  Future<void> _loadGoldPrice() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedData = prefs.getString('gold_data');
    if (cachedData != null) {
      try {
        final data = jsonDecode(cachedData);
        final coins = Map<String, dynamic>.from(data['coins'] ?? {});
        // Ersten verfügbaren Münzdatensatz nehmen und Preis pro Gramm berechnen
        if (coins.isNotEmpty) {
          final first = coins.values.first as Map<String, dynamic>;
          final spot = (first['spot'] as num?)?.toDouble() ?? 0.0;
          final weight = (first['weight'] as num?)?.toDouble() ?? 1.0;
          if (weight > 0) {
            setState(() => _goldPricePerGram = spot / weight);
          }
        }
      } catch (_) {}
    }
  }

  Future<void> _loadScanCount() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDate = prefs.getString(_scanDateKey);
    final today = _todayString();
    if (savedDate != today) {
      // Neuer Tag → Zähler zurücksetzen
      await prefs.setInt(_scanCountKey, 0);
      await prefs.setString(_scanDateKey, today);
      setState(() => _scansUsedToday = 0);
    } else {
      setState(() => _scansUsedToday = prefs.getInt(_scanCountKey) ?? 0);
    }
  }

  Future<void> _incrementScanCount() async {
    final prefs = await SharedPreferences.getInstance();
    final newCount = _scansUsedToday + 1;
    await prefs.setInt(_scanCountKey, newCount);
    await prefs.setString(_scanDateKey, _todayString());
    setState(() => _scansUsedToday = newCount);
  }

  String _todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }

  int get _scansRemaining => _dailyScanLimit - _scansUsedToday;

  Future<void> _pickImage(ImageSource source) async {
    if (_scansRemaining <= 0) {
      setState(() {
        _errorMessage = LanguageService().t('scanner_limit_reached');
      });
      return;
    }

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1024,
    );
    if (picked == null) return;

    setState(() {
      _selectedImage = File(picked.path);
      _result = null;
      _errorMessage = null;
    });

    await _analyzeImage(_selectedImage!);
  }

  Future<void> _analyzeImage(File imageFile) async {
    final apiKey = Config.geminiApiKey;
    if (apiKey.isEmpty) {
      setState(() {
        _errorMessage = 'API Key nicht konfiguriert. Bitte --dart-define=GEMINI_API_KEY=... verwenden.';
      });
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
    });

    try {
      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: apiKey,
      );

      final imageBytes = await imageFile.readAsBytes();
      final prompt = '''
Analyze this image and determine if it shows a gold item (coin, bar, jewelry, etc.).

Respond ONLY with a valid JSON object in this exact format (no markdown, no extra text):
{
  "isGold": true or false,
  "itemType": "e.g. Gold Coin - Krugerrand 1 oz",
  "weightGrams": 31.10,
  "purityPercent": 91.67,
  "confidence": "high/medium/low",
  "notes": "short optional note"
}

If it is NOT a gold item, set isGold to false and leave other fields as null.
''';

      final response = await model.generateContent([
        Content.multi([
          TextPart(prompt),
          DataPart('image/jpeg', imageBytes),
        ]),
      ]);

      final text = response.text ?? '';
      final parsed = _parseResponse(text, _goldPricePerGram);

      await _incrementScanCount();

      setState(() {
        _result = parsed;
        _isAnalyzing = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '${LanguageService().t('scanner_error')}: $e';
        _isAnalyzing = false;
      });
    }
  }

  ScanResult _parseResponse(String text, double goldPricePerGram) {
    try {
      // JSON aus der Antwort extrahieren
      final jsonStart = text.indexOf('{');
      final jsonEnd = text.lastIndexOf('}');
      if (jsonStart == -1 || jsonEnd == -1) throw Exception('No JSON found');
      final jsonStr = text.substring(jsonStart, jsonEnd + 1);
      final Map<String, dynamic> data = json.decode(jsonStr);
      return ScanResult.fromJson(data, goldPricePerGram);
    } catch (_) {
      return ScanResult.unknown();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = LanguageService();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Card(
              color: isDark ? Colors.amber.shade900 : Colors.amber.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.camera_enhance, color: Colors.amber, size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.t('scanner_title'),
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            l.t('scanner_subtitle'),
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Scan-Limit Anzeige
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: _scansRemaining > 0 ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 6),
                Text(
                  '${l.t('scanner_scans_remaining')}: $_scansRemaining / $_dailyScanLimit',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: _scansRemaining > 0 ? Colors.green : Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Bildvorschau
            if (_selectedImage != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  _selectedImage!,
                  height: 220,
                  fit: BoxFit.cover,
                ),
              )
            else
              Container(
                height: 220,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.4),
                    width: 2,
                    style: BorderStyle.solid,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_photo_alternate_outlined,
                          size: 60, color: theme.colorScheme.outline),
                      const SizedBox(height: 8),
                      Text(l.t('scanner_no_image'),
                          style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.outline)),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _scansRemaining > 0
                        ? () => _pickImage(ImageSource.gallery)
                        : null,
                    icon: const Icon(Icons.photo_library),
                    label: Text(l.t('scanner_gallery')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _scansRemaining > 0
                        ? () => _pickImage(ImageSource.camera)
                        : null,
                    icon: const Icon(Icons.camera_alt),
                    label: Text(l.t('scanner_camera')),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Laden-Indikator
            if (_isAnalyzing)
              const Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('KI analysiert das Bild...'),
                ],
              ),

            // Fehlermeldung
            if (_errorMessage != null)
              Card(
                color: theme.colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: theme.colorScheme.error),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(_errorMessage!,
                              style: TextStyle(color: theme.colorScheme.error))),
                    ],
                  ),
                ),
              ),

            // Ergebnis
            if (_result != null) _buildResultCard(_result!, theme, l),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(ScanResult result, ThemeData theme, LanguageService l) {
    if (!result.isGold) {
      return Card(
        color: theme.colorScheme.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.cancel_outlined, color: Colors.orange, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l.t('scanner_not_gold'),
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.amber, size: 28),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    result.itemType ?? l.t('scanner_gold_item'),
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                _confidenceBadge(result.confidence, theme),
              ],
            ),
            const Divider(height: 24),
            if (result.weightGrams != null)
              _infoRow(
                  Icons.scale,
                  l.t('scanner_weight'),
                  '${result.weightGrams!.toStringAsFixed(2)} g',
                  theme),
            if (result.purityPercent != null)
              _infoRow(
                  Icons.star,
                  l.t('scanner_purity'),
                  '${result.purityPercent!.toStringAsFixed(2)}%  (${_purityToKarat(result.purityPercent!)})',
                  theme),
            if (result.estimatedValueUsd != null)
              _infoRow(
                  Icons.attach_money,
                  l.t('scanner_est_value'),
                  '\$${result.estimatedValueUsd!.toStringAsFixed(2)}',
                  theme,
                  highlight: true),
            if (result.notes != null && result.notes!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(result.notes!,
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline)),
              ),
            const SizedBox(height: 8),
            Text(
              l.t('scanner_disclaimer'),
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                  fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, ThemeData theme,
      {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text('$label: ', style: theme.textTheme.bodyMedium),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: highlight ? Colors.amber.shade700 : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _confidenceBadge(String? confidence, ThemeData theme) {
    final color = switch (confidence) {
      'high' => Colors.green,
      'medium' => Colors.orange,
      _ => Colors.red,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        confidence ?? '?',
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }

  String _purityToKarat(double percent) {
    final karat = (percent / 100 * 24).round();
    return '${karat}K';
  }
}

class ScanResult {
  final bool isGold;
  final String? itemType;
  final double? weightGrams;
  final double? purityPercent;
  final double? estimatedValueUsd;
  final String? confidence;
  final String? notes;

  ScanResult({
    required this.isGold,
    this.itemType,
    this.weightGrams,
    this.purityPercent,
    this.estimatedValueUsd,
    this.confidence,
    this.notes,
  });

  factory ScanResult.fromJson(Map<String, dynamic> json, double goldPricePerGram) {
    final isGold = json['isGold'] == true;
    final weight = (json['weightGrams'] as num?)?.toDouble();
    final purity = (json['purityPercent'] as num?)?.toDouble();

    double? estimatedValue;
    if (isGold && weight != null && purity != null) {
      estimatedValue = weight * (purity / 100) * goldPricePerGram;
    }

    return ScanResult(
      isGold: isGold,
      itemType: json['itemType'] as String?,
      weightGrams: weight,
      purityPercent: purity,
      estimatedValueUsd: estimatedValue,
      confidence: json['confidence'] as String?,
      notes: json['notes'] as String?,
    );
  }

  factory ScanResult.unknown() => ScanResult(
        isGold: false,
        notes: 'Antwort konnte nicht verarbeitet werden.',
      );
}
