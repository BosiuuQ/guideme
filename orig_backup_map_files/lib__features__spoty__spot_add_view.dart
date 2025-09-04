import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:geocoding/geocoding.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'spoty_backend.dart';

class SpotAddView extends StatefulWidget {
  const SpotAddView({super.key});

  @override
  State<SpotAddView> createState() => _SpotAddViewState();
}

class _SpotAddViewState extends State<SpotAddView> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController titleCtrl = TextEditingController();
  final TextEditingController descCtrl = TextEditingController();
  final TextEditingController locationCtrl = TextEditingController();
  final TextEditingController startCtrl = TextEditingController();
  final TextEditingController endCtrl = TextEditingController();
  final TextEditingController rulesCtrl = TextEditingController();

  String visibility = 'Publiczna';
  File? _selectedImage;
  LatLng? selectedLatLng;

  final List<String> eventCategories = [
    'Chill', 'Motoryzacyjny', 'Zdjęciowy', 'Klubowy', 'Zlot tematyczny', 'Inne'
  ];
  String selectedCategory = 'Chill';

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _selectedImage = File(picked.path));
  }

  Future<void> _selectLocationOnMap() async {
    final pos = await Geolocator.getCurrentPosition();
    selectedLatLng = LatLng(pos.latitude, pos.longitude);
    try {
      final placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      final placemark = placemarks.first;
      final address =
          "${placemark.locality ?? ''}, ${placemark.street ?? ''} ${placemark.subThoroughfare ?? ''} (${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)})";
      setState(() => locationCtrl.text = address);
    } catch (_) {
      setState(() => locationCtrl.text = "(${pos.latitude}, ${pos.longitude})");
    }
  }

  Future<void> _selectDateTime(TextEditingController controller) async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: DateTime(now.year + 1),
    );
    if (pickedDate == null) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (pickedTime == null) return;

    final dt = DateTime(pickedDate.year, pickedDate.month, pickedDate.day,
        pickedTime.hour, pickedTime.minute);

    controller.text = DateFormat('yyyy-MM-dd HH:mm').format(dt);
  }

  Future<void> _submitSpot() async {
    if (!_formKey.currentState!.validate() || _selectedImage == null || selectedLatLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Wypełnij wszystkie pola i wybierz zdjęcie')));
      return;
    }

    try {
      debugPrint("🔁 Dodawanie spotu...");

      final start = DateFormat('yyyy-MM-dd HH:mm').parse(startCtrl.text);
      final end = DateFormat('yyyy-MM-dd HH:mm').parse(endCtrl.text);
      final duration = end.difference(start);

      if (duration.inMinutes <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⛔ Czas zakończenia musi być po rozpoczęciu')));
        return;
      }

      debugPrint("🕓 Start: $start");
      debugPrint("🕓 End: $end");
      debugPrint("⏱️ Czas trwania: ${duration.inMinutes} min");

      final fileBytes = await _selectedImage!.readAsBytes();
      final fileName = 'spot_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final storageResponse = await Supabase.instance.client.storage
          .from('spoty')
          .uploadBinary(fileName, fileBytes, fileOptions: const FileOptions(upsert: true));

      final imageUrl = Supabase.instance.client.storage
          .from('spoty')
          .getPublicUrl(fileName);

      debugPrint("✅ Zdjęcie przesłane: $imageUrl");

      final success = await SpotyBackend.addSpot(
        tytul: titleCtrl.text,
        opis: descCtrl.text,
        lokalizacja: locationCtrl.text,
        lat: selectedLatLng!.latitude,
        lng: selectedLatLng!.longitude,
        widocznosc: visibility == 'Publiczna' ? 'publiczna' : 'tylko_znajomi',
        data: start.toUtc(),
        czasTrwania: duration,
        typ: selectedCategory,
        zasady: rulesCtrl.text,
        zdjecieUrl: imageUrl,
      );

      if (success && context.mounted) {
        debugPrint("✅ Spot dodany!");
        Navigator.pop(context);
      } else {
        debugPrint("❌ Błąd dodawania spotu.");
      }
    } catch (e) {
      debugPrint("❌ Błąd: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Błąd: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C0F1C),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text("Dodaj Spot", style: TextStyle(color: Colors.white)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildTextField(titleCtrl, "Tytuł"),
              _buildTextField(descCtrl, "Opis", maxLines: 3),
              _buildTextField(locationCtrl, "Lokalizacja"),
              TextButton.icon(
                onPressed: _selectLocationOnMap,
                icon: const Icon(Icons.map, color: Colors.cyanAccent),
                label: const Text("Wybierz na mapie", style: TextStyle(color: Colors.cyanAccent)),
              ),
              _buildDropdown(),
              _buildDateTimePickers(),
              _buildCategoryDropdown(),
              _buildTextField(rulesCtrl, "Zasady", maxLines: 2),
              if (_selectedImage != null)
                Image.file(_selectedImage!, height: 120, fit: BoxFit.cover),
              TextButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.photo, color: Colors.cyanAccent),
                label: const Text("Wybierz zdjęcie", style: TextStyle(color: Colors.cyanAccent)),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _submitSpot,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyanAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
                child: const Text("Dodaj Spot", style: TextStyle(fontSize: 16)),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateTimePickers() {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: startCtrl,
            readOnly: true,
            onTap: () => _selectDateTime(startCtrl),
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration("Data startowa"),
            validator: (val) => val == null || val.isEmpty ? "Wybierz datę" : null,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextFormField(
            controller: endCtrl,
            readOnly: true,
            onTap: () => _selectDateTime(endCtrl),
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration("Data zakończenia"),
            validator: (val) => val == null || val.isEmpty ? "Wybierz czas" : null,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white),
        decoration: _inputDecoration(label),
        validator: (value) => value == null || value.isEmpty ? "Pole wymagane" : null,
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      filled: true,
      fillColor: const Color(0xFF1A1D2E),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    );
  }

  Widget _buildDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: visibility,
        decoration: _inputDecoration("Widoczność"),
        dropdownColor: const Color(0xFF1A1D2E),
        style: const TextStyle(color: Colors.white),
        items: const [
          DropdownMenuItem(value: 'Publiczna', child: Text("Publiczna")),
          DropdownMenuItem(value: 'Tylko dla znajomych', child: Text("Tylko dla znajomych")),
        ],
        onChanged: (val) => setState(() => visibility = val!),
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: selectedCategory,
        decoration: _inputDecoration("Kategoria wydarzenia"),
        dropdownColor: const Color(0xFF1A1D2E),
        style: const TextStyle(color: Colors.white),
        items: eventCategories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
        onChanged: (val) => setState(() => selectedCategory = val!),
      ),
    );
  }
}
