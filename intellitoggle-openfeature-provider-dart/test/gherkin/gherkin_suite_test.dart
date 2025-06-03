import 'package:gherkin/gherkin.dart';
import 'package:test/test.dart'; // Standard test package
import 'steps.dart'; // Your step definitions
import 'hooks/world_setup_hook.dart';

void main() {
  test('Execute Gherkin Feature Tests', () async {
    final config = TestConfiguration(
      features: [
        'test/gherkin/features/evaluation.feature' // Ensure this file exists
      ],
      hooks: [
        WorldSetupHook(),
      ],
      stepDefinitions: steps, // From steps.dart
      createWorld: (config) async => StepWorld(),
      order: ExecutionOrder.sequential,
      tagExpression: null,
      stopAfterTestFailed: true,
      defaultTimeout: const Duration(seconds: 15),

    );

    print('Attempting to run Gherkin with configuration:');
    print('Features path: ${config.features}');
    // Corrected null-aware access for stepDefinitions.length
    print('Number of step definitions loaded: ${config.stepDefinitions?.length ?? 0}');
    print('Reporters: ${config.reporters.map((r) => r.runtimeType).toList()}');

    try {
      await GherkinRunner().execute(config);
      print('Gherkin execution process completed successfully.');
    } on GherkinTestRunFailedException catch (e) {
      print('Gherkin execution failed: ${e.toString()}');
      rethrow;
    } catch (e, s) {
      print('An unexpected error occurred during Gherkin execution: $e');
      print('Stack trace for unexpected error: $s');
      rethrow;
    }
  });
}