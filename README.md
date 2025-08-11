# guide_me

GuideMe



## TODO

1. Zmienić metodę rsowania kursora w trybie mapy tak, aby był on pod nazwami ulic (E)
2. Optymalizacja kamery - obracanie się, skręcanie, naprawić zablokowanie przeciągania kamery, naprawić to gdy stoisz w miejscu albo wykryje jakieś 1-3km wolniej jazdy to potrafiło to zwariować i się obracało bez powodu (E)
3. naprawić instrukcje na górze skręty w lewo w prawo bo trochę zepsute haha (M)
4. wykrywanie zjazdu z trasy dodać/naprawic (M)

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
