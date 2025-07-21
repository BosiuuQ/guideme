import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import 'package:guide_me/features/viewpoint/domain/entity/viewpoint.dart';
import 'package:guide_me/features/viewpoint/viewpoint_backend.dart';
import 'package:guide_me/core/config/routing/app_routes.dart';

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

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _imageFile = File(picked.path);
      });
    }
  }

  Future<MapPoint> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return const MapPoint(x: 0.0, y: 0.0);

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
          return const MapPoint(x: 0.0, y: 0.0);
        }
      }

      final position = await Geolocator.getCurrentPosition();
      return MapPoint(x: position.longitude, y: position.latitude);
    } catch (_) {
      return const MapPoint(x: 0.0, y: 0.0);
    }
  }

  Future<void> _submit() async {
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

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Dodaj punkt widokowy")),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              if (_imageFile != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12.0),
                  child: Image.file(
                    _imageFile!,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.image),
                label: const Text("Wybierz zdjęcie"),
              ),
              const SizedBox(height: 16),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(labelText: "Tytuł"),
                      validator: (value) => value == null || value.isEmpty ? 'Wpisz tytuł' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: "Opis"),
                      validator: (value) => value == null || value.isEmpty ? 'Wpisz opis' : null,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      child: _isLoading
                          ? const CircularProgressIndicator()
                          : const Text("Dodaj punkt"),
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
