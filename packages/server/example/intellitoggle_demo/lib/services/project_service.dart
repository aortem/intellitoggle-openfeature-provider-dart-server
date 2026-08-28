import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/project.dart';
import 'auth_service.dart';

class ProjectService {
  final AppConfig _config;
  final AuthService _authService;

  ProjectService(this._config, this._authService);

  Future<List<Project>> listProjects() async {
    final token = await _authService.getAccessToken();

    final response = await http
        .get(
          Uri.parse(_config.projectsUrl),
          headers: _config.authHeaders(token),
        )
        .timeout(_config.timeout);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final projects = (data['projects'] as List)
          .map((p) => Project.fromJson(p))
          .toList();
      return projects;
    } else {
      throw Exception(
        'Failed to list projects: ${response.statusCode} - ${response.body}',
      );
    }
  }

  Future<Project?> getProject(String projectId) async {
    try {
      final token = await _authService.getAccessToken();

      final response = await http
          .get(
            Uri.parse(_config.projectUrl(projectId)),
            headers: _config.authHeaders(token),
          )
          .timeout(_config.timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Project.fromJson(data['data']);
      } else if (response.statusCode == 404) {
        return null;
      } else {
        throw Exception(
          'Failed to get project: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      if (e.toString().contains('404')) return null;
      rethrow;
    }
  }

  Future<Project> createProject({
    required String name,
    String? description,
  }) async {
    final token = await _authService.getAccessToken();

    final body = jsonEncode({
      'name': name,
      'description': description ?? 'IntelliToggle demo project',
    });

    final response = await http
        .post(
          Uri.parse(_config.projectsUrl),
          headers: _config.authHeaders(token),
          body: body,
        )
        .timeout(_config.timeout);

    if (response.statusCode == 201 || response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return Project.fromJson(data); // API returns direct object, not nested
    } else {
      throw Exception(
        'Failed to create project: ${response.statusCode} - ${response.body}',
      );
    }
  }

  Future<Project> ensureProject(String projectId, String projectName) async {
    print('🔍 Checking if project "$projectId" exists...');

    final existingProject = await getProject(projectId);
    if (existingProject != null) {
      print('✅ Project "$projectId" already exists');
      return existingProject;
    }

    print('📁 Creating new project "$projectId"...');
    final newProject = await createProject(name: projectName);
    print('✅ Project created successfully: ${newProject.id}');

    return newProject;
  }

  Future<void> deleteProject(String projectId) async {
    final token = await _authService.getAccessToken();

    final response = await http
        .delete(
          Uri.parse(_config.projectUrl(projectId)),
          headers: _config.authHeaders(token),
        )
        .timeout(_config.timeout);

    if (response.statusCode != 204 && response.statusCode != 200) {
      throw Exception(
        'Failed to delete project: ${response.statusCode} - ${response.body}',
      );
    }
  }
}
