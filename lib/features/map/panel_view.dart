import 'package:flutter/material.dart';
import 'package:guide_me/features/map/panel_backend.dart';

void showPanelView(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.black87,
    isScrollControlled: false,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _PanelContent(),
  );
}

class _PanelContent extends StatelessWidget {
  const _PanelContent({super.key});

  @override
  Widget build(BuildContext context) {
    final options = [
      {
        'icon': Icons.local_police,
        'label': 'Kontrola',
        'type': 'kontrola',
        'color': const Color(0xFF8A56FF),
      },
      {
        'icon': Icons.visibility_off,
        'label': 'Nieoznakowani',
        'type': 'nieoznakowani',
        'color': const Color(0xFF9575CD),
      },
      {
        'icon': Icons.camera_alt,
        'label': 'Fotoradar',
        'type': 'fotoradar',
        'color': const Color(0xFF4FC3F7),
      },
      {
        'icon': Icons.warning,
        'label': 'Zagrożenie',
        'type': 'zagrozenie',
        'color': const Color(0xFFFFA726),
      },
      {
        'icon': Icons.car_crash,
        'label': 'Wypadek',
        'type': 'wypadek',
        'color': const Color(0xFF00BFA5),
      },
      {
        'icon': Icons.engineering,
        'label': 'Prace drogowe',
        'type': 'roboty_drogowe',
        'color': const Color(0xFFFF7043),
      },
      {
        'icon': Icons.assistant_direction,
        'label': 'Inspekcja',
        'type': 'inspekcja',
        'color': const Color(0xFF64B5F6),
      },
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
      child: Wrap(
        runSpacing: 20,
        children: [
          const Center(
            child: Text(
              'Zgłoś zdarzenie',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 10),
          GridView.count(
            shrinkWrap: true,
            crossAxisCount: 3,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: options.map((item) {
              return GestureDetector(
                onTap: () async {
                  await PanelBackend.addReport(type: item['type'] as String);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Zgłoszono: ${item['label']} 🚨"),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        item['icon'] as IconData,
                        color: item['color'] as Color,
                        size: 30,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item['label'] as String,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
