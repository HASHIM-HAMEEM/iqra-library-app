import 'package:drift/drift.dart';
import 'package:drift/web.dart';

/// Web database connection using IndexedDB
Future<QueryExecutor> openConnection() async {
  return WebDatabase.withStorage(
    await DriftWebStorage.indexedDbIfSupported('library_registration_db'),
  );
}
