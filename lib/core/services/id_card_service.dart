import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:library_registration_app/core/config/app_config.dart';
import 'package:library_registration_app/domain/entities/student.dart';

class IdCardPayload {
  const IdCardPayload({
    required this.token,
    required this.issuedAt,
    required this.verificationUri,
  });

  final String token;
  final DateTime issuedAt;
  final Uri verificationUri;

  String get qrData => verificationUri.toString();
}

class IdCardService {
  static IdCardPayload generate(Student student, {DateTime? issuedAt, String? token}) {
    final resolvedToken = token?.trim() ?? '';
    if (resolvedToken.isEmpty) {
      throw StateError('Student does not have an ID card token yet.');
    }
    final issued = (issuedAt ?? DateTime.now()).toUtc();

    final params = <String, String>{
      'tok': resolvedToken,
    };

    final base = AppConfig.idCardVerificationBaseUrl.trim();
    Uri uri;
    if (base.isNotEmpty) {
      try {
        final baseUri = Uri.parse(base);
        // If someone configured a base URL that already contains query/fragment
        // (e.g. `https://host/#/dashboard`), strip them so we don't generate
        // broken URLs like `/verify-card?...#/dashboard`.
        final cleanBaseUri = baseUri.replace(
          fragment: '',
          queryParameters: const <String, String>{},
        );
        // Append /verify-card path to the base URL (don't replace it)
        final currentPath = cleanBaseUri.path;
        final basePath = currentPath.endsWith('/verify-card')
            ? currentPath
            : (currentPath.endsWith('/') ? '${currentPath}verify-card' : '$currentPath/verify-card');
        uri = cleanBaseUri.replace(path: basePath, queryParameters: params);
      } catch (_) {
        uri = kIsWeb
            ? Uri.parse(Uri.base.origin).replace(path: '/verify-card', queryParameters: params)
            : Uri(path: '/verify-card', queryParameters: params);
      }
    } else {
      // For web builds, fall back to the current origin so QR/links are absolute.
      if (kIsWeb) {
        uri = Uri.parse(Uri.base.origin).replace(path: '/verify-card', queryParameters: params);
      } else {
        uri = Uri(path: '/verify-card', queryParameters: params);
      }
    }

    return IdCardPayload(
      token: resolvedToken,
      issuedAt: issued,
      verificationUri: uri,
    );
  }
}
