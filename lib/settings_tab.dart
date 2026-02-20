import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'haptic_service.dart';

class SettingsTab extends StatefulWidget {
  final ThemeMode currentTheme;
  final Function(ThemeMode) onThemeChanged;

  const SettingsTab({
    super.key,
    required this.currentTheme,
    required this.onThemeChanged,
  });

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  HapticLevel _hapticLevel = HapticLevel.all;

  @override
  void initState() {
    super.initState();
    _loadHapticLevel();
  }

  Future<void> _loadHapticLevel() async {
    await HapticService().init();
    setState(() {
      _hapticLevel = HapticService().getLevel();
    });
  }

  Future<void> _setHapticLevel(HapticLevel level) async {
    await HapticService().setLevel(level);
    setState(() {
      _hapticLevel = level;
    });
    // Test-Feedback
    if (level == HapticLevel.all) {
      HapticService().light();
    } else if (level == HapticLevel.important) {
      HapticService().medium();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Einstellungen',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          
          // Theme Auswahl
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.palette, size: 24),
                      const SizedBox(width: 12),
                      const Text(
                        'Design',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Hell
                  RadioListTile<ThemeMode>(
                    title: Row(
                      children: [
                        Icon(Icons.light_mode, size: 20),
                        const SizedBox(width: 12),
                        const Text('Hell'),
                      ],
                    ),
                    value: ThemeMode.light,
                    groupValue: widget.currentTheme,
                    onChanged: (mode) {
                      if (mode != null) {
                        HapticService().selection();
                        widget.onThemeChanged(mode);
                      }
                    },
                  ),
                  
                  // Dunkel
                  RadioListTile<ThemeMode>(
                    title: Row(
                      children: [
                        Icon(Icons.dark_mode, size: 20),
                        const SizedBox(width: 12),
                        const Text('Dunkel'),
                      ],
                    ),
                    value: ThemeMode.dark,
                    groupValue: widget.currentTheme,
                    onChanged: (mode) {
                      if (mode != null) {
                        HapticService().selection();
                        widget.onThemeChanged(mode);
                      }
                    },
                  ),
                  
                  // System
                  RadioListTile<ThemeMode>(
                    title: Row(
                      children: [
                        Icon(Icons.settings_suggest, size: 20),
                        const SizedBox(width: 12),
                        const Text('System-Standard'),
                      ],
                    ),
                    subtitle: const Padding(
                      padding: EdgeInsets.only(left: 32, top: 4),
                      child: Text(
                        'Passt sich automatisch an dein Gerät an',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                    value: ThemeMode.system,
                    groupValue: widget.currentTheme,
                    onChanged: (mode) {
                      if (mode != null) {
                        HapticService().selection();
                        widget.onThemeChanged(mode);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Haptic Feedback Einstellungen
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.vibration, size: 24),
                      const SizedBox(width: 12),
                      const Text(
                        'Haptisches Feedback',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Alle
                  RadioListTile<HapticLevel>(
                    title: Row(
                      children: [
                        Icon(Icons.vibration, size: 20),
                        const SizedBox(width: 12),
                        const Text('Alle Aktionen'),
                      ],
                    ),
                    subtitle: const Padding(
                      padding: EdgeInsets.only(left: 32, top: 4),
                      child: Text(
                        'Vibration bei allen Interaktionen',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                    value: HapticLevel.all,
                    groupValue: _hapticLevel,
                    onChanged: (level) {
                      if (level != null) _setHapticLevel(level);
                    },
                  ),
                  
                  // Nur wichtige
                  RadioListTile<HapticLevel>(
                    title: Row(
                      children: [
                        Icon(Icons.notification_important, size: 20),
                        const SizedBox(width: 12),
                        const Text('Nur wichtige'),
                      ],
                    ),
                    subtitle: const Padding(
                      padding: EdgeInsets.only(left: 32, top: 4),
                      child: Text(
                        'Vibration nur bei wichtigen Aktionen',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                    value: HapticLevel.important,
                    groupValue: _hapticLevel,
                    onChanged: (level) {
                      if (level != null) _setHapticLevel(level);
                    },
                  ),
                  
                  // Aus
                  RadioListTile<HapticLevel>(
                    title: Row(
                      children: [
                        Icon(Icons.vibration_outlined, size: 20),
                        const SizedBox(width: 12),
                        const Text('Aus'),
                      ],
                    ),
                    subtitle: const Padding(
                      padding: EdgeInsets.only(left: 32, top: 4),
                      child: Text(
                        'Keine Vibration',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                    value: HapticLevel.off,
                    groupValue: _hapticLevel,
                    onChanged: (level) {
                      if (level != null) _setHapticLevel(level);
                    },
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Info-Karte
          Card(
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Deine Einstellungen werden lokal gespeichert und nicht übertragen.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Version Info
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SizedBox.shrink();
              }
              final info = snapshot.data!;
              return Center(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    children: [
                      Text(
                        'Version ${info.version}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                      Text(
                        'Build ${info.buildNumber}',
                        style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
