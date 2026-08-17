import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'analytics_service.dart';
import 'crash_reporter.dart';
import 'remote_config_service.dart';

final analyticsServiceProvider =
    Provider<AnalyticsService>((_) => const NoopAnalyticsService());
final crashReporterProvider =
    Provider<CrashReporter>((_) => const NoopCrashReporter());
final remoteConfigServiceProvider =
    Provider<RemoteConfigService>((_) => const LocalRemoteConfigService());
final remoteSettingsProvider = Provider<RemoteSettings>(
    (ref) => ref.watch(remoteConfigServiceProvider).settings);
