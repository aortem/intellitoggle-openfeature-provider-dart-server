import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:gherkin/gherkin.dart';
import 'package:test/test.dart';
import 'steps.dart';
import 'hooks/world_setup_hook.dart';

// --- helpers moved to top-level to avoid local forward-ref issues ---
String? resolveFeature(String name) {
  final gherkinRel = p.join('specification', 'assets', 'gherkin');
  final candidates = [
    // typical when running inside the package directory
    p.normalize(p.join(Directory.current.path, 'vendor', 'openfeature-spec', gherkinRel, name)),
    // fallback if tests are triggered from repo root
    p.normalize(p.join(Directory.current.path, '..', 'vendor', 'openfeature-spec', gherkinRel, name)),
  ];
  for (final c in candidates) {
    if (File(c).existsSync()) return c;
  }
  return null;
}

String _sanitizeEvaluationV2(String content) {
  // Expand Scenario Outline + Examples into concrete Scenarios (no Examples left)
  // and normalize any data-table indentation under steps.
  final lines = content.split(RegExp(r'\r?\n'));
  final expanded = <String>[];
  int i = 0;

  bool isTag(String s) => s.trim().startsWith('@');
  bool isExamples(String s) => s.trim().startsWith('Examples:');
  bool isScenarioStart(String s) => s.trim().startsWith('Scenario');
  bool isFeature(String s) => s.trim().startsWith('Feature:');

  String replacePlaceholders(String line, Map<String, String> row) {
    var result = line;
    row.forEach((k, v) {
      result = result.replaceAll('<' + k + '>', v);
    });
    return result;
  }

  while (i < lines.length) {
    final line = lines[i];
    final trimmed = line.trim();

    if (isFeature(line) || trimmed.startsWith('Background:') || trimmed.isEmpty) {
      expanded.add(line);
      i++;
      continue;
    }
    if (isTag(line)) {
      i++;
      continue;
    }

    if (trimmed.startsWith('Scenario Outline:')) {
      final indent = line.substring(0, line.indexOf('Scenario Outline:'));
      final scenarioName = trimmed.substring('Scenario Outline:'.length).trim();
      i++;
      // collect outline body
      final body = <String>[];
      while (i < lines.length) {
        final l = lines[i];
        if (isTag(l)) { i++; continue; }
        if (isExamples(l) || isScenarioStart(l) || isFeature(l)) break;
        body.add(l);
        i++;
      }
      // for each examples section, emit concrete scenarios
      while (i < lines.length) {
        if (isTag(lines[i])) { i++; continue; }
        if (!isExamples(lines[i])) break;
        i++; // skip 'Examples:'
        // find header
        while (i < lines.length && (lines[i].trim().isEmpty || isTag(lines[i]) || !lines[i].trim().startsWith('|'))) {
          i++;
        }
        if (i >= lines.length || !lines[i].trim().startsWith('|')) break;
        final headerParts = lines[i].split('|');
        final headers = headerParts.length >= 2
            ? headerParts.sublist(1, headerParts.length - 1).map((e) => e.trim()).toList()
            : <String>[];
        i++;
        // rows
        while (i < lines.length && lines[i].trim().startsWith('|')) {
          final valueParts = lines[i].split('|');
          final values = valueParts.length >= 2
              ? valueParts.sublist(1, valueParts.length - 1).map((e) => e.trim()).toList()
              : <String>[];
          final rowMap = <String, String>{};
          for (int c = 0; c < headers.length && c < values.length; c++) {
            rowMap[headers[c]] = values[c];
          }
          expanded.add(indent + 'Scenario: ' + scenarioName);
          for (final step in body) {
            expanded.add(replacePlaceholders(step, rowMap));
          }
          expanded.add('');
          i++;
        }
        // skip blank lines after a table
        while (i < lines.length && lines[i].trim().isEmpty) { i++; }
      }
      continue;
    }

    // regular (non-outline) scenarios or other lines
    expanded.add(line);
    i++;
  }

  // Normalize table indentation: ensure any '|' line is indented to its preceding step indent
  final normalized = <String>[];
  String prevNonEmpty = '';
  for (final l in expanded) {
    final trimmedLeft = l.trimLeft();
    if (trimmedLeft.startsWith('|')) {
      final m = RegExp(r'^(\\s*)(Given|When|Then|And|But)\\b').firstMatch(prevNonEmpty);
      final indent = m != null ? m!.group(1)! : '  ';
      normalized.add(indent + trimmedLeft);
    } else {
      normalized.add(l);
      if (l.trim().isNotEmpty) prevNonEmpty = l;
    }
  }

    // Remove any leftover 'Examples:' blocks and their table rows
  final cleaned = <String>[];
  for (int idx = 0; idx < normalized.length; idx++) {
    final t = normalized[idx].trim();
    if (t.startsWith('Examples:')) {
      idx++;
      while (idx < normalized.length && normalized[idx].trim().startsWith('|')) {
        idx++;
      }
      idx--; // for loop will increment
      continue;
    }
    cleaned.add(normalized[idx]);
  }

  return cleaned.join('\\n');
}

/// Prepare evaluation_v2 as concrete .feature files (one scenario per file)
/// and return a glob pattern pointing to the generated files.
String _prepareEvaluationV2Features(String originalPath) {
  try {
    final original = File(originalPath).readAsStringSync();
    final sanitized = _sanitizeEvaluationV2(original);

    final rootTmp = Directory(p.join('test', 'gherkin', '_tmp'))
      ..createSync(recursive: true);
    final outDir = Directory(p.join(rootTmp.path, 'eval_v2'));
    if (outDir.existsSync()) {
      for (final f in outDir.listSync()) {
        if (f is File) f.deleteSync();
      }
    } else {
      outDir.createSync(recursive: true);
    }

    final lines = sanitized.split(RegExp(r'\r?\n'));
    final buffer = <String>[];
    String? featureHeader;
    int scenarioCount = 0;

    String twoDigit(int n) => n.toString().padLeft(2, '0');

    void flushScenario() {
      if (buffer.isEmpty) return;
      scenarioCount++;
      final fileName = 'eval_v2_${twoDigit(scenarioCount)}.feature';
      final filePath = p.join(outDir.path, fileName);
      final content = [if (featureHeader != null) featureHeader!, ...buffer].join('\n');
      File(filePath).writeAsStringSync(content);
      buffer.clear();
    }

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('Feature:')) {
        featureHeader = line;
        continue;
      }
      if (trimmed.startsWith('Scenario:')) {
        flushScenario();
        buffer.add(line);
      } else {
        if (buffer.isNotEmpty || trimmed.isNotEmpty) {
          buffer.add(line);
        }
      }
    }
    flushScenario();

    if (scenarioCount == 0) {
      print('[WARN] evaluation_v2 split produced 0 scenarios. Falling back to original.');
      return originalPath;
    }

    // Return glob pattern for runner discovery
    final glob = p.join('test', 'gherkin', '_tmp', 'eval_v2', '*.feature');
    return glob;
  } catch (e) {
    print('[WARN] Failed to prepare evaluation_v2 split: $e');
    return originalPath;
  }
}

void main() {
  final featureNames = [
    'evaluation_v2.feature',
    'contextMerging.feature',
    'metadata.feature',
    'hooks.feature',
  ];

  // helpers now top-level

  for (final name in featureNames) {
    test('Appendix B: $name', () async {
      final resolved = resolveFeature(name);
      print('Resolved feature "$name" -> ${resolved ?? "<not found>"}');
      if (resolved == null) {
        fail('Feature file not found: $name. Checked vendor/openfeature-spec in package and repo root.');
      }
      final featureSpec = name == 'evaluation_v2.feature'
          ? _prepareEvaluationV2Features(resolved)
          : name; // use filename matching for others
      final config = TestConfiguration(
        // evaluation_v2 uses explicit sanitized path; others use filename matching
        features: [featureSpec],
        hooks: [WorldSetupHook()],
        stepDefinitions: steps,
        createWorld: (config) async => StepWorld(),
        order: ExecutionOrder.sequential,
        tagExpression: null,
        stopAfterTestFailed: true,
        defaultTimeout: const Duration(seconds: 15),
        reporters: [
          StdoutReporter(MessageLevel.info),
          ProgressReporter(),
          TestRunSummaryReporter(),
        ],
      );

      try {
        await GherkinRunner().execute(config);
      } on GherkinTestRunFailedException catch (e) {
        fail('Gherkin failed for $name: $e');
      }
    });
  }
}

