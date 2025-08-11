import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:csv/csv.dart';
import 'package:drift/drift.dart';
import 'package:library_registration_app/data/database/app_database.dart';
import 'package:library_registration_app/data/database/dao/activity_logs_dao.dart';
import 'package:library_registration_app/data/database/dao/app_settings_dao.dart';
import 'package:library_registration_app/data/database/dao/students_dao.dart';
import 'package:library_registration_app/data/database/dao/subscriptions_dao.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

enum ImportMode { merge, overwrite }

enum DuplicatePolicy { skip, replace }

class BackupProgress {
  const BackupProgress({
    required this.stage,
    required this.current,
    required this.total,
  });
  final String stage;
  final int current;
  final int total;
}

class BackupResult {
  const BackupResult({
    required this.filePath,
    required this.bytes,
    required this.counts,
    required this.hashes,
  });
  final String filePath;
  final int bytes;
  final Map<String, int> counts;
  final Map<String, String> hashes;
}

class ImportOptions { // e.g., {"students","subscriptions","activity_logs","app_settings"}
  const ImportOptions({
    this.mode = ImportMode.merge,
    this.duplicatePolicy = DuplicatePolicy.skip,
    this.tables,
  });
  final ImportMode mode;
  final DuplicatePolicy duplicatePolicy;
  final Set<String>?
  tables;
}

class ImportResult {
  const ImportResult({
    required this.inserted,
    required this.updated,
    required this.skipped,
  });
  final Map<String, int> inserted;
  final Map<String, int> updated;
  final Map<String, int> skipped;
}

class BackupService {

  BackupService({
    required this.db,
    required this.appSettingsDao,
    required this.studentsDao,
    required this.subscriptionsDao,
    required this.activityLogsDao,
  });
  final AppDatabase db;
  final AppSettingsDao appSettingsDao;
  final StudentsDao studentsDao;
  final SubscriptionsDao subscriptionsDao;
  final ActivityLogsDao activityLogsDao;

  static const _format = 'library-registration-app-backup';
  static const _formatVersion = 1;

  // Export all data + media to a portable zip file
  Future<BackupResult> exportBackup({
    bool includeMedia = true,
    void Function(BackupProgress progress)? onProgress,
  }) async {
    final uuid = const Uuid().v4();
    final tmpRoot = await _createTempDir('backup_$uuid');
    final dataDir = Directory(p.join(tmpRoot.path, 'data'))
      ..createSync(recursive: true);
    final mediaDir = Directory(p.join(tmpRoot.path, 'media'))
      ..createSync(recursive: true);
    Directory(
      p.join(mediaDir.path, 'profile_images'),
    ).createSync(recursive: true);

    // Fetch data
    final students = await studentsDao.getAllStudents();
    final subs = await subscriptionsDao.getAllSubscriptions();
    final logs = await activityLogsDao.getAllActivityLogs();
    final settings = await appSettingsDao.exportSettings();

    onProgress?.call(
      const BackupProgress(stage: 'collect', current: 1, total: 5),
    );

    // Copy media and build mapping of studentId -> relative path
    final studentImageRelPaths = <String, String>{};
    if (includeMedia) {
      for (final s in students) {
        final path = s.profileImagePath;
        if (path != null && path.isNotEmpty) {
          final src = File(path);
          if (await src.exists()) {
            final destName = 'student_${s.id}_${p.basename(path)}';
            final rel = p.posix.join('media', 'profile_images', destName);
            final dest = File(p.join(tmpRoot.path, rel));
            dest.parent.createSync(recursive: true);
            await src.copy(dest.path);
            studentImageRelPaths[s.id] = rel;
          }
        }
      }
    }

    onProgress?.call(
      const BackupProgress(stage: 'serialize', current: 2, total: 5),
    );

    // Write JSON files (streaming where possible)
    final studentsJson = File(p.join(dataDir.path, 'students.json'));
    await _writeJsonArray<StudentData>(
      studentsJson,
      students,
      (s) =>
          _studentToJson(s, includeMedia ? studentImageRelPaths[s.id] : null),
    );

    final subsJson = File(p.join(dataDir.path, 'subscriptions.json'));
    await _writeJsonArray<SubscriptionData>(
      subsJson,
      subs,
      _subscriptionToJson,
    );

    final logsJson = File(p.join(dataDir.path, 'activity_logs.json'));
    await _writeJsonArray<ActivityLogData>(logsJson, logs, _activityLogToJson);

    final settingsJson = File(p.join(dataDir.path, 'app_settings.json'));
    await settingsJson.writeAsString(jsonEncode(settings));

    // Additionally export CSV files for Excel compatibility
    final studentsCsv = File(p.join(dataDir.path, 'students.csv'));
    final subsCsv = File(p.join(dataDir.path, 'subscriptions.csv'));
    final logsCsv = File(p.join(dataDir.path, 'activity_logs.csv'));
    await _writeStudentsCsv(studentsCsv, students);
    await _writeSubscriptionsCsv(subsCsv, subs);
    await _writeActivityLogsCsv(logsCsv, logs);

    // Build metadata
    final meta = {
      'format': _format,
      'formatVersion': _formatVersion,
      'schemaVersion': db.schemaVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'mediaIncluded': includeMedia,
      'counts': {
        'students': students.length,
        'subscriptions': subs.length,
        'activity_logs': logs.length,
        'app_settings': (settings as Map).length,
      },
      'hashes': <String, String>{
        'students.json': await _sha256OfFile(studentsJson),
        'subscriptions.json': await _sha256OfFile(subsJson),
        'activity_logs.json': await _sha256OfFile(logsJson),
        'app_settings.json': await _sha256OfFile(settingsJson),
        // CSV hashes (best-effort)
        'students.csv': await _sha256OfFile(studentsCsv),
        'subscriptions.csv': await _sha256OfFile(subsCsv),
        'activity_logs.csv': await _sha256OfFile(logsCsv),
      },
    };

    final metaJson = File(p.join(tmpRoot.path, 'metadata.json'));
    await metaJson.writeAsString(jsonEncode(meta));

    onProgress?.call(
      const BackupProgress(stage: 'archive', current: 3, total: 5),
    );

    // Create final zip in app documents directory under backups/
    final appDocs = await getApplicationDocumentsDirectory();
    final backupsDir = Directory(p.join(appDocs.path, 'backups'))
      ..createSync(recursive: true);
    final ts = _timestampString(DateTime.now());
    final zipPath = p.join(backupsDir.path, 'backup_$ts.zip');

    final encoder = ZipFileEncoder();
    encoder.create(zipPath);
    // Add contents of tmpRoot but not the root folder itself
    encoder.addDirectory(Directory(tmpRoot.path), includeDirName: false);
    encoder.close();

    onProgress?.call(
      const BackupProgress(stage: 'cleanup', current: 4, total: 5),
    );

    // Cleanup temp directory
    await tmpRoot.delete(recursive: true);

    final bytes = await File(zipPath).length();

    onProgress?.call(const BackupProgress(stage: 'done', current: 5, total: 5));

    // Log activity
    await _logBackupAction(
      action: 'export',
      details: {'filePath': zipPath, 'bytes': bytes, 'counts': meta['counts']},
    );

    return BackupResult(
      filePath: zipPath,
      bytes: bytes,
      counts: Map<String, int>.from(meta['counts']! as Map),
      hashes: Map<String, String>.from(meta['hashes']! as Map),
    );
  }

  // Import backup from a zip file
  Future<ImportResult> importBackup(
    String backupZipPath, {
    ImportOptions options = const ImportOptions(),
    void Function(BackupProgress progress)? onProgress,
  }) async {
    final allowed =
        options.tables ??
        {'students', 'subscriptions', 'activity_logs', 'app_settings'};

    if (!await File(backupZipPath).exists()) {
      throw ArgumentError('Backup file not found: $backupZipPath');
    }

    final uuid = const Uuid().v4();
    final extractRoot = await _createTempDir('import_$uuid');

    // Extract zip to temp
    onProgress?.call(
      const BackupProgress(stage: 'extract', current: 1, total: 5),
    );
    extractFileToDisk(backupZipPath, extractRoot.path);

    // Read metadata
    final metaFile = File(p.join(extractRoot.path, 'metadata.json'));
    if (!await metaFile.exists()) {
      throw StateError('Invalid backup: metadata.json missing');
    }
    final meta =
        jsonDecode(await metaFile.readAsString()) as Map<String, dynamic>;
    if (meta['format'] != _format) {
      throw StateError('Invalid backup format: ${meta['format']}');
    }
    final formatVersion = (meta['formatVersion'] as num?)?.toInt() ?? 0;
    if (formatVersion != _formatVersion) {
      // Basic compatibility check; allow future minor changes if needed
      // For now, require exact match
      throw StateError('Unsupported backup format version: $formatVersion');
    }
    final schemaVersionInBackup =
        (meta['schemaVersion'] as num?)?.toInt() ?? db.schemaVersion;
    if (schemaVersionInBackup > db.schemaVersion) {
      throw StateError(
        'Backup schema ($schemaVersionInBackup) is newer than app schema (${db.schemaVersion}). Please update the app.',
      );
    }

    onProgress?.call(
      const BackupProgress(stage: 'parse', current: 2, total: 5),
    );

    // Load data files
    final dataDir = Directory(p.join(extractRoot.path, 'data'));
    final settingsJson = File(p.join(dataDir.path, 'app_settings.json'));
    final studentsJson = File(p.join(dataDir.path, 'students.json'));
    final subsJson = File(p.join(dataDir.path, 'subscriptions.json'));
    final logsJson = File(p.join(dataDir.path, 'activity_logs.json'));

    var settings = <String, dynamic>{};
    var students = <dynamic>[];
    var subs = <dynamic>[];
    var logs = <dynamic>[];

    if (await settingsJson.exists()) {
      settings =
          jsonDecode(await settingsJson.readAsString()) as Map<String, dynamic>;
    }
    if (await studentsJson.exists()) {
      students = jsonDecode(await studentsJson.readAsString()) as List<dynamic>;
    }
    if (await subsJson.exists()) {
      subs = jsonDecode(await subsJson.readAsString()) as List<dynamic>;
    }
    if (await logsJson.exists()) {
      logs = jsonDecode(await logsJson.readAsString()) as List<dynamic>;
    }

    // Prepare media extraction path
    final appDocs = await getApplicationDocumentsDirectory();
    final profileImagesDir = Directory(p.join(appDocs.path, 'profile_images'))
      ..createSync(recursive: true);

    final createdFiles = <File>[]; // For cleanup on failure

    // Results
    final inserted = <String, int>{
      'students': 0,
      'subscriptions': 0,
      'activity_logs': 0,
      'app_settings': 0,
    };
    final updated = <String, int>{
      'students': 0,
      'subscriptions': 0,
      'activity_logs': 0,
      'app_settings': 0,
    };
    final skipped = <String, int>{
      'students': 0,
      'subscriptions': 0,
      'activity_logs': 0,
      'app_settings': 0,
    };

    onProgress?.call(
      const BackupProgress(stage: 'import', current: 3, total: 5),
    );

    try {
      await db.transaction(() async {
        // Overwrite mode: clear tables first
        if (options.mode == ImportMode.overwrite) {
          if (allowed.contains('subscriptions')) {
            await db.delete(db.subscriptionsTable).go();
          }
          if (allowed.contains('students')) {
            await db.delete(db.studentsTable).go();
          }
          if (allowed.contains('activity_logs')) {
            await db.delete(db.activityLogsTable).go();
          }
          if (allowed.contains('app_settings')) {
            await db.delete(db.appSettingsTable).go();
          }
        }

        // Import app settings first
        if (allowed.contains('app_settings') && settings.isNotEmpty) {
          await appSettingsDao.importSettings(settings);
          inserted['app_settings'] = settings.length;
        }

        // Import students (with media restore)
        if (allowed.contains('students')) {
          for (final raw in students) {
            final m = Map<String, dynamic>.from(raw as Map);

            // Restore media path if relative in backup
            final profilePath = m['profileImagePath'] as String?;
            if (profilePath != null && profilePath.startsWith('media/')) {
              final src = File(p.join(extractRoot.path, profilePath));
              if (await src.exists()) {
                final destName =
                    'student_${m['id']}_${p.basename(profilePath)}';
                final dest = File(p.join(profileImagesDir.path, destName));
                await dest.parent.create(recursive: true);
                await src.copy(dest.path);
                createdFiles.add(dest);
                m['profileImagePath'] = dest.path;
              } else {
                // If media missing, null out the path to avoid broken references
                m['profileImagePath'] = null;
              }
            }

            final companion = StudentsTableCompanion(
              id: Value(m['id'] as String),
              firstName: Value(m['firstName'] as String),
              lastName: Value(m['lastName'] as String),
              dateOfBirth: Value(DateTime.parse(m['dateOfBirth'] as String)),
              email: Value(m['email'] as String),
              phone: Value(m['phone'] as String?),
              address: Value(m['address'] as String?),
              profileImagePath: Value(m['profileImagePath'] as String?),
              subscriptionPlan: Value(m['subscriptionPlan'] as String?),
              subscriptionStartDate: Value(
                _parseNullableDate(m['subscriptionStartDate']),
              ),
              subscriptionEndDate: Value(
                _parseNullableDate(m['subscriptionEndDate']),
              ),
              subscriptionAmount: Value(
                (m['subscriptionAmount'] as num?)?.toDouble(),
              ),
              subscriptionStatus: Value(m['subscriptionStatus'] as String?),
              createdAt: Value(DateTime.parse(m['createdAt'] as String)),
              updatedAt: Value(DateTime.parse(m['updatedAt'] as String)),
              isDeleted: Value(m['isDeleted'] as bool? ?? false),
            );

            try {
              if (options.duplicatePolicy == DuplicatePolicy.replace ||
                  options.mode == ImportMode.overwrite) {
                await db
                    .into(db.studentsTable)
                    .insert(companion, mode: InsertMode.insertOrReplace);
                updated['students'] =
                    (updated['students'] ?? 0) + 1; // treat as upsert
              } else {
                await db.into(db.studentsTable).insert(companion);
                inserted['students'] = (inserted['students'] ?? 0) + 1;
              }
            } on Exception {
              // Likely a uniqueness constraint; skip
              skipped['students'] = (skipped['students'] ?? 0) + 1;
            }
          }
        }

        // Import subscriptions
        if (allowed.contains('subscriptions')) {
          for (final raw in subs) {
            final m = Map<String, dynamic>.from(raw as Map);
            final companion = SubscriptionsTableCompanion(
              id: Value(m['id'] as String),
              studentId: Value(m['studentId'] as String),
              planName: Value(m['planName'] as String),
              startDate: Value(DateTime.parse(m['startDate'] as String)),
              endDate: Value(_parseNullableDate(m['endDate'])),
              amount: Value((m['amount'] as num).toDouble()),
              status: Value(m['status'] as String),
              createdAt: Value(DateTime.parse(m['createdAt'] as String)),
              updatedAt: Value(DateTime.parse(m['updatedAt'] as String)),
            );

            try {
              if (options.duplicatePolicy == DuplicatePolicy.replace ||
                  options.mode == ImportMode.overwrite) {
                await db
                    .into(db.subscriptionsTable)
                    .insert(companion, mode: InsertMode.insertOrReplace);
                updated['subscriptions'] = (updated['subscriptions'] ?? 0) + 1;
              } else {
                await db.into(db.subscriptionsTable).insert(companion);
                inserted['subscriptions'] =
                    (inserted['subscriptions'] ?? 0) + 1;
              }
            } on Exception {
              skipped['subscriptions'] = (skipped['subscriptions'] ?? 0) + 1;
            }
          }
        }

        // Import activity logs
        if (allowed.contains('activity_logs')) {
          for (final raw in logs) {
            final m = Map<String, dynamic>.from(raw as Map);
            final companion = ActivityLogsTableCompanion(
              id: Value(m['id'] as String),
              action: Value(m['action'] as String),
              entityType: Value(m['entityType'] as String),
              entityId: Value(m['entityId'] as String?),
              details: Value(m['details']?.toString()),
              timestamp: Value(DateTime.parse(m['timestamp'] as String)),
              userId: Value(m['userId'] as String?),
            );

            try {
              if (options.duplicatePolicy == DuplicatePolicy.replace ||
                  options.mode == ImportMode.overwrite) {
                await db
                    .into(db.activityLogsTable)
                    .insert(companion, mode: InsertMode.insertOrReplace);
                updated['activity_logs'] = (updated['activity_logs'] ?? 0) + 1;
              } else {
                await db.into(db.activityLogsTable).insert(companion);
                inserted['activity_logs'] =
                    (inserted['activity_logs'] ?? 0) + 1;
              }
            } on Exception {
              skipped['activity_logs'] = (skipped['activity_logs'] ?? 0) + 1;
            }
          }
        }
      });

      onProgress?.call(
        const BackupProgress(stage: 'cleanup', current: 4, total: 5),
      );

      // Cleanup extracted temp
      await extractRoot.delete(recursive: true);

      // Log activity
      await _logBackupAction(
        action: 'import',
        details: {
          'filePath': backupZipPath,
          'inserted': inserted,
          'updated': updated,
          'skipped': skipped,
          'mode': options.mode.name,
          'duplicatePolicy': options.duplicatePolicy.name,
        },
      );

      onProgress?.call(
        const BackupProgress(stage: 'done', current: 5, total: 5),
      );

      return ImportResult(
        inserted: inserted,
        updated: updated,
        skipped: skipped,
      );
    } catch (e) {
      // Rollback any created files
      for (final f in createdFiles) {
        try {
          if (await f.exists()) await f.delete();
        } catch (_) {}
      }
      try {
        if (await extractRoot.exists()) {
          await extractRoot.delete(recursive: true);
        }
      } catch (_) {}
      rethrow;
    }
  }

  // Import from a single CSV file (students.csv, subscriptions.csv, or activity_logs.csv)
  Future<ImportResult> importCsv(
    String csvPath, {
    ImportOptions options = const ImportOptions(),
    void Function(BackupProgress progress)? onProgress,
  }) async {
    if (!await File(csvPath).exists()) {
      throw ArgumentError('CSV file not found: $csvPath');
    }
    final name = p.basename(csvPath).toLowerCase();
    final content = await File(csvPath).readAsString();
    final converter = CsvToListConverter(
      shouldParseNumbers: false,
      eol: '\n',
    );
    final rows = converter.convert(content);
    if (rows.isEmpty) {
      return const ImportResult(inserted: {}, updated: {}, skipped: {});
    }
    final headers = rows.first.map((e) => e.toString()).toList();
    final dataRows = rows.skip(1);

    // Helper to map a row to map using headers (case-insensitive)
    Map<String, String> rowToMap(List<dynamic> row) {
      final m = <String, String>{};
      for (int i = 0; i < headers.length && i < row.length; i++) {
        m[headers[i].toLowerCase()] = row[i]?.toString() ?? '';
      }
      return m;
    }

    final inserted = <String, int>{'students': 0, 'subscriptions': 0, 'activity_logs': 0};
    final updated = <String, int>{'students': 0, 'subscriptions': 0, 'activity_logs': 0};
    final skipped = <String, int>{'students': 0, 'subscriptions': 0, 'activity_logs': 0};

    onProgress?.call(const BackupProgress(stage: 'parse', current: 1, total: 3));

    await db.transaction(() async {
      if (name.contains('students')) {
        for (final r in dataRows) {
          final m = rowToMap(r);
          try {
            final companion = StudentsTableCompanion(
              id: Value(m['id'] ?? const Uuid().v4()),
              firstName: Value(m['firstname'] ?? ''),
              lastName: Value(m['lastname'] ?? ''),
              dateOfBirth: Value(_parseCsvDate(m['dateofbirth'])),
              email: Value(m['email'] ?? ''),
              phone: Value(_emptyToNull(m['phone'])),
              address: Value(_emptyToNull(m['address'])),
              profileImagePath: Value(_emptyToNull(m['profileimagepath'])),
              subscriptionPlan: Value(_emptyToNull(m['subscriptionplan'])),
              subscriptionStartDate: Value(_parseCsvDateOrNull(m['subscriptionstartdate'])),
              subscriptionEndDate: Value(_parseCsvDateOrNull(m['subscriptionenddate'])),
              subscriptionAmount: Value(_parseCsvDouble(m['subscriptionamount'])),
              subscriptionStatus: Value(_emptyToNull(m['subscriptionstatus'])),
              createdAt: Value(_parseCsvDate(m['createdat'])),
              updatedAt: Value(_parseCsvDate(m['updatedat'])),
              isDeleted: Value(_parseCsvBool(m['isdeleted'])),
            );
            if (options.duplicatePolicy == DuplicatePolicy.replace || options.mode == ImportMode.overwrite) {
              await db.into(db.studentsTable).insert(companion, mode: InsertMode.insertOrReplace);
              updated['students'] = (updated['students'] ?? 0) + 1;
            } else {
              await db.into(db.studentsTable).insert(companion);
              inserted['students'] = (inserted['students'] ?? 0) + 1;
            }
          } catch (_) {
            skipped['students'] = (skipped['students'] ?? 0) + 1;
          }
        }
      } else if (name.contains('subscriptions')) {
        for (final r in dataRows) {
          final m = rowToMap(r);
          try {
            final companion = SubscriptionsTableCompanion(
              id: Value(m['id'] ?? const Uuid().v4()),
              studentId: Value(m['studentid'] ?? ''),
              planName: Value(m['planname'] ?? ''),
              startDate: Value(_parseCsvDate(m['startdate'])),
              endDate: Value(_parseCsvDateOrNull(m['enddate'])),
              amount: Value(_parseCsvDouble(m['amount']) ?? 0),
              status: Value(m['status'] ?? ''),
              createdAt: Value(_parseCsvDate(m['createdat'])),
              updatedAt: Value(_parseCsvDate(m['updatedat'])),
            );
            if (options.duplicatePolicy == DuplicatePolicy.replace || options.mode == ImportMode.overwrite) {
              await db.into(db.subscriptionsTable).insert(companion, mode: InsertMode.insertOrReplace);
              updated['subscriptions'] = (updated['subscriptions'] ?? 0) + 1;
            } else {
              await db.into(db.subscriptionsTable).insert(companion);
              inserted['subscriptions'] = (inserted['subscriptions'] ?? 0) + 1;
            }
          } catch (_) {
            skipped['subscriptions'] = (skipped['subscriptions'] ?? 0) + 1;
          }
        }
      } else if (name.contains('activity_logs')) {
        for (final r in dataRows) {
          final m = rowToMap(r);
          try {
            final companion = ActivityLogsTableCompanion(
              id: Value(m['id'] ?? const Uuid().v4()),
              action: Value(m['action'] ?? ''),
              entityType: Value(m['entitytype'] ?? ''),
              entityId: Value(_emptyToNull(m['entityid'])),
              details: Value(_emptyToNull(m['details'])),
              timestamp: Value(_parseCsvDate(m['timestamp'])),
              userId: Value(_emptyToNull(m['userid'])),
            );
            if (options.duplicatePolicy == DuplicatePolicy.replace || options.mode == ImportMode.overwrite) {
              await db.into(db.activityLogsTable).insert(companion, mode: InsertMode.insertOrReplace);
              updated['activity_logs'] = (updated['activity_logs'] ?? 0) + 1;
            } else {
              await db.into(db.activityLogsTable).insert(companion);
              inserted['activity_logs'] = (inserted['activity_logs'] ?? 0) + 1;
            }
          } catch (_) {
            skipped['activity_logs'] = (skipped['activity_logs'] ?? 0) + 1;
          }
        }
      } else {
        throw StateError('Unsupported CSV file name: $name');
      }
    });

    onProgress?.call(const BackupProgress(stage: 'done', current: 3, total: 3));

    return ImportResult(inserted: inserted, updated: updated, skipped: skipped);
  }

  // ----- Helpers -----

  Future<Directory> _createTempDir(String name) async {
    final sysTmp = await getTemporaryDirectory();
    final dir = Directory(p.join(sysTmp.path, name));
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
    await dir.create(recursive: true);
    return dir;
  }

  Future<void> _writeStudentsCsv(File file, List<StudentData> students) async {
    final sink = file.openWrite();
    sink.writeln('id,firstName,lastName,dateOfBirth,email,phone,address,profileImagePath,createdAt,updatedAt,isDeleted,subscriptionPlan,subscriptionStartDate,subscriptionEndDate,subscriptionAmount,subscriptionStatus');
    for (final s in students) {
      sink.writeln([
        s.id,
        _csv(s.firstName),
        _csv(s.lastName),
        s.dateOfBirth.toIso8601String(),
        _csv(s.email),
        _csv(s.phone),
        _csv(s.address),
        _csv(s.profileImagePath),
        s.createdAt.toIso8601String(),
        s.updatedAt.toIso8601String(),
        s.isDeleted,
        _csv(s.subscriptionPlan),
        s.subscriptionStartDate?.toIso8601String() ?? '',
        s.subscriptionEndDate?.toIso8601String() ?? '',
        s.subscriptionAmount?.toString() ?? '',
        _csv(s.subscriptionStatus),
      ].join(','));
    }
    await sink.flush();
    await sink.close();
  }

  Future<void> _writeSubscriptionsCsv(File file, List<SubscriptionData> subs) async {
    final sink = file.openWrite();
    sink.writeln('id,studentId,planName,startDate,endDate,amount,status,createdAt,updatedAt');
    for (final s in subs) {
      sink.writeln([
        s.id,
        s.studentId,
        _csv(s.planName),
        s.startDate.toIso8601String(),
        s.endDate?.toIso8601String() ?? '',
        s.amount,
        s.status,
        s.createdAt.toIso8601String(),
        s.updatedAt.toIso8601String(),
      ].join(','));
    }
    await sink.flush();
    await sink.close();
  }

  Future<void> _writeActivityLogsCsv(File file, List<ActivityLogData> logs) async {
    final sink = file.openWrite();
    sink.writeln('id,action,entityType,entityId,details,timestamp,userId');
    for (final l in logs) {
      sink.writeln([
        l.id,
        _csv(l.action),
        _csv(l.entityType),
        _csv(l.entityId),
        _csv(l.details),
        l.timestamp.toIso8601String(),
        _csv(l.userId),
      ].join(','));
    }
    await sink.flush();
    await sink.close();
  }

  String _csv(String? v) {
    if (v == null) return '';
    final escaped = v.replaceAll('"', '""');
    if (escaped.contains(',') || escaped.contains('\n') || escaped.contains('\r')) {
      return '"$escaped"';
    }
    return escaped;
  }

  Future<void> _writeJsonArray<T>(
    File file,
    List<T> items,
    Map<String, dynamic> Function(T) toJson,
  ) async {
    final sink = file.openWrite();
    sink.write('[');
    for (var i = 0; i < items.length; i++) {
      final m = toJson(items[i]);
      sink.write(jsonEncode(m));
      if (i < items.length - 1) sink.write(',');
    }
    sink.write(']');
    await sink.flush();
    await sink.close();
  }

  Map<String, dynamic> _studentToJson(
    StudentData s,
    String? relativeProfilePath,
  ) {
    return {
      'id': s.id,
      'firstName': s.firstName,
      'lastName': s.lastName,
      'dateOfBirth': s.dateOfBirth.toIso8601String(),
      'email': s.email,
      'phone': s.phone,
      'address': s.address,
      'profileImagePath':
          relativeProfilePath, // relative in backup when media included
      'createdAt': s.createdAt.toIso8601String(),
      'updatedAt': s.updatedAt.toIso8601String(),
      'isDeleted': s.isDeleted,
      'subscriptionPlan': s.subscriptionPlan,
      'subscriptionStartDate': s.subscriptionStartDate?.toIso8601String(),
      'subscriptionEndDate': s.subscriptionEndDate?.toIso8601String(),
      'subscriptionAmount': s.subscriptionAmount,
      'subscriptionStatus': s.subscriptionStatus,
    };
  }

  Map<String, dynamic> _subscriptionToJson(SubscriptionData sub) {
    return {
      'id': sub.id,
      'studentId': sub.studentId,
      'planName': sub.planName,
      'startDate': sub.startDate.toIso8601String(),
      'endDate': sub.endDate?.toIso8601String(),
      'amount': sub.amount,
      'status': sub.status,
      'createdAt': sub.createdAt.toIso8601String(),
      'updatedAt': sub.updatedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> _activityLogToJson(ActivityLogData log) {
    return {
      'id': log.id,
      'action': log.action,
      'entityType': log.entityType,
      'entityId': log.entityId,
      'details': log.details,
      'timestamp': log.timestamp.toIso8601String(),
      'userId': log.userId,
    };
  }

  DateTime? _parseNullableDate(dynamic value) {
    if (value == null) return null;
    if (value is String && value.isEmpty) return null;
    return DateTime.parse(value as String);
  }

  String _timestampString(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    final ss = dt.second.toString().padLeft(2, '0');
    return '$y$m${d}_$hh$mm$ss';
  }

  Future<String> _sha256OfFile(File file) async {
    final bytes = await file.readAsBytes();
    return crypto.sha256.convert(bytes).toString();
  }

  Future<void> _logBackupAction({
    required String action,
    required Map<String, dynamic> details,
  }) async {
    try {
      await activityLogsDao.logActivity(
        id: const Uuid().v4(),
        action: action,
        entityType: 'backup',
        details: details,
      );
    } catch (_) {
      // Best-effort logging; ignore failures
    }
  }

  // CSV helpers
  DateTime _parseCsvDate(String? v) {
    if (v == null || v.isEmpty) return DateTime.fromMillisecondsSinceEpoch(0);
    return DateTime.parse(v);
  }

  DateTime? _parseCsvDateOrNull(String? v) {
    if (v == null || v.isEmpty) return null;
    return DateTime.parse(v);
  }

  double? _parseCsvDouble(String? v) {
    if (v == null || v.isEmpty) return null;
    return double.tryParse(v);
  }

  bool _parseCsvBool(String? v) {
    if (v == null || v.isEmpty) return false;
    final s = v.toLowerCase();
    return s == 'true' || s == '1' || s == 'yes';
  }

  String? _emptyToNull(String? v) => (v == null || v.isEmpty) ? null : v;
}
