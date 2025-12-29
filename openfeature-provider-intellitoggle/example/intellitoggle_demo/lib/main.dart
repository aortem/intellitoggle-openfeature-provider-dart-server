import 'dart:io';
import 'config/app_config.dart';
import 'services/auth_service.dart';
import 'services/project_service.dart';
import 'services/flag_service.dart';
import 'providers/intellitoggle_demo_provider.dart';
import 'models/evaluation_context.dart';

class IntelliToggleDemo {
  late final AppConfig _config;
  late final AuthService _authService;
  late final ProjectService _projectService;
  late final FlagService _flagService;
  late final IntelliToggleDemoProvider _provider;

  Future<void> initialize() async {
    _config = AppConfig.fromEnvironment();
    _authService = AuthService(_config);
    _projectService = ProjectService(_config, _authService);
    _flagService = FlagService(_config, _authService);
    _provider = IntelliToggleDemoProvider(_config);
  }

  Future<void> runDemo() async {
    print('🚀 Starting IntelliToggle Demo');
    print('=' * 50);

    try {
      // Step 1: Authentication
      await _authenticate();

      // Step 2: Project setup
      final project = await _setupProject();

      // Step 3: Flag creation
      await _setupFlags(project.id);

      // Step 4: Provider initialization
      await _provider.initialize();

      // Step 5: Flag evaluation demo
      await _demonstrateFlagEvaluation();

      print('\n✅ Demo completed successfully!');
    } catch (e) {
      print('\n❌ Demo failed: $e');
      exit(1);
    } finally {
      await _provider.shutdown();
    }
  }

  Future<void> _authenticate() async {
    print('\n📡 Authenticating with IntelliToggle...');

    if (await _authService.validateToken()) {
      print('✅ Authentication successful');
    } else {
      throw Exception('Authentication failed');
    }
  }

  Future<dynamic> _setupProject() async {
    print('\n📁 Setting up project...');

    const projectId = 'intellitoggle-demo';
    const projectName = 'IntelliToggle Demo Project';

    final project = await _projectService.ensureProject(projectId, projectName);
    print('✅ Project ready: ${project.name} (${project.id})');

    return project;
  }

  Future<void> _setupFlags(String projectId) async {
    print('\n🚩 Setting up feature flags...');

    await _setupBooleanFlags(projectId);
    await _setupStringFlags(projectId);

    final flags = await _flagService.listFlags(projectId);
    print('✅ ${flags.length} flags ready for evaluation');
  }

  Future<void> _setupBooleanFlags(String projectId) async {
    final booleanFlags = [
      {
        'key': 'new-ui-enabled',
        'name': 'New UI Enabled',
        'description': 'Enable the new user interface',
        'defaultValue': false,
      },
      {
        'key': 'premium-features',
        'name': 'Premium Features',
        'description': 'Enable premium features for users',
        'defaultValue': false,
      },
      {
        'key': 'dark-mode',
        'name': 'Dark Mode',
        'description': 'Enable dark mode theme',
        'defaultValue': true,
      },
    ];

    for (final flagConfig in booleanFlags) {
      final existing = await _flagService.getFlag(
        projectId,
        flagConfig['key'] as String,
      );

      if (existing == null) {
        await _flagService.createBooleanFlag(
          projectId: projectId,
          key: flagConfig['key'] as String,
          name: flagConfig['name'] as String,
          description: flagConfig['description'] as String,
          defaultValue: flagConfig['defaultValue'] as bool,
          tags: ['demo', 'boolean'],
        );
        print('  ✅ Created flag: ${flagConfig['key']}');
      } else {
        print('  ℹ️  Flag exists: ${flagConfig['key']}');
      }
    }
  }

  Future<void> _setupStringFlags(String projectId) async {
    final stringFlags = [
      {
        'key': 'welcome-message',
        'name': 'Welcome Message',
        'description': 'Customizable welcome message',
        'defaultValue': 'Welcome to IntelliToggle!',
        'variations': [
          'Welcome to IntelliToggle!',
          'Hello and welcome!',
          'Greetings, user!',
        ],
      },
      {
        'key': 'api-version',
        'name': 'API Version',
        'description': 'Active API version',
        'defaultValue': 'v1',
        'variations': ['v1', 'v2', 'beta'],
      },
    ];

    for (final flagConfig in stringFlags) {
      final existing = await _flagService.getFlag(
        projectId,
        flagConfig['key'] as String,
      );

      if (existing == null) {
        await _flagService.createStringFlag(
          projectId: projectId,
          key: flagConfig['key'] as String,
          name: flagConfig['name'] as String,
          description: flagConfig['description'] as String,
          defaultValue: flagConfig['defaultValue'] as String,
          variations: (flagConfig['variations'] as List<String>),
          tags: ['demo', 'string'],
        );
        print('  ✅ Created flag: ${flagConfig['key']}');
      } else {
        print('  ℹ️  Flag exists: ${flagConfig['key']}');
      }
    }
  }

  Future<void> _demonstrateFlagEvaluation() async {
    print('\n🎯 Demonstrating flag evaluation...');
    print('-' * 30);

    await _evaluateForDifferentUsers();
    await _evaluateWithMultiContext();
  }

  Future<void> _evaluateForDifferentUsers() async {
    final users = [
      EvaluationContext.user(
        userId: 'user-001',
        email: 'admin@company.com',
        role: 'admin',
        plan: 'enterprise',
      ),
      EvaluationContext.user(
        userId: 'user-002',
        email: 'user@company.com',
        role: 'user',
        plan: 'standard',
      ),
      EvaluationContext.user(
        userId: 'user-003',
        email: 'guest@company.com',
        role: 'guest',
        plan: 'free',
      ),
    ];

    for (final userContext in users) {
      print(
        '\n👤 User: ${userContext.attributes['email']} (${userContext.attributes['role']})',
      );

      // Boolean flags
      final newUi = await _provider.getBooleanFlag(
        'new-ui-enabled',
        false,
        targetingKey: userContext.targetingKey,
        context: userContext.toJson(),
      );

      final premiumFeatures = await _provider.getBooleanFlag(
        'premium-features',
        false,
        targetingKey: userContext.targetingKey,
        context: userContext.toJson(),
      );

      final darkMode = await _provider.getBooleanFlag(
        'dark-mode',
        true,
        targetingKey: userContext.targetingKey,
        context: userContext.toJson(),
      );

      // String flags
      final welcomeMessage = await _provider.getStringFlag(
        'welcome-message',
        'Welcome!',
        targetingKey: userContext.targetingKey,
        context: userContext.toJson(),
      );

      final apiVersion = await _provider.getStringFlag(
        'api-version',
        'v1',
        targetingKey: userContext.targetingKey,
        context: userContext.toJson(),
      );

      print('  🚩 new-ui-enabled: $newUi');
      print('  🚩 premium-features: $premiumFeatures');
      print('  🚩 dark-mode: $darkMode');
      print('  🚩 welcome-message: "$welcomeMessage"');
      print('  🚩 api-version: $apiVersion');
    }
  }

  Future<void> _evaluateWithMultiContext() async {
    print('\n🏢 Multi-context evaluation:');

    final multiContext = EvaluationContext.multi(
      user: EvaluationContext.user(
        userId: 'user-multi',
        email: 'multi@company.com',
        role: 'admin',
        plan: 'enterprise',
      ),
      organization: EvaluationContext.organization(
        orgId: 'org-001',
        name: 'Acme Corp',
        tier: 'enterprise',
        industry: 'technology',
      ),
      device: EvaluationContext.device(
        deviceId: 'device-001',
        os: 'linux',
        version: '5.4.0',
        region: 'us-east-1',
      ),
    );

    final newUi = await _provider.getBooleanFlag(
      'new-ui-enabled',
      false,
      context: multiContext.toJson(),
    );

    final welcomeMessage = await _provider.getStringFlag(
      'welcome-message',
      'Welcome!',
      context: multiContext.toJson(),
    );

    print('  🚩 new-ui-enabled: $newUi');
    print('  🚩 welcome-message: "$welcomeMessage"');
  }
}

Future<void> main() async {
  final demo = IntelliToggleDemo();
  await demo.initialize();
  await demo.runDemo();
}
