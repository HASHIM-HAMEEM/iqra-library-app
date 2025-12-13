import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// Exception thrown when image is too large to be uploaded.
///
/// This exception is raised when an image file exceeds the maximum allowed size
/// limit of 300KB, which is enforced to minimize Supabase storage usage.
class ImageTooLargeException implements Exception {
  /// Actual size of the image file in bytes
  final int actualSizeBytes;

  /// Maximum allowed size in bytes (300KB)
  final int maxSizeBytes;

  /// Creates a new ImageTooLargeException with the given file sizes
  ImageTooLargeException(this.actualSizeBytes, this.maxSizeBytes);

  /// Human-readable error message with formatted file sizes
  String get message =>
      'Image size (${_formatBytes(actualSizeBytes)}) exceeds maximum allowed size (${_formatBytes(maxSizeBytes)})';

  /// Formats bytes into human-readable format (B, KB, MB)
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
    return '${(bytes / (1024 * 1024)).round()} MB';
  }

  @override
  String toString() => message;
}

/// Service for compressing and validating images before upload.
///
/// This service provides automatic image compression to ensure uploaded images
/// stay within acceptable size limits while minimizing Supabase storage usage.
/// It uses the flutter_image_compress package for efficient compression.
///
/// Features:
/// - ALWAYS compresses images to save storage space
/// - Aggressive quality reduction (50-70%) for smaller files
/// - Small dimensions (400x400) optimized for profile photos
/// - Maximum 300KB file size limit
/// - Progressive compression with multiple quality levels
class ImageCompressionService {
  /// Maximum allowed file size in bytes (300KB - aggressive limit for storage savings)
  static const int maxFileSizeBytes = 300 * 1024; // 300KB

  /// Maximum allowed file size in KB (for display purposes)
  static const int maxFileSizeKB = 300;

  /// Target dimensions for profile images (square, small for storage)
  static const int targetWidth = 400;
  static const int targetHeight = 400;

  /// Quality levels for progressive compression
  static const int highQuality = 70;
  static const int mediumQuality = 50;
  static const int lowQuality = 35;

  /// Maximum allowed file size in MB (for backward compatibility)
  static const int maxFileSizeMB = 1;

  /// Compresses an image file to reduce its size for minimal storage usage.
  ///
  /// This method ALWAYS compresses images regardless of original size to ensure
  /// consistent storage savings. It uses progressive quality reduction:
  /// - First try: 70% quality, 400x400
  /// - Second try: 50% quality, 300x300
  /// - Third try: 35% quality, 200x200
  ///
  /// Parameters:
  /// - [imageFile]: The original image file to compress
  ///
  /// Returns:
  /// - A Future<File> containing the compressed image
  ///
  /// Throws:
  /// - [ImageTooLargeException] if the compressed image is still over 300KB
  static Future<File> compressImage(File imageFile) async {
    final originalSize = await imageFile.length();

    // Get temporary directory for compressed file
    final tempDir = await getTemporaryDirectory();
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_compressed.jpg';
    final targetPath = path.join(tempDir.path, fileName);

    try {
      // First pass: 70% quality, 400x400
      var compressedBytes = await FlutterImageCompress.compressWithFile(
        imageFile.absolute.path,
        quality: highQuality,
        minWidth: targetWidth,
        minHeight: targetHeight,
        format: CompressFormat.jpeg,
      );

      if (compressedBytes == null) {
        throw ImageTooLargeException(originalSize, maxFileSizeBytes);
      }

      // Second pass if still too large: 50% quality, 300x300
      if (compressedBytes.length > maxFileSizeBytes) {
        compressedBytes = await FlutterImageCompress.compressWithFile(
          imageFile.absolute.path,
          quality: mediumQuality,
          minWidth: 300,
          minHeight: 300,
          format: CompressFormat.jpeg,
        );

        if (compressedBytes == null) {
          throw ImageTooLargeException(originalSize, maxFileSizeBytes);
        }
      }

      // Third pass if still too large: 35% quality, 200x200
      if (compressedBytes.length > maxFileSizeBytes) {
        compressedBytes = await FlutterImageCompress.compressWithFile(
          imageFile.absolute.path,
          quality: lowQuality,
          minWidth: 200,
          minHeight: 200,
          format: CompressFormat.jpeg,
        );

        if (compressedBytes == null ||
            compressedBytes.length > maxFileSizeBytes) {
          throw ImageTooLargeException(
            compressedBytes?.length ?? originalSize,
            maxFileSizeBytes,
          );
        }
      }

      // Write the compressed version
      final compressedFile = File(targetPath);
      await compressedFile.writeAsBytes(compressedBytes);
      return compressedFile;
    } catch (e) {
      if (e is ImageTooLargeException) {
        rethrow;
      }
      // If compression fails completely, throw exception
      throw ImageTooLargeException(originalSize, maxFileSizeBytes);
    }
  }

  /// Compresses image data (Uint8List) to reduce size.
  /// ALWAYS compresses for consistent storage savings.
  /// Returns compressed data or throws ImageTooLargeException if still too large.
  static Future<Uint8List> compressImageData(Uint8List imageData) async {
    try {
      // First pass: 70% quality, 400x400
      var compressedBytes = await FlutterImageCompress.compressWithList(
        imageData,
        quality: highQuality,
        minWidth: targetWidth,
        minHeight: targetHeight,
        format: CompressFormat.jpeg,
      );

      if (compressedBytes.isEmpty) {
        throw ImageTooLargeException(imageData.length, maxFileSizeBytes);
      }

      // Second pass if still too large: 50% quality, 300x300
      if (compressedBytes.length > maxFileSizeBytes) {
        compressedBytes = await FlutterImageCompress.compressWithList(
          imageData,
          quality: mediumQuality,
          minWidth: 300,
          minHeight: 300,
          format: CompressFormat.jpeg,
        );

        if (compressedBytes.isEmpty) {
          throw ImageTooLargeException(imageData.length, maxFileSizeBytes);
        }
      }

      // Third pass if still too large: 35% quality, 200x200
      if (compressedBytes.length > maxFileSizeBytes) {
        compressedBytes = await FlutterImageCompress.compressWithList(
          imageData,
          quality: lowQuality,
          minWidth: 200,
          minHeight: 200,
          format: CompressFormat.jpeg,
        );

        if (compressedBytes.isEmpty ||
            compressedBytes.length > maxFileSizeBytes) {
          throw ImageTooLargeException(
            compressedBytes.isNotEmpty
                ? compressedBytes.length
                : imageData.length,
            maxFileSizeBytes,
          );
        }
      }

      return compressedBytes;
    } catch (e) {
      if (e is ImageTooLargeException) {
        rethrow;
      }
      throw ImageTooLargeException(imageData.length, maxFileSizeBytes);
    }
  }

  /// Validates if an image file size is within acceptable limits
  static Future<bool> validateImageSize(File imageFile) async {
    final size = await imageFile.length();
    return size <= maxFileSizeBytes;
  }

  /// Gets formatted file size string
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
    return '${(bytes / (1024 * 1024)).round()} MB';
  }

  /// Gets the file size in MB
  static double getFileSizeInMB(int bytes) {
    return bytes / (1024 * 1024);
  }
}
