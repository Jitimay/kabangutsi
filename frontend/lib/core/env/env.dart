/// Build-time configuration. Values come from `--dart-define`, never hard-coded
/// per environment.
///
///   flutter build web -t lib/main_customer.dart --dart-define=API_URL=http://host:8000
class Env {
  const Env({
    required this.apiUrl,
    required this.useMock,
  });

  factory Env.fromDefines() => const Env(
        apiUrl: String.fromEnvironment('API_URL', defaultValue: 'http://localhost:8000'),
        useMock: bool.fromEnvironment('USE_MOCK', defaultValue: true),
      );

  /// Backend base URL, without trailing slash (REST lives under `/v1`).
  final String apiUrl;

  /// When true, repositories use mock implementations (until G1).
  final bool useMock;

  String get restBaseUrl => '$apiUrl/v1';

  String get wsBaseUrl =>
      '${apiUrl.replaceFirst(RegExp('^http'), 'ws')}/v1/ws';
}
