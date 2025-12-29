# IntelliToggle Server-Side Dart SDK Demo

Complete working example of IntelliToggle integration with OpenFeature Dart Server SDK.

## Features

- OAuth2 client credentials authentication
- Project creation and management
- Feature flag setup (boolean/string types)
- Multi-context evaluation
- Real-time provider events
- Error handling and retry logic

## Quick Start

### 1. Get OAuth2 Credentials

```bash
curl -X POST https://dev-api.intellitoggle.com/api/oauth/clients \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TENANT_TOKEN" \
  -H "X-Tenant-ID: YOUR_TENANT_ID" \
  -d '{
    "name": "Demo App",
    "scopes": ["flags:read", "flags:write", "flags:evaluate", "projects:read", "projects:write"]
  }'
```

### 2. Set Environment Variables

```bash
export INTELLITOGGLE_CLIENT_ID="client_xxx"
export INTELLITOGGLE_CLIENT_SECRET="cs_xxx"  
export INTELLITOGGLE_TENANT_ID="tenant_xxx"
```

### 3. Install Dependencies

```bash
dart pub get
```

### 4. Run Demo

```bash
# Interactive mode (step-by-step)
dart run bin/demo.dart

# Quick mode (automated)
dart run bin/demo.dart --quick
```

## What the Demo Does

1. **Authenticates** using OAuth2 client credentials
2. **Creates project** "intellitoggle-demo" if it doesn't exist
3. **Creates feature flags**:
   - Boolean flags: `new-ui-enabled`, `premium-features`, `dark-mode`
   - String flags: `welcome-message`, `api-version`
4. **Initializes OpenFeature provider** with IntelliToggle
5. **Evaluates flags** for different user contexts

## Project Structure

```
intellitoggle_demo/
├── lib/
│   ├── config/app_config.dart          # Environment configuration
│   ├── services/
│   │   ├── auth_service.dart           # OAuth2 authentication
│   │   ├── project_service.dart        # Project management
│   │   └── flag_service.dart           # Flag operations
│   ├── models/
│   │   ├── project.dart                # Project entity
│   │   ├── flag.dart                   # Flag entity
│   │   └── evaluation_context.dart     # Context builders
│   ├── providers/
│   │   └── intellitoggle_demo_provider.dart  # OpenFeature provider wrapper
│   └── main.dart                       # Demo orchestration
├── bin/demo.dart                       # CLI entry point
└── pubspec.yaml                        # Dependencies
```

## Key Code Examples

### Authentication
```dart
final authService = AuthService(config);
final token = await authService.getAccessToken();
```

### Project Setup
```dart
final project = await projectService.ensureProject('demo-project', 'Demo');
```

### Flag Creation
```dart
await flagService.createBooleanFlag(
  projectId: project.id,
  key: 'new-ui-enabled',
  name: 'New UI Enabled',
  defaultValue: false,
);
```

### Flag Evaluation
```dart
final provider = IntelliToggleDemoProvider(config);
await provider.initialize();

final enabled = await provider.getBooleanFlag(
  'new-ui-enabled',
  false,
  targetingKey: 'user-123',
  context: {'role': 'admin', 'plan': 'enterprise'},
);
```

### Multi-Context Evaluation
```dart
final multiContext = EvaluationContext.multi(
  user: EvaluationContext.user(
    userId: 'user-123',
    role: 'admin',
    plan: 'enterprise',
  ),
  organization: EvaluationContext.organization(
    orgId: 'org-456',
    tier: 'premium',
  ),
);

final result = await provider.getBooleanFlag(
  'premium-features',
  false,
  context: multiContext.toJson(),
);
```

## Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `INTELLITOGGLE_CLIENT_ID` | OAuth2 client ID | ✅ |
| `INTELLITOGGLE_CLIENT_SECRET` | OAuth2 client secret | ✅ |
| `INTELLITOGGLE_TENANT_ID` | Your tenant ID | ✅ |
| `INTELLITOGGLE_API_URL` | API endpoint | ❌ (defaults to dev-api) |
| `TIMEOUT_SECONDS` | Request timeout | ❌ (defaults to 30) |

## Expected Output

```
🚀 Starting IntelliToggle Demo
==================================================

📡 Authenticating with IntelliToggle...
✅ Authentication successful

📁 Setting up project...
✅ Project ready: IntelliToggle Demo Project (intellitoggle-demo)

🚩 Setting up feature flags...
  ✅ Created flag: new-ui-enabled
  ✅ Created flag: premium-features
  ✅ Created flag: dark-mode
  ✅ Created flag: welcome-message
  ✅ Created flag: api-version
✅ 5 flags ready for evaluation

✅ IntelliToggle provider initialized

🎯 Demonstrating flag evaluation...
------------------------------

👤 User: admin@company.com (admin)
  🚩 new-ui-enabled: true
  🚩 premium-features: true
  🚩 dark-mode: true
  🚩 welcome-message: "Welcome to IntelliToggle!"
  🚩 api-version: v2

👤 User: user@company.com (user)
  🚩 new-ui-enabled: false
  🚩 premium-features: false
  🚩 dark-mode: true
  🚩 welcome-message: "Hello and welcome!"
  🚩 api-version: v1

🏢 Multi-context evaluation:
  🚩 new-ui-enabled: true
  🚩 welcome-message: "Greetings, user!"

✅ Demo completed successfully!
```

## Next Steps

1. Customize targeting rules in IntelliToggle dashboard
2. Add analytics tracking with hooks
3. Implement streaming updates
4. Add A/B testing experiments
5. Integrate with your application

## Documentation

- [IntelliToggle Dart Provider](https://pub.dev/packages/openfeature_provider_intellitoggle)
- [OpenFeature Dart SDK](https://pub.dev/packages/openfeature_dart_server_sdk) 
- [IntelliToggle API Docs](https://api.intellitoggle.com/docs)
- [IntelliToggle Dashboard](https://intellitoggle.com)