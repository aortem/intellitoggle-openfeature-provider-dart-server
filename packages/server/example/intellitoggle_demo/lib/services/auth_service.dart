import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class AuthService {
  final AppConfig _config;
  String? _accessToken;
  DateTime? _tokenExpiry;

  AuthService(this._config);

  Future<String> getAccessToken() async {
    if (_accessToken != null && _tokenExpiry != null) {
      if (DateTime.now().isBefore(
        _tokenExpiry!.subtract(Duration(minutes: 5)),
      )) {
        return _accessToken!;
      }
    }

    await _refreshToken();
    return _accessToken!;
  }

  Future<void> _refreshToken() async {
    final credentials = base64Encode(
      utf8.encode('${_config.clientId}:${_config.clientSecret}'),
    );

    try {
      final response = await http
          .post(
            Uri.parse(_config.oauthTokenUrl),
            headers: {
              'Content-Type': 'application/x-www-form-urlencoded',
              'Authorization': 'Basic $credentials',
            },
            body:
                'grant_type=client_credentials&scope=flags:read flags:write flags:evaluate projects:read projects:write',
          )
          .timeout(_config.timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _accessToken = data['access_token'];
        final expiresIn = data['expires_in'] ?? 3600;
        _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn));

        print('✅ OAuth2 token obtained successfully');
      } else {
        throw Exception(
          'OAuth2 failed: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      throw Exception('Failed to get access token: $e');
    }
  }

  Future<bool> validateToken() async {
    try {
      await getAccessToken();
      return true;
    } catch (e) {
      print('❌ Token validation failed: $e');
      return false;
    }
  }

  void clearToken() {
    _accessToken = null;
    _tokenExpiry = null;
  }
}
