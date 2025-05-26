// SPDX-License-Identifier: Apache-2.0

/// Unit tests for [ConsoleLoggingHook].
///
/// This test verifies that the ConsoleLoggingHook correctly prints
/// evaluation lifecycle events to stdout. In a real CI environment,
/// you may want to capture stdout or use a logging/mocking library
/// to assert on log output.
///
/// The test ensures that all lifecycle methods (`before`, `after`,
/// `error`, `finallyAfter`) can be called without throwing errors.

import 'package:test/test.dart';
import 'package:intellitoggle_openfeature/intellitoggle_openfeature.dart';

void main() {
  group('ConsoleLoggingHook', () {
    test('prints lifecycle events without throwing', () async {
      // Create a ConsoleLoggingHook instance
      final hook = ConsoleLoggingHook();

      // Build a mock HookContext for testing
      final context = HookContext(
        flagKey: 'flag',
        flagType: FlagType.boolean,
        defaultValue: true,
        clientMetadata: ClientMetadata(name: 'test'),
        providerMetadata: ProviderMetadata(name: 'test'),
        evaluationContext: null,
      );
      final hints = HookHints();

      // Build mock EvaluationDetails for the 'after' lifecycle
      final details = EvaluationDetails(
        flagKey: 'flag',
        value: true,
        reason: 'STATIC',
        variant: null,
      );

      // Call each lifecycle method; should not throw
      hook.before(context, hints);
      hook.after(context, hints, details);
      hook.error(context, hints, Exception('fail'));
      hook.finallyAfter(context, hints);
    });
  });
}