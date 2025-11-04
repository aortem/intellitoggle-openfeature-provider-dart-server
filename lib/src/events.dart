import 'dart:async';

/// Event types for IntelliToggle provider lifecycle
///
/// These events are emitted during various stages of provider operation,
/// allowing applications to monitor and react to provider state changes.
enum IntelliToggleEventType {
  /// Provider is ready and connected
  ready,

  /// An error occurred
  error,

  /// Configuration changed (flags updated)
  configurationChanged,

  /// A flag was evaluated
  flagEvaluated,

  /// Provider is initializing
  initializing,

  /// Provider is shutting down
  shutdown,
}

/// Event emitted by IntelliToggle provider
///
/// Contains information about provider lifecycle events, errors, and
/// flag evaluations for monitoring and debugging purposes.
class IntelliToggleEvent {
  /// Type of event
  final IntelliToggleEventType type;

  /// Optional message describing the event
  final String? message;

  /// Additional event data (context-specific)
  final Map<String, dynamic>? data;

  /// Timestamp when event was created
  final DateTime timestamp;

  /// Private constructor - use factory methods instead
  IntelliToggleEvent._({required this.type, this.message, this.data})
    : timestamp = DateTime.now();

  /// Create a ready event
  ///
  /// Emitted when the provider successfully initializes and is ready to serve requests.
  factory IntelliToggleEvent.ready() {
    return IntelliToggleEvent._(type: IntelliToggleEventType.ready);
  }

  /// Create an error event
  ///
  /// Emitted when an error occurs during provider operation.
  ///
  /// [message] - Human-readable error description
  /// [error] - Optional error object for additional context
  factory IntelliToggleEvent.error(String message, [dynamic error]) {
    return IntelliToggleEvent._(
      type: IntelliToggleEventType.error,
      message: message,
      data: error != null ? {'error': error.toString()} : null,
    );
  }

  /// Create a configuration changed event
  ///
  /// Emitted when flag configuration changes are detected (via polling or streaming).
  ///
  /// [flagsChanged] - Optional list of specific flags that changed
  factory IntelliToggleEvent.configurationChanged([
    List<String>? flagsChanged,
  ]) {
    return IntelliToggleEvent._(
      type: IntelliToggleEventType.configurationChanged,
      data: flagsChanged != null ? {'flagsChanged': flagsChanged} : null,
    );
  }

  /// Create a flag evaluated event
  ///
  /// Emitted when a flag is successfully evaluated.
  ///
  /// [flagKey] - The flag that was evaluated
  /// [value] - The evaluated value
  /// [reason] - Reason for the evaluation result
  /// [variant] - Optional variant identifier
  /// [context] - Optional evaluation context used
  factory IntelliToggleEvent.flagEvaluated(
    String flagKey,
    dynamic value,
    String reason, {
    String? variant,
    Map<String, dynamic>? context,
  }) {
    return IntelliToggleEvent._(
      type: IntelliToggleEventType.flagEvaluated,
      data: {
        'flagKey': flagKey,
        'value': value,
        'reason': reason,
        if (variant != null) 'variant': variant,
        if (context != null) 'context': context,
      },
    );
  }

  /// Create an initializing event
  ///
  /// Emitted when the provider starts initialization process.
  factory IntelliToggleEvent.initializing() {
    return IntelliToggleEvent._(type: IntelliToggleEventType.initializing);
  }

  /// Create a shutdown event
  ///
  /// Emitted when the provider is shutting down and cleaning up resources.
  factory IntelliToggleEvent.shutdown() {
    return IntelliToggleEvent._(type: IntelliToggleEventType.shutdown);
  }

  @override
  String toString() {
    final buffer = StringBuffer('IntelliToggleEvent{type: $type');
    if (message != null) buffer.write(', message: $message');
    if (data != null) buffer.write(', data: $data');
    buffer.write(', timestamp: $timestamp}');
    return buffer.toString();
  }
}

/// Event emitter for IntelliToggle provider events
///
/// Manages event broadcasting to subscribers using Dart streams.
/// Provides a broadcast stream that multiple listeners can subscribe to.
class IntelliToggleEventEmitter {
  final StreamController<IntelliToggleEvent> _controller = StreamController<IntelliToggleEvent>.broadcast();
  final List<StreamSubscription> _subscriptions = [];
  Stream<IntelliToggleEvent> get stream => _controller.stream;
  StreamSubscription<IntelliToggleEvent> listen(void Function(IntelliToggleEvent) onData) {
    final sub = _controller.stream.listen(onData);
    _subscriptions.add(sub);
    return sub;
  }
  void emit(IntelliToggleEvent event) {
    if (!_controller.isClosed) {
      _controller.add(event);
    }
  }
  void dispose() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    _controller.close();
  }
  bool get isClosed => _controller.isClosed;
}
