import 'package:library_registration_app/core/platform/export_file_saver_stub.dart'
    if (dart.library.js_interop)
      'package:library_registration_app/core/platform/export_file_saver_web.dart'
    if (dart.library.io)
      'package:library_registration_app/core/platform/export_file_saver_io.dart';

Future<String> saveExportBytes(List<int> bytes, String fileName) {
  return saveExportBytesImpl(bytes, fileName);
}
