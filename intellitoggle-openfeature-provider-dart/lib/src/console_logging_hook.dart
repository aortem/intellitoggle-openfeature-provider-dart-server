import 'package:openfeature_dart_server_sdk/hooks.dart';

/// A hook that logs evaluation lifecycle events to the console.
///
/// This hook is useful for debugging and local development. It prints
/// messages to stdout at each stage of the flag evaluation lifecycle.
class ConsoleLoggingHook extends Hook {
  @override
  HookMetadata get metadata => const HookMetadata(name: 'ConsoleLoggingHook');

  /// Called before flag evaluation begins.
  @override
  Future<void> before(HookContext context) async {
    print(
      '[OpenFeature] BEFORE: Evaluating flag "${context.flagKey}" with context: ${context.evaluationContext}',
    );
  }

  /// Called after flag evaluation completes successfully.
  @override
  Future<void> after(HookContext context) async {
    print(
      '[OpenFeature] AFTER: Flag "${context.flagKey}" evaluation completed.',
    );
  }

  /// Called if an error occurs during flag evaluation.
  @override
  Future<void> error(HookContext context) async {
    print(
      '[OpenFeature] ERROR: Flag "${context.flagKey}" evaluation failed.',
    );
  }

  /// Called after evaluation, regardless of outcome.
  @override
  Future<void> finally_(HookContext context, [Object? result, Object? error]) async {
    print(
      '[OpenFeature] FINALLY: Finished evaluation for flag "${context.flagKey}"',
    );
  }
}