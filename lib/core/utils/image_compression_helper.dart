import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class ImageCompressionHelper {
  /// Compress an image file to reduce its size for faster uploads and loading
  /// 
  /// [file] - The original image file
  /// [quality] - Compression quality (0-100), default 85. Lower = smaller file, lower quality
  /// [maxWidth] - Maximum width in pixels, default 1920
  /// [maxHeight] - Maximum height in pixels, default 1920
  /// 
  /// Returns compressed file or null if compression fails
  static Future<File?> compressImage(
    File file, {
    int quality = 85,
    int maxWidth = 1920,
    int maxHeight = 1920,
  }) async {
    try {
      // Get temp directory for storing compressed image
      final tempDir = await getTemporaryDirectory();
      final targetPath = path.join(
        tempDir.path,
        'compressed_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      // Compress the image
      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: quality,
        minWidth: maxWidth,
        minHeight: maxHeight,
        format: CompressFormat.jpeg,
      );

      if (result == null) {
        debugPrint('Image compression failed');
        return null;
      }

      final originalSize = await file.length();
      final compressedSize = await result.length();
      final reductionPercent = ((1 - compressedSize / originalSize) * 100).toStringAsFixed(1);
      
      debugPrint('Image compressed: ${_formatBytes(originalSize)} → ${_formatBytes(compressedSize)} (${reductionPercent}% reduction)');

      return File(result.path);
    } catch (e) {
      debugPrint('Error compressing image: $e');
      return null;
    }
  }

  /// Format bytes to human-readable string
  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}
