import 'dart:async';
import 'package:open_feature/open_feature.dart';
import 'package:http/http.dart' as http;
import 'provider.dart';
import 'options.dart';
import 'utils.dart';

/// A wrapper around the OpenFeature client that talks to IntelliToggle.
class IntelliToggleClient {
  final String namespace;
  final IntelliToggleProvider _provider;

  /// Internal constructor used by the provider.
  IntelliToggleClient._(this.namespace, this._provider);

  /// Public factory to obtain a client after you’ve set the provider.
  factory IntelliToggleClient({String namespace = ''}) {
    final provider =
        OpenFeature.instance.getProvider() as IntelliToggleProvider;
    return IntelliToggleClient._(namespace, provider);
  }

  Future<ResolutionDetails<T>> getBooleanValue<T>(
    String flagKey,
    T defaultValue, {
    required EvaluationContext evaluationContext,
  }) {
    final opts = FlagOptions(
      flagKey: flagKey,
      defaultValue: defaultValue,
      type: FlagValueType.BOOLEAN,
      evaluationContext: evaluationContext,
    );
    return OpenFeature.instance.getClient(namespace).getValue(opts)
        as Future<ResolutionDetails<T>>;
  }

  Future<ResolutionDetails<T>> getStringValue<T>(
    String flagKey,
    T defaultValue, {
    required EvaluationContext evaluationContext,
  }) {
    final opts = FlagOptions(
      flagKey: flagKey,
      defaultValue: defaultValue,
      type: FlagValueType.STRING,
      evaluationContext: evaluationContext,
    );
    return OpenFeature.instance.getClient(namespace).getValue(opts)
        as Future<ResolutionDetails<T>>;
  }

  // Internal helper called by the provider
  Future<ResolutionDetails<T>> _evaluateFlag<T>({
    required String key,
    required T defaultValue,
    required EvaluationContext context,
    required Type type,
  }) async {
    final uri = _provider.options.baseUri
        .resolve('/flags/$key')
        .replace(queryParameters: {'namespace': namespace});

    final body = encodeContext(context, _provider.options.defaultContext);
    final resp = await http
        .post(
          uri,
          headers: {
            'Authorization': 'Bearer ${_provider.options.sdkKey}',
            'Content-Type': 'application/json',
          },
          body: body,
        )
        .timeout(_provider.options.timeout);

    if (resp.statusCode != 200) {
      return ResolutionDetails(
        value: defaultValue,
        errorCode: ErrorCode.PARSE_ERROR,
        reason: Reason.ERROR,
      );
    }

    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final value = json['value'] as T;

    return ResolutionDetails(
      value: value,
      reason: Reason.TARGETING_MATCH,
      flagKey: key,
      variant: json['variant'] as String?,
    );
  }
}
