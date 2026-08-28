import 'dart:io';

class AppConfig {
  static const String _defaultBaseUrl = 'https://dev-api.intellitoggle.com';

  final String clientId;
  final String clientSecret;
  final String tenantId;
  final String baseUrl;
  final Duration timeout;

  AppConfig._({
    required this.clientId,
    required this.clientSecret,
    required this.tenantId,
    required this.baseUrl,
    required this.timeout,
  });

  factory AppConfig.fromEnvironment() {
    final clientId = Platform.environment['INTELLITOGGLE_CLIENT_ID'];
    final clientSecret = Platform.environment['INTELLITOGGLE_CLIENT_SECRET'];
    final tenantId = Platform.environment['INTELLITOGGLE_TENANT_ID'];

    if (clientId == null || clientSecret == null || tenantId == null) {
      throw Exception('''
Missing required environment variables. Please set:
- INTELLITOGGLE_CLIENT_ID
- INTELLITOGGLE_CLIENT_SECRET  
- INTELLITOGGLE_TENANT_ID
''');
    }

    return AppConfig._(
      clientId: clientId,
      clientSecret: clientSecret,
      tenantId: tenantId,
      baseUrl: Platform.environment['INTELLITOGGLE_API_URL'] ?? _defaultBaseUrl,
      timeout: Duration(
        seconds:
            int.tryParse(Platform.environment['TIMEOUT_SECONDS'] ?? '30') ?? 30,
      ),
    );
  }

  String get oauthTokenUrl => '$baseUrl/oauth/token';
  String get projectsUrl => '$baseUrl/api/projects/';
  String get flagsUrl => '$baseUrl/api/flags';

  String projectUrl(String projectId) => '$projectsUrl/$projectId';
  String projectFlagsUrl(String projectId) =>
      '$baseUrl/api/flags/projects/$projectId/flags';
  String flagEvaluateUrl(String projectId, String flagKey) =>
      '$baseUrl/api/flags/projects/$projectId/flags/$flagKey/evaluate';

  Map<String, String> get defaultHeaders => {
    'Content-Type': 'application/json',
    'X-Tenant-ID': tenantId,
  };

  Map<String, String> authHeaders(String token) => {
    ...defaultHeaders,
    'Authorization': 'Bearer $token',
  };
}
