import 'package:openfeature_dart_server_sdk/hooks.dart';
import '../utils/telemetry.dart';
import 'package:openfeature_dart_server_sdk/feature_provider.dart';



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
  Future<void> after(HookContext context, [Object? result]) async {
    if (_span != null) {
      _span!.setAttribute('feature_flag.variant', result);

      _span!.setAttribute('feature_flag.evaluation.success', true);
      Telemetry.metrics.increment('evaluation.success');

    }
  }


  @override
  Future<void> error(HookContext context, [Object? error]) async {
    if (_span != null) {

      _span!.setAttribute('feature_flag.variant', 'error');
      _span!.setAttribute('feature_flag.evaluation.success', false);
      _span!.setAttribute('error.code', 'evaluation_failed');
      Telemetry.metrics.increment('evaluation.error');

    }
  }


  @override
  Future<void> finally_(HookContext context, [Object? result, Object? error]) async {
    if (_span != null) {
      final end = DateTime.now();
      final latency = end.difference(_startTime);

      Telemetry.recordLatency(context.flagKey, latency);

      Telemetry.endSpan(_span!);
    }
  }

  

}
