import 'package:flutter/material.dart';
import 'package:guide_me/features/garage/domain/entity/vehicle.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class VehicleEditView extends StatefulWidget {
  final Vehicle vehicle;

  const VehicleEditView({super.key, required this.vehicle});

  @override
  State<VehicleEditView> createState() => _VehicleEditViewState();
}

class _VehicleEditViewState extends State<VehicleEditView> {
  late final TextEditingController _brand;
  late final TextEditingController _model;
  late final TextEditingController _horsepower;
  late final TextEditingController _capacity;
  late final TextEditingController _year;
  late final TextEditingController _color;
  late final TextEditingController _fuel;
  late final TextEditingController _gearbox;
  late final TextEditingController _drive;
  late final TextEditingController _note;

  bool _loading = false;

  final supabase = Supabase.instance.client;

  @override
  void initState() {
    final v = widget.vehicle;
    _brand = TextEditingController(text: v.brand);
    _model = TextEditingController(text: v.model);
    _horsepower = TextEditingController(text: v.horsepower.toString());
    _capacity = TextEditingController(text: v.capacityCm3.toString());
    _year = TextEditingController(text: v.productionYear.toString());
    _color = TextEditingController(text: v.color);
    _fuel = TextEditingController(text: v.fuelType);
    _gearbox = TextEditingController(text: v.gearbox);
    _drive = TextEditingController(text: v.drive);
    _note = TextEditingController(text: v.note);
    super.initState();
  }

  @override
  void dispose() {
    _brand.dispose();
    _model.dispose();
    _horsepower.dispose();
    _capacity.dispose();
    _year.dispose();
    _color.dispose();
    _fuel.dispose();
    _gearbox.dispose();
    _drive.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _loading = true);

    final updated = widget.vehicle.copyWith(
      brand: _brand.text,
      model: _model.text,
      horsepower: int.tryParse(_horsepower.text) ?? 0,
      capacityCm3: int.tryParse(_capacity.text) ?? 0,
      productionYear: int.tryParse(_year.text) ?? 2000,
      color: _color.text,
      fuelType: _fuel.text,
      gearbox: _gearbox.text,
      drive: _drive.text,
      note: _note.text,
    );

    try {
      await supabase
          .from('garaz')
          .update({
            'brand': updated.brand,
            'model': updated.model,
            'horsepower': updated.horsepower,
            'capacity_cm3': updated.capacityCm3,
            'production_year': updated.productionYear,
            'color': updated.color,
            'fuel_type': updated.fuelType,
            'gearbox': updated.gearbox,
            'drive': updated.drive,
            'note': updated.note,
          })
          .eq('id', updated.id);

if (mounted) {
  Navigator.pop(context, true); // 👈 przekazuje, że zapisano
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('✅ Zaktualizowano dane pojazdu')),
  );
}    } catch (e) {
      print('❌ Błąd podczas aktualizacji: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Nie udało się zapisać zmian')),
        );
      }
    }

    setState(() => _loading = false);
  }

  Widget _buildField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white54),
          filled: true,
          fillColor: Colors.black26,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text("Edytuj pojazd")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildField("Marka", _brand),
            _buildField("Model", _model),
            _buildField("Moc (KM)", _horsepower),
            _buildField("Pojemność (cm3)", _capacity),
            _buildField("Rok produkcji", _year),
            _buildField("Kolor", _color),
            _buildField("Rodzaj paliwa", _fuel),
            _buildField("Skrzynia biegów", _gearbox),
            _buildField("Napęd", _drive),
            _buildField("Notatka", _note),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loading ? null : _save,
              child: _loading
                  ? const CircularProgressIndicator()
                  : const Text("Zapisz zmiany"),
            ),
          ],
        ),
      ),
    );
  }
}
