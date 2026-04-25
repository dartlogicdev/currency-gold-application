import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';

// AdMob Banner Ad Unit IDs (platform-specific)
final String _bannerAdUnitId = Platform.isIOS
    ? 'ca-app-pub-7469061721257322/8290022352'  // iOS
    : 'ca-app-pub-7469061721257322/2524469058'; // Android

// Registrierte Testgeräte (Debug-Modus)
const List<String> _testDeviceIds = ['36B189AE3FD8463BC3F9E080FCEACDF2'];

// Completer, der signalisiert, dass ATT aufgelöst wurde (iOS) bzw. sofort bereit ist (Android).
// BannerAdWidget wartet darauf, bevor es eine Ad-Anfrage stellt.
final Completer<void> _attReadyCompleter = Completer<void>();

// ATT-Status nach Auflösung – bestimmt ob personalisierte oder nicht-personalisierte Ads angefragt werden.
// null = Android (kein ATT), authorized = personalisiert, alles andere = nicht-personalisiert.
TrackingStatus? _attStatus;

Future<void> initAdMob() async {
  // Nur SDK-Initialisierung – ATT wird nach dem ersten Frame angefragt (iOS-Requirement)
  await MobileAds.instance.initialize();
  await MobileAds.instance.updateRequestConfiguration(
    RequestConfiguration(testDeviceIds: _testDeviceIds),
  );
  // Auf Android gibt es kein ATT → sofort bereit, keine Personalisierungseinschränkung
  if (!Platform.isIOS) {
    if (!_attReadyCompleter.isCompleted) _attReadyCompleter.complete();
  }
}

/// Muss NACH dem ersten Frame aufgerufen werden (Apple erfordert sichtbare App-UI).
/// Fragt ATT-Permission an und signalisiert danach, dass Ads geladen werden dürfen.
/// try/finally garantiert, dass der Completer immer abgeschlossen wird –
/// auch wenn das ATT-Plugin einen Fehler wirft.
Future<void> requestAttAndReloadAds() async {
  if (!Platform.isIOS) return;
  try {
    var status = await AppTrackingTransparency.trackingAuthorizationStatus;
    if (status == TrackingStatus.notDetermined) {
      status = await AppTrackingTransparency.requestTrackingAuthorization();
    }
    _attStatus = status;
    debugPrint('[ATT] Status: $status');
  } catch (e) {
    debugPrint('[ATT] Fehler beim ATT-Request: $e');
    _attStatus = TrackingStatus.denied; // Fallback: nicht-personalisiert
  } finally {
    // ATT ist jetzt aufgelöst (authorized, denied, restricted oder Fehler) → Ad laden erlaubt
    if (!_attReadyCompleter.isCompleted) _attReadyCompleter.complete();
  }
}

/// Gibt zurück ob nicht-personalisierte Ads angefragt werden sollen.
/// - iOS: nur wenn ATT nicht authorized (DSGVO-sicher, funktioniert auch ohne Tracking-Erlaubnis)
/// - Android: immer false (kein ATT, DSGVO-Consent separat)
bool get _useNonPersonalizedAds {
  if (!Platform.isIOS) return false;
  return _attStatus != TrackingStatus.authorized;
}

class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    // Auf iOS warten, bis ATT aufgelöst ist – erst dann Ad-Request stellen.
    // Ohne ATT-Autorisierung verwirft AdMob auf echten Geräten die Anfrage (sehr niedrige Fill-Rate).
    // Auf Android ist _attReadyCompleter sofort completed (wird in initAdMob gesetzt).
    _attReadyCompleter.future.then((_) {
      if (mounted) _loadAd();
    });
  }

  void _loadAd() {
    // Vorheriges Banner sauber disposen falls noch vorhanden
    _bannerAd?.dispose();
    _bannerAd = null;
    _isLoaded = false;

    _bannerAd = BannerAd(
      adUnitId: _bannerAdUnitId,
      size: AdSize.banner,
      // nonPersonalizedAds: true → DSGVO-konform ohne Consent-Dialog,
      // zeigt kontextuelle statt personalisierte Ads (funktioniert auch ohne ATT-Erlaubnis).
      request: AdRequest(nonPersonalizedAds: _useNonPersonalizedAds),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          debugPrint('[AdMob] Banner geladen (nonPersonalized=$_useNonPersonalizedAds)');
          setState(() => _isLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('[AdMob] Banner failed (code=${error.code}): ${error.message}');
          ad.dispose();
          _bannerAd = null; // Referenz nullen, verhindert double-dispose
          // Retry nach 15 Sekunden
          Future.delayed(const Duration(seconds: 15), () {
            if (mounted) _loadAd();
          });
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded || _bannerAd == null) return const SizedBox.shrink();
    return SizedBox(
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      child: AdWidget(ad: _bannerAd!),
    );
  }
}
