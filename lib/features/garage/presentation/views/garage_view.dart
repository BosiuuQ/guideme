import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:guide_me/core/config/routing/app_routes.dart';
import 'package:guide_me/core/constants/app_colors.dart';
import 'package:guide_me/features/garage/garage_backend.dart';
import 'package:guide_me/features/garage/domain/entity/vehicle.dart';
import 'package:guide_me/features/garage/presentation/widgets/vehicle_card_widget.dart';
import 'package:guide_me/features/garage/presentation/views/vehicle_log_view.dart'; // <— DODANE: ekran dziennika

class GarageView extends StatefulWidget {
  const GarageView({Key? key}) : super(key: key);

  @override
  State<GarageView> createState() => _GarageViewState();
}

class _GarageViewState extends State<GarageView> {
  String _garageStatus = "otwarty";
  late Future<List<Vehicle>> _vehiclesFuture;

  // Użycie slotów garażu
  int _usedSlots = 0;
  int _limitSlots = 0;
  bool _loadingUsage = true;

  @override
  void initState() {
    super.initState();
    _refreshAll();
  }

  Future<void> _refreshAll() async {
    _loadVehicles();
    await _loadUsage();
  }

  void _loadVehicles() {
    _vehiclesFuture = GarageBackend.getVehicles();
    _vehiclesFuture.then((vehicles) {
      if (!mounted) return;
      if (vehicles.isNotEmpty) {
        final firstStatus = vehicles.first.status;
        setState(() {
          _garageStatus = firstStatus;
        });
      }
    });
  }

  Future<void> _loadUsage() async {
    try {
      setState(() => _loadingUsage = true);
      final usage = await GarageBackend.getGarageUsage(); // {used, limit}
      if (!mounted) return;
      setState(() {
        _usedSlots = usage['used'] ?? 0;
        _limitSlots = usage['limit'] ?? 0;
        _loadingUsage = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _usedSlots = 0;
        _limitSlots = 0;
        _loadingUsage = false;
      });
      _snack("Nie udało się pobrać limitu garażu: $e");
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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
      _snack("Błąd: $e");
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
              await _refreshAll();
              _snack("Pojazd został usunięty.");
            },
            child: const Text("Usuń"),
          ),
        ],
      ),
    );
  }

  bool get _isFull => _limitSlots > 0 && _usedSlots >= _limitSlots;

  void _handleAddPressed() async {
    if (_isFull) {
      _snack("Garaż pełny (${_usedSlots}/${_limitSlots}). Zwiększ limit lub usuń pojazd.");
      return;
    }
    context.pushNamed(AppRoutes.addNewVehicleView, extra: _garageStatus).then((_) async {
      // po powrocie odśwież i sloty i listę
      await _refreshAll();
    });
  }

  // Delikatny „glass” chip ze stanem slotów, np. 1/2
  Widget _usageChip() {
    final text = _loadingUsage ? '—/—' : '$_usedSlots/$_limitSlots';
    final bg = Colors.white.withOpacity(0.06);
    final border = Colors.white.withOpacity(0.18);
    final txtColor = _isFull ? Colors.redAccent : AppColors.lightBlue;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 12, spreadRadius: -6, offset: Offset(0, 6)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.garage_outlined, size: 16, color: Colors.white70),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(color: txtColor, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // „Szklany” okrągły przycisk na overlay (ikonka dziennika)
  Widget _logGlassIconButton({required VoidCallback onTap, String tooltip = 'Dziennik pojazdu'}) {
    final border = Colors.white.withOpacity(0.24);
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Material(
          color: Colors.white.withOpacity(0.10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: border),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(24),
            child: Tooltip(
              message: tooltip,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Icon(Icons.menu_book_rounded, color: Colors.white.withOpacity(0.95), size: 20),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FutureBuilder<List<Vehicle>>(
        future: _vehiclesFuture,
        builder: (context, snapshot) {
          // FAB zawsze widoczny, ale przy pełnym stanie pokazuje komunikat zamiast przejścia
          return FloatingActionButton(
            backgroundColor: _isFull ? AppColors.blue.withOpacity(0.4) : AppColors.blue,
            onPressed: _handleAddPressed,
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
            // Chip ze slotami
            _usageChip(),
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
          if (snapshot.connectionState == ConnectionState.waiting && _loadingUsage) {
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
              await _refreshAll();
            },
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
              itemCount: vehicles.length,
              itemBuilder: (context, index) {
                final vehicle = vehicles[index];

                // KARTA POJAZDU + overlay z ikonką dziennika
                return Stack(
                  children: [
                    VehicleCardWidget(
                      vehicle: vehicle,
                      onTap: () {
                        context.pushNamed(AppRoutes.vehicleDetailsView, extra: vehicle).then((_) async {
                          await _refreshAll();
                        });
                      },
                      onLongPress: () => _confirmDeleteVehicle(vehicle),
                      isChecked: false,
                    ),
                    Positioned(
                      top: 10,
                      right: 12,
                      child: _logGlassIconButton(
                        onTap: () {
                          // Przejście do dziennika konkretnego pojazdu
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => VehicleLogView(vehicleId: vehicle.id),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
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
    final disabled = _isFull;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // „Glass” chip także w pustym stanie
          _usageChip(),
          const SizedBox(height: 16),
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
              backgroundColor: MaterialStateProperty.all(
                disabled ? AppColors.blue.withOpacity(0.4) : AppColors.blue,
              ),
              foregroundColor: MaterialStateProperty.all(Colors.white),
              padding: MaterialStateProperty.all(const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
              shape: MaterialStateProperty.all(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            onPressed: disabled
                ? () => _snack("Garaż pełny (${_usedSlots}/${_limitSlots}). Zwiększ limit lub usuń pojazd.")
                : _handleAddPressed,
            child: Text(
              disabled ? "Garaż pełny" : "Dodaj nowy pojazd",
              style: TextStyle(color: Colors.grey.shade300, fontWeight: FontWeight.w600),
            ),
          ),
          if (disabled) ...[
            const SizedBox(height: 10),
            Text(
              "Limit osiągnięty (${_usedSlots}/${_limitSlots}).",
              style: TextStyle(color: Colors.redAccent.withOpacity(0.9)),
            ),
          ]
        ],
      ),
    );
  }
}
