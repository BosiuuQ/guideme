# guide_me

GuideMe

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

fvm dart run build_runner build --delete-conflicting-outputs
"# guideme" 

pod spodem instrukcja z chata, tego co robilem zeby to dzialalo, jak w tym gownie nie ma wszystkich plikow to zrob nowy projekt i podmien plik
ew sprawdz czy w android/app/src/main/AndroidManifest.xml Jest linia: <meta-data
            android:name="com.google.android.geo.API_KEY"
            android:value="AIzaSyCdl4aWnYfr3dBsmYdXd-WvXc3xOHn7PtA" />
Jezeli nie to dodaj nad activity
I sprawdz czy w build.grandle jest linia : ndkVersion = "27.0.12077973"
Jezeli nie to dodaj tu:
defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.guide_me"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        ndkVersion = "27.0.12077973"
    }


# 📱 Instrukcja uruchomienia aplikacji Flutter (Google Maps) na emulatorze

## ✅ Wymagania wstępne

1. **Pobierz i zainstaluj Android Studio (najlepiej najnowszą wersję)**  
   https://developer.android.com/studio

2. **Pobierz Flutter SDK (najnowsza wersja)**  
   https://docs.flutter.dev/get-started/install

3. **Dodaj Flutter do zmiennej systemowej `PATH`**  
   Aby móc korzystać z komendy `flutter` w terminalu (cmd / PowerShell), dodaj folder Fluttera (np. `C:\flutter\bin`) do zmiennej środowiskowej `PATH`.

---

## 🖥️ Konfiguracja emulatora

1. Otwórz **Android Studio**
2. Przejdź do `Device Manager`
3. Utwórz emulator **Pixel 7** z najnowszą wersją systemu Android (np. Android 15)
4. Uruchom emulator

---

## 🚀 Uruchamianie aplikacji Flutter

W terminalu (cmd, PowerShell lub terminal w Android Studio) wpisz zawsze poniższe 3 komendy:

```bash
flutter clean
flutter pub get
flutter run
```

---

## ⌨️ Jeśli **klawiatura nie działa** w emulatorze

1. Otwórz **CMD / PowerShell**
2. Wpisz komendę (zamień `[user]` na swoją nazwę użytkownika w systemie):

```bash
cd "C:\Users\[user]\AppData\Local\Android\Sdk\platform-tools"
. db shell settings put secure show_ime_with_hard_keyboard 0
```

3. Uruchom ponownie emulator.

---

## 🗺️ Obsługa mapy

- **Scrollowanie mapy (zoom)**:
  - `Ctrl` + `klik lewym` + **przeciąganie góra/dół** = zbliżenie/oddalenie
- **Przesuwanie mapy**:
  - Zwykłe przeciąganie myszką

---

Gotowe! 🎉  
Aplikacja powinna działać prawidłowo i używać aktualnej lokalizacji ustawionej w emulatorze. Jeśli masz problemy z Google Maps API, upewnij się, że Twój klucz API ma włączone wszystkie wymagane usługi (`Maps SDK for Android`, `Geolocation API`, itp.).
