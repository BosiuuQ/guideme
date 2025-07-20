import 'package:flutter/material.dart';
import 'package:guide_me/core/constants/app_colors.dart';
import 'package:guide_me/features/garage/domain/entity/vehicle.dart';
import 'package:guide_me/features/garage/garage_backend.dart';

class UserGarageView extends StatefulWidget {
  final String userId;
  const UserGarageView({super.key, required this.userId});

  @override
  State<UserGarageView> createState() => _UserGarageViewState();
}

class _UserGarageViewState extends State<UserGarageView> {
  late Future<List<Vehicle>> vehiclesFuture;

  @override
  void initState() {
    super.initState();
    vehiclesFuture = GarageBackend.getVehiclesForUser(widget.userId);
  }

  void _showVehicleDetailsDialog(BuildContext context, Vehicle vehicle) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: AppColors.darkBlue,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (vehicle.imageUrls.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(vehicle.imageUrls.first, height: 200, fit: BoxFit.cover),
                  ),
                const SizedBox(height: 16),
                Text("${vehicle.brand} ${vehicle.model}",
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 8),
                Text("Rocznik: ${vehicle.productionYear} • ${vehicle.horsepower} KM",
                    style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 8),
                Text("Pojemność: ${vehicle.capacityCm3} cm³", style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 8),
                Text("Kolor: ${vehicle.color}", style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 8),
                Text("Paliwo: ${vehicle.fuelType}", style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 8),
                Text("Skrzynia: ${vehicle.gearbox}", style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 8),
                Text("Napęd: ${vehicle.drive}", style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 12),
                if (vehicle.note.isNotEmpty)
                  Text("Notatka: ${vehicle.note}",
                      style: const TextStyle(color: Colors.white60, fontStyle: FontStyle.italic)),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  icon: const Icon(Icons.flag),
                  label: const Text("Zgłoś pojazd"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    _showReportDialog(vehicle);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showReportDialog(Vehicle vehicle) async {
    String reason = "";

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Zgłoś pojazd"),
        backgroundColor: AppColors.darkBlue,
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 18),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Podaj powód zgłoszenia:", style: TextStyle(color: Colors.white)),
            const SizedBox(height: 8),
            TextField(
              onChanged: (value) => reason = value,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Np. zdjęcie niezgodne z zasadami...",
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white12,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Anuluj")),
          ElevatedButton(
            onPressed: () async {
              if (reason.trim().isEmpty) return;
              Navigator.pop(context);
              await GarageBackend.reportVehicleToDiscord(
                vehicleId: vehicle.id,
                reason: reason,
                imageUrl: vehicle.imageUrls.firstOrNull ?? "",
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Zgłoszenie wysłane do moderatorów")),
                );
              }
            },
            child: const Text("Zgłoś"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBlue,
      appBar: AppBar(
        backgroundColor: AppColors.darkBlue,
        title: const Text("Garaż użytkownika"),
      ),
      body: FutureBuilder<List<Vehicle>>(
        future: vehiclesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text("Błąd: ${snapshot.error}", style: const TextStyle(color: Colors.red)),
            );
          }

          final vehicles = snapshot.data ?? [];

          if (vehicles.isEmpty) {
            return const Center(
              child: Text("Ten użytkownik nie dodał jeszcze żadnych pojazdów.",
                  style: TextStyle(color: Colors.white54)),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: vehicles.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final vehicle = vehicles[index];
              return Card(
                color: Colors.white10,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  onTap: () => _showVehicleDetailsDialog(context, vehicle),
                  leading: vehicle.imageUrls.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(vehicle.imageUrls.first,
                              width: 60, height: 60, fit: BoxFit.cover),
                        )
                      : const Icon(Icons.directions_car, size: 40, color: Colors.white54),
                  title: Text(
                    "${vehicle.brand} ${vehicle.model}",
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    "${vehicle.productionYear} • ${vehicle.horsepower} KM",
                    style: const TextStyle(color: Colors.white54),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
