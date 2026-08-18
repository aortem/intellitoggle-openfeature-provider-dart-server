// SPDX-License-Identifier: BSD-3-Clause

import 'dart:async';

import 'package:openfeature_dart_client_sdk/openfeature_dart_client_sdk.dart';

/// One flag value already evaluated by a trusted IntelliToggle backend.
final class IntelliToggleClientFlag {
  IntelliToggleClientFlag({
    required Object value,
    this.reason = 'STATIC',
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

  final Map<String, IntelliToggleClientFlag> flags;
}

/// Resolves a trusted backend snapshot synchronously on a Dart client.
///
/// This provider never authenticates with IntelliToggle and never performs
/// network, file, or platform-channel I/O.
final class IntelliToggleClientProvider
    implements FeatureProvider, ProviderEventSource, ShutdownProvider {
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

  @override
  Stream<ProviderEvent> get events => _events.stream;

  @override
  ProviderMetadata get metadata =>
      const ProviderMetadata(name: 'IntelliToggle Client Snapshot Provider');

  /// Replaces all locally available values with a backend-resolved snapshot.
  void replaceSnapshot(IntelliToggleClientSnapshot snapshot) {
    _ensureOpen();
    final previousKeys = _flags.keys.toSet();
    final nextKeys = snapshot.flags.keys.toSet();
    final changedKeys = <String>{...previousKeys, ...nextKeys}.toList()..sort();
    _flags = snapshot.flags;
    _events.add(
      ProviderEvent(
        type: ProviderEventType.configurationChanged,
        flagsChanged: changedKeys,
      ),
    );
  }

  /// Convenience wrapper for a flat backend response of flag values.
  void replaceValues(Map<String, Object> values) {
    replaceSnapshot(IntelliToggleClientSnapshot.fromValues(values));
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
  if (value == null ||
      value is bool ||
      value is String ||
      value is num ||
      value is DateTime) {
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
