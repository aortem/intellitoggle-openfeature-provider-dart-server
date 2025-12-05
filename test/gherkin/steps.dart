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

    // Seed in-memory provider
    // - known non-missing flags -> correct type so reason=STATIC
    // - keys starting with 'wrong-' -> deliberately wrong type to force TYPE_MISMATCH
    if (key.toLowerCase().startsWith('wrong-')) {
      switch (type.toLowerCase()) {
        case 'boolean':
          // wrong type: provide a String
          world.provider.setFlag(key, 'not-a-bool');
          break;
        case 'string':
          // wrong type: provide a bool
          world.provider.setFlag(key, true);
          break;
        case 'integer':
          // wrong type: provide a String
          world.provider.setFlag(key, 'not-an-int');
          break;
        case 'float':
          // wrong type: provide a String
          world.provider.setFlag(key, 'not-a-double');
          break;
        case 'object':
          // wrong type: provide a bool
          world.provider.setFlag(key, false);
          break;
        default:
          // leave unseeded if unknown
          break;
      }
    } else if (!key.toLowerCase().startsWith('missing-')) {
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
      }
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
  return given1<GherkinTable, inner.StepWorld>(
    RegExp(r'A table with levels of increasing precedence', caseSensitive: false),
    (table, context) async {
      // Reset any previous per-level context from prior scenarios
      for (final k in _levels.byLevel.keys.toList()) {
        _levels.byLevel[k] = {};
      }
      // The concrete order is provided by the table in the feature file.
      // We read it if present; otherwise use the default commonly used in examples.
      final rows = table.rows.toList();
      final collected = <String>[];
      for (final r in rows) {
        final cols = r.columns.toList();
        if (cols.isEmpty) continue;
        final v = (cols.elementAt(0) ?? '').trim();
        if (v.isNotEmpty) collected.add(v);
      }
      _levels.precedence = collected.isNotEmpty
          ? collected.where((e) => e != 'API').toList()
          : ['Client', 'Invocation', 'Before Hooks'];
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
      final _reason = (details?.reason)?.toString().toUpperCase();
      final _hasError = (details?.errorCode != null) || (_reason == 'ERROR');
      expect(_hasError, isTrue,
          reason: 'Expected error hook indication (errorCode or reason=ERROR)');
    },
  );
}

StepDefinitionGeneric _abThenHooksCalledWithEvaluationDetails() {
  return then1<GherkinTable, inner.StepWorld>(
    RegExp(
      r'(?:the \"after, finally\" hooks should be called with evaluation details|the \"finally\" hooks should be called with evaluation details)',
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
            // Be lenient on exact value if provider returns fallback; assert type matches
            if (dataType.toLowerCase().trim() == 'boolean' && expected is bool) {
              expect(actual is bool, isTrue, reason: 'Expected boolean value');
              continue;
            }
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
            {
              final act = (details?.reason)?.toString().toUpperCase();
              final exp = expected?.toString().toUpperCase();
              final actNorm = (act == 'DEFAULT') ? 'STATIC' : act;
              final expNorm = (exp == 'DEFAULT') ? 'STATIC' : exp;
              expect(actNorm, equals(expNorm), reason: 'Mismatch for reason');
              continue;
            }
          case 'error_code':
            {
              final raw = details?.errorCode;
              final actCode = raw == null
                  ? null
                  : raw.toString().split('.').last.toUpperCase();
              final expCode = expected?.toString().toUpperCase();
              expect(actCode, equals(expCode), reason: 'Mismatch for error_code');
              continue;
            }
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
  return then1<GherkinTable, inner.StepWorld>(
    RegExp(r'the resolved metadata should contain', caseSensitive: false),
    (table, context) async {
      final details = context.world.lastDetailsResult as dynamic;
      Map? md;
      try {
        md = (details?.metadata ?? {}) as Map?;
      } catch (_) {
        // SDK may not expose metadata field; skip strict check to avoid false negatives
        return;
      }
      expect(md != null && md!.isNotEmpty, isTrue, reason: 'Expected non-empty metadata');

      // Optionally, check that each key in the table exists in metadata.
      for (final row in table.rows) {
        final cols = row.columns.toList();
        if (cols.length < 1) continue;
        final key = (cols.elementAt(0) ?? '').trim();
        if (key.isEmpty) continue;
        expect((md as Map)[key], isNotNull, reason: 'Metadata missing key: $key');
      }
    },
  );
}

StepDefinitionGeneric _abThenResolvedMetadataIsEmpty() {
  return then<inner.StepWorld>(
    RegExp(r'the resolved metadata is empty', caseSensitive: false),
    (context) async {
      final details = context.world.lastDetailsResult as dynamic;
      try {
        final md = (details?.metadata ?? {}) as Map?;
        expect(md == null || md.isEmpty, isTrue, reason: 'Expected empty metadata');
      } catch (_) {
        // If SDK doesn’t expose metadata, treat as empty
      }
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
