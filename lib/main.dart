import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'currency_tab.dart';
import 'gold_tab.dart';
// import 'chart_tab.dart'; // TODO: Aktivieren wenn Charts produktionsreif
// import 'affiliate_tab.dart'; // TODO: Aktivieren für V2 mit Affiliate
import 'debug_mode_check.dart';
import 'config.dart';
import 'analytics_service.dart';
import 'theme_service.dart';
import 'settings_tab.dart';
import 'haptic_service.dart';
import 'language_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Zeige Environment Info beim Start
  debugPrint('=== CURRENCY GOLD APP ===');
  debugPrint('Mode: ${Config.isDevelopment ? 'DEVELOPMENT' : 'PRODUCTION'}');
  debugPrint('API URL: ${Config.apiBaseUrl}');
  debugPrint('========================');

  // Tracke App-Start
  await AnalyticsService().incrementSessionCount();
  
  // Initialisiere HapticService
  await HapticService().init();

  // Initialisiere LanguageService
  await LanguageService().init();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.system;
  String _langCode = LanguageService().currentCode;
  bool _zakatEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final theme = await ThemeService().getThemeMode();
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _themeMode = theme;
      _langCode = LanguageService().currentCode;
      _zakatEnabled = prefs.getBool('zakat_enabled') ?? false;
    });
  }

  void _changeTheme(ThemeMode mode) {
    setState(() {
      _themeMode = mode;
    });
    ThemeService().setThemeMode(mode);
  }

  void _changeLanguage(String code) {
    LanguageService().setLanguage(code);
    setState(() {
      _langCode = code;
    });
  }

  Future<void> _changeZakat(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('zakat_enabled', value);
    setState(() {
      _zakatEnabled = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
      ),
      home: HomePage(
        onThemeChanged: _changeTheme,
        currentTheme: _themeMode,
        langCode: _langCode,
        onLangChanged: _changeLanguage,
        zakatEnabled: _zakatEnabled,
        onZakatChanged: _changeZakat,
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  final Function(ThemeMode) onThemeChanged;
  final ThemeMode currentTheme;
  final String langCode;
  final Function(String) onLangChanged;
  final bool zakatEnabled;
  final Function(bool) onZakatChanged;

  const HomePage({
    super.key,
    required this.onThemeChanged,
    required this.currentTheme,
    required this.langCode,
    required this.onLangChanged,
    required this.zakatEnabled,
    required this.onZakatChanged,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _analytics = AnalyticsService();
  
  // Dynamische Tab-Namen basierend auf sichtbaren Tabs
  List<String> get _tabNames {
    final l = LanguageService();
    final showDebug = Config.isDevelopment;
    final names = [l.t('tab_currency'), l.t('tab_gold'), l.t('tab_settings')];
    if (showDebug) names.add(l.t('tab_debug'));
    return names;
  }

  @override
  void initState() {
    super.initState();
    
    // Anzahl Tabs hängt von Environment ab
    final showDebug = Config.isDevelopment;
    // final showChartTab = false; // TODO: Aktivieren wenn Charts produktionsreif
    
    int tabCount = 3; // Currency + Gold + Settings
    // if (showChartTab) tabCount++;
    if (showDebug) tabCount++;
    
    _tabController = TabController(length: tabCount, vsync: this);
    
    // Tracke initialen Tab-View
    _analytics.trackTabView(_tabNames[0]);
    
    // Listener für Tab-Wechsel
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        final tabName = _tabNames[_tabController.index];
        _analytics.trackTabView(tabName);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Anzahl Tabs hängt von Environment ab
    final showDebug = Config.isDevelopment;
    // final showPartnerTab = false; // TODO: Aktivieren für V2 mit Affiliate
    // final showChartTab = false; // TODO: Aktivieren wenn Charts produktionsreif

    return Scaffold(
      appBar: AppBar(
        title: const Text('Money Exchanger'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: LanguageService().t('tab_currency')),
            Tab(text: LanguageService().t('tab_gold')),
            Tab(icon: const Icon(Icons.settings), text: LanguageService().t('tab_settings')),
            if (showDebug) Tab(text: LanguageService().t('tab_debug')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          CurrencyTab(langCode: widget.langCode),
          GoldTab(langCode: widget.langCode, zakatEnabled: widget.zakatEnabled),
          SettingsTab(
            currentTheme: widget.currentTheme,
            onThemeChanged: widget.onThemeChanged,
            langCode: widget.langCode,
            onLangChanged: widget.onLangChanged,
            zakatEnabled: widget.zakatEnabled,
            onZakatChanged: widget.onZakatChanged,
          ),
          if (showDebug) const DebugModeCheck(),
        ],
      ),
    );
  }
}
