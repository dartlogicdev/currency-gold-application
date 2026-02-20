# 🔑 Release Signing Setup - Anleitung

## ✅ Was bereits erledigt ist:

1. ✅ Upload-Keystore erstellt: `C:\Users\Sena\upload-keystore.jks`
2. ✅ Konfigurations-Datei erstellt: `android/key.properties`
3. ✅ Build-Konfiguration aktualisiert
4. ✅ .gitignore schützt dein Passwort vor Git

---

## 🔧 Was DU jetzt tun musst:

### **SCHRITT 1: Passwort eintragen**

1. Öffne die Datei: `android/key.properties`
2. Ersetze **BEIDE** `[DEIN_PASSWORT_HIER]` mit deinem echten Keystore-Passwort
3. Speichern

**Vorher:**
```
storePassword=[DEIN_PASSWORT_HIER]
keyPassword=[DEIN_PASSWORT_HIER]
```

**Nachher:**
```
storePassword=deinEchtesPasswort123
keyPassword=deinEchtesPasswort123
```

⚠️ **WICHTIG:** Verwende dein echtes Passwort, das du bei der Keystore-Erstellung eingegeben hast!

---

### **SCHRITT 2: Signierte APK bauen**

Nach dem Passwort eintragen:

```bash
flutter build apk --release
```

Die signierte APK liegt dann in:
```
build/app/outputs/flutter-apk/app-release.apk
```

---

## 🔒 Sicherheits-Tipps

### **Was ist geschützt?**
✅ `key.properties` ist in `.gitignore` → wird NICHT in Git gespeichert
✅ `upload-keystore.jks` liegt außerhalb des Projekts
✅ Passwörter bleiben lokal auf deinem PC

### **Was musst du sichern?**
🔐 **Keystore-Datei:** `C:\Users\Sena\upload-keystore.jks`
🔐 **Passwort:** Notiere es an einem sicheren Ort
🔐 **Key-Alias:** `upload`

**Backup-Empfehlung:**
- Kopiere `upload-keystore.jks` auf USB-Stick
- Speichere Passwort in Passwort-Manager
- OHNE diese Daten kannst du KEINE Updates veröffentlichen!

---

## ❓ Häufige Probleme

### **"Keystore not found"**
→ Überprüfe Pfad in `key.properties`, Zeile 4:
```
storeFile=C:\\Users\\Sena\\upload-keystore.jks
```

### **"Wrong password"**
→ Passwort falsch eingegeben in `key.properties`

### **Build funktioniert nicht**
```bash
flutter clean
flutter pub get
flutter build apk --release
```

---

## 📱 Nächste Schritte nach erfolgreichem Build

1. ✅ APK auf Testgerät installieren
2. ✅ Alle Funktionen testen
3. ✅ Screenshots machen für Play Store
4. ✅ Im Play Console hochladen

---

## 🆘 Support

Bei Problemen:
- Prüfe `android/key.properties` (Passwort richtig?)
- Prüfe Keystore-Pfad (existiert die .jks Datei?)
- Führe `flutter clean` aus

**Du schaffst das!** 🚀
