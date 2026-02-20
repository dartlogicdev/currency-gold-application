import 'package:flutter/material.dart';

class SettingsTab extends StatelessWidget {
  final ThemeMode currentTheme;
  final Function(ThemeMode) onThemeChanged;

  const SettingsTab({
    super.key,
    required this.currentTheme,
    required this.onThemeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
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
                    groupValue: currentTheme,
                    onChanged: (mode) {
                      if (mode != null) onThemeChanged(mode);
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
                    groupValue: currentTheme,
                    onChanged: (mode) {
                      if (mode != null) onThemeChanged(mode);
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
                    groupValue: currentTheme,
                    onChanged: (mode) {
                      if (mode != null) onThemeChanged(mode);
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
        ],
      ),
    );
  }
}
