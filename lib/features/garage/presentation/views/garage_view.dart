import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:guide_me/core/config/routing/app_routes.dart';
import 'package:guide_me/core/constants/app_colors.dart';
import 'package:guide_me/features/garage/garage_backend.dart';
import 'package:guide_me/features/garage/domain/entity/vehicle.dart';
import 'package:guide_me/features/garage/presentation/widgets/vehicle_card_widget.dart';

class GarageView extends StatefulWidget {
  const GarageView({Key? key}) : super(key: key);

  @override
  State<GarageView> createState() => _GarageViewState();
}

class _GarageViewState extends State<GarageView> {
  String _garageStatus = "otwarty";
  late Future<List<Vehicle>> _vehiclesFuture;

  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }

  void _loadVehicles() {
    _vehiclesFuture = GarageBackend.getVehicles();
    _vehiclesFuture.then((vehicles) {
      if (vehicles.isNotEmpty) {
        final firstStatus = vehicles.first.status;
        setState(() {
          _garageStatus = firstStatus;
        });
      }
    });
  }

  Future<void> _toggleGarageStatus() async {
    try {
      final newStatus = switch (_garageStatus) {
        "otwarty" => "zamkniety",
        "zamkniety" => "dla_znajomych",
        _ => "otwarty",
      };

      await GarageBackend.updateAllVehicleStatuses(newStatus);
      setState(() {
        _garageStatus = newStatus;
      });
      _loadVehicles();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Błąd: $e")));
    }
  }

  Icon _statusIcon() {
    if (_garageStatus == 'zamkniety') {
      return const Icon(Icons.lock, color: Colors.yellow);
    } else if (_garageStatus == 'dla_znajomych') {
      return const Icon(Icons.group, color: Colors.lightBlueAccent);
    } else {
      return const Icon(Icons.lock_open, color: Colors.yellow);
    }
  }

  void _showStatusLegend() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black87,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Row(children: [
                Icon(Icons.lock_open, color: Colors.yellow),
                SizedBox(width: 12),
                Text("Garaż otwarty", style: TextStyle(color: Colors.white)),
              ]),
              SizedBox(height: 16),
              Row(children: [
                Icon(Icons.lock, color: Colors.yellow),
                SizedBox(width: 12),
                Text("Garaż zamknięty", style: TextStyle(color: Colors.white)),
              ]),
              SizedBox(height: 16),
              Row(children: [
                Icon(Icons.group, color: Colors.lightBlueAccent),
                SizedBox(width: 12),
                Text("Dostęp tylko dla znajomych", style: TextStyle(color: Colors.white)),
              ]),
            ],
          ),
        );
      },
    );
  }

  void _confirmDeleteVehicle(Vehicle vehicle) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Usuń pojazd"),
        content: Text("Czy na pewno chcesz usunąć pojazd '${vehicle.brand} ${vehicle.model}'?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Anuluj")),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await GarageBackend.deleteVehicleWithLog(vehicle.id);
              _loadVehicles();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Pojazd został usunięty.")),
              );
            },
            child: const Text("Usuń"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FutureBuilder<List<Vehicle>>(
        future: _vehiclesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox();
          }
          return FloatingActionButton(
            backgroundColor: AppColors.blue,
            onPressed: () {
              context.pushNamed(AppRoutes.addNewVehicleView, extra: _garageStatus);
            },
            child: const Icon(Icons.add),
          );
        },
      ),
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Flexible(child: Text("Garaż")),
            const SizedBox(width: 8.0),
            PopupMenuButton<String>(
              icon: _statusIcon(),
              onSelected: (value) {
                if (value == 'toggle') _toggleGarageStatus();
                if (value == 'legend') _showStatusLegend();
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'toggle', child: Text('Zmień status')),
                PopupMenuItem(value: 'legend', child: Text('Co oznaczają ikonki?')),
              ],
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: FutureBuilder<List<Vehicle>>(
        future: _vehiclesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Błąd: ${snapshot.error}"));
          }
          final vehicles = snapshot.data ?? [];
          if (vehicles.isEmpty) {
            return _emptyGarage();
          }
          return RefreshIndicator(
            onRefresh: () async {
              _loadVehicles();
            },
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
              itemCount: vehicles.length,
              itemBuilder: (context, index) {
                final vehicle = vehicles[index];
                return VehicleCardWidget(
                  vehicle: vehicle,
                  onTap: () {
                    context.pushNamed(AppRoutes.vehicleDetailsView, extra: vehicle);
                  },
                  onLongPress: () => _confirmDeleteVehicle(vehicle),
                  isChecked: false,
                );
              },
              separatorBuilder: (context, index) => const SizedBox(height: 24.0),
            ),
          );
        },
      ),
    );
  }

  Widget _emptyGarage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            "Twój garaż stoi pusty :(",
            style: TextStyle(
              color: AppColors.lightBlue,
              fontSize: 18.0,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24.0),
          ElevatedButton(
            style: ButtonStyle(
              backgroundColor: MaterialStateProperty.all(AppColors.blue),
              foregroundColor: MaterialStateProperty.all(Colors.white),
            ),
            onPressed: () {
              context.pushNamed(AppRoutes.addNewVehicleView, extra: _garageStatus);
            },
            child: Text(
              "Dodaj nowy pojazd",
              style: TextStyle(color: Colors.grey.shade400),
            ),
          )
        ],
      ),
    );
  }
}
