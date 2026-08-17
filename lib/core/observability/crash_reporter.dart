abstract interface class CrashReporter {
  Future<void> recordUnexpected(Object error, StackTrace stack,
      {String? reason, bool fatal = false});
}

class NoopCrashReporter implements CrashReporter {
  const NoopCrashReporter();
  @override
  Future<void> recordUnexpected(Object error, StackTrace stack,
      {String? reason, bool fatal = false}) async {}
}
