import 'package:openfeature_dart_server_sdk/hooks.dart';
import 'package:openfeature_dart_server_sdk/feature_provider.dart';
import '../utils/telemetry.dart';

/// OpenTelemetry-compatible telemetry hook for OpenFeature
/// Complies with OpenFeature Appendix D and OTel semantic conventions
class IntelliToggleTelemetryHook extends Hook {
  TelemetrySpan? _span;
  DateTime? _startTime;

  @override
  HookMetadata get metadata =>
      const HookMetadata(name: 'IntelliToggleTelemetryHook');

  @override
  Future<void> before(HookContext context) async {
    _startTime = DateTime.now();

    // Start span with OTel naming convention
    final attributes = <String, Object?>{
      'feature_flag.key': context.flagKey,
      'feature_flag.provider_name': 'IntelliToggle',
    };

    // Extract targetingKey from evaluation context map (required by OTel)
    if (context.evaluationContext != null) {
      final evalContext = context.evaluationContext;

      // Check for targetingKey in the map
      if (evalContext is Map<String, dynamic> &&
          evalContext.containsKey('targetingKey')) {
        attributes['feature_flag.context.targetingKey'] =
            evalContext['targetingKey'];
      }
    }

    _span = Telemetry.startSpan('feature_flag', attributes: attributes);

    // Increment total evaluation counter
    Telemetry.metrics.increment('feature_flag.evaluation_count');
  }

  @override
  Future<void> after(HookContext context) async {
    // Note: This hook may not be called by all SDK implementations
    // We handle everything in finally_() to ensure it runs
  }

  @override
  Future<void> error(HookContext context) async {
    // Note: We handle errors in finally_() to ensure consistent behavior
  }

  @override
  Future<void> finally_(
    HookContext context,
    EvaluationDetails? evaluationDetails, [
    HookHints? hints,
  ]) async {
    if (_span == null || _startTime == null) return;

    final latency = DateTime.now().difference(_startTime!);

    // Record latency in histogram
    Telemetry.recordLatency(context.flagKey, latency);

    // Check if this was an error or success from context
    final isError = context.error != null;

    if (isError) {
      // === ERROR PATH ===
      _span!.setAttribute('feature_flag.evaluation.success', false);

      // Extract error code and message
      String errorCode = 'GENERAL';
      String errorMessage = 'Unknown error';

      final error = context.error;
      if (error is Exception) {
        errorMessage = error.toString();
        // Try to extract error code from exception message
        if (errorMessage.contains('FLAG_NOT_FOUND')) {
          errorCode = 'FLAG_NOT_FOUND';
        } else if (errorMessage.contains('TYPE_MISMATCH')) {
          errorCode = 'TYPE_MISMATCH';
        } else if (errorMessage.contains('PROVIDER_NOT_READY')) {
          errorCode = 'PROVIDER_NOT_READY';
        }
      }

      _span!.setAttribute('feature_flag.evaluation.error_code', errorCode);

      // Emit span event for error (Appendix D requirement)
      _span!.addEvent(
        'feature_flag.evaluation_error',
        attributes: {'error.type': errorCode, 'error.message': errorMessage},
      );

      Telemetry.metrics.increment('feature_flag.evaluation_error_count');
    } else {
      // === SUCCESS PATH ===
      _span!.setAttribute('feature_flag.evaluation.success', true);

      // Use evaluationDetails if available (preferred)
      if (evaluationDetails != null) {
        // EvaluationDetails contains: flagKey, value, variant, reason, evaluationTime, additionalDetails
        if (evaluationDetails.variant != null) {
          _span!.setAttribute(
            'feature_flag.variant',
            evaluationDetails.variant,
          );
        }
        _span!.setAttribute(
          'feature_flag.evaluation.reason',
          evaluationDetails.reason,
        );

        // Check additionalDetails for error information
        final additionalDetails = evaluationDetails.additionalDetails;
        if (additionalDetails != null &&
            additionalDetails['errorCode'] != null) {
          // Found error in additional details
          _span!.setAttribute('feature_flag.evaluation.success', false);
          _span!.setAttribute(
            'feature_flag.evaluation.error_code',
            additionalDetails['errorCode'].toString(),
          );

          _span!.addEvent(
            'feature_flag.evaluation_error',
            attributes: {
              'error.type': additionalDetails['errorCode'].toString(),
              'error.message':
                  additionalDetails['errorMessage']?.toString() ??
                  'Evaluation failed',
            },
          );

          Telemetry.metrics.increment('feature_flag.evaluation_error_count');
        } else {
          Telemetry.metrics.increment('feature_flag.evaluation_success_count');
        }
      } else if (context.result != null) {
        // Fallback to context.result if evaluationDetails not available
        final result = context.result;

        if (result is FlagEvaluationResult) {
          // It's a FlagEvaluationResult object
          if (result.variant != null) {
            _span!.setAttribute('feature_flag.variant', result.variant);
          }
          _span!.setAttribute('feature_flag.evaluation.reason', result.reason);

          // Check for error in result
          if (result.errorCode != null) {
            _span!.setAttribute('feature_flag.evaluation.success', false);
            _span!.setAttribute(
              'feature_flag.evaluation.error_code',
              result.errorCode.toString(),
            );

            _span!.addEvent(
              'feature_flag.evaluation_error',
              attributes: {
                'error.type': result.errorCode.toString(),
                'error.message': result.errorMessage ?? 'Evaluation failed',
              },
            );

            Telemetry.metrics.increment('feature_flag.evaluation_error_count');
          } else {
            Telemetry.metrics.increment(
              'feature_flag.evaluation_success_count',
            );
          }
        } else {
          // Just the value, use default reason
          _span!.setAttribute('feature_flag.evaluation.reason', 'STATIC');
          Telemetry.metrics.increment('feature_flag.evaluation_success_count');
        }
      } else {
        // No result and no error - count as success with default reason
        _span!.setAttribute('feature_flag.evaluation.reason', 'DEFAULT');
        Telemetry.metrics.increment('feature_flag.evaluation_success_count');
      }
    }

    // END THE SPAN HERE (critical - must be last)
    Telemetry.endSpan(_span!);

    _span = null;
    _startTime = null;
  }
}
