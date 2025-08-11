import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

/// Native database connection for mobile and desktop platforms
Future<QueryExecutor> openConnection() async {
  // Ensure sqlite3 is properly initialized on mobile platforms
  if (Platform.isAndroid) {
    await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
  }

  // Get the application documents directory
  final dbFolder = await getApplicationDocumentsDirectory();
  final file = File(p.join(dbFolder.path, 'library_registration.db'));

  // Configure SQLite with required extensions
  return NativeDatabase.createInBackground(
    file,
    setup: (database) {
      // Enable foreign key constraints
      database.execute('PRAGMA foreign_keys = ON;');

      // Enable WAL mode for better performance
      database.execute('PRAGMA journal_mode = WAL;');

      // Set synchronous mode to NORMAL for better performance
      database.execute('PRAGMA synchronous = NORMAL;');

      // Set cache size (negative value means KB)
      database.execute('PRAGMA cache_size = -2000;');

      // Set temp store to memory
      database.execute('PRAGMA temp_store = MEMORY;');
    },
  );
}
