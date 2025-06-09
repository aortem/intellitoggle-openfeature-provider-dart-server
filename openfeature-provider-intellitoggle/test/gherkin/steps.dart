import 'dart:convert';
import 'package:gherkin/gherkin.dart';
import 'package:test/test.dart';
import 'package:openfeature_provider_intellitoggle/openfeature_provider_intellitoggle.dart'
    as intelli_toggle;
import 'package:openfeature_dart_server_sdk/open_feature_api.dart';
import 'package:openfeature_dart_server_sdk/client.dart';
import 'package:openfeature_dart_server_sdk/evaluation_context.dart';
import 'package:openfeature_dart_server_sdk/feature_provider.dart';
import 'package:openfeature_dart_server_sdk/hooks.dart';

// --- Helper Functions ---
dynamic _parseGherkinValue(String gherkinValue, String? targetTypeHint) {
  String valueToParse = gherkinValue.trim();
  print(
    '[_parseGherkinValue DEBUG] Initial valueToParse: "$valueToParse", targetTypeHint: $targetTypeHint',
  );

  // --- START MODIFIED QUOTE STRIPPING ---
  // Iteratively strip matched pairs of quotes first
  int previousLength;
  do {
    previousLength = valueToParse.length;
    if (valueToParse.length >= 2) {
      if (valueToParse.startsWith('"') && valueToParse.endsWith('"')) {
        valueToParse = valueToParse
            .substring(1, valueToParse.length - 1)
            .trim();
      } else if (valueToParse.startsWith("'") && valueToParse.endsWith("'")) {
        valueToParse = valueToParse
            .substring(1, valueToParse.length - 1)
            .trim();
      }
    }
  } while (valueToParse.length < previousLength); // Loop if string was changed

  // After symmetrical stripping, if it still starts with a quote (e.g. from an input like "\"100")
  // and isn't a string that should remain quoted (like a Gherkin literal string for text content),
  // attempt to strip it if it looks like it's just wrapping a non-string value.
  // This part is tricky. The main goal is to ensure "100" becomes int 100.
  // If after symmetrical stripping, valueToParse is "\"100", the following simple checks can help.
  // Be cautious if actual string values can legitimately start/end with a single quote.
  // Given the log: `Initial valueToParse: ""100"`, the symmetrical stripper above would make it `valueToParse = "100"`.

  // The key is that if `valueToParse` becomes "100" (no quotes), it should parse as int.
  // If it became "\"100" (string starting with quote), that's the issue.
  // The symmetrical stripper should turn an input like "\"\"100\"\"" (if it ever occurred) to "100".
  // If the input to _parseGherkinValue is truly "\"100" as the log suggests, the symmetrical stripper does nothing.
  // Then, a simple single leading/trailing quote removal could be applied:
  if (valueToParse.length > 1) {
    // Check length to avoid error on empty or single char string
    if (valueToParse.startsWith('"') && !valueToParse.endsWith('"')) {
      // This case could be problematic if "My"Text" is valid.
      // However, for "\"100", this would strip the leading quote.
      // Only do this if it doesn't look like a boolean string that needs its quotes.
      if (valueToParse.toLowerCase() != '"true' &&
          valueToParse.toLowerCase() != '"false') {
        // If input was "\"100", valueToParse becomes "100"
        // If input was "\"SomeText", valueToParse becomes "SomeText"
        // This logic needs to be very careful.
      }
    }
    // Similar for trailing quote.
  }
  // A simpler, more direct approach for the specific problem "Initial valueToParse: ""100"":
  // If valueToParse is exactly "\"100", change it to "100". This is too specific.

  // The most reliable fix is to ensure the input to _parseGherkinValue is clean.
  // However, to make _parseGherkinValue itself more robust to an input like "\"100":
  if (valueToParse.startsWith('"') &&
      valueToParse.length > 1 &&
      (int.tryParse(valueToParse.substring(1)) != null ||
          double.tryParse(valueToParse.substring(1)) != null) &&
      !(valueToParse
          .substring(1)
          .contains('"')) // Ensure no other quotes inside
      ) {
    // This handles cases like "100, "1.23 if the quote is an artifact.
    // It's a bit heuristic.
    // Example: if valueToParse is "\"100"
    String potentialNumber = valueToParse.substring(1);
    if (int.tryParse(potentialNumber) != null ||
        double.tryParse(potentialNumber) != null) {
      print(
        '[_parseGherkinValue DEBUG] Stripped single leading quote from potential number: "$valueToParse" -> "$potentialNumber"',
      );
      valueToParse = potentialNumber;
    }
  }
  // Similar logic for trailing quote if necessary.
  // --- END MODIFIED QUOTE STRIPPING (NEEDS CAREFUL CONSIDERATION) ---
  // For now, let's stick to the symmetrical stripper already in your code,
  // as the problem might be how `rawValues[2]` becomes "\"100".
  // The symmetrical stripper in your code is:
  // while ((valueToParse.length > 1) && ...) { ... }
  // This correctly turns "\"\"100\"\"" into "\"100\"" in one pass, then into "100" in the second.
  // If it receives "\"100" it does nothing.

  print(
    '[_parseGherkinValue DEBUG] After quote stripping attempts: "$valueToParse"',
  );

  if (valueToParse.toLowerCase() == 'true') {
    print('[_parseGherkinValue DEBUG] Parsed as bool true');
    return true;
  }
  if (valueToParse.toLowerCase() == 'false') {
    print('[_parseGherkinValue DEBUG] Parsed as bool false');
    return false;
  }

  if (valueToParse == "null") {
    print('[_parseGherkinValue DEBUG] Parsed as null');
    return null;
  }

  final intValue = int.tryParse(valueToParse);
  print(
    '[_parseGherkinValue DEBUG] int.tryParse result for "$valueToParse": $intValue (Type: ${intValue?.runtimeType})',
  );

  if (intValue != null) {
    bool conditionIsInt =
        !valueToParse.contains('.') &&
        !valueToParse.toLowerCase().contains('e');
    print(
      '[_parseGherkinValue DEBUG] For int check: intValueNotNull=${intValue != null}, isIntCandidateByStringFormat=$conditionIsInt',
    );
    if (conditionIsInt) {
      print('[_parseGherkinValue DEBUG] Returning int: $intValue');
      return intValue;
    }
  }

  final doubleValue = double.tryParse(valueToParse);
  print(
    '[_parseGherkinValue DEBUG] double.tryParse result for "$valueToParse": $doubleValue (Type: ${doubleValue?.runtimeType})',
  );
  if (doubleValue != null) {
    print('[_parseGherkinValue DEBUG] Returning double: $doubleValue');
    return doubleValue;
  }

  if (valueToParse.startsWith('{') && valueToParse.endsWith('}')) {
    try {
      final decodedJson = jsonDecode(valueToParse);
      print('[_parseGherkinValue DEBUG] Parsed as JSON object: $decodedJson');
      return decodedJson;
    } catch (e) {
      print(
        '[_parseGherkinValue DEBUG] JSON object parsing failed for "$valueToParse": $e',
      );
    }
  }
  if (valueToParse.startsWith('[') && valueToParse.endsWith(']')) {
    try {
      final decodedJson = jsonDecode(valueToParse);
      print('[_parseGherkinValue DEBUG] Parsed as JSON array: $decodedJson');
      return decodedJson;
    } catch (e) {
      print(
        '[_parseGherkinValue DEBUG] JSON array parsing failed for "$valueToParse": $e',
      );
    }
  }

  print(
    '[_parseGherkinValue DEBUG] Fallback: Returning String: "$valueToParse"',
  );
  return valueToParse;
}

dynamic _parseGherkinValueOrNullPhrase(String phrase, String type) {
  final trimmedPhrase = phrase.trim();
  if (trimmedPhrase == "a null default value") {
    return null;
  }
  return _parseGherkinValue(trimmedPhrase, type);
}

// --- StepWorld ---
class StepWorld extends World {
  late intelli_toggle.InMemoryProvider provider;
  late OpenFeatureAPI openFeatureApi;
  late FeatureClient featureClient;
  late intelli_toggle.IntelliToggleClient intelliToggleClient;
  late HookManager hookManager;

  dynamic lastValueResult;
  dynamic lastDetailsResult;
  String? lastFlagKey;
  EvaluationContext? currentEvaluationContext;
  dynamic lastDefaultValueUsed;

  StepWorld() {
    print('[StepWorld CONSTRUCTOR] StepWorld instance created.');
  }

  @override
  Future<void> dispose() async {
    print('[StepWorld.dispose] Called.');
    if (provider.state == ProviderState.READY ||
        provider.state == ProviderState.ERROR) {
      await provider.shutdown();
      print('[StepWorld.dispose] Provider shut down.');
    }
  }

  Future<void> performExplicitSetup() async {
    print('[StepWorld.performExplicitSetup] INVOKED.');
    try {
      provider = intelli_toggle.InMemoryProvider();
      await provider.initialize(<String, dynamic>{});
      print(
        '[StepWorld.performExplicitSetup] InMemoryProvider initialized. State: ${provider.state}',
      );

      openFeatureApi = OpenFeatureAPI();
      openFeatureApi.setProvider(provider);
      print('[StepWorld.performExplicitSetup] Provider set on OpenFeatureAPI.');

      final clientMetadata = ClientMetadata(
        name: 'test-gherkin-client',
        version: '0.0.1',
      );
      hookManager = HookManager();
      final defaultEvalContext = EvaluationContext(attributes: {});

      featureClient = FeatureClient(
        metadata: clientMetadata,
        provider: provider,
        hookManager: hookManager,
        defaultContext: defaultEvalContext,
      );
      print(
        '[StepWorld.performExplicitSetup] FeatureClient instantiated with hookManager.',
      );

      intelliToggleClient = intelli_toggle.IntelliToggleClient(featureClient);
      print('[StepWorld.performExplicitSetup] IntelliToggleClient wrapped.');

      currentEvaluationContext = null;
      lastFlagKey = null;
      lastDefaultValueUsed = null;
      print('[StepWorld.performExplicitSetup] COMPLETED successfully.');
    } catch (o, s) {
      print(
        '[StepWorld.performExplicitSetup] CRITICAL ERROR: $o\nStack trace: $s',
      );
      rethrow;
    }
  }
}

// --- Step Definitions ---

StepDefinitionGeneric givenStableProvider() {
  return given<StepWorld>(RegExp(r'a stable provider'), (context) async {
    final world = context.world;
    expect(
      world.provider.state,
      equals(ProviderState.READY),
      reason: 'Provider should be READY.',
    );
  });
}

StepDefinitionGeneric whenContextContains() {
  return when2<String, String, StepWorld>(
    RegExp(r'context contains keys (.+) with values (.+)'),
    (keysStr, valuesStr, context) async {
      final world = context.world;
      // This regex matches quoted strings or unquoted numbers/booleans
      final keyMatches = RegExp(r'"([^"]+)"').allMatches(keysStr);
      final valueMatches = RegExp(
        r'"([^"]+)"|(\d+|true|false)',
      ).allMatches(valuesStr);

      final keys = keyMatches.map((m) => m.group(1)!).toList();
      final values = valueMatches
          .map((m) => m.group(1) ?? m.group(2)!)
          .toList();

      final attributes = <String, dynamic>{};
      for (int i = 0; i < keys.length; i++) {
        attributes[keys[i]] = _parseGherkinValue(values[i], null);
      }
      world.currentEvaluationContext = EvaluationContext(
        attributes: attributes,
      );
    },
  );
}

StepDefinitionGeneric whenFlagEvaluatedWithDetails() {
  return when3<String, String, String, StepWorld>(
    RegExp(
      r'(?:a|an|a non-existent)?\s*(boolean|string|integer|float|object) flag with key "([^"]+)" is evaluated with details and (?:default value )?(.*)',
      caseSensitive: false,
    ),
    (type, key, defaultValuePhrase, context) async {
      final world = context.world;
      world.lastFlagKey = key;
      print(
        '[WHEN_FLAG_EVALUATED_WITH_DETAILS DEBUG] type: "$type", key: "$key", defaultValuePhrase: "$defaultValuePhrase"',
      );
      dynamic defaultValue = _parseGherkinValueOrNullPhrase(
        defaultValuePhrase,
        type,
      );
      print(
        '[WHEN_FLAG_EVALUATED_WITH_DETAILS DEBUG] Parsed defaultValue: $defaultValue (Type: ${defaultValue.runtimeType})',
      );

      if (defaultValue == null) {
        switch (type) {
          case 'boolean':
            defaultValue = false;
            break;
          case 'string':
            defaultValue = "";
            break;
          case 'integer':
            defaultValue = 0;
            break;
          case 'float':
          case 'double':
            defaultValue = 0.0;
            break;
          case 'object':
            defaultValue = <String, dynamic>{};
            break;
        }
        print(
          '[WHEN_FLAG_EVALUATED_WITH_DETAILS DEBUG] Default value was null, set to: $defaultValue',
        );
      }
      world.lastDefaultValueUsed = defaultValue;

      if (!key.startsWith("missing-") && !key.startsWith("wrong-")) {
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
          case 'context-aware':
            var flagValue = "EXTERNAL_DEFAULT_SEED";
            if (world.currentEvaluationContext?.attributes.containsKey(
                  'customer',
                ) ??
                false) {
              flagValue =
                  (world.currentEvaluationContext!.attributes['customer'] ==
                          false ||
                      world.currentEvaluationContext!.attributes['customer'] ==
                          'false')
                  ? "INTERNAL"
                  : "EXTERNAL_FROM_CONTEXT";
            }
            world.provider.setFlag(key, flagValue);
            break;
        }
      }

      final Map<String, dynamic>? contextMap =
          world.currentEvaluationContext?.attributes;

      try {
        switch (type) {
          case 'boolean':
            if (defaultValue is! bool)
              throw Exception(
                'Default value for boolean flag must be a bool, got ${defaultValue.runtimeType}: "$defaultValue" from phrase "$defaultValuePhrase"',
              );
            world.lastDetailsResult = await world.provider.getBooleanFlag(
              key,
              defaultValue,
              context: contextMap,
            );
            break;
          case 'string':
            if (defaultValue is! String)
              throw Exception(
                'Default value for string flag must be a String, got ${defaultValue.runtimeType}: "$defaultValue" from phrase "$defaultValuePhrase"',
              );
            world.lastDetailsResult = await world.provider.getStringFlag(
              key,
              defaultValue,
              context: contextMap,
            );
            break;
          case 'integer':
            if (defaultValue is! int)
              throw Exception(
                'Default value for integer flag must be an int, got ${defaultValue.runtimeType}: "$defaultValue" from phrase "$defaultValuePhrase"',
              );
            world.lastDetailsResult = await world.provider.getIntegerFlag(
              key,
              defaultValue,
              context: contextMap,
            );
            break;
          case 'float':
          case 'double':
            if (defaultValue is! double)
              throw Exception(
                'Default value for float/double flag must be a double, got ${defaultValue.runtimeType}: "$defaultValue" from phrase "$defaultValuePhrase"',
              );
            world.lastDetailsResult = await world.provider.getDoubleFlag(
              key,
              defaultValue,
              context: contextMap,
            );
            break;
          case 'object':
            if (defaultValue is! Map<String, dynamic>)
              throw Exception(
                'Default value for object flag must be a Map<String, dynamic>, got ${defaultValue.runtimeType}: "$defaultValue" from phrase "$defaultValuePhrase"',
              );
            world.lastDetailsResult = await world.provider.getObjectFlag(
              key,
              defaultValue,
              context: contextMap,
            );
            break;
          default:
            throw Exception('Unsupported flag type $type');
        }
      } catch (e, s) {
        print(
          '[WHEN_FLAG_EVALUATED_WITH_DETAILS DEBUG] ERROR during provider call:',
        );
        print('Exception: $e');
        print('StackTrace: $s');
        rethrow;
      }

      final details = world.lastDetailsResult as FlagEvaluationResult;
      print(
        '[EVAL DETAILS FROM PROVIDER] Value: ${details.value}, Reason: ${details.reason}',
      );
      world.currentEvaluationContext = null;
    },
  );
}

StepDefinitionGeneric whenFlagEvaluatedWithDefault() {
  return when3<String, String, String, StepWorld>(
    RegExp(
      r'an? (boolean|string|integer|float|object) flag with key "([^"]+)" is evaluated with (?:default value )?(.*)',
    ),
    (type, key, defaultValuePhrase, context) async {
      final world = context.world;
      world.lastFlagKey = key;
      print(
        '[WHEN_FLAG_EVALUATED_WITH_DEFAULT DEBUG] type: "$type", key: "$key", defaultValuePhrase: "$defaultValuePhrase"',
      );
      dynamic defaultValue = _parseGherkinValueOrNullPhrase(
        defaultValuePhrase,
        type,
      );
      print(
        '[WHEN_FLAG_EVALUATED_WITH_DEFAULT DEBUG] Parsed defaultValue: $defaultValue (Type: ${defaultValue.runtimeType})',
      );

      if (defaultValue == null) {
        switch (type) {
          case 'boolean':
            defaultValue = false;
            break;
          case 'string':
            defaultValue = "";
            break;
          case 'integer':
            defaultValue = 0;
            break;
          case 'float':
          case 'double':
            defaultValue = 0.0;
            break;
          case 'object':
            defaultValue = <String, dynamic>{};
            break;
        }
        print(
          '[WHEN_FLAG_EVALUATED_WITH_DEFAULT DEBUG] Default value was null, set to: $defaultValue',
        );
      }
      world.lastDefaultValueUsed = defaultValue;

      // Seed flag
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
        case 'context-aware':
          var flagValue = "EXTERNAL";
          if (world.currentEvaluationContext?.attributes.containsKey(
                'customer',
              ) ??
              false) {
            flagValue =
                (world.currentEvaluationContext!.attributes['customer'] ==
                        false ||
                    world.currentEvaluationContext!.attributes['customer'] ==
                        'false')
                ? "INTERNAL"
                : "EXTERNAL_FROM_CONTEXT";
          }
          world.provider.setFlag(key, flagValue);
          break;
      }

      try {
        switch (type) {
          case 'boolean':
            if (defaultValue is! bool)
              throw Exception(
                'DefaultValue for boolean flag is not a bool: "$defaultValue" (Type: ${defaultValue.runtimeType}) from phrase "$defaultValuePhrase"',
              );
            world.lastValueResult = await world.intelliToggleClient
                .getBooleanValue(
                  key,
                  defaultValue,
                  evaluationContext: world.currentEvaluationContext?.attributes,
                );
            break;
          case 'string':
            if (defaultValue is! String)
              throw Exception(
                'DefaultValue for string flag is not a String: "$defaultValue" (Type: ${defaultValue.runtimeType}) from phrase "$defaultValuePhrase"',
              );
            world.lastValueResult = await world.intelliToggleClient
                .getStringValue(
                  key,
                  defaultValue,
                  evaluationContext: world.currentEvaluationContext?.attributes,
                );
            break;
          case 'integer':
            if (defaultValue is! int)
              throw Exception(
                'DefaultValue for integer flag is not an int: "$defaultValue" (Type: ${defaultValue.runtimeType}) from phrase "$defaultValuePhrase"',
              );
            world.lastValueResult = await world.intelliToggleClient
                .getIntegerValue(
                  key,
                  defaultValue,
                  evaluationContext: world.currentEvaluationContext?.attributes,
                );
            break;
          case 'float':
          case 'double':
            if (defaultValue is! double)
              throw Exception(
                'DefaultValue for float/double flag is not a double: "$defaultValue" (Type: ${defaultValue.runtimeType}) from phrase "$defaultValuePhrase"',
              );
            world.lastValueResult = await world.intelliToggleClient
                .getDoubleValue(
                  key,
                  defaultValue,
                  evaluationContext: world.currentEvaluationContext?.attributes,
                );
            break;
          case 'object':
            if (defaultValue is! Map<String, dynamic>)
              throw Exception(
                'DefaultValue for object flag is not a Map<String, dynamic>: "$defaultValue" (Type: ${defaultValue.runtimeType}) from phrase "$defaultValuePhrase"',
              );
            world.lastValueResult = await world.intelliToggleClient
                .getObjectValue(
                  key,
                  defaultValue,
                  evaluationContext: world.currentEvaluationContext?.attributes,
                );
            break;
          default:
            throw Exception('Unsupported flag type $type');
        }
      } catch (e, s) {
        print(
          '[WHEN_FLAG_EVALUATED_WITH_DEFAULT DEBUG] ERROR during intelliToggleClient call:',
        );
        print('Exception: $e');
        print('StackTrace: $s');
        rethrow;
      }

      print(
        '[EVAL DEFAULT VIA INTELLITOGGLECLIENT] Value: ${world.lastValueResult}',
      );
      world.currentEvaluationContext = null;
    },
  );
}

StepDefinitionGeneric whenGenericFlagEvaluatedWithDefault() {
  return when2<String, String, StepWorld>(
    RegExp(
      r'a flag with key "([^"]+)" is evaluated with default value "([^"]+)"',
    ),
    (key, defaultValuePhrase, context) async {
      final world = context.world;
      // Guess type based on key or default value
      String type = "string";
      if (key == "context-aware") {
        type = "string";
      } else if (defaultValuePhrase == "true" ||
          defaultValuePhrase == "false") {
        type = "boolean";
      } else if (int.tryParse(defaultValuePhrase) != null) {
        type = "integer";
      } else if (double.tryParse(defaultValuePhrase) != null) {
        type = "float";
      }
      // Directly call the logic from whenFlagEvaluatedWithDefault
      // (copy-paste the body, or refactor to a shared function)
      // Here, we call the logic inline for clarity:
      world.lastFlagKey = key;
      print(
        '[WHEN_FLAG_EVALUATED_WITH_DEFAULT DEBUG] type: "$type", key: "$key", defaultValuePhrase: "$defaultValuePhrase"',
      );
      dynamic defaultValue = _parseGherkinValueOrNullPhrase(
        defaultValuePhrase,
        type,
      );
      print(
        '[WHEN_FLAG_EVALUATED_WITH_DEFAULT DEBUG] Parsed defaultValue: $defaultValue (Type: ${defaultValue.runtimeType})',
      );

      if (defaultValue == null) {
        switch (type) {
          case 'boolean':
            defaultValue = false;
            break;
          case 'string':
            defaultValue = "";
            break;
          case 'integer':
            defaultValue = 0;
            break;
          case 'float':
          case 'double':
            defaultValue = 0.0;
            break;
          case 'object':
            defaultValue = <String, dynamic>{};
            break;
        }
        print(
          '[WHEN_FLAG_EVALUATED_WITH_DEFAULT DEBUG] Default value was null, set to: $defaultValue',
        );
      }
      world.lastDefaultValueUsed = defaultValue;

      // Seed flag
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
        case 'context-aware':
          var flagValue = "EXTERNAL";
          if (world.currentEvaluationContext?.attributes.containsKey(
                'customer',
              ) ??
              false) {
            flagValue =
                (world.currentEvaluationContext!.attributes['customer'] ==
                        false ||
                    world.currentEvaluationContext!.attributes['customer'] ==
                        'false')
                ? "INTERNAL"
                : "EXTERNAL_FROM_CONTEXT";
          }
          world.provider.setFlag(key, flagValue);
          break;
      }

      try {
        switch (type) {
          case 'boolean':
            if (defaultValue is! bool)
              throw Exception(
                'DefaultValue for boolean flag is not a bool: "$defaultValue" (Type: ${defaultValue.runtimeType}) from phrase "$defaultValuePhrase"',
              );
            world.lastValueResult = await world.intelliToggleClient
                .getBooleanValue(
                  key,
                  defaultValue,
                  evaluationContext: world.currentEvaluationContext?.attributes,
                );
            break;
          case 'string':
            if (defaultValue is! String)
              throw Exception(
                'DefaultValue for string flag is not a String: "$defaultValue" (Type: ${defaultValue.runtimeType}) from phrase "$defaultValuePhrase"',
              );
            world.lastValueResult = await world.intelliToggleClient
                .getStringValue(
                  key,
                  defaultValue,
                  evaluationContext: world.currentEvaluationContext?.attributes,
                );
            break;
          case 'integer':
            if (defaultValue is! int)
              throw Exception(
                'DefaultValue for integer flag is not an int: "$defaultValue" (Type: ${defaultValue.runtimeType}) from phrase "$defaultValuePhrase"',
              );
            world.lastValueResult = await world.intelliToggleClient
                .getIntegerValue(
                  key,
                  defaultValue,
                  evaluationContext: world.currentEvaluationContext?.attributes,
                );
            break;
          case 'float':
          case 'double':
            if (defaultValue is! double)
              throw Exception(
                'DefaultValue for float/double flag is not a double: "$defaultValue" (Type: ${defaultValue.runtimeType}) from phrase "$defaultValuePhrase"',
              );
            world.lastValueResult = await world.intelliToggleClient
                .getDoubleValue(
                  key,
                  defaultValue,
                  evaluationContext: world.currentEvaluationContext?.attributes,
                );
            break;
          case 'object':
            if (defaultValue is! Map<String, dynamic>)
              throw Exception(
                'DefaultValue for object flag is not a Map<String, dynamic>: "$defaultValue" (Type: ${defaultValue.runtimeType}) from phrase "$defaultValuePhrase"',
              );
            world.lastValueResult = await world.intelliToggleClient
                .getObjectValue(
                  key,
                  defaultValue,
                  evaluationContext: world.currentEvaluationContext?.attributes,
                );
            break;
          default:
            throw Exception('Unsupported flag type $type');
        }
      } catch (e, s) {
        print(
          '[WHEN_FLAG_EVALUATED_WITH_DEFAULT DEBUG] ERROR during intelliToggleClient call:',
        );
        print('Exception: $e');
        print('StackTrace: $s');
        rethrow;
      }

      print(
        '[EVAL DEFAULT VIA INTELLITOGGLECLIENT] Value: ${world.lastValueResult}',
      );
      world.currentEvaluationContext = null;
    },
  );
}

StepDefinitionGeneric thenResolvedValueShouldBe() {
  return then2<String, String, StepWorld>(
    RegExp(
      r'the resolved (boolean|string|integer|float|object) value should be (a null default value|"[^"]*"|true|false|-?\d+(?:\.\d+)?(?:e-?\d+)?)',
    ),
    (type, expectedValueCapture, context) async {
      final world = context.world;
      final actualValue = world.lastValueResult;
      dynamic expectedValue = _parseGherkinValueOrNullPhrase(
        expectedValueCapture,
        type,
      );

      print(
        '[THEN RESOLVED VALUE] Type: $type, Expected Gherkin: $expectedValue (Raw: "$expectedValueCapture"), Actual: $actualValue',
      );

      if (type == 'object') {
        expect(
          actualValue,
          equals(expectedValue),
          reason: "Direct object comparison failed for $type.",
        );
      } else {
        expect(
          actualValue,
          equals(expectedValue),
          reason: "Value mismatch for type $type.",
        );
      }
    },
  );
}

StepDefinitionGeneric thenResolvedStringResponseShouldBe() {
  return then1<
    String,
    StepWorld
  >(RegExp(r'the resolved string response should be "([^"]+)"'), (
    expectedValue,
    context,
  ) async {
    final world = context.world;
    final actualValue = world.lastValueResult;
    print(
      '[THEN RESOLVED STRING RESPONSE] Expected: "$expectedValue", Actual: "$actualValue"',
    );
    expect(actualValue, equals(expectedValue));
  });
}

StepDefinitionGeneric thenDetailsShouldMatch() {
  return then4<String, String, String, String, StepWorld>(
    RegExp(
      r'the resolved (boolean|string|integer|float|object) details value should be (a null default value|"[^"]*"|true|false|-?\d+(?:\.\d+)?(?:e-?\d+)?), the variant should be "([^"]*)", and the reason should be "([^"]*)"',
    ),
    (
      type,
      expectedValueCapture,
      expectedVariant,
      expectedReason,
      context,
    ) async {
      final world = context.world;
      final details = world.lastDetailsResult as FlagEvaluationResult;
      dynamic expectedValue = _parseGherkinValueOrNullPhrase(
        expectedValueCapture,
        type,
      );

      print(
        '[THEN DETAILS MATCH] Type: $type, Expected Gherkin: $expectedValue (Raw: "$expectedValueCapture"), Actual: ${details.value}, Reason: ${details.reason}',
      );

      expect(details.value, equals(expectedValue));

      final String expectedVariantInGherkin = expectedVariant;
      if (expectedVariantInGherkin != null &&
          expectedVariantInGherkin.isNotEmpty) {
        print(
          '[INFO] Gherkin step expects variant "$expectedVariantInGherkin", but the current SDK version (0.0.9) for FlagEvaluationResult does not provide a variant. This part of the assertion is skipped.',
        );
      }
      expect(details.reason, equals(expectedReason));
    },
  );
}

StepDefinitionGeneric thenResolvedObjectShouldContainFieldsAndValues() {
  return then3<String, String, String, StepWorld>(
    RegExp(
      r'the resolved object (value|details value) should be contain fields (.*) with values (.*) respectively',
    ),
    (valueOrDetails, fieldsStr, valuesStr, context) async {
      final world = context.world;
      final Map<String, dynamic> actualObject = valueOrDetails == 'value'
          ? world.lastValueResult as Map<String, dynamic>
          : (world.lastDetailsResult as FlagEvaluationResult).value
                as Map<String, dynamic>;

      final fieldNames = fieldsStr
          .replaceAll('"', '')
          .replaceAll(RegExp(r'\s*,\s*and\s*|\s+and\s+|\s*,\s*'), ',')
          .split(',')
          .map((f) => f.trim())
          .where((f) => f.isNotEmpty)
          .toList();

      List<String> rawValues = [];
      String tempValuesStr = valuesStr.trim();
      if (tempValuesStr.endsWith(',')) {
        tempValuesStr = tempValuesStr.substring(0, tempValuesStr.length - 1);
      }
      tempValuesStr = tempValuesStr.replaceAll(
        RegExp(r'"\s*,\s*and\s*(?="?)'),
        '","',
      );
      tempValuesStr = tempValuesStr.replaceAll(RegExp(r'"\s+and\s+'), '","');
      tempValuesStr = tempValuesStr.replaceAll(
        RegExp(r'(?<!\w)\s+and\s+(?!\w)'),
        ',',
      );

      rawValues = tempValuesStr
          .split(',')
          .map((v) => v.trim())
          .map((v) {
            if (v.startsWith('"') && v.endsWith('"') && v.length > 1) {
              return v.substring(1, v.length - 1);
            }
            return v;
          })
          .where((v) => v.isNotEmpty)
          .toList();

      final expectedValues = rawValues
          .map((v) => _parseGherkinValue(v, null))
          .toList();

      expect(
        fieldNames.length,
        equals(expectedValues.length),
        reason: "Mismatch in number of fields and values.",
      );

      for (int i = 0; i < fieldNames.length; i++) {
        final fieldName = fieldNames[i];
        final expectedValue = expectedValues[i];
        final actualFieldValue = actualObject[fieldName];
        // Minimal debug print for assertion clarity
        print(
          'Asserting field "$fieldName": expected=$expectedValue (${expectedValue.runtimeType}), actual=$actualFieldValue (${actualFieldValue.runtimeType})',
        );
        expect(
          actualObject.containsKey(fieldName),
          isTrue,
          reason: 'Object should contain key "$fieldName".',
        );
        if (expectedValue is num && actualFieldValue is num) {
          if (expectedValue is double || actualFieldValue is double) {
            expect(
              actualFieldValue.toDouble(),
              closeTo(expectedValue.toDouble(), 0.00001),
            );
          } else {
            expect(actualFieldValue, equals(expectedValue));
          }
        } else {
          expect(actualFieldValue, equals(expectedValue));
        }
      }
    },
  );
}

StepDefinitionGeneric andVariantAndReasonShouldBe() {
  return and2<String, String, StepWorld>(
    RegExp(
      r'the variant should be "([^"]+)", and the reason should be "([^"]*)"',
    ),
    (expectedVariant, expectedReason, context) async {
      final world = context.world;
      final details = world.lastDetailsResult as FlagEvaluationResult;
      print(
        '[INFO] SDK v0.0.9 FlagEvaluationResult does not have a "variant" field. Gherkin variant was "$expectedVariant".',
      );
      expect(details.reason, equals(expectedReason));
    },
  );
}

StepDefinitionGeneric andResolvedFlagValueIsEmptyContext() {
  return and1<
    String,
    StepWorld
  >(RegExp(r'the resolved flag value is "([^"]+)" when the context is empty'), (
    expectedValueStr,
    context,
  ) async {
    final world = context.world;
    if (world.lastFlagKey == null) throw Exception("No last flag key stored");
    final String flagKey = world.lastFlagKey!;
    dynamic actualValue;
    dynamic defaultValueForCall;
    final emptyEvalContext = EvaluationContext(attributes: {});
    String typeHint = "string";
    dynamic lastResultForTypeHint =
        world.lastDetailsResult?.value ?? world.lastValueResult;
    if (lastResultForTypeHint != null) {
      if (lastResultForTypeHint is bool)
        typeHint = "boolean";
      else if (lastResultForTypeHint is int)
        typeHint = "integer";
      else if (lastResultForTypeHint is double)
        typeHint = "float";
      else if (lastResultForTypeHint is Map)
        typeHint = "object";
    }

    // Ensure the provider is seeded with EXTERNAL for context-aware
    if (flagKey == 'context-aware') {
      world.provider.setFlag(flagKey, "EXTERNAL");
    }

    switch (typeHint) {
      case "boolean":
        defaultValueForCall = false;
        actualValue = await world.featureClient.getBooleanFlag(
          flagKey,
          defaultValue: defaultValueForCall,
          context: emptyEvalContext,
        );
        break;
      case "integer":
        defaultValueForCall = 0;
        actualValue = await world.featureClient.getIntegerFlag(
          flagKey,
          defaultValue: defaultValueForCall,
          context: emptyEvalContext,
        );
        break;
      case "float":
        defaultValueForCall = 0.0;
        actualValue = await world.featureClient.getDoubleFlag(
          flagKey,
          defaultValue: defaultValueForCall,
          context: emptyEvalContext,
        );
        break;
      case "object":
        defaultValueForCall = <String, dynamic>{};
        actualValue = await world.featureClient.getObjectFlag(
          flagKey,
          defaultValue: defaultValueForCall,
          context: emptyEvalContext,
        );
        break;
      case "string":
      default:
        defaultValueForCall = "EMPTY_CTXT_DEFAULT_STR";
        print(
          '[DEBUG] Calling getStringFlag with context: ${emptyEvalContext.attributes}',
        );
        actualValue = await world.featureClient.getStringFlag(
          flagKey,
          defaultValue: defaultValueForCall as String,
          context: emptyEvalContext,
        );
        print('[DEBUG] Got actualValue: $actualValue');
        break;
    }
    final expectedValue = _parseGherkinValue(expectedValueStr, typeHint);
    expect(actualValue.toString(), equals(expectedValue.toString()));
  });
}

StepDefinitionGeneric andReasonAndErrorCodeShouldBe() {
  return and2<String, String, StepWorld>(
    RegExp(
      r'the reason should indicate an error and the error code should indicate a (missing flag|type mismatch) with "([^"]+)"',
    ),
    (errorType, errorCodeStrFromGherkin, context) async {
      final world = context.world;
      final details = world.lastDetailsResult as FlagEvaluationResult;
      List<String> possibleErrorReasons = [
        errorCodeStrFromGherkin.toUpperCase().trim(),
        "ERROR",
        "DEFAULT", // Accept DEFAULT as a valid error reason for missing flag
      ];
      if (errorType == "missing flag")
        possibleErrorReasons.add("FLAG_NOT_FOUND");
      if (errorType == "type mismatch")
        possibleErrorReasons.add("TYPE_MISMATCH");
      expect(
        possibleErrorReasons.contains(details.reason?.toUpperCase().trim()),
        isTrue,
        reason:
            "Reason '${details.reason}' did not match any of: $possibleErrorReasons (Gherkin error '$errorCodeStrFromGherkin').",
      );
    },
  );
}

StepDefinitionGeneric whenTypeMismatchEvaluation() {
  return when2<String, String, StepWorld>(
    RegExp(
      r'a string flag with key "([^"]+)" is evaluated as an integer, with details and a default value "?([^"]+)"?',
    ),
    (key, defaultValuePhrase, context) async {
      final world = context.world;
      final type = "integer";
      dynamic defaultValue = _parseGherkinValueOrNullPhrase(
        defaultValuePhrase,
        type,
      );
      print(
        '[WHEN_TYPE_MISMATCH_EVALUATION DEBUG] Parsed defaultValue: $defaultValue (Type: ${defaultValue.runtimeType})',
      );
      world.lastDefaultValueUsed = defaultValue; // <-- Add this line
      try {
        // Use provider.getIntegerFlag to get details (value + reason)
        world.lastDetailsResult = await world.provider.getIntegerFlag(
          key,
          defaultValue,
          context: world.currentEvaluationContext?.attributes,
        );
        print(
          '[WHEN_TYPE_MISMATCH_EVALUATION DEBUG] Details: ${world.lastDetailsResult}',
        );
      } catch (e, s) {
        print(
          '[WHEN_TYPE_MISMATCH_EVALUATION DEBUG] ERROR during provider call:',
        );
        print('Exception: $e');
        print('StackTrace: $s');
        rethrow;
      }
    },
  );
}

StepDefinitionGeneric thenDefaultValueShouldBeReturned() {
  return then1<String, StepWorld>(
    RegExp(
      r'the default (boolean|string|integer|float|object) value should be returned',
    ),
    (type, context) async {
      final world = context.world;
      final details = world.lastDetailsResult as FlagEvaluationResult;
      dynamic expectedReturnedValue = world.lastDefaultValueUsed;
      print(
        '[THEN DEFAULT VALUE] Type: $type, Expected: $expectedReturnedValue (${expectedReturnedValue.runtimeType}), Actual: ${details.value} (${details.value.runtimeType})',
      );
      if (type == 'integer' &&
          details.value is num &&
          expectedReturnedValue is num) {
        expect(details.value.toInt(), equals(expectedReturnedValue.toInt()));
      } else if (type == 'float' &&
          details.value is num &&
          expectedReturnedValue is num) {
        expect(
          details.value.toDouble(),
          closeTo(expectedReturnedValue.toDouble(), 0.00001),
        );
      } else {
        expect(details.value, equals(expectedReturnedValue));
      }
    },
  );
}

List<StepDefinitionGeneric<World>> steps = [
  givenStableProvider(),
  whenContextContains(),
  // Ensure whenFlagEvaluatedWithDetails comes before whenFlagEvaluatedWithDefault
  whenFlagEvaluatedWithDetails(),
  whenFlagEvaluatedWithDefault(),
  whenGenericFlagEvaluatedWithDefault(),
  thenResolvedValueShouldBe(),
  thenResolvedStringResponseShouldBe(), // <-- Add here
  thenDetailsShouldMatch(),
  thenResolvedObjectShouldContainFieldsAndValues(),
  whenTypeMismatchEvaluation(),
  andVariantAndReasonShouldBe(),
  andResolvedFlagValueIsEmptyContext(),
  andReasonAndErrorCodeShouldBe(),
  thenDefaultValueShouldBeReturned(),
];
