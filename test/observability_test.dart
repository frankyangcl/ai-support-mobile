import 'package:ai_support_mobile/core/errors/api_exception.dart';
import 'package:ai_support_mobile/core/network/api_client.dart';
import 'package:ai_support_mobile/core/observability/crash_reporter.dart';
import 'package:ai_support_mobile/core/observability/error_reporting_policy.dart';
import 'package:ai_support_mobile/core/observability/firebase_observability.dart';
import 'package:ai_support_mobile/core/observability/remote_config_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('Firebase unavailable falls back without blocking core startup', () async {
    final services = await initializeObservability(initializer: () async => throw StateError('No Firebase configuration'));
    expect(services.firebaseAvailable, isFalse);
    expect(services.remoteConfig.settings.chatFeatureEnabled, isTrue);
    await services.analytics.logEvent('login_success');
  });

  test('Remote Config local defaults are safe', () {
    const settings = RemoteSettings();
    expect(settings.welcomeMessage, isNotEmpty);
    expect(settings.maxVisibleCitations, 5);
    expect(settings.chatFeatureEnabled, isTrue);
    expect(settings.maintenanceBanner, isEmpty);
  });

  test('Firebase service or Remote Config failure retains local fallback', () async {
    final services = await initializeObservability(initializer: () async {});
    expect(services.firebaseAvailable, isFalse);
    expect(services.remoteConfig.settings, isA<RemoteSettings>());
  });

  test('unexpected exception is reported but expected network error is not', () async {
    final reporter = RecordingCrashReporter();
    await reportIfUnexpected(reporter, StateError('parser bug'), StackTrace.current, reason: 'test');
    await reportIfUnexpected(reporter, const ApiException('offline', type: ApiErrorType.network), StackTrace.current, reason: 'test');
    expect(reporter.errors, hasLength(1));
    expect(reporter.errors.single, isA<StateError>());
  });

  test('401 invokes centralized auth-expired callback', () async {
    var expired = false;
    final client = ApiClient(baseUrl: 'https://api.test', client: MockClient((_) async => http.Response('{}', 401)), onUnauthorized: () => expired = true);
    await expectLater(client.getJson('/api/documents'), throwsA(isA<ApiException>()));
    expect(expired, isTrue);
  });
}

class RecordingCrashReporter implements CrashReporter {
  final errors = <Object>[];
  @override Future<void> recordUnexpected(Object error, StackTrace stack, {String? reason, bool fatal = false}) async => errors.add(error);
}
