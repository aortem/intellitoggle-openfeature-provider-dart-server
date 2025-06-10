import 'package:test/test.dart';
import 'package:openfeature_provider_intellitoggle/openfeature_provider_intellitoggle.dart';
import 'package:openfeature_dart_server_sdk/hooks.dart';

void main() {
  group('InMemoryProvider', () {
    late InMemoryProvider provider;

    setUp(() {
      provider = InMemoryProvider();
    });

    test('resolves boolean flag at runtime', () async {
      provider.setFlag('feature-x', true);
      final result = await provider.getBooleanFlag('feature-x', false);
      expect(result.value, true);
    });

    test('resolves string flag at runtime', () async {
      provider.setFlag('feature-y', 'hello');
      final result = await provider.getStringFlag('feature-y', 'default');
      expect(result.value, 'hello');
    });

    test('emits configuration changed event on set and remove', () async {
      final events = <IntelliToggleEvent>[];
      final sub = provider.events.listen(events.add);

      provider.setFlag('foo', 1);
      await Future.delayed(Duration(milliseconds: 10));
      expect(
        events.any(
          (e) => e.type == IntelliToggleEventType.configurationChanged,
        ),
        isTrue,
      );

      provider.removeFlag('foo');
      await Future.delayed(Duration(milliseconds: 10));
      expect(
        events
            .where((e) => e.type == IntelliToggleEventType.configurationChanged)
            .length,
        greaterThan(1),
      );
      await sub.cancel();
    });
  });

  group('ConsoleLoggingHook', () {
    late ConsoleLoggingHook hook;
    late MockLogger logger;

    setUp(() {
      hook = ConsoleLoggingHook();
      logger = MockLogger();
      hook.logFunction = logger.log;
    });

    test('logs before, after, and finally', () async {
      final context = MockHookContext(
        flagKey: 'test-flag',
        defaultValue: false,
        evaluationContext: {},
        invocationContext: {},
        error: null,
        result: null,
        metadata: {},
      );

      await hook.before(context);
      await hook.after(context);
      await hook.finally_(context);

      expect(
        logger.messages.any(
          (m) => m.contains('BEFORE: Evaluating flag "test-flag"'),
        ),
        true,
      );
      expect(
        logger.messages.any(
          (m) => m.contains('AFTER: Flag "test-flag" evaluation completed.'),
        ),
        true,
      );
      expect(
        logger.messages.any(
          (m) =>
              m.contains('FINALLY: Finished evaluation for flag "test-flag"'),
        ),
        true,
      );
    });

    test('logs error and finally on error', () async {
      final context = MockHookContext(
        flagKey: 'test-flag',
        defaultValue: false,
        evaluationContext: {},
        invocationContext: {},
        error: Exception('Test Error'),
        result: null,
        metadata: {},
      );

      await hook.before(context);
      await hook.error(context);
      await hook.finally_(context);

      expect(
        logger.messages.any(
          (m) => m.contains('ERROR: Flag "test-flag" evaluation failed.'),
        ),
        true,
      );
      expect(
        logger.messages.any(
          (m) =>
              m.contains('FINALLY: Finished evaluation for flag "test-flag"'),
        ),
        true,
      );
    });
  });
}

class MockLogger {
  List<String> messages = [];

  void log(String message) {
    messages.add(message);
  }
}

class MockHookContext implements HookContext {
  @override
  final String flagKey;

  @override
  final Object defaultValue;

  @override
  final Map<String, dynamic>? evaluationContext;

  @override
  final Map<String, dynamic>? invocationContext;

  @override
  final Exception? error; // Changed to Exception?

  @override
  final Object? result;

  @override
  final Map<String, dynamic> metadata;

  MockHookContext({
    required this.flagKey,
    required this.defaultValue,
    this.invocationContext,
    this.evaluationContext,
    required this.error,
    required this.result,
    required this.metadata,
  });
}
