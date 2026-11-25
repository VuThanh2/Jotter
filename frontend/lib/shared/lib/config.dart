abstract final class AppConfig {
  /// Set with `--dart-define=API_URL=https://...` when building for a deployment.
  static const apiBaseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://localhost:5080',
  );

  static const searchDebounce = Duration(milliseconds: 300);
  static const autosaveDelay = Duration(milliseconds: 700);
}
