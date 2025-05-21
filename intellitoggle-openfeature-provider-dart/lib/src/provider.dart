import 'dart:async';
import 'package:open_feature/open_feature.dart';
import 'package:http/http.dart' as http;
import 'client.dart';
import 'options.dart';
import 'utils.dart';

/// An OpenFeature provider that talks to IntelliToggle’s HTTP API.
class IntelliToggleProvider implements Provider {
  final IntelliToggleOptions options;
  late final http.Client _http;
  late final Future<void> _ready;

  IntelliToggleProvider(this.options) {
    _http = http.Client();
    _ready = _initialize();
  }

  /// Internal SDK initialization (e.g. warm‐up endpoint, caching).
  Future<void> _initialize() async {
    final uri = options.baseUri.resolve('/healthz');
    final resp = await _http.get(uri).timeout(options.timeout);
    if (resp.statusCode != 200) {
      throw StateError('IntelliToggle API health check failed');
    }
  }

  @override
  Future<ResolutionDetails<T>> get<T>(
    FlagEvaluationContext ctx,
    FlagOptions opts,
  ) async {
    // Wait for SDK to be ready
    await _ready;

    // Build the HTTP client & request
    final client = IntelliToggleClient._with(this);
    return client._evaluateFlag(
      key: opts.flagKey,
      defaultValue: opts.defaultValue as T,
      context: ctx.evaluationContext ?? {},
      type: T,
    );
  }

  @override
  Future<void> shutdown() async {
    _http.close();
  }

  @override
  String get metadata => 'IntelliToggleProvider';
}
