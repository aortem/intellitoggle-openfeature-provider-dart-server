<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/aortem/logos/main/Aortem-logo-small.png" />
    <img align="center" alt="Aortem Logo" src="https://raw.githubusercontent.com/aortem/logos/main/Aortem-logo-small.png" />
  </picture>
</p>

<!-- x-hide-in-docs-end -->
<p align="center" class="github-badges">
  <!-- Release Badge -->
  <a href="https://github.com/aortem/intellitoggle/tags">
    <img alt="GitHub Tag" src="https://img.shields.io/github/v/tag/aortem/intellitoggle?style=for-the-badge" />
  </a>
  <!-- Dart-Specific Badges -->
  <a href="https://pub.dev/packages/openfeature_provider_intellitoggle">
    <img alt="Pub Version" src="https://img.shields.io/pub/v/openfeature_provider_intellitoggle.svg?style=for-the-badge" />
  </a>
  <a href="https://dart.dev/">
    <img alt="Built with Dart" src="https://img.shields.io/badge/Built%20with-Dart-blue.svg?style=for-the-badge" />
  </a>
<!-- x-hide-in-docs-start -->

# IntelliToggle OpenFeature Provider for Dart (Server-Side SDK)

Official IntelliToggle provider for the OpenFeature Dart Server SDK. Enables secure feature flag evaluation with OAuth2 authentication, multi-tenant isolation, and real-time updates.

> **Note:** This provider targets server-side Dart applications. Flutter support is available but secondary to server-side functionality.

## Features

- **OpenFeature compliance** - Boolean, String, Integer, Double, and Object flag evaluation
- **OAuth2 authentication** - Client credentials flow with tenant isolation
- **Advanced targeting** - Multi-context evaluation with rules engine
- **Real-time updates** - Streaming configuration changes and webhooks
- **Local development** - InMemoryProvider for testing without external dependencies
- **OREP server** - Remote evaluation protocol for distributed systems

## Supported Dart Versions

Dart **3.8.1** and above.

---

## Installation

```yaml
dependencies:
  openfeature_dart_server_sdk: ^0.0.10
  openfeature_provider_intellitoggle: ^0.0.4
```

```bash
dart pub get
```

---

## Authentication

IntelliToggle uses OAuth2 Client Credentials for secure API access.

### Get OAuth2 Credentials

```bash
curl -X POST https://api.intellitoggle.com/api/oauth2/clients \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TENANT_TOKEN" \
  -H "X-Tenant-ID: YOUR_TENANT_ID" \
  -d '{
    "name": "My Server App",
    "scopes": ["flags:read", "flags:evaluate"]
  }'
```

Response:
```json
{
  "clientId": "client_1234567890",
  "clientSecret": "cs_1234567890_secret"
}
```

### Environment Setup

```env
INTELLITOGGLE_CLIENT_ID=client_1234567890
INTELLITOGGLE_CLIENT_SECRET=cs_1234567890_secret
INTELLITOGGLE_TENANT_ID=your_tenant_id
INTELLITOGGLE_API_URL=https://api.intellitoggle.com
```

---

## Basic Usage

```dart
import 'package:openfeature_dart_server_sdk/openfeature_dart_server_sdk.dart';
import 'package:openfeature_provider_intellitoggle/openfeature_provider_intellitoggle.dart';

void main() async {
  // Initialize provider with OAuth2 client secret
  final provider = IntelliToggleProvider(
    sdkKey: 'YOUR_CLIENT_SECRET',
    options: IntelliToggleOptions.production(),
  );

  // Set as global provider
  await OpenFeatureAPI().setProvider(provider);

  // Create client
  final client = IntelliToggleClient(
    FeatureClient(
      metadata: ClientMetadata(name: 'my-service'),
      hookManager: HookManager(),
    ),
  );

  // Evaluate flags
  final enabled = await client.getBooleanValue(
    'new-api-endpoint',
    false,
    targetingKey: 'user-123',
    evaluationContext: {
      'role': 'admin',
      'plan': 'enterprise',
      'region': 'us-east',
    },
  );

  print('Feature enabled: $enabled');
}
```

---

## Advanced Usage

### Multi-Context Evaluation

```dart
final multiContext = client.createMultiContext({
  'user': {
    'targetingKey': 'user-123',
    'role': 'admin',
    'plan': 'enterprise',
  },
  'organization': {
    'targetingKey': 'org-456',
    'tier': 'premium',
    'industry': 'fintech',
  },
});

final config = await client.getObjectValue(
  'feature-config',
  {},
  evaluationContext: multiContext.attributes,
);
```

### Custom Context Types

```dart
final deviceContext = client.createContext(
  targetingKey: 'device-789',
  kind: 'device',
  customAttributes: {
    'os': 'linux',
    'version': '5.4.0',
    'datacenter': 'us-west-2',
  },
);

final threshold = await client.getIntegerValue(
  'rate-limit',
  1000,
  evaluationContext: deviceContext.attributes,
);
```

### Event Handling

```dart
provider.events.listen((event) {
  switch (event.type) {
    case IntelliToggleEventType.ready:
      print('Provider ready');
      break;
    case IntelliToggleEventType.configurationChanged:
      print('Flags updated: ${event.data?['flagsChanged']}');
      break;
    case IntelliToggleEventType.error:
      print('Error: ${event.message}');
      break;
  }
});
```

### Global Context

```dart
// Set context for all evaluations
OpenFeatureAPI().setGlobalContext(
  OpenFeatureEvaluationContext({
    'environment': 'production',
    'service': 'api-gateway',
    'version': '2.1.0',
  })
);
```

---

## Configuration Options

### Production Configuration

```dart
final options = IntelliToggleOptions.production(
  baseUri: Uri.parse('https://api.intellitoggle.com'),
  timeout: Duration(seconds: 10),
  pollingInterval: Duration(minutes: 5),
);
```

### Development Configuration  

```dart
final options = IntelliToggleOptions.development(
  baseUri: Uri.parse('http://localhost:8080'),
  timeout: Duration(seconds: 5),
);
```

### Custom Configuration

```dart
final options = IntelliToggleOptions(
  timeout: Duration(seconds: 15),
  enablePolling: true,
  pollingInterval: Duration(minutes: 2),
  enableStreaming: true,
  maxRetries: 5,
  enableLogging: true,
);
```

---

## Local Development

### InMemoryProvider

```dart
final provider = InMemoryProvider();

// Set test flags
provider.setFlag('feature-enabled', true);
provider.setFlag('api-version', 'v2');
provider.setFlag('rate-limits', {
  'requests_per_minute': 1000,
  'burst_size': 50,
});

await OpenFeatureAPI().setProvider(provider);

// Evaluate flags
final client = IntelliToggleClient(FeatureClient(
  metadata: ClientMetadata(name: 'test'),
  hookManager: HookManager(),
));

final enabled = await client.getBooleanValue('feature-enabled', false);
print('Feature enabled: $enabled');

// Update flags at runtime
provider.setFlag('feature-enabled', false);
```

### OREP Server

Start remote evaluation server:

```bash
dart run bin/orep_server.dart
```

Environment variables:
```env
OREP_HOST=0.0.0.0
OREP_PORT=8080  
OREP_AUTH_TOKEN=secure-token-123
```

Test evaluation:
```bash
curl -X POST http://localhost:8080/v1/flags/my-flag/evaluate \
  -H "Authorization: Bearer secure-token-123" \
  -H "Content-Type: application/json" \
  -d '{
    "defaultValue": false,
    "type": "boolean", 
    "context": {
      "targetingKey": "user-123",
      "role": "admin"
    }
  }'
```

---

## API Integration

### OAuth2 Token Exchange

```dart
Future<String> getAccessToken() async {
  final response = await http.post(
    Uri.parse('https://api.intellitoggle.com/oauth/token'),
    headers: {'Content-Type': 'application/x-www-form-urlencoded'},
    body: 'grant_type=client_credentials'
        '&client_id=$clientId'
        '&client_secret=$clientSecret'
        '&scope=flags:read flags:evaluate',
  );

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    return data['access_token'];
  }
  throw Exception('OAuth2 failed: ${response.body}');
}
```

### Direct API Calls

```dart
Future<Map<String, dynamic>> evaluateFlag({
  required String flagKey,
  required String projectId,
  required Map<String, dynamic> context,
}) async {
  final token = await getAccessToken();
  
  final response = await http.post(
    Uri.parse('$baseUrl/api/flags/projects/$projectId/flags/$flagKey/evaluate'),
    headers: {
      'Authorization': 'Bearer $token',
      'X-Tenant-ID': tenantId,
      'Content-Type': 'application/json',
    },
    body: jsonEncode(context),
  );
  
  if (response.statusCode == 200) {
    return jsonDecode(response.body);
  }
  throw Exception('Evaluation failed: ${response.body}');
}
```

---

## Error Handling

### Exception Types

```dart
try {
  final result = await client.getBooleanValue('my-flag', false);
} on FlagNotFoundException {
  // Flag doesn't exist
} on AuthenticationException {
  // Invalid credentials
} on ApiException catch (e) {
  // API error with status code
  print('API error: ${e.code}');
} catch (e) {
  // General error
}
```

### Retry Configuration

```dart
final options = IntelliToggleOptions(
  maxRetries: 3,
  retryDelay: Duration(seconds: 1),
  timeout: Duration(seconds: 10),
);
```

---

## Hook System

### Console Logging Hook

```dart
final hook = ConsoleLoggingHook();

// Add globally
OpenFeatureAPI().addHooks([hook]);

// Add to specific client
final hookManager = HookManager();
hookManager.addHook(hook);
```

### Custom Analytics Hook

```dart
class AnalyticsHook extends Hook {
  @override
  Future<void> after(HookContext context) async {
    // Track flag usage
    analytics.track('flag_evaluated', {
      'flag_key': context.flagKey,
      'result': context.result,
    });
  }
}
```

---

## Flutter Integration (Brief)

For Flutter applications, IntelliToggle provides UI state management and direct API integration:

```dart
// Add to pubspec.yaml
dependencies:
  flutter_dotenv: ^5.2.1
  provider: ^6.1.5

// Basic Flutter service
class IntelliToggleService extends ChangeNotifier {
  Future<String> getAccessToken() async {
    // OAuth2 implementation
  }
  
  Future<Map<String, dynamic>> evaluateFlag({
    required String projectId,
    required String flagKey,
    required Map<String, dynamic> context,
  }) async {
    // Direct API calls
  }
}
```

Flutter apps use direct HTTP API calls rather than the OpenFeature provider pattern. See the [sample Flutter app](https://github.com/aortem/intellitoggle-openfeature-provider-dart-server/tree/main/example) for complete implementation.

---

## Provider Options

### IntelliToggleOptions

| Option | Description | Default |
|--------|-------------|---------|
| `baseUri` | API endpoint | `https://api.intellitoggle.com` |
| `timeout` | Request timeout | `10 seconds` |
| `enablePolling` | Poll for config changes | `true` |
| `pollingInterval` | Polling frequency | `5 minutes` |
| `enableStreaming` | Real-time updates | `false` |
| `maxRetries` | Retry attempts | `3` |
| `enableLogging` | Debug logging | `false` |

### Factory Methods

```dart
// Production optimized
IntelliToggleOptions.production()

// Development optimized  
IntelliToggleOptions.development()
```

---

## Context Types

### Single Context

```dart
{
  'targetingKey': 'user-123',
  'kind': 'user',
  'role': 'admin',
  'plan': 'enterprise'
}
```

### Multi-Context

```dart
{
  'kind': 'multi',
  'user': {
    'targetingKey': 'user-123',
    'role': 'admin'
  },
  'organization': {
    'targetingKey': 'org-456', 
    'plan': 'enterprise'
  }
}
```

### Reserved Attributes

- `targetingKey` - Required identifier for targeting
- `kind` - Context type (`user`, `organization`, `device`, `multi`)
- `anonymous` - Anonymous context flag
- `privateAttributes` - Attributes to exclude from logs

---

## OREP/OPTSP Support

### OREP Endpoints

- `POST /v1/flags/{flagKey}/evaluate` - Evaluate flag
- `GET /v1/provider/metadata` - Provider info

### OPTSP Endpoints  

- `POST /v1/provider/seed` - Seed test flags
- `POST /v1/provider/reset` - Clear all flags
- `POST /v1/provider/shutdown` - Shutdown provider

### Authentication

All endpoints require Bearer token:
```bash
curl -H "Authorization: Bearer changeme-token" ...
```

---

## Security

### TLS Requirements

Production deployments require HTTPS endpoints. HTTP only allowed for `localhost`.

### Token Management

- Client secrets are never logged or exposed
- Tokens have configurable TTL (default: 60 minutes)  
- Automatic token refresh with 10-minute buffer

### Tenant Isolation

All requests include `X-Tenant-ID` header for multi-tenancy:

```dart
headers: {
  'Authorization': 'Bearer $token',
  'X-Tenant-ID': '$tenantId',
}
```

---

## Contributing

We welcome contributions! See [`CONTRIBUTING.md`](https://github.com/intellitoggle/openfeature-dart/blob/main/CONTRIBUTING.md) for guidelines.

---

## Learn More

* **Website:** [https://intellitoggle.com](https://intellitoggle.com)
* **Docs & CLI:** [https://sdks.aortem.io/intellitoggle](https://sdks.aortem.io/intellitoggle/)
* **API Reference:** [https://api.intellitoggle.com/docs](https://api.intellitoggle.com/docs)
* **GitHub:** [https://github.com/aortem/intellitoggle-openfeature-provider-dart-server](https://github.com/aortem/intellitoggle-openfeature-provider-dart-server)
