import 'dart:convert';

class CacheService {
  CacheService({this.maxEntries = 300, this.namespace = 'v1'});

  final int maxEntries;
  final String namespace;

  final Map<String, String> _entries = <String, String>{};

  String _sanitizeKey(String key) =>
      key.replaceAll(RegExp('[^A-Za-z0-9_.-]'), '_');

  String _fullKey(String key) => _sanitizeKey('$namespace-$key');

  Future<Map<String, dynamic>?> _readRaw(String key) async {
    final encoded = _entries[_fullKey(key)];
    if (encoded == null) return null;
    try {
      return json.decode(encoded) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeRaw(String key, Map<String, dynamic> payload) async {
    final fullKey = _fullKey(key);
    _entries[fullKey] = json.encode(payload);
    await _pruneIfNeeded();
  }

  Future<void> invalidate(String key) async {
    _entries.remove(_fullKey(key));
  }

  Future<void> clearAll() async {
    _entries.clear();
  }

  Future<void> clearByPrefix(String prefix) async {
    final fullPrefix = _fullKey(prefix);
    final keys = _entries.keys
        .where((k) => k.startsWith(fullPrefix))
        .toList(growable: false);
    for (final key in keys) {
      _entries.remove(key);
    }
  }

  Future<void> _pruneIfNeeded() async {
    if (_entries.length <= maxEntries) return;
    final toRemove = _entries.length - maxEntries;
    final keys = _entries.keys.take(toRemove).toList(growable: false);
    for (final key in keys) {
      _entries.remove(key);
    }
  }

  Future<List<T>?> getListStale<T>({
    required String key,
    required T Function(Map<String, dynamic>) fromJson,
  }) async {
    final raw = await _readRaw(key);
    if (raw == null) return null;
    final data = raw['data'] as List<dynamic>? ?? <dynamic>[];
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
    final data = raw['data'] as List<dynamic>? ?? <dynamic>[];
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
