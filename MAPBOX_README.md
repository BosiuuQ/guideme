Instrukcja konfiguracji Mapbox dla Androida/iOS (ważne)
- W folderze android/app/src/main/AndroidManifest.xml znajduje się meta-data:
    <meta-data android:name="com.mapbox.token" android:value="YOUR_MAPBOX_ACCESS_TOKEN" />
  Zamień "YOUR_MAPBOX_ACCESS_TOKEN" na swój publiczny token (pk.*) z konta Mapbox.
- Dla nowszych wersji SDK możesz też ustawić MAPBOX_DOWNLOADS_TOKEN w pliku android/gradle.properties (jeśli używasz prywatnych pobrań).
- Alternatywnie możesz przekazać token przez --dart-define ACCESS_TOKEN=pk.xxx i zmodyfikować kod, aby używał tej zmiennej.
- Styl ustawiony domyślnie w kodzie: mapbox://styles/bosiuuq/cmb9d84f300t001r25irj47nk
- Kąt nachylenia (tilt) ustawiony na 45 stopni dla efektu 3D.
- Jeśli chcesz zachować obecny token hardcoded, jest on już ustawiony w main_map_widget.dart (możesz go zmienić).
