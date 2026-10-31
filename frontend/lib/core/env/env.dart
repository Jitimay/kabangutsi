/// Build-time configuration. Values come from `--dart-define`, never hard-coded
/// per environment.
///
///   flutter build web -t lib/main_customer.dart --dart-define=API_URL=http://host:8000 --dart-define=USE_MOCK=false
class Env {
  const Env({required this.apiUrl, required this.useMock});

  factory Env.fromDefines() => const Env(apiUrl: kApiUrl, useMock: kUseMock);

  static const kApiUrl = String.fromEnvironment('API_URL', defaultValue: 'http://localhost:8000');

  /// Compile-time constant so the mock backend is tree-shaken out of real builds.
  static const kUseMock = bool.fromEnvironment('USE_MOCK', defaultValue: false);

  /// Backend base URL, without trailing slash (REST lives under `/v1`).
  final String apiUrl;

  /// When true, repositories use mock implementations (until G1).
  final bool useMock;

  String get restBaseUrl => '$apiUrl/v1';

  String get wsBaseUrl => '${apiUrl.replaceFirst(RegExp('^http'), 'ws')}/v1/ws';
}
