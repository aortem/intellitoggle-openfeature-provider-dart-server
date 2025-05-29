import 'dart:convert';

import 'package:gherkin/gherkin.dart';
import 'package:test/test.dart';

import 'package:intellitoggle_openfeature/intellitoggle_openfeature.dart' as intelli_toggle;
import 'package:openfeature_dart_server_sdk/client.dart';
import 'package:openfeature_dart_server_sdk/evaluation_context.dart';
import 'package:openfeature_dart_server_sdk/hooks.dart';
import 'package:openfeature_dart_server_sdk/open_feature_api.dart';


class FlagEvaluationResult<T> {
  final T value;
  final String variant;
  final String reason;

  FlagEvaluationResult(this.value, this.variant, this.reason);
}


class StepWorld extends World {
  late intelli_toggle.InMemoryProvider provider;
  late FeatureClient featureClient;
  late intelli_toggle.IntelliToggleClient client;

  dynamic lastResult;
  FlagEvaluationResult? lastDetails;

  @override
  Future<void> setUp() async {
    provider = intelli_toggle.InMemoryProvider();
    await provider.initialize();

    OpenFeatureAPI().setProvider(provider);

    featureClient = FeatureClient(
      metadata: ClientMetadata(name: 'test-client'),
      defaultContext: EvaluationContext(attributes: {}),
      hookManager: HookManager(),
      provider: provider,
    );

    client = intelli_toggle.IntelliToggleClient(featureClient);
  }
}

// GIVEN a stable provider
StepDefinitionGeneric givenStableProvider() {
  return given<StepWorld>(
    RegExp(r'a stable provider'),
    (context) async {
      // provider is initialized in setUp, so this can be no-op or log
      print('[Setup] Provider is ready');
    },
  );
}

// WHEN a flag is evaluated with default value
StepDefinitionGeneric whenFlagEvaluatedWithDefault() {
  return when3<String, String, String, StepWorld>(
    RegExp(r'an? (boolean|string|integer|float|object) flag with key "([^"]+)" is evaluated with default value "?([^"]*)"?'),
    (type, key, defaultValue, context) async {
      final world = context.world;

      // Seed flags for your InMemoryProvider
      switch (key) {
        case 'boolean-flag':
          world.provider.setFlag(key, true);
          break;
        case 'string-flag':
          world.provider.setFlag(key, 'hi');
          break;
        case 'integer-flag':
          world.provider.setFlag(key, 10);
          break;
        case 'float-flag':
          world.provider.setFlag(key, 0.5);
          break;
        case 'object-flag':
          world.provider.setFlag(key, {
            'showImages': true,
            'title': 'Check out these pics!',
            'imagesPerPage': 100,
          });
          break;
        default:
          // no flag seed needed, use default in evaluation
          break;
      }

      // Evaluate the flag with your IntelliToggleClient
      switch (type) {
        case 'boolean':
          world.lastResult = await world.client.getBooleanValue(key, defaultValue.toLowerCase() == 'true');
          break;
        case 'string':
          world.lastResult = await world.client.getStringValue(key, defaultValue);
          break;
        case 'integer':
          world.lastResult = await world.client.getIntegerValue(key, int.tryParse(defaultValue) ?? 0);
          break;
        case 'float':
          world.lastResult = await world.client.getDoubleValue(key, double.tryParse(defaultValue) ?? 0.0);
          break;
        case 'object':
          world.lastResult = await world.client.getObjectValue(key, {});
          break;
        default:
          throw Exception('Unsupported flag type $type');
      }
    },
  );
}

// THEN the resolved value should be
StepDefinitionGeneric thenResolvedValueShouldBe() {
  return then2<String, String, StepWorld>(
    RegExp(r'the resolved (boolean|string|integer|float|object) value should be "([^"]*)"'),
    (type, expected, context) async {
      final actual = context.world.lastResult;
      switch (type) {
        case 'boolean':
          expect(actual.toString(), expected);
          break;
        case 'string':
          expect(actual, expected);
          break;
        case 'integer':
          expect(actual.toString(), expected);
          break;
        case 'float':
          expect((actual as double).toString(), expected);
          break;
        case 'object':
          final map = actual as Map<String, dynamic>;
          expect(map['showImages'].toString(), 'true');
          expect(map['title'], 'Check out these pics!');
          expect(map['imagesPerPage'].toString(), '100');
          break;
        default:
          throw Exception('Unsupported flag type $type');
      }
    },
  );
}

// WHEN flag evaluated with details (FlagEvaluationResult)
StepDefinitionGeneric whenFlagEvaluatedWithDetails() {
  return when3<String, String, String, StepWorld>(
    RegExp(r'(boolean|string|integer|float|object) flag with key "([^"]+)" is evaluated with details and default value "([^"]*)"'),
    (type, key, defaultValue, context) async {
      final world = context.world;

      // Seed flags same as above
      switch (key) {
        case 'boolean-flag':
          world.provider.setFlag(key, true);
          break;
        case 'string-flag':
          world.provider.setFlag(key, 'hi');
          break;
        case 'integer-flag':
          world.provider.setFlag(key, 10);
          break;
        case 'float-flag':
          world.provider.setFlag(key, 0.5);
          break;
        case 'object-flag':
          world.provider.setFlag(key, {
            'showImages': true,
            'title': 'Check out these pics!',
            'imagesPerPage': 100,
          });
          break;
        default:
          break;
      }

      switch (type) {
  case 'boolean':
    final value = await world.featureClient.getBooleanFlag(key);
    world.lastDetails = FlagEvaluationResult<bool>(value, 'default-variant', 'default-reason');
    break;
  case 'string':
    final value = await world.featureClient.getStringFlag(key);
    world.lastDetails = FlagEvaluationResult<String>(value, 'default-variant', 'default-reason');
    break;
  case 'integer':
    final value = await world.featureClient.getIntegerFlag(key);
    world.lastDetails = FlagEvaluationResult<int>(value, 'default-variant', 'default-reason');
    break;
  case 'float':
    final value = await world.featureClient.getDoubleFlag(key);
    world.lastDetails = FlagEvaluationResult<double>(value, 'default-variant', 'default-reason');
    break;
  case 'object':
    final value = await world.featureClient.getObjectFlag(key);
    world.lastDetails = FlagEvaluationResult<Map<String, dynamic>>(value, 'default-variant', 'default-reason');
    break;
  default:
    throw Exception('Unsupported flag type $type');
}
    },
  );
}

// THEN detailed flag result should match
StepDefinitionGeneric thenDetailsShouldMatch() {
  return then4<String, String, String, String, StepWorld>(
    RegExp(r'the resolved (boolean|string|integer|float|object) details value should be "([^"]*)", the variant should be "([^"]*)", and the reason should be "([^"]*)"'),
    (type, expectedValue, expectedVariant, expectedReason, context) async {
      final details = context.world.lastDetails!;
      expect(details.value.toString(), expectedValue);
      expect(details.variant, expectedVariant);
      expect(details.reason, expectedReason);
    },
  );
}

// OPTIONAL: simple debug step if needed
StepDefinitionGeneric debugStepSimple() {
  return given1<String, StepWorld>(
    'some debug step',
    (arg1, context) async {
      print('DEBUG: $arg1');
    },
  );
}

// Collect all steps
List<StepDefinitionGeneric> steps = [
  givenStableProvider(),
  whenFlagEvaluatedWithDefault(),
  thenResolvedValueShouldBe(),
  whenFlagEvaluatedWithDetails(),
  thenDetailsShouldMatch(),
  debugStepSimple(),
];
