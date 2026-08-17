class RemoteSettings {
  const RemoteSettings(
      {this.welcomeMessage = defaultWelcomeMessage,
      this.maxVisibleCitations = 5,
      this.chatFeatureEnabled = true,
      this.maintenanceBanner = ''});
  static const defaultWelcomeMessage =
      'Hi! Ask me anything about your company documents.';
  final String welcomeMessage;
  final int maxVisibleCitations;
  final bool chatFeatureEnabled;
  final String maintenanceBanner;
}

abstract interface class RemoteConfigService {
  RemoteSettings get settings;
  Future<void> fetch();
}

class LocalRemoteConfigService implements RemoteConfigService {
  const LocalRemoteConfigService([this.settings = const RemoteSettings()]);
  @override
  final RemoteSettings settings;
  @override
  Future<void> fetch() async {}
}
