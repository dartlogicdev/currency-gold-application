import 'package:flutter/material.dart';
import 'currency_tab.dart';
import 'gold_tab.dart';
import 'chart_tab.dart';
import 'affiliate_tab.dart';
import 'debug_mode_check.dart';
import 'config.dart';
import 'analytics_service.dart';
import 'theme_service.dart';
import 'settings_tab.dart';
import 'haptic_service.dart';

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

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final theme = await ThemeService().getThemeMode();
    setState(() {
      _themeMode = theme;
    });
  }

  void _changeTheme(ThemeMode mode) {
    setState(() {
      _themeMode = mode;
    });
    ThemeService().setThemeMode(mode);
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
      home: HomePage(onThemeChanged: _changeTheme, currentTheme: _themeMode),
    );
  }
}

class HomePage extends StatefulWidget {
  final Function(ThemeMode) onThemeChanged;
  final ThemeMode currentTheme;
  
  const HomePage({super.key, required this.onThemeChanged, required this.currentTheme});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _analytics = AnalyticsService();
  
  // Dynamische Tab-Namen basierend auf sichtbaren Tabs
  List<String> get _tabNames {
    final showDebug = Config.isDevelopment;
    final showChartTab = false; // TODO: Aktivieren wenn Charts produktionsreif
    
    final names = ['Currency', 'Gold', 'Settings'];
    if (showChartTab) names.add('Chart');
    if (showDebug) names.add('Debug');
    return names;
  }

  @override
  void initState() {
    super.initState();
    
    // Anzahl Tabs hängt von Environment ab
    final showDebug = Config.isDevelopment;
    final showChartTab = false; // TODO: Aktivieren wenn Charts produktionsreif
    
    int tabCount = 3; // Currency + Gold + Settings
    if (showChartTab) tabCount++;
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
    final showPartnerTab = false; // TODO: Aktivieren für V2 mit Affiliate
    final showChartTab = false; // TODO: Aktivieren wenn Charts produktionsreif

    return Scaffold(
      appBar: AppBar(
        title: const Text('Money Exchanger'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            const Tab(text: 'Currency'),
            const Tab(text: 'Gold'),
            const Tab(icon: Icon(Icons.settings), text: 'Einstellungen'),
            if (showChartTab) const Tab(text: 'Chart'),
            if (showPartnerTab) const Tab(text: 'Partner'),
            if (showDebug) const Tab(text: 'Debug'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          const CurrencyTab(),
          const GoldTab(),
          SettingsTab(
            currentTheme: widget.currentTheme,
            onThemeChanged: widget.onThemeChanged,
          ),
          if (showChartTab) ChartTab(),
          if (showPartnerTab) AffiliateTab(),
          if (showDebug) const DebugModeCheck(),
        ],
      ),
    );
  }
}
