import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static Future<bool> ensureCameraPermission() async {
    if (Platform.isIOS) {
      final status = await Permission.camera.status;
      if (status.isGranted) return true;
      final result = await Permission.camera.request();
      return result.isGranted;
    } else {
      // Android
      final status = await Permission.camera.status;
      if (status.isGranted) return true;
      final result = await Permission.camera.request();
      return result.isGranted;
    }
  }

  static Future<bool> ensurePhotoLibraryPermission() async {
    if (Platform.isIOS) {
      final status = await Permission.photos.status;
      if (status.isGranted) return true;
      final result = await Permission.photos.request();
      return result.isGranted;
    } else {
      // Android 13+: READ_MEDIA_IMAGES, lower: READ_EXTERNAL_STORAGE
      final status = await Permission.photos.status;
      if (status.isGranted) return true;
      final result = await Permission.photos.request();
      return result.isGranted;
    }
  }
}
