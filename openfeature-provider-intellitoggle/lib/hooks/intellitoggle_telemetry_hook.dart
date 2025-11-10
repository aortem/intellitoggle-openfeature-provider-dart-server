import 'package:openfeature_dart_server_sdk/hooks.dart';
import '../utils/telemetry.dart';

class IntelliToggleTelemetryHook extends Hook {
  TelemetrySpan? _span;
  late DateTime _startTime;

  @override
  HookMetadata get metadata => const HookMetadata(name: 'OpenTelemetryHook');

  @override
  Future<void> before(HookContext context) async {
    _startTime = DateTime.now();

    _span = Telemetry.startSpan(
      'feature_evaluation',
      attributes: {
        'feature_flag.key': context.flagKey,
        'feature_flag.provider_name': 'intellitoggle',
        'feature_flag.context': context.evaluationContext.toString(),
      },
    );

    Telemetry.metrics.increment('evaluation.total');
  }

  @override
  Future<void> after(HookContext context) async {
    if (_span != null) {
      _span!.setAttribute('feature_flag.evaluation.success', true);
      Telemetry.metrics.increment('evaluation.success');
      Telemetry.endSpan(_span!);
    }
  }

  @override
  Future<void> error(HookContext context) async {
    if (_span != null) {
      _span!.setAttribute('feature_flag.evaluation.success', false);
      _span!.setAttribute('error.code', 'evaluation_failed');
      Telemetry.metrics.increment('evaluation.error');
      Telemetry.endSpan(_span!);
    }
  }

  @override
  Future<void> finally_(HookContext context, [Object? result, Object? error]) async {
    if (_span != null) {
      final end = DateTime.now();
      final latency = end.difference(_startTime);
      Telemetry.recordLatency(context.flagKey, latency);
    }
  }
}
