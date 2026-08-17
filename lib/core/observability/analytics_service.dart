abstract interface class AnalyticsService {
  Future<void> logEvent(String name, {Map<String, Object>? parameters});
}

class NoopAnalyticsService implements AnalyticsService {
  const NoopAnalyticsService();
  @override
  Future<void> logEvent(String name, {Map<String, Object>? parameters}) async {}
}

extension BestEffortAnalytics on AnalyticsService {
  Future<void> track(String name, {Map<String, Object>? parameters}) async {
    try {
      await logEvent(name, parameters: parameters);
    } catch (_) {/* Observability must not block the product. */}
  }
}
