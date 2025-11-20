/// Internal Telemetry Utility for OpenFeature + OpenTelemetry compatibility.
/// 
/// This implementation:
/// - Contains NO external dependencies (as required by ticket)
/// - Generates OTel-compliant telemetry signals
/// - Uses bucketed histograms (not unbounded lists)
/// - Supports span events per Appendix D

class Telemetry {
  static final _metrics = _TelemetryMetrics();
  static final _spans = <String, _TelemetrySpan>{};

  /// Start a new span with OTel naming conventions
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

  /// End an existing span
  static void endSpan(_TelemetrySpan span, {Object? error}) {
    span.endTime = DateTime.now();

    if (error != null) {
      span.attributes['error'] = true;
      span.attributes['error.message'] = error.toString();
    }

    // Remove from active spans
    _spans.remove(span.id);

    // In production, this would export to OTel collector
    // For now, we log for debugging
    if (_debugMode) {
      print('[TELEMETRY] Span ended: ${span.name} (${span.duration?.inMilliseconds}ms)');
      print('  Attributes: ${span.attributes}');
      if (span.events.isNotEmpty) {
        print('  Events: ${span.events.length}');
      }
    }
  }

  /// Access metrics API
  static _TelemetryMetrics get metrics => _metrics;

  /// Record latency in histogram
  static void recordLatency(String flagKey, Duration latency) {
    _metrics.recordLatency(flagKey, latency);
  }

  // Debug mode for testing
  static bool _debugMode = false;
  static void enableDebugMode() => _debugMode = true;
}

// ---------------------------------------------------------------------------
// INTERNAL SPAN MODEL (NO EXTERNAL OTEL DEPENDENCIES)
// ---------------------------------------------------------------------------

class _TelemetrySpan {
  final String id = DateTime.now().microsecondsSinceEpoch.toString();
  final String name;
  final DateTime startTime;
  DateTime? endTime;

  final Map<String, Object?> attributes;
  final List<_SpanEvent> events = [];

  _TelemetrySpan({
    required this.name,
    required this.startTime,
    required this.attributes,
  });

  /// Set or update a span attribute
  void setAttribute(String key, Object? value) {
    attributes[key] = value;
  }

  /// Add a span event (required by Appendix D for errors)
  void addEvent(String name, {Map<String, Object?>? attributes}) {
    events.add(_SpanEvent(
      name: name,
      timestamp: DateTime.now(),
      attributes: attributes ?? {},
    ));
  }

  /// Calculate span duration
  Duration? get duration {
    if (endTime == null) return null;
    return endTime!.difference(startTime);
  }

  @override
  String toString() {
    return 'Span($name) {duration: ${duration?.inMilliseconds}ms, attributes: $attributes, events: ${events.length}}';
  }
}

/// Span event model (for error events per Appendix D)
class _SpanEvent {
  final String name;
  final DateTime timestamp;
  final Map<String, Object?> attributes;

  _SpanEvent({
    required this.name,
    required this.timestamp,
    required this.attributes,
  });
}

// ---------------------------------------------------------------------------
// INTERNAL METRICS MODEL (COUNTERS + BUCKETED HISTOGRAM)
// ---------------------------------------------------------------------------

class _TelemetryMetrics {
  final Map<String, int> counters = {};
  
  // Bucketed histogram: flagKey -> {bucket_ms: count}
  // This prevents unbounded memory growth
  final Map<String, Map<int, int>> latencyHistogram = {};

  /// Increment a counter metric
  void increment(String name) {
    counters[name] = (counters[name] ?? 0) + 1;
  }

  /// Record latency in bucketed histogram
  /// Buckets (ms): [0-1, 2-5, 6-10, 11-50, 51-200, 201-1000, 1001-5000, >5000]
  void recordLatency(String flagKey, Duration latency) {
    final ms = latency.inMilliseconds;
    final bucket = _chooseBucketMs(ms);
    
    latencyHistogram.putIfAbsent(flagKey, () => {});
    final map = latencyHistogram[flagKey]!;
    map[bucket] = (map[bucket] ?? 0) + 1;
  }

  /// Choose histogram bucket based on latency
  /// Returns bucket upper bound in milliseconds
  int _chooseBucketMs(int ms) {
    if (ms <= 1) return 1;
    if (ms <= 5) return 5;
    if (ms <= 10) return 10;
    if (ms <= 50) return 50;
    if (ms <= 200) return 200;
    if (ms <= 1000) return 1000;
    if (ms <= 5000) return 5000;
    return 10000; // catch-all for >5000ms
  }

  /// Get histogram percentiles for a flag (useful for analysis)
  Map<String, double> getPercentiles(String flagKey) {
    final histogram = latencyHistogram[flagKey];
    if (histogram == null || histogram.isEmpty) {
      return {};
    }

    // Calculate total count
    final total = histogram.values.fold<int>(0, (sum, count) => sum + count);
    
    // Calculate cumulative distribution
    final sortedBuckets = histogram.keys.toList()..sort();
    var cumulative = 0;
    final percentiles = <String, double>{};

    for (final bucket in sortedBuckets) {
      cumulative += histogram[bucket]!;
      final percentile = (cumulative / total) * 100;
      
      // Record key percentiles
      if (percentile >= 50 && !percentiles.containsKey('p50')) {
        percentiles['p50'] = bucket.toDouble();
      }
      if (percentile >= 95 && !percentiles.containsKey('p95')) {
        percentiles['p95'] = bucket.toDouble();
      }
      if (percentile >= 99 && !percentiles.containsKey('p99')) {
        percentiles['p99'] = bucket.toDouble();
      }
    }

    return percentiles;
  }

  /// Reset all metrics (useful for testing)
  void reset() {
    counters.clear();
    latencyHistogram.clear();
  }
}

/// Public typedef for span type
typedef TelemetrySpan = _TelemetrySpan;