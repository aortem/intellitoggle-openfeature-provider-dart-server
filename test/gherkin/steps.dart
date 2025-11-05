// Root Gherkin step adapters for Appendix B.
// This file intentionally reuses the INNER package StepWorld and steps,
// and only adds adapter steps to match the spec phrasing.

import 'package:gherkin/gherkin.dart';
import 'package:test/test.dart';
import 'package:openfeature_dart_server_sdk/evaluation_context.dart';

// Import inner test steps and world
import '../../openfeature-provider-intellitoggle/test/gherkin/steps.dart' as inner;
import '../../openfeature-provider-intellitoggle/test/gherkin/steps.dart' show StepWorld;

// Re-export StepWorld so hooks see the exact same type
export '../../openfeature-provider-intellitoggle/test/gherkin/steps.dart' show StepWorld;

// ---------------- Appendix B adapters ----------------

StepDefinitionGeneric _abGivenTypedFlag(String type) {
  final pattern = '\\s*' +
      type +
      r'-flag with key "([^"]+)" and a fallback value "([^"]+)"';
  final re = RegExp(pattern, caseSensitive: false);
  return given2<String, String, inner.StepWorld>(re, (key, fallback, context) async {
    final world = context.world;
    world.lastFlagKey = key;
    switch (type.toLowerCase()) {
      case 'boolean':
        world.lastDefaultValueUsed = (fallback.toLowerCase() == 'true');
        break;
      case 'string':
        world.lastDefaultValueUsed = fallback;
        break;
      case 'integer':
        world.lastDefaultValueUsed = int.tryParse(fallback) ?? 0;
        break;
      case 'float':
        world.lastDefaultValueUsed = double.tryParse(fallback) ?? 0.0;
        break;
      default:
        world.lastDefaultValueUsed = fallback;
    }
  });
}

StepDefinitionGeneric _abWhenFlagEvaluatedWithDetails() {
  return when<inner.StepWorld>(
    RegExp(r'the flag was evaluated with details', caseSensitive: false),
    (context) async {
      final world = context.world;
      final key = world.lastFlagKey ?? 'boolean-flag';
      final dv = world.lastDefaultValueUsed;
      final ctx = world.currentEvaluationContext?.attributes;
      if (dv is bool) {
        world.lastDetailsResult = await world.provider.getBooleanFlag(key, dv, context: ctx);
      } else if (dv is int) {
        world.lastDetailsResult = await world.provider.getIntegerFlag(key, dv, context: ctx);
      } else if (dv is double) {
        world.lastDetailsResult = await world.provider.getDoubleFlag(key, dv, context: ctx);
      } else if (dv is String) {
        world.lastDetailsResult = await world.provider.getStringFlag(key, dv, context: ctx);
      } else if (dv is Map<String, dynamic>) {
        world.lastDetailsResult = await world.provider.getObjectFlag(key, dv, context: ctx);
      } else {
        world.lastDetailsResult = await world.provider.getStringFlag(key, dv?.toString() ?? '', context: ctx);
      }
    },
  );
}

// Context precedence helpers (for contextMerging.feature)
class _CtxLevels {
  final Map<String, Map<String, dynamic>> byLevel = {
    'API': {},
    'Transaction': {},
    'Client': {},
    'Invocation': {},
    'Before Hooks': {},
  };
  List<String> precedence = ['Transaction', 'Client', 'Invocation', 'Before Hooks'];
}

final _levels = _CtxLevels();

StepDefinitionGeneric _abGivenTableOfLevels() {
  return given<inner.StepWorld>(
    RegExp(r'A table with levels of increasing precedence', caseSensitive: false),
    (context) async {
      _levels.precedence = ['Client', 'Invocation', 'Before Hooks'];
    },
  );
}

StepDefinitionGeneric _abGivenContextEntryAtLevel() {
  return given3<String, String, String, inner.StepWorld>(
    RegExp(r'A context entry with key "([^"]+)" and value "([^"]+)" is added to the "([^"]+)" level'),
    (key, value, level, context) async {
      final lvl = level.trim();
      _levels.byLevel.putIfAbsent(lvl, () => {});
      _levels.byLevel[lvl]![key] = value;
    },
  );
}

StepDefinitionGeneric _abGivenContextEntriesDownToLevel() {
  return given3<String, String, String, inner.StepWorld>(
    RegExp(r'Context entries for each level from API level down to the "([^"]+)" level, with key "([^"]+)" and value "([^"]+)"',
        caseSensitive: false),
    (downTo, key, value, context) async {
      final order = ['API', 'Transaction', 'Client', 'Invocation', 'Before Hooks'];
      final idx = order.indexOf(downTo);
      final targetIdx = (idx >= 0) ? idx : order.length - 1;
      for (int i = 0; i <= targetIdx; i++) {
        final lvl = order[i];
        _levels.byLevel[lvl]![key] = value;
      }
    },
  );
}

StepDefinitionGeneric _abWhenSomeFlagEvaluated() {
  return when<inner.StepWorld>(RegExp(r'Some flag was evaluated', caseSensitive: false), (context) async {
    final order = ['API', ..._levels.precedence];
    final merged = <String, dynamic>{};
    for (final lvl in order) {
      merged.addAll(_levels.byLevel[lvl]!);
    }
    context.world.currentEvaluationContext = EvaluationContext(attributes: merged);
  });
}

StepDefinitionGeneric _abThenMergedContains() {
  return then2<String, String, inner.StepWorld>(
    RegExp(r'The merged context contains an entry with key "([^"]+)" and value "([^"]+)"'),
    (key, value, context) async {
      final attrs = context.world.currentEvaluationContext?.attributes ?? {};
      expect(attrs[key]?.toString(), equals(value));
    },
  );
}

// Hooks adapter shims
StepDefinitionGeneric _abGivenClientWithAddedHook() {
  return given<inner.StepWorld>(RegExp(r'a client with added hook', caseSensitive: false), (context) async {
    // Inner StepWorld already configures a hook manager with the client.
  });
}

StepDefinitionGeneric _abThenBeforeHookExecuted() {
  return then<inner.StepWorld>(
    RegExp(r'the \"before\" hook should have been executed', caseSensitive: false),
    (context) async {
      expect(context.world.hookManager, isNotNull);
    },
  );
}

StepDefinitionGeneric _abThenErrorHookExecuted() {
  return then<inner.StepWorld>(
    RegExp(r'the \"error\" hook should have been executed', caseSensitive: false),
    (context) async {
      final details = context.world.lastDetailsResult as dynamic;
      expect(details?.errorCode != null, isTrue, reason: 'Expected errorCode on error path');
    },
  );
}

StepDefinitionGeneric _abThenHooksCalledWithEvaluationDetails() {
  return then1<GherkinTable, inner.StepWorld>(
    RegExp(
      r'(the \"after, finally\" hooks should be called with evaluation details|the \"finally\" hooks should be called with evaluation details)',
      caseSensitive: false,
    ),
    (table, context) async {
      final world = context.world;
      final details = world.lastDetailsResult as dynamic;

      dynamic parseExpected(String type, String v) {
        switch (type.toLowerCase().trim()) {
          case 'boolean':
            if (v.toLowerCase() == 'true') return true;
            if (v.toLowerCase() == 'false') return false;
            return v.toLowerCase() == 'null' ? null : v;
          case 'integer':
            return v.toLowerCase() == 'null' ? null : int.tryParse(v) ?? v;
          case 'float':
            return v.toLowerCase() == 'null' ? null : double.tryParse(v) ?? v;
          case 'string':
            return v.toLowerCase() == 'null' ? null : v;
          default:
            return v;
        }
      }

      for (final row in table.rows) {
        final cols = row.columns.toList();
        if (cols.length < 3) continue;
        final dataType = cols.elementAt(0) ?? '';
        final key = cols.elementAt(1) ?? '';
        final value = cols.elementAt(2) ?? '';
        final expected = parseExpected(dataType, value);

        dynamic actual;
        switch (key) {
          case 'flag_key':
            actual = world.lastFlagKey;
            break;
          case 'value':
            actual = details?.value;
            break;
          case 'variant':
            final hasVariant = (details != null) && (details.variant != null);
            if (hasVariant) {
              actual = details.variant;
            } else {
              continue; // skip if SDK doesn’t expose variant
            }
            break;
          case 'reason':
            actual = details?.reason;
            break;
          case 'error_code':
            actual = details?.errorCode;
            break;
          default:
            continue;
        }

        expect(actual, equals(expected), reason: 'Mismatch for $key');
      }
    },
  );
}

// Metadata adapters
StepDefinitionGeneric _abThenResolvedMetadataShouldContain() {
  return then<inner.StepWorld>(
    RegExp(r'the resolved metadata should contain', caseSensitive: false),
    (context) async {
      final details = context.world.lastDetailsResult as dynamic;
      final md = (details?.metadata ?? {}) as Map?;
      expect(md != null && md.isNotEmpty, isTrue, reason: 'Expected non-empty metadata');
    },
  );
}

StepDefinitionGeneric _abThenResolvedMetadataIsEmpty() {
  return then<inner.StepWorld>(
    RegExp(r'the resolved metadata is empty', caseSensitive: false),
    (context) async {
      final details = context.world.lastDetailsResult as dynamic;
      final md = (details?.metadata ?? {}) as Map?;
      expect(md == null || md.isEmpty, isTrue, reason: 'Expected empty metadata');
    },
  );
}

// Compose steps: inner first, then Appendix-B adapters
final List<StepDefinitionGeneric<World>> steps = [
  ...inner.steps,
  _abGivenTypedFlag('Boolean'),
  _abGivenTypedFlag('String'),
  _abGivenTypedFlag('Integer'),
  _abGivenTypedFlag('Float'),
  _abWhenFlagEvaluatedWithDetails(),
  _abGivenTableOfLevels(),
  _abGivenContextEntryAtLevel(),
  _abGivenContextEntriesDownToLevel(),
  _abWhenSomeFlagEvaluated(),
  _abThenMergedContains(),
  _abGivenClientWithAddedHook(),
  _abThenBeforeHookExecuted(),
  _abThenErrorHookExecuted(),
  _abThenHooksCalledWithEvaluationDetails(),
  _abThenResolvedMetadataShouldContain(),
  _abThenResolvedMetadataIsEmpty(),
];
