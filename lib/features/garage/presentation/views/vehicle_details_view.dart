import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:guide_me/core/constants/app_assets.dart';
import 'package:guide_me/core/constants/app_colors.dart';
import 'package:guide_me/features/garage/domain/entity/vehicle.dart';
import 'package:guide_me/features/garage/garage_backend.dart';
import 'package:guide_me/features/garage/presentation/views/vehicle_log_view.dart';
import 'package:guide_me/features/garage/presentation/views/vehicle_edit_view.dart';
import 'package:guide_me/features/garage/presentation/widgets/vehicle_details_images_slider_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class VehicleDetailsView extends StatefulWidget {
  const VehicleDetailsView({super.key, required this.vehicle});
  final Vehicle vehicle;

  @override
  State<VehicleDetailsView> createState() => _VehicleDetailsViewState();
}

class _VehicleDetailsViewState extends State<VehicleDetailsView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _descriptionAnimationController =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
  bool _isDeleting = false;
  late Vehicle vehicle;

  @override
  void initState() {
    super.initState();
    vehicle = widget.vehicle;
  }

  @override
  void dispose() {
    _descriptionAnimationController.dispose();
    super.dispose();
  }

  Future<void> _fetchVehicleDetails() async {
    final response = await Supabase.instance.client
        .from('garaz')
        .select()
        .eq('id', vehicle.id)
        .single();

    setState(() {
      vehicle = Vehicle.fromMap(response); // upewnij się, że masz tę metodę w modelu
    });
  }

  void _showMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black87,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.menu_book_rounded, color: Colors.white),
            title: const Text('Dziennik pojazdu', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => VehicleLogView(vehicleId: vehicle.id),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.edit, color: Colors.white),
            title: const Text('Edytuj dane', style: TextStyle(color: Colors.white)),
            onTap: () async {
              Navigator.pop(context);
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => VehicleEditView(vehicle: vehicle),
                ),
              );

              if (result == true) {
                await _fetchVehicleDetails();
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
            title: const Text('Usuń pojazd', style: TextStyle(color: Colors.redAccent)),
            onTap: _confirmDelete,
          ),
        ],
      ),
    );
  }

  void _confirmDelete() {
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.black87,
        title: const Text('Usuń pojazd', style: TextStyle(color: Colors.white)),
        content: const Text('Czy na pewno chcesz usunąć ten pojazd?',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Anuluj', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: _isDeleting
                ? null
                : () async {
                    setState(() => _isDeleting = true);
                    Navigator.of(context).pop();
                    await GarageBackend.deleteVehicleWithLog(vehicle.id);
                    if (!mounted) return;
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Pojazd usunięty')),
                    );
                  },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: _isDeleting
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Usuń'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101935),
      appBar: AppBar(
        backgroundColor: const Color(0xFF101935),
        title: const Text("Szczegóły pojazdu"),
        actions: [
          IconButton(
            icon: const Icon(Icons.directions_car),
            onPressed: _showMenu,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              VehicleDetailsImagesSliderWidget(vehicle: vehicle),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: MediaQuery.sizeOf(context).width - 48.0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _mainInfoWidget(
                              icon: Image.asset(
                                AppAssets.speedometerIcon,
                                height: 24.0,
                                width: 24.0,
                                color: AppColors.lightBlue,
                              ),
                              title: "Moc",
                              description: "${vehicle.horsepower} KM",
                            ),
                            _mainInfoWidget(
                              icon: Image.asset(
                                AppAssets.engineIcon,
                                height: 24.0,
                                width: 24.0,
                                color: AppColors.lightBlue,
                              ),
                              title: "Pojemność\nskokowa",
                              description: "${vehicle.capacityCm3} cm³",
                            ),
                            _mainInfoWidget(
                              icon: const Icon(Icons.calendar_month_rounded,
                                  size: 24.0, color: Colors.white),
                              title: "Rok\nprodukcji",
                              description: "${vehicle.productionYear}",
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12.0).copyWith(top: 20.0),
                      child: Text(
                        "${vehicle.brand} ${vehicle.model}",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 22.0,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    _infoTileWidget(title: "Kolor", description: vehicle.color ?? '-'),
                    _divider(),
                    _infoTileWidget(title: "Rodzaj paliwa", description: vehicle.fuelType ?? '-'),
                    _divider(),
                    _infoTileWidget(title: "Skrzynia biegów", description: vehicle.gearbox ?? '-'),
                    _divider(),
                    _infoTileWidget(title: "Napęd", description: vehicle.drive ?? '-'),
                    _divider(),
                    _infoTileWidget(title: "Notka od właściciela", description: vehicle.note ?? '-'),
                  ],
                ).animate(
                  controller: _descriptionAnimationController,
                  effects: const [
                    FadeEffect(duration: Duration(milliseconds: 800)),
                    MoveEffect(duration: Duration(milliseconds: 500)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _divider() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 4.0),
      child: Divider(thickness: 0.5, indent: 4.0, endIndent: 4.0, color: Colors.white24),
    );
  }

  Widget _mainInfoWidget({
    required Widget icon,
    required String title,
    required String description,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        icon,
        const SizedBox(height: 4.0),
        Text(title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11.0, color: Colors.white70)),
        const SizedBox(height: 2.0),
        Text(description,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 13.0, color: Colors.white)),
      ],
    );
  }

  Widget _infoTileWidget({required String title, required String description}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 16.0, color: Colors.white)),
        Text(description,
            style: const TextStyle(fontSize: 14.0, color: Colors.white70)),
      ],
    );
  }
}
