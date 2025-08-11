import 'package:flutter/foundation.dart';

/// Lightweight telemetry service with PII redaction and in-app diagnostics feed.
class TelemetryService {
  TelemetryService._internal();

  static final TelemetryService instance = TelemetryService._internal();

  /// In-memory diagnostics stream for optional developer overlay.
  final ValueNotifier<List<String>> _logFeed = ValueNotifier<List<String>>(<String>[]);
  ValueListenable<List<String>> get logFeed => _logFeed;

  /// Basic rate-limiting to avoid log spam.
  DateTime _lastEventTime = DateTime.fromMillisecondsSinceEpoch(0);
  int _eventsInWindow = 0;
  static const Duration _rateWindow = Duration(seconds: 2);
  static const int _maxEventsPerWindow = 50;

  void captureEvent({
    required String type,
    required String feature,
    Map<String, Object?> context = const {},
    bool developerOnly = false,
  }) {
    final now = DateTime.now();
    _applyRateLimit(now);
    if (_eventsInWindow >= _maxEventsPerWindow) return;
    _eventsInWindow++;

    final sanitized = _sanitizeContext(context);
    final line = '[EVENT] $type • $feature • ${now.toIso8601String()} • $sanitized';
    _append(line, developerOnly: developerOnly);
  }

  void captureException(
    Object error,
    StackTrace stack, {
    required String feature,
    Map<String, Object?> context = const {},
    bool developerOnly = true,
  }) {
    final now = DateTime.now();
    _applyRateLimit(now);
    if (_eventsInWindow >= _maxEventsPerWindow) return;
    _eventsInWindow++;

    final sanitized = _sanitizeContext(context);
    final summary = '[EXCEPTION] $feature • ${now.toIso8601String()} • $sanitized';
    _append(summary, developerOnly: developerOnly);
    // Always print to console in debug for developers.
    if (kDebugMode) {
      // ignore: avoid_print
      print('$summary\n$error\n$stack');
    }
    // Wire to Sentry/Crashlytics here when available.
  }

  void _append(String line, {required bool developerOnly}) {
    // In production, we still collect but avoid noisy prints; send to remote when wired.
    if (kDebugMode) {
      // ignore: avoid_print
      print(line);
    }
    final current = List<String>.from(_logFeed.value)..add(line);
    // Keep last 200 entries.
    if (current.length > 200) current.removeRange(0, current.length - 200);
    _logFeed.value = current;
  }

  void _applyRateLimit(DateTime now) {
    if (now.difference(_lastEventTime) > _rateWindow) {
      _lastEventTime = now;
      _eventsInWindow = 0;
    }
  }

  Map<String, Object?> _sanitizeContext(Map<String, Object?> context) {
    final Map<String, Object?> out = <String, Object?>{};
    for (final entry in context.entries) {
      final key = entry.key.toLowerCase();
      final value = entry.value;
      if (value == null) {
        out[entry.key] = null;
        continue;
      }
      if (_isPiiKey(key)) {
        out[entry.key] = _hash(value.toString());
      } else if (value is Map) {
        out[entry.key] = _sanitizeContext(value.cast<String, Object?>());
      } else if (value is Iterable) {
        out[entry.key] = value.map((e) => _hash(e.toString())).toList();
      } else {
        out[entry.key] = value;
      }
    }
    return out;
  }

  bool _isPiiKey(String key) {
    return key.contains('name') ||
        key.contains('email') ||
        key.contains('phone') ||
        key.contains('mobile') ||
        key.contains('whatsapp') ||
        key.contains('contact') ||
        key.contains('passport') ||
        key.contains('aadhaar') ||
        key.contains('nationalid') ||
        key == 'id' ||
        key.endsWith('_id') ||
        key.contains('address') ||
        key.contains('seatnumber') ||
        key.contains('studentid') ||
        key.contains('guardian');
  }

  String _hash(String input) {
    // Lightweight non-cryptographic hash for correlation without exposing PII.
    int hash = 0;
    for (int i = 0; i < input.length; i++) {
      hash = 0x1fffffff & (hash + input.codeUnitAt(i));
      hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
      hash ^= (hash >> 6);
    }
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    hash ^= (hash >> 11);
    hash = 0x1fffffff & (hash + ((0x000003ff & hash) << 15));
    return hash.toRadixString(16);
  }
}


