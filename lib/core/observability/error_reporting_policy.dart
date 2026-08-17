import '../errors/api_exception.dart';
import 'crash_reporter.dart';

Future<void> reportIfUnexpected(CrashReporter reporter, Object error, StackTrace stack, {required String reason}) async {
  if (error is ApiException && (error.type == ApiErrorType.network || error.type == ApiErrorType.timeout || error.statusCode == 401 || error.statusCode == 409)) return;
  try {
    await reporter.recordUnexpected(error, stack, reason: reason);
  } catch (_) {
    // Crash reporting is best effort and must never block a user action.
  }
}
