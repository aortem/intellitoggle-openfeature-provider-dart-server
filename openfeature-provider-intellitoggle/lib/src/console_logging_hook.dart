import 'package:openfeature_dart_server_sdk/hooks.dart';

/// A hook that logs evaluation lifecycle events to the console.
class ConsoleLoggingHook extends Hook {
  /// Allows overriding the print function for testing.
  void Function(String message) logFunction = print; // Default to print

  @override
  HookMetadata get metadata => const HookMetadata(name: 'ConsoleLoggingHook');

  @override
  Future<void> before(HookContext context) async {
    logFunction(
      '[OpenFeature] BEFORE: Evaluating flag "${context.flagKey}" with context: ${context.evaluationContext}',
    );
  }

  @override
  Future<void> after(HookContext context) async {
    logFunction(
      '[OpenFeature] AFTER: Flag "${context.flagKey}" evaluation completed.',
    );
  }

  @override
  Future<void> error(HookContext context) async {
    logFunction(
      '[OpenFeature] ERROR: Flag "${context.flagKey}" evaluation failed.',
    );
  }

  @override
  Future<void> finally_(HookContext context, [Object? result, Object? error]) async {
    logFunction(
      '[OpenFeature] FINALLY: Finished evaluation for flag "${context.flagKey}"',
    );
  }
}