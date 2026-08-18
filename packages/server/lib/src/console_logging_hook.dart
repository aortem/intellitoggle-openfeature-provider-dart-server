import 'dart:convert';
import 'package:openfeature_dart_server_sdk/hooks.dart';

/// A hook that logs evaluation lifecycle events to stdout.
///
/// Per Appendix A, it can optionally print the evaluation context in a
/// human-readable serialized form.
class ConsoleLoggingHook extends Hook {
  static const String _circularReferenceMarker = '[Circular]';

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
  Future<Map<String, dynamic>?> before(HookContext context) async {
    _log('before', context);
    return null;
  }

  @override
  Future<void> after(HookContext context) async {
    _log('after', context);
  }

  @override
  Future<void> error(HookContext context) async {
    _log('error', context);
  }

  @override
  Future<void> finally_(
    HookContext context,
    EvaluationDetails? evaluationDetails, [
    HookHints? hints,
  ]) async {
    _log('finally', context, evaluationDetails: evaluationDetails);
  }

  String _providerName(HookContext context) {
    try {
      if (context.providerMetadata != null) {
        return context.providerMetadata!.name;
      }
      final md = context.metadata;
      return (md['providerName'] ??
              md['provider_name'] ??
              md['provider'] ??
              'unknown')
          .toString();
    } catch (_) {}
    return 'unknown';
  }

  void _log(
    String stage,
    HookContext context, {
    EvaluationDetails? evaluationDetails,
  }) {
    try {
      final payload = jsonEncode({
        'stage': stage,
        'domain': domain,
        'provider_name': _providerName(context),
        'flag_key': context.flagKey,
        if (printContext)
          'evaluation_context': _safeJsonValue(context.evaluationContext),
        if (!printContext && context.evaluationContext.isNotEmpty)
          'evaluation_context_keys': context.evaluationContext.keys.toList(
            growable: false,
          ),
        if (context.result != null) 'result': _safeJsonValue(context.result),
        if (evaluationDetails != null) 'reason': evaluationDetails.reason,
        if (context.error != null) 'error_message': context.error.toString(),
      });
      logFunction('[OpenFeature] $payload');
    } catch (error) {
      try {
        logFunction(
          '[OpenFeature] ConsoleLoggingHook failed to serialize '
          'stage=$stage flag=${context.flagKey}: $error',
        );
      } catch (_) {}
    }
  }

  Object? _safeJsonValue(dynamic value, [Set<Object>? visited]) {
    final seen = visited ?? Set<Object>.identity();

    if (value == null || value is num || value is bool || value is String) {
      return value;
    }

    if (value is Map) {
      if (!seen.add(value)) {
        return _circularReferenceMarker;
      }

      try {
        return value.map<String, Object?>((key, entryValue) {
          return MapEntry(key.toString(), _safeJsonValue(entryValue, seen));
        });
      } finally {
        seen.remove(value);
      }
    }

    if (value is Iterable) {
      if (!seen.add(value)) {
        return _circularReferenceMarker;
      }

      try {
        return value
            .map((entry) => _safeJsonValue(entry, seen))
            .toList(growable: false);
      } finally {
        seen.remove(value);
      }
    }

    try {
      return value.toString();
    } catch (_) {
      return '<unprintable ${value.runtimeType}>';
    }
  }
}
