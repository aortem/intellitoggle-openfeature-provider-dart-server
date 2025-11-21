import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/flag.dart';
import '../models/evaluation_context.dart';
import 'auth_service.dart';

class FlagService {
  final AppConfig _config;
  final AuthService _authService;

  FlagService(this._config, this._authService);

  Future<List<Flag>> listFlags(String projectId) async {
    final token = await _authService.getAccessToken();

    final response = await http
        .get(
          Uri.parse(_config.projectFlagsUrl(projectId)),
          headers: _config.authHeaders(token),
        )
        .timeout(_config.timeout);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['flags'] as List).map((f) => Flag.fromJson(f)).toList();
    } else {
      throw Exception(
        'Failed to list flags: ${response.statusCode} - ${response.body}',
      );
    }
  }

  Future<Flag?> getFlag(String projectId, String flagKey) async {
    try {
      final token = await _authService.getAccessToken();

      final response = await http
          .get(
            Uri.parse('${_config.projectFlagsUrl(projectId)}/$flagKey'),
            headers: _config.authHeaders(token),
          )
          .timeout(_config.timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // GET returns: {success: true, data: {flag: {...}}}
        return Flag.fromJson(data['data']['flag']);
      } else if (response.statusCode == 404) {
        return null;
      } else {
        throw Exception(
          'Failed to get flag: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      if (e.toString().contains('404')) return null;
      rethrow;
    }
  }

  Future<Flag> createBooleanFlag({
    required String projectId,
    required String key,
    required String name,
    String? description,
    bool defaultValue = false,
    List<String>? tags,
  }) async {
    final token = await _authService.getAccessToken();

    final body = jsonEncode({
      'key': key,
      'name': name,
      'description': description ?? 'Demo boolean flag',
      'type': 'boolean',
      'enabled': true,
      'defaultValue': defaultValue,
      'flag_variations': [
        {'id': 'off', 'value': false, 'name': 'Off'},
        {'id': 'on', 'value': true, 'name': 'On'},
      ],
      'tags': tags ?? ['demo'],
      'environment': 'production',
    });

    final response = await http
        .post(
          Uri.parse(_config.projectFlagsUrl(projectId)),
          headers: _config.authHeaders(token),
          body: body,
        )
        .timeout(_config.timeout);

    if (response.statusCode == 201 || response.statusCode == 200) {
      final data = jsonDecode(response.body);
      // FIX: Backend returns data directly, not nested in 'flag'
      return Flag.fromJson(data['data']);
    } else {
      throw Exception(
        'Failed to create flag: ${response.statusCode} - ${response.body}',
      );
    }
  }

  Future<Flag> createStringFlag({
    required String projectId,
    required String key,
    required String name,
    String? description,
    String defaultValue = 'default',
    List<String> variations = const ['default', 'variant1', 'variant2'],
    List<String>? tags,
  }) async {
    final token = await _authService.getAccessToken();

    final variationObjects = variations
        .map(
          (v) => {
            'id': v.toLowerCase().replaceAll(' ', '_'),
            'value': v,
            'name': v,
          },
        )
        .toList();

    final body = jsonEncode({
      'key': key,
      'name': name,
      'description': description ?? 'Demo string flag',
      'type': 'string',
      'enabled': true,
      'defaultValue': defaultValue,
      'flag_variations': variationObjects,
      'tags': tags ?? ['demo'],
      'environment': 'production',
    });

    final response = await http
        .post(
          Uri.parse(_config.projectFlagsUrl(projectId)),
          headers: _config.authHeaders(token),
          body: body,
        )
        .timeout(_config.timeout);

    if (response.statusCode == 201 || response.statusCode == 200) {
      final data = jsonDecode(response.body);
      // FIX: Backend returns data directly, not nested in 'flag'
      return Flag.fromJson(data['data']);
    } else {
      throw Exception(
        'Failed to create string flag: ${response.statusCode} - ${response.body}',
      );
    }
  }

  Future<Map<String, dynamic>> evaluateFlag({
    required String projectId,
    required String flagKey,
    required EvaluationContext context,
    dynamic defaultValue,
  }) async {
    final token = await _authService.getAccessToken();

    final body = jsonEncode({
      'context': context.toJson(),
      'defaultValue': defaultValue,
    });

    final response = await http
        .post(
          Uri.parse(_config.flagEvaluateUrl(projectId, flagKey)),
          headers: _config.authHeaders(token),
          body: body,
        )
        .timeout(_config.timeout);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(
        'Failed to evaluate flag: ${response.statusCode} - ${response.body}',
      );
    }
  }

  Future<void> deleteFlag(String projectId, String flagKey) async {
    final token = await _authService.getAccessToken();

    final response = await http
        .delete(
          Uri.parse('${_config.projectFlagsUrl(projectId)}/$flagKey'),
          headers: _config.authHeaders(token),
        )
        .timeout(_config.timeout);

    if (response.statusCode != 204 && response.statusCode != 200) {
      throw Exception(
        'Failed to delete flag: ${response.statusCode} - ${response.body}',
      );
    }
  }
}
