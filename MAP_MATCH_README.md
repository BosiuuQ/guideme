Map Matching integration (Mapbox) - Guide Me app
---------------------------------------------------

What I changed:
- Added optional Map Matching (snap-to-road) support to:
  `features/map/mapa/map_logic_handler.dart`.

- The new code calls Mapbox Map Matching API (https://docs.mapbox.com/api/navigation/map-matching/)
  using Dart's `dart:io` HttpClient when a new GPS position arrives.
  It is non-blocking: existing animation and movement logic remain unchanged.
  The handler sets `_targetLocation` immediately to the raw GPS point and then,
  asynchronously, attempts to map-match using the previous and current GPS positions.
  If a snapped point is returned and it is within `mapMatchingMaxDistanceMeters` (defaults to 100m),
  `_targetLocation` is replaced with the snapped point and `onUpdate` is triggered.

How to enable and configure:
1. Provide your Mapbox access token at runtime. Example (where you create the MapLogicHandler):
   ```dart
   final mapLogic = MapLogicHandler();
   mapLogic.setMapboxAccessToken('YOUR_MAPBOX_ACCESS_TOKEN_HERE');
   // optionally adjust snapping radius:
   mapLogic.mapMatchingMaxDistanceMeters = 100.0; // default is 100
   ```

2. No extra pubspec dependency was added (uses `dart:io` and `dart:convert`) so no `pub get` changes needed.
   If you prefer `package:http`, feel free to replace the HttpClient usage.

3. Permissions & Network:
   - Ensure Android/iOS network permissions are set (INTERNET) — usual Flutter projects have Internet by default,
     but double-check AndroidManifest and iOS entitlements if required.

Notes & limitations:
- Map Matching is called only when there is a previous GPS position (`_lastGpsPosition != null`).
  This is because Mapbox Map Matching performs better with a trace of two or more points.
- If Mapbox returns no match or an error occurs, the code silently falls back to the raw GPS position.
- Matching is asynchronous and will not block or change the existing tick/animation logic.

Files modified:
- features/map/mapa/map_logic_handler.dart
- A backup of the original file was created alongside it:
  features/map/mapa/map_logic_handler.dart.mapmatch.bak

If you want, I can:
- Move the Mapbox token to secure storage or into app config.
- Add logging to help debug map-matching results.
- Switch to `package:http` and add to pubspec for easier testing.
