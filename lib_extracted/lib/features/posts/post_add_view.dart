import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:guide_me/features/posts/instagram_backend.dart';
import 'package:go_router/go_router.dart';
import 'package:guide_me/core/config/routing/app_routes.dart';

class PostAddView extends StatefulWidget {
  const PostAddView({Key? key}) : super(key: key);

  @override
  _PostAddViewState createState() => _PostAddViewState();
}

class _PostAddViewState extends State<PostAddView> {
  final TextEditingController _captionController = TextEditingController();
  File? _selectedImage;
  bool _isSubmitting = false;
  final ImagePicker _picker = ImagePicker();
  final supabase = Supabase.instance.client;

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _submitPost() async {
    final caption = _captionController.text.trim();
    if (caption.isEmpty || _selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Wypełnij wszystkie pola i wybierz zdjęcie")),
      );
      return;
    }
    setState(() {
      _isSubmitting = true;
    });
    try {
      final fileExt = _selectedImage!.path.split('.').last;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final filePath = 'posts/$fileName';
      final bytes = await _selectedImage!.readAsBytes();

      await supabase.storage.from('instaguide').uploadBinary(filePath, bytes);
      final publicUrl = supabase.storage.from('instaguide').getPublicUrl(filePath);

      await InstagramBackend.addPost(caption, publicUrl);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Post dodany")),
      );

      /// 🔁 Przekieruj do widoku z postami
      context.goNamed(AppRoutes.instagramPosty);

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Błąd: $e")),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Dodaj Post"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _selectedImage == null
                ? ElevatedButton(
                    onPressed: _pickImage,
                    child: const Text("Wybierz zdjęcie"),
                  )
                : Column(
                    children: [
                      Image.file(
                        _selectedImage!,
                        height: 200,
                      ),
                      ElevatedButton(
                        onPressed: _pickImage,
                        child: const Text("Zmień zdjęcie"),
                      ),
                    ],
                  ),
            const SizedBox(height: 16),
            TextField(
              controller: _captionController,
              decoration: const InputDecoration(
                labelText: "Opis posta",
              ),
            ),
            const SizedBox(height: 32),
            _isSubmitting
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _submitPost,
                    child: const Text("Dodaj post"),
                  ),
          ],
        ),
      ),
    );
  }
}
