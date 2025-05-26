import 'package:openfeature_dart_server_sdk/hook.dart';

/// A hook that logs evaluation lifecycle events to the console.
///
/// This hook is useful for debugging and local development. It prints
/// messages to stdout at each stage of the flag evaluation lifecycle:
/// - before: right before evaluation starts
/// - after: after evaluation completes successfully
/// - error: if an error occurs during evaluation
/// - finallyAfter: after evaluation, regardless of success or error
class ConsoleLoggingHook extends Hook {
  /// Called before flag evaluation begins.
  ///
  /// Logs the flag key and evaluation context.
  @override
  void before(HookContext context, HookHints hints) {
    print('[OpenFeature] BEFORE: Evaluating flag "${context.flagKey}" with context: ${context.evaluationContext?.attributes}');
  }

  /// Called after flag evaluation completes successfully.
  ///
  /// Logs the flag key, resolved value, and reason.
  @override
  void after(HookContext context, HookHints hints, EvaluationDetails details) {
    print('[OpenFeature] AFTER: Flag "${context.flagKey}" resolved to value: ${details.value} (reason: ${details.reason})');
  }

  /// Called if an error occurs during flag evaluation.
  ///
  /// Logs the flag key and error details.
  @override
  void error(HookContext context, HookHints hints, Exception error) {
    print('[OpenFeature] ERROR: Flag "${context.flagKey}" evaluation failed: $error');
  }

  /// Called after evaluation, regardless of outcome.
  ///
  /// Logs the flag key to indicate evaluation is finished.
  @override
  void finallyAfter(HookContext context, HookHints hints) {
    print('[OpenFeature] FINALLY: Finished evaluation for flag "${context.flagKey}"');
  }
}