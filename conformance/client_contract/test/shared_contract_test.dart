import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:openfeature_client_provider_contract/client_provider_contract.dart';
import 'package:openfeature_provider_intellitoggle_client/openfeature_provider_intellitoggle_client.dart';

void main() => runClientProviderContract(
  providerName: 'IntelliToggle OFREP remote provider',
  createFixture: IntelliToggleFixture.new,
);

class HeldResponse implements HeldProviderResponse {
  final entered = Completer<void>();
  final completed = Completer<void>();
  @override
  Future<void> get started => entered.future;
  @override
  void release() {
    if (!completed.isCompleted) completed.complete();
  }
}

class IntelliToggleFixture implements ClientProviderFixture {
  final subjects = <String?, Map<String, Object>>{};
  final held = <HeldResponse>[];
  HeldResponse? next;
  bool fail = false;
  late final MockClient transport;
  late final IntelliToggleRemoteClientProvider actual;
  late final InstrumentedProvider observed;
  IntelliToggleFixture() {
    transport = MockClient((request) async {
      final context = (jsonDecode(request.body) as Map)['context'] as Map;
      final subject = context['targetingKey'] as String?;
      // Capture the entire response BEFORE the gate, making old requests stale.
      final body = jsonEncode({
        'flags': [
          for (final entry in (subjects[subject] ?? <String, Object>{}).entries)
            {
              'key': entry.key,
              'value': entry.value,
              'reason': 'TARGETING_MATCH',
              'variant': 'contract',
            },
        ],
      });
      final failed = fail;
      fail = false;
      final response = next;
      next = null;
      if (response != null) {
        response.entered.complete();
        await response.completed.future;
      }
      return http.Response(
        failed ? '{"error":"controlled failure"}' : body,
        failed ? 503 : 200,
      );
    });
    actual = IntelliToggleRemoteClientProvider(
      apiBaseUri: Uri.parse('https://intellitoggle.contract.test'),
      tokenProvider: (_) async => 'non-secret-controlled-fixture-token',
      httpClient: transport,
    );
    observed = InstrumentedProvider(actual);
  }
  @override
  FeatureProvider get provider => observed;
  // Shutdown permanently closes the real provider's event stream and transport
  // lifecycle. Consumers must create a new instance instead of reinitializing it.
  @override
  bool get supportsReinitialization => false;
  @override
  int get shutdownCalls => observed.shutdownCalls;
  @override
  void setFlags(String? subject, Map<String, Object> flags) =>
      subjects[subject] = Map.of(flags);
  @override
  void failNextRequest() => fail = true;
  @override
  HeldProviderResponse holdNextResponse() {
    final response = HeldResponse();
    held.add(response);
    next = response;
    return response;
  }

  @override
  Future<void> refresh() => actual.refresh();
  @override
  Future<void> close() async {
    for (final response in held) {
      response.release();
    }
    await actual.shutdown();
    transport.close();
  }
}

/// Transparent call counter; every provider operation delegates unchanged to
/// the real remote provider. No flags, events or reconciliation are simulated here.
class InstrumentedProvider
    implements
        FeatureProvider,
        InitializableProvider,
        ContextReconciliationProvider,
        ProviderEventSource,
        ShutdownProvider,
        DomainScopedProvider {
  final IntelliToggleRemoteClientProvider delegate;
  int shutdownCalls = 0;
  InstrumentedProvider(this.delegate);
  @override
  ProviderMetadata get metadata => delegate.metadata;
  @override
  Stream<ProviderEvent> get events => delegate.events;
  @override
  Future<void> initialize(EvaluationContext context, {String? domain}) =>
      delegate.initialize(context, domain: domain);
  @override
  Future<void> onContextChanged(
    EvaluationContext previousContext,
    EvaluationContext newContext,
  ) => delegate.onContextChanged(previousContext, newContext);
  @override
  Future<void> shutdown() {
    shutdownCalls++;
    return delegate.shutdown();
  }

  @override
  ResolutionDetails<bool> resolveBooleanValue(
    String key,
    bool fallback,
    EvaluationContext context,
  ) => delegate.resolveBooleanValue(key, fallback, context);
  @override
  ResolutionDetails<int> resolveIntegerValue(
    String key,
    int fallback,
    EvaluationContext context,
  ) => delegate.resolveIntegerValue(key, fallback, context);
  @override
  ResolutionDetails<double> resolveDoubleValue(
    String key,
    double fallback,
    EvaluationContext context,
  ) => delegate.resolveDoubleValue(key, fallback, context);
  @override
  ResolutionDetails<String> resolveStringValue(
    String key,
    String fallback,
    EvaluationContext context,
  ) => delegate.resolveStringValue(key, fallback, context);
  @override
  ResolutionDetails<Map<String, Object?>> resolveStructureValue(
    String key,
    Map<String, Object?> fallback,
    EvaluationContext context,
  ) => delegate.resolveStructureValue(key, fallback, context);
}
