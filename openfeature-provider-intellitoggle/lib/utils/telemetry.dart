/// Internal Telemetry Utility for OpenFeature + OpenTelemetry compatibility.
/// NOTE: This contains *no external dependencies*, as required by the ticket.
/// It generates OTel-compliant telemetry signals in a lightweight format.

class Telemetry {
  static final _metrics = _TelemetryMetrics();
  static final _spans = <String, _TelemetrySpan>{};

  /// Start a new span.
  static _TelemetrySpan startSpan(
    String name, {
    Map<String, Object?> attributes = const {},
  }) {
    final span = _TelemetrySpan(
      name: name,
      startTime: DateTime.now(),
      attributes: Map.of(attributes),
    );

    _spans[span.id] = span;
    return span;
  }

  /// End an existing span.
  static void endSpan(_TelemetrySpan span, {Object? error}) {
    span.endTime = DateTime.now();

    if (error != null) {
      span.attributes['error.code'] = error.toString();
    }

    // In a real OTEL exporter, this is where we would push external trace events.
    // For now, we keep the span internally for debugging or tests.
  }

  /// Access metrics API.
  static _TelemetryMetrics get metrics => _metrics;

  /// Utility to record latency for compatibility with histogram metrics.
  static void recordLatency(String flagKey, Duration latency) {
    _metrics.recordLatency(flagKey, latency);
  }
}

// ---------------------------------------------------------------------------
// INTERNAL SPAN MODEL (NO EXTERNAL OTEL DEPENDENCIES)
// ---------------------------------------------------------------------------

class _TelemetrySpan {
  final String id = DateTime.now().millisecondsSinceEpoch.toString();
  final String name;
  final DateTime startTime;
  DateTime? endTime;

  final Map<String, Object?> attributes;

  _TelemetrySpan({
    required this.name,
    required this.startTime,
    required this.attributes,
  });

  void setAttribute(String key, Object? value) {
    attributes[key] = value;
  }

  @override
  String toString() {
    return 'Span($name) {start: $startTime, end: $endTime, attributes: $attributes}';
  }
}

// ---------------------------------------------------------------------------
// INTERNAL METRICS MODEL (COUNTERS + HISTOGRAM)
// ---------------------------------------------------------------------------

class _TelemetryMetrics {
  final Map<String, int> counters = {};
  final Map<String, List<Duration>> latencyHistogram = {};

  void increment(String name) {
    counters[name] = (counters[name] ?? 0) + 1;
  }

  void recordLatency(String flagKey, Duration latency) {
    latencyHistogram.putIfAbsent(flagKey, () => []);
    latencyHistogram[flagKey]!.add(latency);
  }

  @override
  String toString() {
    return 'Metrics { counters: $counters, latency: $latencyHistogram }';
  }
}
typedef TelemetrySpan = _TelemetrySpan;
