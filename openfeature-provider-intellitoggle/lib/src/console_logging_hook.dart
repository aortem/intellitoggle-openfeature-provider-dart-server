import 'dart:convert';
import 'package:openfeature_dart_server_sdk/hooks.dart';

/// A hook that logs evaluation lifecycle events to stdout.
///
/// Per Appendix A, it can optionally print the evaluation context in a
/// human-readable serialized form.
class ConsoleLoggingHook extends Hook {
  /// Controls whether evaluation context is included in logs.
  final bool printContext;

  /// Optional domain label for logs.
  final String domain;

  /// Allows overriding the print function for testing.
  void Function(String message) logFunction;

  ConsoleLoggingHook({
    this.printContext = false,
    this.domain = 'flag_evaluation',
    void Function(String message)? logger,
  }) : logFunction = logger ?? print;

  @override
  HookMetadata get metadata => const HookMetadata(name: 'ConsoleLoggingHook');

  @override
  Future<void> before(HookContext context) async {
    final payload = <String, dynamic>{
      'stage': 'before',
      'domain': domain,
      'provider_name': _providerName(context),
      'flag_key': context.flagKey,
      if (printContext) 'evaluation_context': _stringify(context.evaluationContext),
    };
    logFunction('[OpenFeature] ${jsonEncode(payload)}');
  }

  @override
  Future<void> after(HookContext context) async {
    final payload = <String, dynamic>{
      'stage': 'after',
      'domain': domain,
      'provider_name': _providerName(context),
      'flag_key': context.flagKey,
      if (printContext) 'evaluation_context': _stringify(context.evaluationContext),
      // Best-effort mapping of result details if present
      if (context.result != null) 'result': context.result,
    };
    logFunction('[OpenFeature] ${jsonEncode(payload)}');
  }

  @override
  Future<void> error(HookContext context) async {
    final err = context.error;
    final payload = <String, dynamic>{
      'stage': 'error',
      'domain': domain,
      'provider_name': _providerName(context),
      'flag_key': context.flagKey,
      if (printContext) 'evaluation_context': _stringify(context.evaluationContext),
      'error_message': err?.toString(),
    };
    logFunction('[OpenFeature] ${jsonEncode(payload)}');
  }

  @override
  Future<void> finally_(HookContext context, EvaluationDetails? evaluationDetails, [HookHints? hints]) async {
    final payload = <String, dynamic>{
      'stage': 'finally',
      'domain': domain,
      'provider_name': _providerName(context),
      'flag_key': context.flagKey,
      if (evaluationDetails != null) 'reason': evaluationDetails.reason,
    };
    logFunction('[OpenFeature] ${jsonEncode(payload)}');
  }

  String _providerName(HookContext context) {
    try {
      final md = context.metadata;
      return (md['providerName'] ?? md['provider_name'] ?? md['provider'] ?? 'unknown').toString();
    } catch (_) {}
    return 'unknown';
  }

  String _stringify(Object? obj) {
    try {
      if (obj == null) return 'null';
      if (obj is String) return obj;
      return const JsonEncoder.withIndent('  ').convert(obj);
    } catch (_) {
      return obj.toString();
    }
  }
}
