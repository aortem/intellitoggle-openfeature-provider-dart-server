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

    test('supports initial flags via constructor', () async {
      final seeded = InMemoryProvider(initialFlags: {
        'a': true,
        'b': 'hello',
      });
      final br = await seeded.getBooleanFlag('a', false);
      final sr = await seeded.getStringFlag('b', 'x');
      expect(br.value, true);
      expect(sr.value, 'hello');
    });

    test('supports context-aware callbacks', () async {
      provider.setFlag('is-admin', (Map<String, dynamic> ctx) => ctx['role'] == 'admin');
      final r1 = await provider.getBooleanFlag('is-admin', false, context: {'role': 'admin'});
      final r2 = await provider.getBooleanFlag('is-admin', false, context: {'role': 'user'});
      expect(r1.value, true);
      expect(r2.value, false);
    });

    test('configuration changed emits union of previous and new keys', () async {
      final events = <IntelliToggleEvent>[];
      final sub = provider.events.listen(events.add);
      provider.setFlag('a', 1);
      provider.setFlag('b', 2);
      // remove a and add c -> union should be a,b,c
      provider.removeFlag('a');
      provider.setFlag('c', 3);
      await Future.delayed(const Duration(milliseconds: 20));
      final confEvents = events.where((e) => e.type == IntelliToggleEventType.configurationChanged).toList();
      expect(confEvents, isNotEmpty);
      final last = confEvents.last;
      final changed = (last.data?['flagsChanged'] as List<dynamic>?)?.cast<String>() ?? <String>[];
      expect(changed.toSet().containsAll({'a','b','c'}), true);
      await sub.cancel();
    });
  });

  group('ConsoleLoggingHook', () {
    late ConsoleLoggingHook hook;
    late MockLogger logger;

    setUp(() {
      hook = ConsoleLoggingHook(printContext: true, logger: (m) => logger.log(m));
      logger = MockLogger();
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
      await hook.finally_(context, null);

      expect(logger.messages.any((m) => m.contains('"stage":"before"') && m.contains('"flag_key":"test-flag"')), true);
      expect(logger.messages.any((m) => m.contains('"stage":"after"') && m.contains('"flag_key":"test-flag"')), true);
      expect(logger.messages.any((m) => m.contains('"stage":"finally"') && m.contains('"flag_key":"test-flag"')), true);
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
      await hook.finally_(context, null);

      expect(logger.messages.any((m) => m.contains('"stage":"error"') && m.contains('"flag_key":"test-flag"')), true);
      expect(logger.messages.any((m) => m.contains('"stage":"finally"') && m.contains('"flag_key":"test-flag"')), true);
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
  final String flagKey;
  final Object defaultValue;
  final Map<String, dynamic>? evaluationContext;
  final Map<String, dynamic>? invocationContext;
  final Exception? error;
  final Object? result;
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
