import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';
import 'core/constants/app_colors.dart';

/// PermissionGate widget
/// Wrap your app with this to ensure location permission is requested
/// and to block the UI if permission is permanently denied.
///
/// Accepts [initialGranted] so the caller (e.g. main) can pass a pre-fetched
/// permission state to avoid any startup flicker.
class PermissionGate extends StatefulWidget {
  final Widget child;
  final bool? initialGranted;
  const PermissionGate({required this.child, this.initialGranted, super.key});

  @override
  State<PermissionGate> createState() => _PermissionGateState();
}

class _PermissionGateState extends State<PermissionGate> with WidgetsBindingObserver {
  bool _ready = false; // true => show child
  bool _checked = false; // whether we've checked at least once
  bool _permanentlyDenied = false;
  String? _error;

  // track whether we've already requested on startup to ensure only one auto-request
  bool _requestedOnStart = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Use initialGranted (when provided) to avoid UI flicker on app startup.
    if (widget.initialGranted != null) {
      _ready = widget.initialGranted!;
      _checked = true;
      // if initialGranted == false, we will perform a single request on start
      if (!widget.initialGranted!) {
        // schedule a single request after first frame
        WidgetsBinding.instance.addPostFrameCallback((_) => _requestPermissionOnceOnStart());
      }
    } else {
      // If nobody provided initial state, probe current status WITHOUT requesting permission (no system dialog).
      Permission.locationWhenInUse.status.then((s) {
        if (s.isGranted) {
          setState(() {
            _ready = true;
            _checked = true;
          });
        } else if (s.isPermanentlyDenied) {
          setState(() {
            _ready = false;
            _permanentlyDenied = true;
            _checked = true;
          });
        } else {
          // Not granted — request once on start.
          setState(() { _checked = true; });
          WidgetsBinding.instance.addPostFrameCallback((_) => _requestPermissionOnceOnStart());
        }
      }).catchError((e) {
        setState(() {
          _error = e.toString();
          _checked = true;
        });
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Listen for app resume: re-check permission (useful when user goes to Settings).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      Permission.locationWhenInUse.status.then((s) {
        if (s.isGranted) {
          setState(() {
            _ready = true;
            _permanentlyDenied = false;
            _error = null;
          });
        } else {
          setState(() {
            _ready = false;
            _permanentlyDenied = s.isPermanentlyDenied;
          });
        }
      }).catchError((_) {});
    }
  }

  Future<void> _requestPermissionOnceOnStart() async {
    if (_requestedOnStart) return;
    _requestedOnStart = true;
    await _requestPermission(); // reuse same flow
  }

  Future<void> _requestPermission() async {
    try {
      // Single request triggered by the user pressing the button OR auto-start.
      final res = await Permission.locationWhenInUse.request();
      var granted = res.isGranted;
      var permDenied = res.isPermanentlyDenied;

      // Try alternate permission type if not granted and not permanently denied.
      if (!granted && !permDenied) {
        final res2 = await Permission.location.request();
        granted = res2.isGranted;
        permDenied = permDenied || res2.isPermanentlyDenied;
      }

      setState(() {
        _ready = granted;
        _checked = true;
        _permanentlyDenied = !granted && permDenied;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    }
  }

  Future<void> _openSettings() async {
    await openAppSettings();
    // After returning from settings, didChangeAppLifecycleState will re-check.
  }

  void _closeApp() {
    try {
      SystemNavigator.pop();
    } catch (_) {}
  }

  Widget _buildBlockingContent(BuildContext context) {
    // Determine colors: prefer app theme if dark; otherwise force app dark colors.
    ThemeData? themeData;
    try {
      themeData = Theme.of(context);
    } catch (_) {
      themeData = null;
    }

    final bool forceAppDark = themeData == null || themeData.brightness == Brightness.light;

    final bg = forceAppDark ? AppColors.darkBlue : (themeData!.scaffoldBackgroundColor);
    final cardColor = forceAppDark ? AppColors.lighterDarkBlue : (themeData?.cardColor ?? AppColors.lighterDarkBlue);
    final primary = forceAppDark ? AppColors.blue : (themeData?.colorScheme.primary ?? AppColors.blue);
    final textTheme = themeData?.textTheme ?? ThemeData.dark().textTheme;

    // Force white text for readability as requested
    final headingStyle = textTheme.titleLarge?.copyWith(color: Colors.white);
    final bodyStyle = textTheme.bodyMedium?.copyWith(color: Colors.white);
    final captionStyle = textTheme.bodySmall?.copyWith(color: Colors.white);

    return Container(
      color: bg,
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 28.0),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Card(
            elevation: 10,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            color: cardColor,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: LayoutBuilder(builder: (context, constraints) {
                final wide = constraints.maxWidth > 420;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.location_on_outlined, size: 56, color: primary),
                    const SizedBox(height: 12),
                    Text(
                      'Aplikacja potrzebuje dostępu do lokalizacji',
                      style: headingStyle,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Aby aplikacja działała poprawnie (planowanie tras, nawigacja), musimy mieć dostęp do twojej lokalizacji. '
                      'Możesz przyznać uprawnienie teraz lub otworzyć ustawienia aplikacji.',
                      style: bodyStyle,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    if (_error != null) ...[
                      Text('Błąd: $_error', style: captionStyle),
                      const SizedBox(height: 12),
                    ],
                    // Buttons: symmetric layout
                    if (wide) ...[
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: ElevatedButton(
                                onPressed: _requestPermission,
                                style: ElevatedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  backgroundColor: primary,
                                  padding: const EdgeInsets.symmetric(horizontal: 18),
                                ),
                                child: const Text('Spróbuj ponownie'),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: OutlinedButton(
                                onPressed: _openSettings,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: primary,
                                  side: BorderSide(color: primary),
                                  padding: const EdgeInsets.symmetric(horizontal: 18),
                                ),
                                child: const Text('Otwórz ustawienia'),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 44,
                        width: 160,
                        child: TextButton(
                          onPressed: _closeApp,
                          child: Text('Zamknij', style: TextStyle(color: primary)),
                        ),
                      ),
                    ] else ...[
                      Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _requestPermission,
                              style: ElevatedButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: primary,
                                padding: const EdgeInsets.symmetric(horizontal: 18),
                              ),
                              child: const Text('Spróbuj ponownie'),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: OutlinedButton(
                              onPressed: _openSettings,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: primary,
                                side: BorderSide(color: primary),
                                padding: const EdgeInsets.symmetric(horizontal: 18),
                              ),
                              child: const Text('Otwórz ustawienia'),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 44,
                            child: TextButton(
                              onPressed: _closeApp,
                              child: Text('Zamknij', style: TextStyle(color: primary)),
                            ),
                          ),
                        ],
                      )
                    ],
                    const SizedBox(height: 6),
                    if (_permanentlyDenied)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          'Uprawnienie permanentnie zablokowane — otwórz ustawienia, aby dać dostęp.',
                          style: captionStyle,
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                );
              }),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // If permission granted, show the wrapped app immediately.
    if (_ready) return widget.child;

    // If we have checked and know it's denied, show the blocking UI.
    // If we haven't checked yet, show blocking UI while we probe/request on start.
    final needsWrappers = Directionality.maybeOf(context) == null;

    final blocking = SafeArea(child: _buildBlockingContent(context));

    if (needsWrappers) {
      return Directionality(
        textDirection: TextDirection.ltr,
        child: Theme(
          data: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: AppColors.darkBlue,
            colorScheme: ColorScheme.dark(primary: AppColors.blue),
            cardColor: AppColors.lighterDarkBlue,
          ),
          child: Material(
            color: AppColors.darkBlue,
            child: blocking,
          ),
        ),
      );
    } else {
      return blocking;
    }
  }
}
