import 'dart:async';

/// Configuration options for the IntelliToggle provider.
class IntelliToggleOptions {
  /// Your SDK key from the IntelliToggle dashboard.
  final String sdkKey;

  /// The base URI for the IntelliToggle API.
  final Uri baseUri;

  /// Timeout for HTTP requests & SDK initialization.
  final Duration timeout;

  /// Optional map of global default attributes to include in every context.
  final Map<String, Object?> defaultContext;

  const IntelliToggleOptions({
    required this.sdkKey,
    required this.baseUri,
    this.timeout = const Duration(seconds: 10),
    this.defaultContext = const {},
  });
}
