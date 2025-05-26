import 'package:test/test.dart';
import 'package:intellitoggle_openfeature/intellitoggle_openfeature.dart';

/// Unit tests for [InMemoryProvider].
///
/// These tests verify the core behaviors required by OpenFeature Appendix A:
/// - The provider can resolve flags set at runtime.
/// - Configuration change events are emitted when flags are set or removed.
///
/// To test Appendix A requirements:
/// 1. Register the InMemoryProvider.
/// 2. Set and update flags at runtime and verify resolution.
/// 3. Listen for configuration changed events and verify they are emitted.
/// 4. (For ConsoleLoggingHook, see its own test file.)
void main() {
  group('InMemoryProvider', () {
    late InMemoryProvider provider;

    setUp(() {
      // Create a new provider before each test.
      provider = InMemoryProvider();
    });

    test('resolves boolean flag', () async {
      // Set a boolean flag and verify it resolves as expected.
      provider.setFlag('test-bool', true);
      final result = await provider.getBooleanFlag('test-bool', false);
      expect(result.value, true);
    });

    test('emits configuration changed event', () async {
      // Listen for configuration changed events.
      final events = <IntelliToggleEvent>[];
      provider.events.listen(events.add);

      // Set a flag and expect a configuration changed event.
      provider.setFlag('foo', 1);
      await Future.delayed(Duration(milliseconds: 10));
      expect(events.any((e) => e.type == IntelliToggleEventType.configurationChanged), isTrue);
    });

    test('removing flag emits configuration changed', () async {
      // Set and then remove a flag, expecting a configuration changed event.
      provider.setFlag('bar', 123);
      final events = <IntelliToggleEvent>[];
      provider.events.listen(events.add);

      provider.removeFlag('bar');
      await Future.delayed(Duration(milliseconds: 10));
      expect(events.any((e) => e.type == IntelliToggleEventType.configurationChanged), isTrue);
    });
  });
}