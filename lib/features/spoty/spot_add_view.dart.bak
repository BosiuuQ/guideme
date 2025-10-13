import 'dart:ui';
import 'package:flutter/material.dart';

class SpotAddView extends StatefulWidget {
  const SpotAddView({super.key});

  @override
  State<SpotAddView> createState() => _SpotAddViewState();
}

class _SpotAddViewState extends State<SpotAddView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade1;
  late final Animation<double> _fade2;
  late final Animation<double> _fade3;
  late final Animation<double> _scaleBadge;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..forward();

    _fade1 = CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.45, curve: Curves.easeOut));
    _fade2 = CurvedAnimation(parent: _ctrl, curve: const Interval(0.25, 0.7, curve: Curves.easeOut));
    _fade3 = CurvedAnimation(parent: _ctrl, curve: const Interval(0.45, 1.0, curve: Curves.easeOut));
    _scaleBadge = Tween<double>(begin: 0.95, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: const Interval(0.2, 0.6, curve: Curves.easeOutBack)));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const bgStart = Color(0xFF0C0F1C); // głęboki granat
    const bgEnd = Color(0xFF0A1F2E);   // turkusowy granat
    const accent = Color(0xFF00E5FF);  // neon turkus (akcent GuideMe)
    const accent2 = Color(0xFF4AF2C5); // miękki miętowy

    return Scaffold(
      backgroundColor: bgStart,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          tooltip: 'Wstecz',
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text('Dodaj Spot', style: TextStyle(color: Colors.white)),
        centerTitle: false,
      ),
      body: Stack(
        children: [
          // Tło: gradient + delikatne „promienie”
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [bgStart, bgEnd],
                ),
              ),
            ),
          ),
          Positioned(
            left: -80,
            top: -40,
            child: _GlowBlob(size: 220, color: accent.withOpacity(0.12)),
          ),
          Positioned(
            right: -60,
            bottom: -20,
            child: _GlowBlob(size: 180, color: accent2.withOpacity(0.10)),
          ),

          // Zawartość
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Column(
                children: [
                  // Badge z wersją
                  ScaleTransition(
                    scale: _scaleBadge,
                    child: _VersionPill(
                      label: 'Dostępne od',
                      version: 'Beta 0.5.0',
                      accent: accent,
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Karta „glassmorphism”
                  Expanded(
                    child: FadeTransition(
                      opacity: _fade1,
                      child: _GlassCard(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Ikona / ilustracja
                            TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0.9, end: 1.0),
                              duration: const Duration(milliseconds: 900),
                              curve: Curves.easeOutBack,
                              builder: (context, value, child) => Transform.scale(scale: value, child: child),
                              child: Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      accent.withOpacity(0.22),
                                      Colors.transparent,
                                    ],
                                  ),
                                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                                ),
                                child: const Icon(Icons.location_on_rounded, size: 72, color: Colors.white),
                              ),
                            ),
                            const SizedBox(height: 20),
                            // Tytuł
                            FadeTransition(
                              opacity: _fade2,
                              child: const Text(
                                'Dodawanie Spotów',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 26,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Podtytuł
                            FadeTransition(
                              opacity: _fade3,
                              child: Text(
                                'Ta funkcja zostanie odblokowana w aktualizacji\nBeta 0.5.0. Przygotuj miejsce, opis i zdjęcie!',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.78),
                                  fontSize: 14.5,
                                  height: 1.35,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            // „Checklist”
                            FadeTransition(
                              opacity: _fade3,
                              child: _Checklist(
                                items: const [
                                  'Zgłoś lokalizację i precyzyjne współrzędne',
                                  'Dodaj tytuł, opis i zasady spotu',
                                  'Ustaw widoczność: publiczna / tylko dla znajomych',
                                  'Dodaj zdjęcie podglądowe miejsca',
                                ],
                                accent: accent,
                              ),
                            ),
                            const SizedBox(height: 28),
                            // Przyciski
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(width: 12),
                                _NeonButton.outlined(
                                  label: 'Powrót',
                                  icon: Icons.arrow_back_rounded,
                                  onPressed: () => Navigator.maybePop(context),
                                  accent: accent,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Paski postępu „coming soon”
                            const _SoonProgress(),
                          ],
                        ),
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

/// Delikatna świecąca plama tła
class _GlowBlob extends StatelessWidget {
  final double size;
  final Color color;
  const _GlowBlob({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: color, blurRadius: size * 0.75, spreadRadius: size * 0.25),
        ],
      ),
    );
  }
}

/// Szklana karta z rozmyciem
class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: Colors.white.withOpacity(0.04),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 26,
                spreadRadius: 2,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Pastylka z wersją
class _VersionPill extends StatelessWidget {
  final String label;
  final String version;
  final Color accent;
  const _VersionPill({required this.label, required this.version, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_clock_rounded, size: 18, color: accent),
          const SizedBox(width: 8),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: Colors.white.withOpacity(0.75),
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: LinearGradient(
                colors: [accent.withOpacity(0.85), accent.withOpacity(0.45)],
              ),
            ),
            child: Text(
              version,
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w800,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Listowana „checklista” punktów
class _Checklist extends StatelessWidget {
  final List<String> items;
  final Color accent;
  const _Checklist({required this.items, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final text in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 22, width: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: accent.withOpacity(0.6), width: 1.6),
                    gradient: RadialGradient(colors: [
                      accent.withOpacity(0.25),
                      Colors.transparent,
                    ]),
                  ),
                  child: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Neonowy przycisk (wypełniony lub obrys)
class _NeonButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final Color accent;
  final bool outlined;

  const _NeonButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.accent,
  }) : outlined = false;

  const _NeonButton.outlined({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.accent,
  }) : outlined = true;

  @override
  Widget build(BuildContext context) {
    final base = outlined
        ? OutlinedButton.styleFrom(
            side: BorderSide(color: accent.withOpacity(0.8), width: 1.4),
            foregroundColor: accent,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          )
        : ElevatedButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: Colors.black,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          );

    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    );

    return outlined
        ? OutlinedButton(onPressed: onPressed, style: base, child: child)
        : ElevatedButton(onPressed: onPressed, style: base, child: child);
  }
}

/// Pasek „coming soon” – delikatna animacja
class _SoonProgress extends StatefulWidget {
  const _SoonProgress();

  @override
  State<_SoonProgress> createState() => _SoonProgressState();
}

class _SoonProgressState extends State<_SoonProgress> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _c.drive(CurveTween(curve: Curves.easeInOut)),
      child: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Text(
          'COMING SOON…',
          style: TextStyle(
            color: Colors.white.withOpacity(0.55),
            letterSpacing: 3.2,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
