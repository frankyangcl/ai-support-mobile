import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';

import 'analytics_service.dart';
import 'crash_reporter.dart';
import 'remote_config_service.dart';

typedef FirebaseInitializer = Future<void> Function();

class ObservabilityServices {
  const ObservabilityServices(
      {required this.analytics,
      required this.crashReporter,
      required this.remoteConfig,
      required this.firebaseAvailable});
  final AnalyticsService analytics;
  final CrashReporter crashReporter;
  final RemoteConfigService remoteConfig;
  final bool firebaseAvailable;
}

Future<ObservabilityServices> initializeObservability(
    {FirebaseInitializer? initializer}) async {
  try {
    await (initializer ?? _initializeFirebase)();
    final remote = FirebaseRemoteConfigService(FirebaseRemoteConfig.instance);
    await remote.fetch();
    return ObservabilityServices(
      analytics: FirebaseAnalyticsService(FirebaseAnalytics.instance),
      crashReporter: FirebaseCrashReporter(FirebaseCrashlytics.instance),
      remoteConfig: remote,
      firebaseAvailable: true,
    );
  } catch (_) {
    return const ObservabilityServices(
      analytics: NoopAnalyticsService(),
      crashReporter: NoopCrashReporter(),
      remoteConfig: LocalRemoteConfigService(),
      firebaseAvailable: false,
    );
  }
}

Future<void> _initializeFirebase() async => Firebase.initializeApp();

class FirebaseAnalyticsService implements AnalyticsService {
  const FirebaseAnalyticsService(this._analytics);
  final FirebaseAnalytics _analytics;
  @override
  Future<void> logEvent(String name, {Map<String, Object>? parameters}) =>
      _analytics.logEvent(name: name, parameters: parameters);
}

class FirebaseCrashReporter implements CrashReporter {
  const FirebaseCrashReporter(this._crashlytics);
  final FirebaseCrashlytics _crashlytics;
  @override
  Future<void> recordUnexpected(Object error, StackTrace stack,
          {String? reason, bool fatal = false}) =>
      _crashlytics.recordError(error, stack, reason: reason, fatal: fatal);
}

class FirebaseRemoteConfigService implements RemoteConfigService {
  FirebaseRemoteConfigService(this._remoteConfig);
  final FirebaseRemoteConfig _remoteConfig;
  @override
  RemoteSettings get settings => RemoteSettings(
        welcomeMessage: _remoteConfig.getString('welcome_message'),
        maxVisibleCitations: _remoteConfig.getInt('max_visible_citations'),
        chatFeatureEnabled: _remoteConfig.getBool('chat_feature_enabled'),
        maintenanceBanner: _remoteConfig.getString('maintenance_banner'),
      );
  @override
  Future<void> fetch() async {
    await _remoteConfig.setDefaults(const {
      'welcome_message': RemoteSettings.defaultWelcomeMessage,
      'max_visible_citations': 5,
      'chat_feature_enabled': true,
      'maintenance_banner': '',
    });
    await _remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 5),
        minimumFetchInterval: const Duration(hours: 1)));
    try {
      await _remoteConfig.fetchAndActivate();
    } catch (_) {/* Local defaults remain active. */}
  }
}
