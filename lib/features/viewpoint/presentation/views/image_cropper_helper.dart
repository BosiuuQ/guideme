// lib/features/viewpoint/presentation/views/image_cropper_helper.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';

class ImageCropperHelper {
  static Future<File?> crop({
    required File file,
    String title = 'Przytnij zdjęcie',
    int compressQuality = 92,
  }) async {
    final result = await ImageCropper().cropImage(
      sourcePath: file.path,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: compressQuality,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: title,
          // Kluczowe — unikamy “edge to edge”
          toolbarColor: const Color(0xFF0C0F1C),
          statusBarColor: const Color(0xFF0C0F1C),
          backgroundColor: const Color(0xFF000000),
          toolbarWidgetColor: Colors.white,            // ikony widoczne
          activeControlsWidgetColor: Colors.lightBlueAccent,
          lockAspectRatio: false,
          // opcjonalnie:
          // showCropGrid: true,
          // hideBottomControls: false,
        ),
        IOSUiSettings(
          title: title,
          aspectRatioLockEnabled: false,
          rotateButtonsHidden: false,
          resetAspectRatioEnabled: true,
        ),
      ],
    );

    if (result == null) return null;
    return File(result.path);
  }
}
