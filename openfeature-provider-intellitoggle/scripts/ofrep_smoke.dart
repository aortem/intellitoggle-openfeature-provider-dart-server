import 'dart:io';
import 'package:openfeature_provider_intellitoggle/openfeature_provider_intellitoggle.dart';

Future<void> main() async {
  final base =
      Platform.environment['OFREP_BASE_URL'] ?? 'http://127.0.0.1:8080';
  final token = Platform.environment['OFREP_AUTH_TOKEN'] ?? 'changeme-token';

  final provider = IntelliToggleProvider(
    clientId: "client_",
    clientSecret: "cs_",
    tenantId: "tenant_",
    options: IntelliToggleOptions(
      useOfrep: true,
      ofrepBaseUri: Uri.parse(base),
      enableLogging: true,
      timeout: const Duration(seconds: 5),
      maxRetries: 2,
    ),
  );

  print('Initializing provider against $base ...');
  try {
    await provider.initialize({});
  } catch (e) {
    print('Init error: $e');
  }

  Future<void> eval<T>(String key, T def) async {
    if (T == bool) {
      final r = await provider.getBooleanFlag(
        key,
        def as bool,
        context: {'targetingKey': 'smoke-user'},
      );
      print('bool $key => ${r.value} reason=${r.reason} err=${r.errorCode}');
    } else if (T == String) {
      final r = await provider.getStringFlag(
        key,
        def as String,
        context: {'targetingKey': 'smoke-user'},
      );
      print('string $key => ${r.value} reason=${r.reason} err=${r.errorCode}');
    } else if (T == int) {
      final r = await provider.getIntegerFlag(
        key,
        def as int,
        context: {'targetingKey': 'smoke-user'},
      );
      print('int $key => ${r.value} reason=${r.reason} err=${r.errorCode}');
    } else if (T == double) {
      final r = await provider.getDoubleFlag(
        key,
        def as double,
        context: {'targetingKey': 'smoke-user'},
      );
      print('double $key => ${r.value} reason=${r.reason} err=${r.errorCode}');
    } else {
      final r = await provider.getObjectFlag(
        key,
        def as Map<String, dynamic>,
        context: {'targetingKey': 'smoke-user'},
      );
      print('object $key => ${r.value} reason=${r.reason} err=${r.errorCode}');
    }
  }

  await eval<bool>('bool-flag', false);
  await eval<String>('string-flag', '');
  await eval<int>('int-flag', 0);
  await eval<double>('double-flag', 0.0);
  await eval<Map<String, dynamic>>('object-flag', {});
}
