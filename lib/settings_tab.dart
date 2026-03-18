import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'config.dart';
import 'haptic_service.dart';
import 'language_service.dart';

class SettingsTab extends StatefulWidget {
  final ThemeMode currentTheme;
  final Function(ThemeMode) onThemeChanged;
  final String langCode;
  final Function(String) onLangChanged;
  final bool zakatEnabled;
  final Function(bool) onZakatChanged;
  final double dealerMarkup;
  final bool dealerMarkupEnabled;
  final Function(double) onDealerMarkupChanged;
  final Function(bool) onDealerMarkupEnabledChanged;

  const SettingsTab({
    super.key,
    required this.currentTheme,
    required this.onThemeChanged,
    required this.langCode,
    required this.onLangChanged,
    required this.zakatEnabled,
    required this.onZakatChanged,
    required this.dealerMarkup,
    required this.dealerMarkupEnabled,
    required this.onDealerMarkupChanged,
    required this.onDealerMarkupEnabledChanged,
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

  Future<void> _openPrivacyPolicy() async {
    final uri = Uri.parse(Config.privacyPolicyUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
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
    final l = LanguageService();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.t('settings_title'),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),

          // Sprache
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.language, size: 24),
                      const SizedBox(width: 12),
                      Text(l.t('settings_language'),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...LanguageService.supportedLanguages.map((lang) {
                    return RadioListTile<String>(
                      dense: true,
                      title: Text('${lang['flag']}  ${lang['name']}'),
                      value: lang['code']!,
                      groupValue: widget.langCode,
                      onChanged: (code) {
                        if (code != null) {
                          HapticService().selection();
                          widget.onLangChanged(code);
                        }
                      },
                    );
                  }),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Theme Auswahl
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.palette, size: 24),
                      const SizedBox(width: 12),
                      Text(l.t('settings_design'),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  RadioListTile<ThemeMode>(
                    title: Row(children: [const Icon(Icons.light_mode, size: 20), const SizedBox(width: 12), Text(l.t('settings_light'))]),
                    value: ThemeMode.light,
                    groupValue: widget.currentTheme,
                    onChanged: (mode) { if (mode != null) { HapticService().selection(); widget.onThemeChanged(mode); } },
                  ),
                  RadioListTile<ThemeMode>(
                    title: Row(children: [const Icon(Icons.dark_mode, size: 20), const SizedBox(width: 12), Text(l.t('settings_dark'))]),
                    value: ThemeMode.dark,
                    groupValue: widget.currentTheme,
                    onChanged: (mode) { if (mode != null) { HapticService().selection(); widget.onThemeChanged(mode); } },
                  ),
                  RadioListTile<ThemeMode>(
                    title: Row(children: [const Icon(Icons.settings_suggest, size: 20), const SizedBox(width: 12), Text(l.t('settings_system'))]),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(left: 32, top: 4),
                      child: Text(l.t('settings_system_sub'), style: const TextStyle(fontSize: 12)),
                    ),
                    value: ThemeMode.system,
                    groupValue: widget.currentTheme,
                    onChanged: (mode) { if (mode != null) { HapticService().selection(); widget.onThemeChanged(mode); } },
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
                      const Icon(Icons.vibration, size: 24),
                      const SizedBox(width: 12),
                      Text(l.t('settings_haptic'),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  RadioListTile<HapticLevel>(
                    title: Row(children: [const Icon(Icons.vibration, size: 20), const SizedBox(width: 12), Text(l.t('settings_haptic_all'))]),
                    subtitle: Padding(padding: const EdgeInsets.only(left: 32, top: 4), child: Text(l.t('settings_haptic_all_sub'), style: const TextStyle(fontSize: 12))),
                    value: HapticLevel.all,
                    groupValue: _hapticLevel,
                    onChanged: (level) { if (level != null) _setHapticLevel(level); },
                  ),
                  RadioListTile<HapticLevel>(
                    title: Row(children: [const Icon(Icons.notification_important, size: 20), const SizedBox(width: 12), Text(l.t('settings_haptic_important'))]),
                    subtitle: Padding(padding: const EdgeInsets.only(left: 32, top: 4), child: Text(l.t('settings_haptic_important_sub'), style: const TextStyle(fontSize: 12))),
                    value: HapticLevel.important,
                    groupValue: _hapticLevel,
                    onChanged: (level) { if (level != null) _setHapticLevel(level); },
                  ),
                  RadioListTile<HapticLevel>(
                    title: Row(children: [const Icon(Icons.vibration_outlined, size: 20), const SizedBox(width: 12), Text(l.t('settings_haptic_off'))]),
                    subtitle: Padding(padding: const EdgeInsets.only(left: 32, top: 4), child: Text(l.t('settings_haptic_off_sub'), style: const TextStyle(fontSize: 12))),
                    value: HapticLevel.off,
                    groupValue: _hapticLevel,
                    onChanged: (level) { if (level != null) _setHapticLevel(level); },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Zakat-Modus
          Card(
            child: SwitchListTile(
              secondary: const Icon(Icons.calculate_outlined, size: 24),
              title: Text(l.t('settings_zakat'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              subtitle: Text(l.t('settings_zakat_sub'), style: const TextStyle(fontSize: 12)),
              value: widget.zakatEnabled,
              onChanged: (val) {
                HapticService().selection();
                widget.onZakatChanged(val);
              },
            ),
          ),

          const SizedBox(height: 16),

          // Händleraufschlag
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.percent, size: 24),
                      const SizedBox(width: 12),
                      Text(l.t('settings_dealer'),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      widget.dealerMarkupEnabled
                          ? '${widget.dealerMarkup.toInt()}%'
                          : l.t('settings_dealer_off'),
                    ),
                    subtitle: Text(l.t('settings_dealer_sub'), style: const TextStyle(fontSize: 12)),
                    value: widget.dealerMarkupEnabled,
                    onChanged: (val) {
                      HapticService().selection();
                      widget.onDealerMarkupEnabledChanged(val);
                    },
                  ),
                  if (widget.dealerMarkupEnabled)
                    Slider(
                      value: widget.dealerMarkup,
                      min: 1,
                      max: 5,
                      divisions: 4,
                      label: '${widget.dealerMarkup.toInt()}%',
                      onChanged: (val) {
                        HapticService().selection();
                        widget.onDealerMarkupChanged(val);
                      },
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Rechtliches
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: Text(l.t('settings_privacy')),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () {
                    HapticService().light();
                    _openPrivacyPolicy();
                  },
                ),
              ],
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
                  Icon(Icons.info_outline, color: Theme.of(context).colorScheme.onSecondaryContainer),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l.t('settings_info'),
                      style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSecondaryContainer),
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
              if (!snapshot.hasData) return const SizedBox.shrink();
              final info = snapshot.data!;
              return Center(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    children: [
                      Text('Version ${info.version}', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
                      Text('Build ${info.buildNumber}', style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4))),
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
