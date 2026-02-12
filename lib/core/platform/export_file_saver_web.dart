import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

Future<String> saveExportBytesImpl(List<int> bytes, String fileName) async {
  final uint8 = Uint8List.fromList(bytes);
  final blob = web.Blob(
    <JSUint8Array>[uint8.toJS].toJS,
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = fileName
    ..style.display = 'none';

  web.document.body?.appendChild(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
  return fileName;
}
