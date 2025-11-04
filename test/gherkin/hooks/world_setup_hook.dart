import 'package:gherkin/gherkin.dart';
// Corrected import path to access StepWorld from the parent directory
import '../steps.dart'; 

class WorldSetupHook extends Hook {
  @override
  int get priority => 1; // Higher priority hooks run first

  @override
  // Corrected 'tags' parameter type to Iterable<Tag>
  Future<void> onAfterScenarioWorldCreated(World world, String scenario, Iterable<Tag> tags) async {
    // StepWorld should be recognized now that the import path is correct
    // and assuming steps.dart is syntactically correct.
    if (world is StepWorld) { 
      print('[WorldSetupHook] onAfterScenarioWorldCreated - World is StepWorld. Performing explicit setup...');
      // Call the public setup method on your world
      await world.performExplicitSetup(); 
      // Ensure provider is not null before accessing its state, or handle LateInitializationError
      try {
        print('[WorldSetupHook] onAfterScenarioWorldCreated - Explicit setup completed. Provider state: ${world.provider.state}');
      } catch (e) {
        print('[WorldSetupHook] onAfterScenarioWorldCreated - Explicit setup completed, but error accessing provider state: $e');
      }
    } else {
      print('[WorldSetupHook] onAfterScenarioWorldCreated - World is NOT StepWorld. Type: ${world.runtimeType}');
    }
  }
}
