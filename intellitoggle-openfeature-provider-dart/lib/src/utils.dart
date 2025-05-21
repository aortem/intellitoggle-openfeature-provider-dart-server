import 'dart:convert';

/// A generic map-based context for flag evaluations.
typedef EvaluationContext = Map<String, Object?>;

/// Encodes [ctx] to JSON, merging in any defaults.
String encodeContext(
  EvaluationContext ctx,
  Map<String, Object?> defaultContext,
) {
  final merged = Map<String, Object?>.from(defaultContext)..addAll(ctx);
  return jsonEncode(merged);
}
