import 'package:flutter/material.dart';
import 'package:guide_me/core/constants/app_colors.dart';
import 'package:guide_me/features/level/level_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LevelView extends StatefulWidget {
  final int currentLevel;

  const LevelView({
    super.key,
    required this.currentLevel,
  });

  @override
  State<LevelView> createState() => _LevelViewState();
}

class _LevelViewState extends State<LevelView> {
  double? currentKm;

  @override
  void initState() {
    super.initState();
    _loadDistance();
  }

  Future<void> _loadDistance() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    final data = await Supabase.instance.client
        .from('user_distance')
        .select('total_km')
        .eq('user_id', userId)
        .single();

    setState(() {
      currentKm = (data['total_km'] ?? 0).toDouble();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (currentKm == null) {
      return const Scaffold(
        backgroundColor: AppColors.darkBlue,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final nextLevel = widget.currentLevel < 100 ? widget.currentLevel + 1 : widget.currentLevel;
    final currentThreshold = LevelService.levelThresholds[widget.currentLevel] ?? 0;
    final nextThreshold = LevelService.levelThresholds[nextLevel] ?? currentKm!;
    final progress = ((currentKm! - currentThreshold) / (nextThreshold - currentThreshold)).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: AppColors.darkBlue,
      appBar: AppBar(
        backgroundColor: AppColors.darkBlue,
        elevation: 0,
        title: const Text('Twój Poziom', style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Text('Poziom ${widget.currentLevel}', style: const TextStyle(fontSize: 26, color: Colors.white))),
              const SizedBox(height: 10),
              Center(child: Text('${currentKm!.toStringAsFixed(1)} km', style: const TextStyle(color: Colors.white70))),
              const SizedBox(height: 20),
              LinearProgressIndicator(
                value: progress,
                minHeight: 14,
                backgroundColor: Colors.white10,
                valueColor: const AlwaysStoppedAnimation(AppColors.blue),
                borderRadius: BorderRadius.circular(10),
              ),
              const SizedBox(height: 10),
              Center(
                child: Text(
                  'Do poziomu $nextLevel: ${(nextThreshold - currentKm!).clamp(0, double.infinity).toStringAsFixed(1)} km',
                  style: const TextStyle(color: Colors.white60),
                ),
              ),
              const SizedBox(height: 30),
              const Text('Jak zdobywać punkty?', style: TextStyle(fontSize: 20, color: Colors.white)),
              const SizedBox(height: 10),
              _earnTips(),
              const SizedBox(height: 30),
              const Text('GuidePoints – Twoja nagroda za aktywność', style: TextStyle(fontSize: 20, color: Colors.white)),
              const SizedBox(height: 10),
              _guidePointsInfo(),
              const SizedBox(height: 40),
              Center(
                child: Text(
                  'GuidePoints do zbierania dostępne będą\nod aktualizacji GuideMe v0.3.0',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _earnTips() {
    const style = TextStyle(color: Colors.white70);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text('• Przejeżdżaj kilometry z aplikacją GuideMe', style: style),
        Text('• Dodawaj punkty widokowe i posty', style: style),
        Text('• Oceniaj miejsca innych użytkowników', style: style),
      ],
    );
  }

  Widget _guidePointsInfo() {
    const style = TextStyle(color: Colors.white70);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text(
          '• Czym są GuidePoints?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 6),
        Text(
          'GuidePoints to wirtualna waluta, którą zdobywasz za aktywność w aplikacji – np. za przejechane kilometry, dodane punkty widokowe, ocenianie miejsc i dzielenie się postami.',
          style: style,
        ),
        SizedBox(height: 16),
        Text(
          '• Na co mogę je wymienić?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 6),
        Text(
          'W naszym sklepie wymienisz GuidePoints na:',
          style: style,
        ),
        Text('  – Konto premium (GuideMe PRO)', style: style),
        Text('  – Wirtualne dodatki do aplikacji', style: style),
        Text('  – Fizyczne nagrody: gadżety do auta, wlepki, zapachy i wiele więcej!', style: style),
        SizedBox(height: 16),
        Text(
          'Zbieraj, wymieniaj i pokazuj swoją aktywność na trasie!',
          style: TextStyle(color: AppColors.blue, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
