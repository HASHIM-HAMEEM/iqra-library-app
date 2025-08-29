import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// Exception thrown when image is too large to be uploaded.
///
/// This exception is raised when an image file exceeds the maximum allowed size
/// limit of 1MB, which is enforced to optimize storage and bandwidth usage.
class ImageTooLargeException implements Exception {
  /// Actual size of the image file in bytes
  final int actualSizeBytes;

  /// Maximum allowed size in bytes (1MB)
  final int maxSizeBytes;

  /// Creates a new ImageTooLargeException with the given file sizes
  ImageTooLargeException(this.actualSizeBytes, this.maxSizeBytes);

  /// Human-readable error message with formatted file sizes
  String get message => 'Image size (${_formatBytes(actualSizeBytes)}) exceeds maximum allowed size (${_formatBytes(maxSizeBytes)})';

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
/// stay within acceptable size limits (1MB maximum) while maintaining good quality.
/// It uses the flutter_image_compress package for efficient compression.
///
/// Features:
/// - Automatic compression to reduce file size
/// - Quality-based compression (starts at 80%, falls back to 60%)
/// - Size validation with clear error messages
/// - Support for both File and Uint8List inputs
/// - Progressive compression with multiple quality levels
class ImageCompressionService {
  /// Maximum allowed file size in bytes (1MB)
  static const int maxFileSizeBytes = 1024 * 1024;

  /// Maximum allowed file size in MB (for display purposes)
  static const int maxFileSizeMB = 1;

  /// Compresses an image file to reduce its size while maintaining quality.
  ///
  /// This method applies progressive compression starting with 80% quality,
  /// then falls back to 60% quality if the result is still too large.
  /// The compressed image is saved to the temporary directory.
  ///
  /// Parameters:
  /// - [imageFile]: The original image file to compress
  ///
  /// Returns:
  /// - A Future<File> containing the compressed image
  ///
  /// Throws:
  /// - [ImageTooLargeException] if the compressed image is still over 1MB
  static Future<File> compressImage(File imageFile) async {
    // First check original file size
    final originalSize = await imageFile.length();
    if (originalSize <= maxFileSizeBytes) {
      return imageFile; // No compression needed
    }

    // Get temporary directory for compressed file
    final tempDir = await getTemporaryDirectory();
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_compressed.jpg';
    final targetPath = path.join(tempDir.path, fileName);

    try {
      // Compress the image
      final compressedBytes = await FlutterImageCompress.compressWithFile(
        imageFile.absolute.path,
        quality: 80, // Start with 80% quality
        minWidth: 800, // Max width
        minHeight: 800, // Max height
        format: CompressFormat.jpeg,
      );

      if (compressedBytes == null) {
        throw ImageTooLargeException(originalSize, maxFileSizeBytes);
      }

      // If still too large, try with lower quality
      if (compressedBytes.length > maxFileSizeBytes) {
        final moreCompressedBytes = await FlutterImageCompress.compressWithFile(
          imageFile.absolute.path,
          quality: 60, // Lower quality
          minWidth: 600, // Smaller dimensions
          minHeight: 600,
          format: CompressFormat.jpeg,
        );

        if (moreCompressedBytes == null || moreCompressedBytes.length > maxFileSizeBytes) {
          throw ImageTooLargeException(
            moreCompressedBytes?.length ?? compressedBytes.length,
            maxFileSizeBytes
          );
        }

        // Write the more compressed version
        final compressedFile = File(targetPath);
        await compressedFile.writeAsBytes(moreCompressedBytes);
        return compressedFile;
      }

      // Write the compressed version
      final compressedFile = File(targetPath);
      await compressedFile.writeAsBytes(compressedBytes);
      return compressedFile;

    } catch (e) {
      if (e is ImageTooLargeException) {
        rethrow;
      }
      // If compression fails, check if original is still acceptable
      if (originalSize <= maxFileSizeBytes) {
        return imageFile;
      }
      throw ImageTooLargeException(originalSize, maxFileSizeBytes);
    }
  }

  /// Compresses image data (Uint8List) to reduce size
  /// Returns compressed data or throws ImageTooLargeException if still too large
  static Future<Uint8List> compressImageData(Uint8List imageData) async {
    if (imageData.length <= maxFileSizeBytes) {
      return imageData; // No compression needed
    }

    try {
      // Compress the image data
      final compressedBytes = await FlutterImageCompress.compressWithList(
        imageData,
        quality: 80, // Start with 80% quality
        minWidth: 800, // Max width
        minHeight: 800, // Max height
        format: CompressFormat.jpeg,
      );

      if (compressedBytes.isEmpty) {
        throw ImageTooLargeException(imageData.length, maxFileSizeBytes);
      }

      // If still too large, try with lower quality
      if (compressedBytes.length > maxFileSizeBytes) {
        final moreCompressedBytes = await FlutterImageCompress.compressWithList(
          imageData,
          quality: 60, // Lower quality
          minWidth: 600, // Smaller dimensions
          minHeight: 600,
          format: CompressFormat.jpeg,
        );

        if (moreCompressedBytes.isEmpty || moreCompressedBytes.length > maxFileSizeBytes) {
          throw ImageTooLargeException(
            moreCompressedBytes.isNotEmpty ? moreCompressedBytes.length : compressedBytes.length,
            maxFileSizeBytes
          );
        }

        return moreCompressedBytes;
      }

      return compressedBytes;

    } catch (e) {
      if (e is ImageTooLargeException) {
        rethrow;
      }
      // If compression fails, check if original is still acceptable
      if (imageData.length <= maxFileSizeBytes) {
        return imageData;
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
