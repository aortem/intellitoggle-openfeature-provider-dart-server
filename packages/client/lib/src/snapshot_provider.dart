// SPDX-License-Identifier: BSD-3-Clause

import 'dart:async';

import 'package:openfeature_dart_client_sdk/openfeature_dart_client_sdk.dart';

/// One flag value already evaluated by a trusted IntelliToggle backend.
final class IntelliToggleClientFlag {
  IntelliToggleClientFlag({
    required Object value,
    this.reason = 'CACHED',
    this.variant,
    Map<String, Object> flagMetadata = const {},
  }) : value = _copyFlagValue(value),
       flagMetadata = _copyMetadata(flagMetadata);

  final Object value;
  final String reason;
  final String? variant;
  final Map<String, Object> flagMetadata;
}

/// An immutable set of values resolved for one client subject and context.
final class IntelliToggleClientSnapshot {
  IntelliToggleClientSnapshot(Map<String, IntelliToggleClientFlag> flags)
    : flags = Map<String, IntelliToggleClientFlag>.unmodifiable(
        _validateFlags(flags),
      );

  factory IntelliToggleClientSnapshot.fromValues(Map<String, Object> values) {
    return IntelliToggleClientSnapshot(
      values.map(
        (key, value) => MapEntry(key, IntelliToggleClientFlag(value: value)),
      ),
    );
  }

  /// Builds a snapshot from a decoded backend JSON response.
  ///
  /// The full response shape is `{"flags": {"flag-key": {"value": ...}}}`.
  /// A flat map of flag keys to values is also accepted as a shorthand.
  factory IntelliToggleClientSnapshot.fromJson(Map<String, Object?> json) {
    final Object? wrappedFlags = json.length == 1 ? json['flags'] : null;
    if (wrappedFlags != null) {
      if (wrappedFlags is! Map<String, Object?>) {
        throw ArgumentError.value(
          wrappedFlags,
          'json.flags',
          'Expected a JSON object of flag entries.',
        );
      }
      return IntelliToggleClientSnapshot(
        wrappedFlags.map(
          (key, entry) => MapEntry(key, _flagFromJsonEntry(key, entry)),
        ),
      );
    }

    return IntelliToggleClientSnapshot(
      json.map(
        (key, value) => MapEntry(
          key,
          IntelliToggleClientFlag(value: _requireFlagValue(key, value)),
        ),
      ),
    );
  }

  final Map<String, IntelliToggleClientFlag> flags;
}

/// Resolves a trusted backend snapshot synchronously on a Dart client.
///
/// This provider never authenticates with IntelliToggle and never performs
/// network, file, or platform-channel I/O.
final class IntelliToggleClientProvider
    implements
        FeatureProvider,
        ProviderEventSource,
        ShutdownProvider,
        ContextReconciliationProvider {
  IntelliToggleClientProvider([IntelliToggleClientSnapshot? snapshot])
    : _flags = snapshot?.flags ?? const {};

  factory IntelliToggleClientProvider.fromValues(Map<String, Object> values) {
    return IntelliToggleClientProvider(
      IntelliToggleClientSnapshot.fromValues(values),
    );
  }

  Map<String, IntelliToggleClientFlag> _flags;
  final StreamController<ProviderEvent> _events =
      StreamController<ProviderEvent>.broadcast(sync: true);
  bool _closed = false;

  /// Whether this single-use provider has been shut down by the SDK or caller.
  bool get isShutDown => _closed;

  /// Sorted keys currently available in the immutable snapshot.
  List<String> get snapshotKeys => _flags.keys.toList()..sort();

  @override
  Stream<ProviderEvent> get events => _events.stream;

  @override
  ProviderMetadata get metadata =>
      const ProviderMetadata(name: 'IntelliToggle Client Snapshot Provider');

  /// Replaces all locally available values with a backend-resolved snapshot.
  void replaceSnapshot(IntelliToggleClientSnapshot snapshot) {
    _ensureOpen();
    final changedKeys =
        <String>{..._flags.keys, ...snapshot.flags.keys}
            .where(
              (key) => !_clientFlagsEqual(_flags[key], snapshot.flags[key]),
            )
            .toList()
          ..sort();
    _flags = snapshot.flags;
    if (changedKeys.isNotEmpty) {
      _events.add(
        ProviderEvent(
          type: ProviderEventType.configurationChanged,
          flagsChanged: changedKeys,
        ),
      );
    }
  }

  /// Convenience wrapper for a flat backend response of flag values.
  void replaceValues(Map<String, Object> values) {
    replaceSnapshot(IntelliToggleClientSnapshot.fromValues(values));
  }

  /// Invalidates values resolved for the previous subject or context.
  ///
  /// A backend refresh must call [replaceSnapshot] before evaluations can use
  /// values for the new context.
  @override
  Future<void> onContextChanged(
    EvaluationContext previousContext,
    EvaluationContext newContext,
  ) async {
    _ensureOpen();
    final invalidatedKeys = _flags.keys.toList()..sort();
    _flags = const {};
    _events.add(
      ProviderEvent(
        type: ProviderEventType.contextChanged,
        flagsChanged: invalidatedKeys,
      ),
    );
  }

  @override
  ResolutionDetails<bool> resolveBooleanValue(
    String flagKey,
    bool defaultValue,
    EvaluationContext context,
  ) => _resolve(flagKey, defaultValue);

  @override
  ResolutionDetails<double> resolveDoubleValue(
    String flagKey,
    double defaultValue,
    EvaluationContext context,
  ) => _resolve(flagKey, defaultValue);

  @override
  ResolutionDetails<int> resolveIntegerValue(
    String flagKey,
    int defaultValue,
    EvaluationContext context,
  ) => _resolve(flagKey, defaultValue);

  @override
  ResolutionDetails<String> resolveStringValue(
    String flagKey,
    String defaultValue,
    EvaluationContext context,
  ) => _resolve(flagKey, defaultValue);

  @override
  ResolutionDetails<Map<String, Object?>> resolveStructureValue(
    String flagKey,
    Map<String, Object?> defaultValue,
    EvaluationContext context,
  ) => _resolve(flagKey, defaultValue);

  @override
  Future<void> shutdown() async {
    if (_closed) {
      return;
    }
    _closed = true;
    await _events.close();
  }

  ResolutionDetails<T> _resolve<T extends Object>(
    String flagKey,
    T defaultValue,
  ) {
    if (_closed) {
      return ResolutionDetails<T>(
        value: defaultValue,
        errorCode: ErrorCode.providerNotReady,
        errorMessage: 'The IntelliToggle client provider is shut down.',
        reason: 'ERROR',
      );
    }

    final flag = _flags[flagKey];
    if (flag == null) {
      return ResolutionDetails<T>(
        value: defaultValue,
        errorCode: ErrorCode.flagNotFound,
        errorMessage: 'Flag "$flagKey" was not present in the snapshot.',
        reason: 'ERROR',
      );
    }

    final value = flag.value;
    if (T == double && value is int) {
      return ResolutionDetails<T>(
        value: value.toDouble() as T,
        reason: flag.reason,
        variant: flag.variant,
        flagMetadata: flag.flagMetadata,
      );
    }
    if (value is! T) {
      return ResolutionDetails<T>(
        value: defaultValue,
        errorCode: ErrorCode.typeMismatch,
        errorMessage: 'Flag "$flagKey" has an unexpected type.',
        reason: 'ERROR',
      );
    }

    return ResolutionDetails<T>(
      value: value,
      reason: flag.reason,
      variant: flag.variant,
      flagMetadata: flag.flagMetadata,
    );
  }

  void _ensureOpen() {
    if (_closed) {
      throw StateError('The IntelliToggle client provider is shut down.');
    }
  }
}

IntelliToggleClientFlag _flagFromJsonEntry(String key, Object? entry) {
  if (entry is! Map<String, Object?>) {
    throw ArgumentError.value(
      entry,
      'json.flags.$key',
      'Expected an object containing a non-null "value".',
    );
  }
  if (!entry.containsKey('value')) {
    throw ArgumentError.value(
      entry,
      'json.flags.$key',
      'Missing required "value".',
    );
  }

  final reason = entry['reason'];
  if (reason != null && reason is! String) {
    throw ArgumentError.value(
      reason,
      'json.flags.$key.reason',
      'Expected a string.',
    );
  }
  final variant = entry['variant'];
  if (variant != null && variant is! String) {
    throw ArgumentError.value(
      variant,
      'json.flags.$key.variant',
      'Expected a string.',
    );
  }
  final metadata = entry['metadata'];
  if (metadata != null && metadata is! Map<String, Object?>) {
    throw ArgumentError.value(
      metadata,
      'json.flags.$key.metadata',
      'Expected a JSON object.',
    );
  }

  return IntelliToggleClientFlag(
    value: _requireFlagValue(key, entry['value']),
    reason: reason as String? ?? 'CACHED',
    variant: variant as String?,
    flagMetadata: _metadataFromJson(key, metadata as Map<String, Object?>?),
  );
}

Object _requireFlagValue(String key, Object? value) {
  if (value == null) {
    throw ArgumentError.value(
      value,
      'json.flags.$key.value',
      'Flag "$key" must have a non-null value.',
    );
  }
  return value;
}

Map<String, Object> _metadataFromJson(
  String key,
  Map<String, Object?>? metadata,
) {
  if (metadata == null) return const {};
  return metadata.map((metadataKey, value) {
    if (value == null) {
      throw ArgumentError.value(
        value,
        'json.flags.$key.metadata.$metadataKey',
        'Metadata values must be bool, String, or num.',
      );
    }
    return MapEntry(metadataKey, value);
  });
}

bool _clientFlagsEqual(
  IntelliToggleClientFlag? previous,
  IntelliToggleClientFlag? next,
) {
  if (identical(previous, next)) return true;
  if (previous == null || next == null) return false;
  return previous.reason == next.reason &&
      previous.variant == next.variant &&
      _deepJsonEqual(previous.value, next.value) &&
      _deepJsonEqual(previous.flagMetadata, next.flagMetadata);
}

bool _deepJsonEqual(Object? left, Object? right) {
  if (identical(left, right) || left == right) return true;
  if (left is List<Object?> && right is List<Object?>) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (!_deepJsonEqual(left[index], right[index])) return false;
    }
    return true;
  }
  if (left is Map<String, Object?> && right is Map<String, Object?>) {
    if (left.length != right.length) return false;
    for (final entry in left.entries) {
      if (!right.containsKey(entry.key) ||
          !_deepJsonEqual(entry.value, right[entry.key])) {
        return false;
      }
    }
    return true;
  }
  return false;
}

Map<String, IntelliToggleClientFlag> _validateFlags(
  Map<String, IntelliToggleClientFlag> flags,
) {
  for (final key in flags.keys) {
    if (key.trim().isEmpty) {
      throw ArgumentError.value(key, 'flags', 'Flag keys must not be empty.');
    }
  }
  return flags;
}

Object _copyFlagValue(Object value) {
  if (value is bool || value is String || value is int || value is double) {
    return value;
  }
  if (value is Map<String, Object?>) {
    return _copyStructure(value, path: 'value');
  }
  throw ArgumentError.value(
    value,
    'value',
    'Expected bool, String, int, double, or Map<String, Object?>.',
  );
}

Map<String, Object?> _copyStructure(
  Map<String, Object?> value, {
  required String path,
}) {
  return Map<String, Object?>.unmodifiable(
    value.map(
      (key, child) =>
          MapEntry(key, _copyStructureValue(child, path: '$path.$key')),
    ),
  );
}

Object? _copyStructureValue(Object? value, {required String path}) {
  if (value == null || value is bool || value is String || value is num) {
    return value;
  }
  if (value is List<Object?>) {
    return List<Object?>.unmodifiable(
      value.indexed.map(
        (entry) => _copyStructureValue(entry.$2, path: '$path[${entry.$1}]'),
      ),
    );
  }
  if (value is Map<String, Object?>) {
    return _copyStructure(value, path: path);
  }
  throw ArgumentError.value(
    value,
    path,
    'Expected a JSON-compatible snapshot value.',
  );
}

Map<String, Object> _copyMetadata(Map<String, Object> value) {
  final result = <String, Object>{};
  for (final entry in value.entries) {
    final metadataValue = entry.value;
    if (metadataValue is! bool &&
        metadataValue is! String &&
        metadataValue is! num) {
      throw ArgumentError.value(
        metadataValue,
        'flagMetadata.${entry.key}',
        'Metadata values must be bool, String, or num.',
      );
    }
    result[entry.key] = metadataValue;
  }
  return Map<String, Object>.unmodifiable(result);
}
