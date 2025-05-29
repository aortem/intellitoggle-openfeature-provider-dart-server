import 'package:gherkin/gherkin.dart';
import 'steps.dart';

void main() async {
  final config = TestConfiguration(
    features: ['test/gherkin/features/*.feature'],  // use relative path pattern
    stepDefinitions: steps,
    createWorld: (config) async => StepWorld(),
    order: ExecutionOrder.sequential,
    tagExpression: null,
    stopAfterTestFailed: true,
    defaultTimeout: const Duration(seconds: 10),
  );

  print('Features: ${config.features}');
  print('Steps: ${steps.length}');
  for (final s in steps) {
    print('Loaded step: $s');
  }

  try {
    await GherkinRunner().execute(config);
  } catch (e) {
    print('Gherkin run error: $e');
  }
}
