// SPDX-License-Identifier: BSD-3-Clause

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:openfeature_dart_client_sdk/openfeature_dart_client_sdk.dart';

import 'snapshot_provider.dart';

/// Supplies a short-lived evaluation token for one OpenFeature context.
///
/// Applications should obtain this token from their own trusted backend. The
/// callback must never embed an IntelliToggle OAuth client secret in a browser
/// or mobile application.
typedef IntelliToggleEvaluationTokenProvider =
    Future<String> Function(EvaluationContext context);

/// Fetches backend-evaluated flag values from IntelliToggle's OFREP endpoint.
///
/// Network work occurs only during initialization, explicit [refresh], and
/// context reconciliation. Typed OpenFeature resolutions remain synchronous
/// and read from the most recent immutable snapshot.
final class IntelliToggleRemoteClientProvider
    implements
        FeatureProvider,
        InitializableProvider,
        ContextReconciliationProvider,
        ProviderEventSource,
        ShutdownProvider,
        DomainScopedProvider {
  IntelliToggleRemoteClientProvider({
    required this.apiBaseUri,
    required this.tokenProvider,
    http.Client? httpClient,
    this.requestTimeout = const Duration(seconds: 5),
  }) : _httpClient = httpClient ?? http.Client(),
       _ownsHttpClient = httpClient == null;

  final Uri apiBaseUri;
  final IntelliToggleEvaluationTokenProvider tokenProvider;
  final http.Client _httpClient;
  final bool _ownsHttpClient;
  final Duration requestTimeout;
  final StreamController<ProviderEvent> _events =
      StreamController<ProviderEvent>.broadcast(sync: true);

  IntelliToggleClientProvider _snapshot = IntelliToggleClientProvider();
  EvaluationContext? _activeContext;
  String? _etag;
  int _refreshGeneration = 0;
  bool _closed = false;

  bool get isShutDown => _closed;

  @override
  Stream<ProviderEvent> get events => _events.stream;

  @override
  ProviderMetadata get metadata =>
      const ProviderMetadata(name: 'IntelliToggle OFREP Client Provider');

  @override
  Future<void> initialize(EvaluationContext context, {String? domain}) async {
    _ensureOpen();
    try {
      await _refreshFor(context, resetCacheValidator: true);
      _events.add(ProviderEvent(type: ProviderEventType.ready));
    } on Object catch (error) {
      _events.add(
        ProviderEvent(
          type: ProviderEventType.error,
          message: '$error',
          errorCode: ErrorCode.general,
        ),
      );
    }
  }

  /// Refreshes values for the active context, using ETag revalidation.
  Future<void> refresh() async {
    _ensureOpen();
    final context = _activeContext;
    if (context == null) {
      throw StateError('The provider has not been initialized.');
    }
    await _refreshFor(context);
  }

  @override
  Future<void> onContextChanged(
    EvaluationContext previousContext,
    EvaluationContext newContext,
  ) async {
    _ensureOpen();
    _refreshGeneration++;
    final previousKeys = _snapshotKeys;
    _events.add(
      ProviderEvent(
        type: ProviderEventType.reconciling,
        flagsChanged: previousKeys,
      ),
    );

    // Drop values before crossing a subject boundary. A failed request must
    // never leave the previous subject's values available to the new context.
    await _snapshot.shutdown();
    _snapshot = IntelliToggleClientProvider();
    _etag = null;
    try {
      await _refreshFor(newContext, resetCacheValidator: true);
      _events.add(
        ProviderEvent(
          type: ProviderEventType.contextChanged,
          flagsChanged: <String>{...previousKeys, ..._snapshotKeys}.toList()
            ..sort(),
        ),
      );
    } on Object catch (error) {
      _events.add(
        ProviderEvent(
          type: ProviderEventType.error,
          flagsChanged: previousKeys,
          message: '$error',
          errorCode: ErrorCode.general,
        ),
      );
    }
  }

  @override
  ResolutionDetails<bool> resolveBooleanValue(
    String flagKey,
    bool defaultValue,
    EvaluationContext context,
  ) => _snapshot.resolveBooleanValue(flagKey, defaultValue, context);

  @override
  ResolutionDetails<double> resolveDoubleValue(
    String flagKey,
    double defaultValue,
    EvaluationContext context,
  ) => _snapshot.resolveDoubleValue(flagKey, defaultValue, context);

  @override
  ResolutionDetails<int> resolveIntegerValue(
    String flagKey,
    int defaultValue,
    EvaluationContext context,
  ) => _snapshot.resolveIntegerValue(flagKey, defaultValue, context);

  @override
  ResolutionDetails<String> resolveStringValue(
    String flagKey,
    String defaultValue,
    EvaluationContext context,
  ) => _snapshot.resolveStringValue(flagKey, defaultValue, context);

  @override
  ResolutionDetails<Map<String, Object?>> resolveStructureValue(
    String flagKey,
    Map<String, Object?> defaultValue,
    EvaluationContext context,
  ) => _snapshot.resolveStructureValue(flagKey, defaultValue, context);

  @override
  Future<void> shutdown() async {
    if (_closed) return;
    _closed = true;
    _refreshGeneration++;
    await _snapshot.shutdown();
    if (_ownsHttpClient) _httpClient.close();
    await _events.close();
  }

  Future<void> _refreshFor(
    EvaluationContext context, {
    bool resetCacheValidator = false,
  }) async {
    final generation = ++_refreshGeneration;
    final targetingKey = context.targetingKey;
    if (targetingKey == null || targetingKey.trim().isEmpty) {
      throw const OpenFeatureException(
        'IntelliToggle OFREP requires a targeting key.',
        errorCode: ErrorCode.targetingKeyMissing,
      );
    }
    if (resetCacheValidator) _etag = null;

    final token = (await tokenProvider(context)).trim();
    if (token.isEmpty) {
      throw const OpenFeatureException(
        'The evaluation token provider returned an empty token.',
        errorCode: ErrorCode.providerNotReady,
      );
    }

    final endpoint = apiBaseUri.resolve('/ofrep/v1/evaluate/flags');
    final response = await _httpClient
        .post(
          endpoint,
          headers: {
            'authorization': 'Bearer $token',
            'content-type': 'application/json',
            'accept': 'application/json',
            'if-none-match': ?_etag,
          },
          body: jsonEncode({'context': context.asMap()}),
        )
        .timeout(requestTimeout);
    if (generation != _refreshGeneration || _closed) return;

    if (response.statusCode == 304) {
      _activeContext = context;
      return;
    }
    if (response.statusCode != 200) {
      throw OpenFeatureException(
        _errorMessage(response),
        errorCode: _errorCode(response.statusCode),
      );
    }

    Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw const OpenFeatureException(
        'IntelliToggle returned invalid JSON.',
        errorCode: ErrorCode.parseError,
      );
    }
    if (decoded is! Map) {
      throw const OpenFeatureException(
        'IntelliToggle returned an invalid OFREP response.',
        errorCode: ErrorCode.parseError,
      );
    }

    final nextSnapshot = _snapshotFromOfrep(Map<String, Object?>.from(decoded));
    if (generation != _refreshGeneration || _closed) return;
    final previousKeys = _snapshotKeys;
    await _snapshot.shutdown();
    _snapshot = IntelliToggleClientProvider(nextSnapshot);
    _activeContext = context;
    _etag = response.headers['etag'];
    final changed = <String>{...previousKeys, ..._snapshotKeys}.toList()
      ..sort();
    if (changed.isNotEmpty) {
      _events.add(
        ProviderEvent(
          type: ProviderEventType.configurationChanged,
          flagsChanged: changed,
        ),
      );
    }
  }

  List<String> get _snapshotKeys => _snapshot.snapshotKeys;

  void _ensureOpen() {
    if (_closed) {
      throw StateError('The IntelliToggle OFREP provider is shut down.');
    }
  }
}

IntelliToggleClientSnapshot _snapshotFromOfrep(Map<String, Object?> json) {
  final flags = json['flags'];
  if (flags is! List) {
    throw const OpenFeatureException(
      'IntelliToggle OFREP response is missing flags.',
      errorCode: ErrorCode.parseError,
    );
  }

  final result = <String, IntelliToggleClientFlag>{};
  for (final rawFlag in flags) {
    if (rawFlag is! Map) {
      throw const OpenFeatureException(
        'IntelliToggle returned an invalid flag evaluation.',
        errorCode: ErrorCode.parseError,
      );
    }
    final flag = Map<String, Object?>.from(rawFlag);
    if (flag.containsKey('errorCode')) continue;
    final key = flag['key'];
    final value = flag['value'];
    final reason = flag['reason'];
    final variant = flag['variant'];
    final metadata = flag['metadata'];
    if (key is! String ||
        key.isEmpty ||
        value == null ||
        reason is! String ||
        (variant != null && variant is! String) ||
        (metadata != null && metadata is! Map)) {
      throw const OpenFeatureException(
        'IntelliToggle returned an invalid flag evaluation.',
        errorCode: ErrorCode.parseError,
      );
    }
    result[key] = IntelliToggleClientFlag(
      value: value,
      reason: reason,
      variant: variant as String?,
      flagMetadata: _ofrepMetadata(metadata),
    );
  }
  return IntelliToggleClientSnapshot(result);
}

Map<String, Object> _ofrepMetadata(Object? metadata) {
  if (metadata == null) return const {};
  final result = <String, Object>{};
  for (final entry in (metadata as Map).entries) {
    final key = entry.key;
    final value = entry.value;
    if (key is! String ||
        (value is! bool && value is! String && value is! num)) {
      throw const OpenFeatureException(
        'IntelliToggle returned invalid flag metadata.',
        errorCode: ErrorCode.parseError,
      );
    }
    result[key] = value;
  }
  return result;
}

ErrorCode _errorCode(int statusCode) => switch (statusCode) {
  400 => ErrorCode.invalidContext,
  401 || 403 => ErrorCode.providerNotReady,
  404 => ErrorCode.flagNotFound,
  _ => ErrorCode.general,
};

String _errorMessage(http.Response response) {
  try {
    final decoded = jsonDecode(response.body);
    if (decoded is Map && decoded['errorDetails'] is String) {
      return decoded['errorDetails'] as String;
    }
  } on FormatException {
    // Use the status-only message below.
  }
  return 'IntelliToggle OFREP request failed with status '
      '${response.statusCode}.';
}
