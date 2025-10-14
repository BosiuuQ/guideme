import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import 'package:guide_me/features/viewpoint/domain/entity/viewpoint.dart';
import 'package:guide_me/features/viewpoint/viewpoint_backend.dart';

// NOWE: helper do cropa
import 'image_cropper_helper.dart';

class ViewpointAddView extends StatefulWidget {
  const ViewpointAddView({super.key});

  @override
  State<ViewpointAddView> createState() => _ViewpointAddViewState();
}

class _ViewpointAddViewState extends State<ViewpointAddView> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  File? _imageFile;
  bool _isLoading = false;
  bool _acceptedRules = false;

  // ---- BACK HANDLER ----
  Future<bool> _handleBack() async {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return false;
    }
    if (mounted) {
      context.go('/mainView/viewpointView');
    }
    return false;
  }

  // ---- PICK IMAGE + CROP ----
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 95,
      maxWidth: 4096,
    );
    if (picked == null) return;

    final original = File(picked.path);

    // od razu proponujemy przycięcie
    final cropped = await ImageCropperHelper.crop(file: original);
    setState(() {
      _imageFile = cropped ?? original;
    });
  }

  Future<void> _cropCurrentImage() async {
    if (_imageFile == null) return;
    final cropped = await ImageCropperHelper.crop(file: _imageFile!);
    if (cropped != null) {
      setState(() {
        _imageFile = cropped;
      });
    }
  }

  // ---- LOCATION ----
  Future<MapPoint> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return const MapPoint(x: 0.0, y: 0.0);

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          return const MapPoint(x: 0.0, y: 0.0);
        }
      }

      final position = await Geolocator.getCurrentPosition();
      return MapPoint(x: position.longitude, y: position.latitude);
    } catch (_) {
      return const MapPoint(x: 0.0, y: 0.0);
    }
  }

  // ---- ZASADY ----
  Future<void> _showRulesSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black87,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              16 + MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Center(
                    child: SizedBox(
                      width: 44,
                      height: 5,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.all(Radius.circular(999)),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Zasady dodawania punktów',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '• Motoryzacja na pierwszym planie, ale inne tematy są OK, byle w klimacie społeczności.\n'
                    '• Szacunek i zero spamu – bez wyzwisk, nękania, floodu, clickbaitu.\n'
                    '• Twoje treści – publikuj tylko materiały, do których masz prawa/zgody.\n'
                    '• Prywatność – nie ujawniaj danych osobowych; zamazuj twarze bez zgody.\n'
                    '• Bezpieczeństwo – nie promuj nielegalnych/brawurowych zachowań; jeśli teren prywatny/tor – zaznacz to w opisie.\n'
                    '• Treści wrażliwe – bez drastyki; edukacyjne materiały oznacz ostrzeżeniem.\n'
                    '• Reklamy i sprzedaż – oznacz #reklama / #współpraca; zakaz nielegalnych ofert.\n'
                    '• Lokalizacje – nie podawaj dokładnych adresów prywatnych (garaże, domy).\n'
                    '• Moderacja – treści niezgodne mogą być ukryte/usunięte; powtarzające się naruszenia = blokada.\n'
                    '• Zgłaszanie – ••• → Zgłoś (spam/nienawiść/bezpieczeństwo/prawa aut.).',
                    style: TextStyle(color: Colors.white70, height: 1.4),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ---- SUBMIT ----
  Future<void> _submit() async {
    if (!_acceptedRules) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Zaznacz akceptację zasad społeczności.")),
      );
      return;
    }

    if (!_formKey.currentState!.validate() || _imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Uzupełnij wszystkie pola i wybierz zdjęcie.")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception("Nie jesteś zalogowany.");

      final canAdd = await ViewpointBackend.canAddViewpoint(user.id);
      if (!canAdd) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Limit: Można dodać tylko jeden punkt na godzinę.")),
        );
        return;
      }

      final fileName = 'viewpoint_${const Uuid().v4()}.jpg';
      final coordinates = await _getCurrentLocation();

      final viewpoint = Viewpoint(
        id: '',
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        imageUrl: '',
        likes: 0,
        rating: 0,
        creatorId: user.id,
        coordinates: coordinates,
        address: '',
        isFavourite: false,
      );

      await ViewpointBackend.addViewpoint(viewpoint, _imageFile!, fileName);

      if (!mounted) return;
      context.go('/mainView/viewpointView');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Dodano nowy punkt widokowy!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Błąd: ${e.toString()}")),
      );
    }

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const bgStart = Color(0xFF0C0F1C);
    const bgEnd = Color(0xFF0A1F2E);

    final canSubmit = !_isLoading &&
        _acceptedRules &&
        _imageFile != null &&
        _titleController.text.trim().isNotEmpty &&
        _descriptionController.text.trim().isNotEmpty;

    return WillPopScope(
      onWillPop: _handleBack,
      child: Scaffold(
        backgroundColor: bgStart,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          leading: IconButton(
            tooltip: 'Wstecz',
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70),
            onPressed: _handleBack,
          ),
          title: const Text("Dodaj punkt widokowy", style: TextStyle(color: Colors.white)),
          actions: [
            IconButton(
              tooltip: 'Zasady',
              icon: const Icon(Icons.rule, color: Colors.white70),
              onPressed: _showRulesSheet,
            ),
          ],
        ),
        body: Stack(
          children: [
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
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: Column(
                  children: [
                    // Karta obrazu
                    InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: _pickImage,
                      child: Ink(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withOpacity(0.08)),
                        ),
                        child: _imageFile == null
                            ? Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                                    ),
                                    child: const Icon(Icons.add_a_photo_rounded,
                                        size: 42, color: Colors.white70),
                                  ),
                                  const SizedBox(height: 10),
                                  const Text(
                                    'Dodaj zdjęcie punktu',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Pokaż klimat miejsca.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.65),
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.file(
                                      _imageFile!,
                                      height: 230,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton.icon(
                                        onPressed: _cropCurrentImage,
                                        icon: const Icon(Icons.crop),
                                        label: const Text('Przytnij'),
                                      ),
                                      const SizedBox(width: 8),
                                      TextButton.icon(
                                        onPressed: _pickImage,
                                        icon: const Icon(Icons.swap_horiz_rounded),
                                        label: const Text('Zmień zdjęcie'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Formularz (tytuł + opis)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.08)),
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _titleController,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: "Tytuł",
                                labelStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
                                hintText: "Nazwa miejsca / punktu",
                                hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                                border: InputBorder.none,
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Wpisz tytuł' : null,
                              onChanged: (_) => setState(() {}),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _descriptionController,
                              style: const TextStyle(color: Colors.white),
                              maxLines: 4,
                              minLines: 3,
                              decoration: InputDecoration(
                                labelText: "Opis",
                                labelStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
                                hintText: "Co warto wiedzieć? Jak dojechać? Tor/spot/prywatny teren?",
                                hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                                border: InputBorder.none,
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Wpisz opis' : null,
                              onChanged: (_) => setState(() {}),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Mini zasady + checkbox
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.035),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.08)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Mini-zasady',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              )),
                          const SizedBox(height: 8),
                          Text(
                            '• Szacunek, zero spamu i clickbaitu\n'
                            '• Twoje treści – miej prawa/zgody\n'
                            '• Prywatność – zamazuj twarze\n'
                            '• Bezpieczeństwo – nie promuj łamania prawa',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              height: 1.35,
                              fontSize: 12.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: _showRulesSheet,
                              icon: const Icon(Icons.rule, size: 18),
                              label: const Text('Pełne zasady'),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Checkbox(
                                value: _acceptedRules,
                                onChanged: (v) => setState(() => _acceptedRules = v ?? false),
                                activeColor: Colors.lightBlueAccent,
                              ),
                              const Expanded(
                                child: Text(
                                  'Potwierdzam zgodność z zasadami i prawa do treści.',
                                  style: TextStyle(color: Colors.white70, fontSize: 12.5),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Submit
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: canSubmit ? _submit : null,
                        icon: _isLoading
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.add_location_alt_rounded),
                        label: const Text('Dodaj punkt'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
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
      ),
    );
  }
}
