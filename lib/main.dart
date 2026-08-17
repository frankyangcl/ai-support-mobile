import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/observability/crash_reporter.dart';
import 'core/observability/firebase_observability.dart';
import 'core/observability/observability_providers.dart';

Future<void> main() async {
  CrashReporter reporter = const NoopCrashReporter();
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    final services = await initializeObservability();
    reporter = services.crashReporter;
    FlutterError.onError = (details) {
      if (kDebugMode) FlutterError.presentError(details);
      unawaited(reporter.recordUnexpected(
          details.exception, details.stack ?? StackTrace.current,
          reason: 'Flutter framework error', fatal: true));
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      unawaited(reporter.recordUnexpected(error, stack,
          reason: 'Uncaught platform error', fatal: true));
      return true;
    };
    runApp(ProviderScope(overrides: [
      analyticsServiceProvider.overrideWithValue(services.analytics),
      crashReporterProvider.overrideWithValue(services.crashReporter),
      remoteConfigServiceProvider.overrideWithValue(services.remoteConfig),
    ], child: const AISupportApp()));
  }, (error, stack) {
    if (kDebugMode) debugPrint('Unexpected application error: $error');
    unawaited(reporter.recordUnexpected(error, stack,
        reason: 'Uncaught zone error', fatal: true));
  });
}
