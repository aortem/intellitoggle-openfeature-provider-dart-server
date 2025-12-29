import 'dart:io';
import 'package:intellitoggle_demo/main.dart';

void main(List<String> arguments) async {
  print('╔════════════════════════════════════════════════╗');
  print('║              IntelliToggle Demo                ║');
  print('║         Server-Side Dart SDK Sample           ║');
  print('╚════════════════════════════════════════════════╝');

  // Check for help argument
  if (arguments.contains('-h') || arguments.contains('--help')) {
    _printHelp();
    return;
  }

  // Validate environment variables
  if (!_validateEnvironment()) {
    _printEnvironmentHelp();
    exit(1);
  }

  // Run interactive demo
  if (arguments.isEmpty || arguments.contains('--interactive')) {
    await _runInteractiveDemo();
  } else if (arguments.contains('--quick')) {
    await _runQuickDemo();
  } else {
    print('Unknown arguments: ${arguments.join(' ')}');
    _printHelp();
    exit(1);
  }
}

bool _validateEnvironment() {
  final required = [
    'INTELLITOGGLE_CLIENT_ID',
    'INTELLITOGGLE_CLIENT_SECRET',
    'INTELLITOGGLE_TENANT_ID',
  ];

  for (final envVar in required) {
    if (Platform.environment[envVar] == null ||
        Platform.environment[envVar]!.isEmpty) {
      return false;
    }
  }
  return true;
}

Future<void> _runInteractiveDemo() async {
  print('\n🎮 Interactive Demo Mode');
  print('Press Enter to continue through each step...\n');

  final demo = IntelliToggleDemo();
  await demo.initialize();

  print('Step 1: Authentication');
  _waitForEnter();

  print('Step 2: Project Setup');
  _waitForEnter();

  print('Step 3: Flag Creation');
  _waitForEnter();

  print('Step 4: Provider Initialization');
  _waitForEnter();

  print('Step 5: Flag Evaluation');
  _waitForEnter();

  await demo.runDemo();
}

Future<void> _runQuickDemo() async {
  print('\n⚡ Quick Demo Mode - Running automatically...\n');

  final demo = IntelliToggleDemo();
  await demo.initialize();
  await demo.runDemo();
}

void _waitForEnter() {
  print('Press Enter to continue...');
  stdin.readLineSync();
}

void _printHelp() {
  print('''
Usage: dart run bin/demo.dart [options]

Options:
  --interactive    Run step-by-step interactive demo (default)
  --quick         Run quick automated demo
  -h, --help      Show this help message

Examples:
  dart run bin/demo.dart
  dart run bin/demo.dart --interactive
  dart run bin/demo.dart --quick

Environment Variables Required:
  INTELLITOGGLE_CLIENT_ID      OAuth2 client ID
  INTELLITOGGLE_CLIENT_SECRET  OAuth2 client secret
  INTELLITOGGLE_TENANT_ID      Your tenant ID

Optional:
  INTELLITOGGLE_API_URL        API endpoint (default: https://dev-api.intellitoggle.com)
  TIMEOUT_SECONDS              Request timeout (default: 30)
''');
}

void _printEnvironmentHelp() {
  print('''
❌ Missing required environment variables!

To get your OAuth2 credentials, run:

curl -X POST https://dev-api.intellitoggle.com/api/oauth/clients \\
  -H "Content-Type: application/json" \\
  -H "Authorization: Bearer YOUR_TENANT_TOKEN" \\
  -H "X-Tenant-ID: YOUR_TENANT_ID" \\
  -d '{
    "name": "Demo App",
    "scopes": ["flags:read", "flags:write", "flags:evaluate", "projects:read", "projects:write"]
  }'

Then create a .env file or export these variables:
export INTELLITOGGLE_CLIENT_ID="client_xxx"
export INTELLITOGGLE_CLIENT_SECRET="cs_xxx"
export INTELLITOGGLE_TENANT_ID="tenant_xxx"

Run the demo again after setting up your credentials.
''');
}
