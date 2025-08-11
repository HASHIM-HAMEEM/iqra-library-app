import 'package:drift/drift.dart';

/// Base connection interface for different platforms
Future<QueryExecutor> openConnection() async {
  throw UnsupportedError(
    'No suitable database implementation was found on this platform. '
    'Make sure that you have imported the correct drift package for your platform.',
  );
}
