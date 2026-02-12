import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;

/// Exception thrown when image is too large to be uploaded.
///
/// This exception is raised when an image exceeds the maximum allowed size
/// limit of 300KB, which is enforced to minimize Supabase storage usage.
class ImageTooLargeException implements Exception {
  ImageTooLargeException(this.actualSizeBytes, this.maxSizeBytes);

  /// Actual size of the image data in bytes.
  final int actualSizeBytes;

  /// Maximum allowed size in bytes (300KB).
  final int maxSizeBytes;

  String get message =>
      'Image size (${_formatBytes(actualSizeBytes)}) exceeds maximum allowed '
      'size (${_formatBytes(maxSizeBytes)})';

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
    return '${(bytes / (1024 * 1024)).round()} MB';
  }

  @override
  String toString() => message;
}

/// Service for compressing and validating images before upload.
class ImageCompressionService {
  // Keep profile photos reasonably small for storage and fast loads.
  static const int maxFileSizeBytes = 1024 * 1024; // 1MB
  static const int maxFileSizeKB = 1024;
  static const int maxFileSizeMB = 1;

  static const int targetWidth = 400;
  static const int targetHeight = 400;
  static const int highQuality = 70;
  static const int mediumQuality = 50;
  static const int lowQuality = 35;

  static Future<Uint8List> compressImageData(Uint8List imageData) async {
    if (imageData.isEmpty) return imageData;

    // If already within limit, keep as-is to avoid quality loss.
    if (imageData.length <= maxFileSizeBytes) return imageData;

    // Web: `flutter_image_compress` isn't available. Use pure Dart compression.
    if (kIsWeb) {
      return _compressWithImagePackage(imageData);
    }

    // Non-web: try native compression first, fall back to pure Dart if needed.
    try {
      final attempts = <({int quality, int minSize})>[
        (quality: highQuality, minSize: targetWidth),
        (quality: mediumQuality, minSize: 320),
        (quality: lowQuality, minSize: 240),
      ];

      Uint8List? last;
      for (final a in attempts) {
        final out = await FlutterImageCompress.compressWithList(
          imageData,
          quality: a.quality,
          minWidth: a.minSize,
          minHeight: a.minSize,
        );
        if (out.isEmpty) continue;
        last = out;
        if (out.length <= maxFileSizeBytes) return out;
      }

      // If we managed to compress but it's still too big, throw a size error.
      if (last != null && last.isNotEmpty) {
        throw ImageTooLargeException(last.length, maxFileSizeBytes);
      }
    } on MissingPluginException {
      // Fall through to pure Dart.
    } catch (_) {
      // Fall through to pure Dart.
    }

    return _compressWithImagePackage(imageData);
  }

  static bool validateImageSizeBytes(Uint8List imageData) {
    return imageData.length <= maxFileSizeBytes;
  }

  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
    return '${(bytes / (1024 * 1024)).round()} MB';
  }

  static String detectFileExtension(Uint8List bytes, {String fallback = 'jpg'}) {
    if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xD8) {
      return 'jpg';
    }
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'png';
    }
    return fallback;
  }

  static String mimeTypeForExtension(String extension) {
    final ext = extension.toLowerCase().replaceAll('.', '').trim();
    return switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      _ => 'application/octet-stream',
    };
  }

  static Future<Uint8List> _compressWithImagePackage(Uint8List imageData) async {
    final decoded = img.decodeImage(imageData);
    if (decoded == null) {
      // Unknown format; allow it if it already fits.
      if (imageData.length <= maxFileSizeBytes) return imageData;
      throw ImageTooLargeException(imageData.length, maxFileSizeBytes);
    }

    final oriented = img.bakeOrientation(decoded);

    final attempts = <({int maxDim, int quality})>[
      (maxDim: 400, quality: 75),
      (maxDim: 320, quality: 60),
      (maxDim: 240, quality: 45),
      (maxDim: 200, quality: 35),
    ];

    Uint8List? last;
    for (final a in attempts) {
      final resized = _resizeToMax(oriented, a.maxDim);
      final encoded = img.encodeJpg(resized, quality: a.quality);
      final out = Uint8List.fromList(encoded);
      last = out;
      if (out.length <= maxFileSizeBytes) return out;
    }

    throw ImageTooLargeException(last?.length ?? imageData.length, maxFileSizeBytes);
  }

  static img.Image _resizeToMax(img.Image input, int maxDim) {
    final maxSide = math.max(input.width, input.height);
    if (maxSide <= maxDim) return input;
    final scale = maxDim / maxSide;
    final w = math.max(1, (input.width * scale).round());
    final h = math.max(1, (input.height * scale).round());
    return img.copyResize(
      input,
      width: w,
      height: h,
      interpolation: img.Interpolation.average,
    );
  }
}
