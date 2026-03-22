# Store Listing Assets für KaratExchange

Dieser Ordner enthält alle Texte für die Veröffentlichung im Google Play Store.

## Dateien

### 📝 store_title.txt
**Verwendung:** App-Titel im Store (max. 80 Zeichen)
```
KaratExchange - Gold & Währungen: Live-Kurse und Preisvergleich
```

### 📄 store_short_description.txt
**Verwendung:** Kurzbeschreibung im Store Listing (max. 80 Zeichen)
```
Aktuelle Wechselkurse & Goldpreise. Favoriten, Warenkorb, Offline-Modus.
```

### 📖 store_description_full.txt
**Verwendung:** Vollständige App-Beschreibung im Store (max. 4000 Zeichen)
- Detaillierte Feature-Liste
- Zielgruppen-Beschreibung
- Geplante Features für V2
- Support-Kontakt

### ⭐ store_features.txt
**Verwendung:** Feature-Aufzählung für Screenshots oder Grafiken
- Kompakte Liste mit Checkmarks
- 8 Haupt-Features

### 📱 promo_social_media.txt
**Verwendung:** Posts für Social Media (WhatsApp, Twitter, Instagram, etc.)
- Kurz und prägnant
- Mit Emojis
- Call-to-Action

## Nächste Schritte für Store-Veröffentlichung

### 🎨 Grafische Assets (noch zu erstellen)
- [ ] App Icon (512x512px)
- [ ] Feature Graphic (1024x500px)
- [ ] Screenshots (mind. 2, empfohlen 4-8)
  - Currency Tab mit Favoriten
  - Gold Tab mit Warenkorb
  - Info-Box mit Cache-Metadaten
  - Dark Mode Darstellung

### 📋 Play Console Konfiguration
- [ ] Store Listing: Titel, Beschreibungen, Screenshots hochladen
- [ ] Content Rating: IARC-Fragebogen ausfüllen (wahrscheinlich "Alle")
- [ ] Privacy Policy: URL bereitstellen (TODO: erstellen)
- [ ] App-Kategorie: Finanzen
- [ ] Sprachen: Deutsch (evtl. später Englisch, Türkisch)

### 🔧 Technische Vorbereitung
- [x] Application ID: `dev.dartlogic.currencygold` ✅
- [ ] Signing Key erstellen und in build.gradle.kts konfigurieren
- [ ] `usesCleartextTraffic="false"` setzen (Server nutzt HTTPS)
- [ ] Versionierung prüfen (aktuell: 1.0.0+1)

### 📄 Rechtliches
- [ ] Privacy Policy verfassen und hosten
- [ ] Impressum (falls in Deutschland erforderlich)
- [ ] Play Store Developer Account (einmalig 25 USD)

## Hinweise

- **E-Mail-Adresse**: In `store_description_full.txt` Zeile 77 noch eintragen
- **Charakterlimits**: Alle Texte sind bereits optimiert
- **Emojis**: Funktionieren im Play Store problemlos
- **Sprache**: Derzeit nur Deutsch, kann später lokalisiert werden

## Kontakt & Support

- **GitHub**: github.com/hasances/currency-gold-application
- **E-Mail**: [DEINE_EMAIL_HIER]
