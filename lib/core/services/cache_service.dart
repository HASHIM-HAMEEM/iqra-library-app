import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class CacheService {
  CacheService({this.maxEntries = 300, this.namespace = 'v1'});

  final int maxEntries;
  final String namespace;

  Directory? _cacheDir;

  Future<Directory> _getCacheDir() async {
    if (_cacheDir != null) return _cacheDir!;
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'cache'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _cacheDir = dir;
    return dir;
  }

  String _sanitizeKey(String key) =>
      key.replaceAll(RegExp('[^A-Za-z0-9_.-]'), '_');

  Future<File> _fileForKey(String key) async {
    final dir = await _getCacheDir();
    final name = _sanitizeKey('$namespace-$key');
    return File(p.join(dir.path, '$name.json'));
  }

  Future<Map<String, dynamic>?> _readRaw(String key) async {
    try {
      final f = await _fileForKey(key);
      if (!await f.exists()) return null;
      final content = await f.readAsString();
      return json.decode(content) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeRaw(String key, Map<String, dynamic> payload) async {
    final f = await _fileForKey(key);
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(json.encode(payload), flush: true);
    await tmp.rename(f.path);
    await _pruneIfNeeded();
  }

  Future<void> invalidate(String key) async {
    try {
      final f = await _fileForKey(key);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  Future<void> clearAll() async {
    try {
      final dir = await _getCacheDir();
      if (await dir.exists()) {
        await for (final e in dir.list()) {
          try {
            await e.delete(recursive: true);
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  Future<void> clearByPrefix(String prefix) async {
    try {
      final dir = await _getCacheDir();
      if (!await dir.exists()) return;
      final sanitized = _sanitizeKey('$namespace-$prefix');
      await for (final e in dir.list()) {
        if (e is File) {
          final name = p.basename(e.path);
          if (name.startsWith(sanitized)) {
            try {
              await e.delete();
            } catch (_) {}
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _pruneIfNeeded() async {
    try {
      final dir = await _getCacheDir();
      final files = await dir.list().toList();
      final jsonFiles = files
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList();
      if (jsonFiles.length <= maxEntries) return;
      jsonFiles.sort(
        (a, b) => a.statSync().modified.compareTo(b.statSync().modified),
      );
      final toDelete = jsonFiles.length - maxEntries;
      for (var i = 0; i < toDelete; i++) {
        try {
          await jsonFiles[i].delete();
        } catch (_) {}
      }
    } catch (_) {}
  }

  Future<List<T>?> getListStale<T>({
    required String key,
    required T Function(Map<String, dynamic>) fromJson,
  }) async {
    final raw = await _readRaw(key);
    if (raw == null) return null;
    final data = (raw['data'] as List<dynamic>? ?? <dynamic>[]);
    return data.map((e) => fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<T?> getItemStale<T>({
    required String key,
    required T Function(Map<String, dynamic>) fromJson,
  }) async {
    final raw = await _readRaw(key);
    if (raw == null) return null;
    final data = raw['data'] as Map<String, dynamic>?;
    if (data == null) return null;
    return fromJson(data);
  }

  Future<List<T>?> getList<T>({
    required String key,
    required Duration maxAge,
    required T Function(Map<String, dynamic>) fromJson,
  }) async {
    final raw = await _readRaw(key);
    if (raw == null) return null;
    try {
      final ts = DateTime.parse(raw['timestamp'] as String);
      if (DateTime.now().difference(ts) > maxAge) return null;
    } catch (_) {
      return null;
    }
    final data = (raw['data'] as List<dynamic>? ?? <dynamic>[]);
    return data.map((e) => fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> setList<T>({
    required String key,
    required List<T> data,
    required Map<String, dynamic> Function(T) toJson,
  }) async {
    final serialized = data.map(toJson).toList();
    await _writeRaw(key, {
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'data': serialized,
    });
  }

  Future<T?> getItem<T>({
    required String key,
    required Duration maxAge,
    required T Function(Map<String, dynamic>) fromJson,
  }) async {
    final raw = await _readRaw(key);
    if (raw == null) return null;
    try {
      final ts = DateTime.parse(raw['timestamp'] as String);
      if (DateTime.now().difference(ts) > maxAge) return null;
    } catch (_) {
      return null;
    }
    final data = raw['data'] as Map<String, dynamic>?;
    if (data == null) return null;
    return fromJson(data);
  }

  Future<void> setItem<T>({
    required String key,
    required T data,
    required Map<String, dynamic> Function(T) toJson,
  }) async {
    await _writeRaw(key, {
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'data': toJson(data),
    });
  }
}
