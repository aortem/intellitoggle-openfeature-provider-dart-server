import 'dart:async';
import 'dart:io';

import 'package:grpc/grpc.dart';
import 'package:openfeature_dart_server_sdk/feature_provider.dart'
    hide InMemoryProvider;
import 'package:openfeature_provider_intellitoggle/openfeature_provider_intellitoggle.dart';
import 'package:openfeature_provider_intellitoggle/src/grpc/ofrep_service.dart';

Future<FeatureProvider> _createProvider() async {
  final mode = (Platform.environment['OREP_PROVIDER_MODE'] ?? 'inmemory')
      .toLowerCase();
  if (mode == 'intellitoggle') {
    final clientId = Platform.environment['INTELLITOGGLE_CLIENT_ID'];
    final clientSecret = Platform.environment['INTELLITOGGLE_CLIENT_SECRET'];
    final tenantId = Platform.environment['INTELLITOGGLE_TENANT_ID'];
    if (clientId == null ||
        clientSecret == null ||
        tenantId == null ||
        clientId.isEmpty ||
        clientSecret.isEmpty ||
        tenantId.isEmpty) {
      throw StateError(
        'INTELLITOGGLE_CLIENT_ID, INTELLITOGGLE_CLIENT_SECRET, and INTELLITOGGLE_TENANT_ID must be set when OREP_PROVIDER_MODE=intellitoggle',
      );
    }
    final env = (Platform.environment['INTELLITOGGLE_ENV'] ?? 'production')
        .toLowerCase();
    final options = env == 'development'
        ? IntelliToggleOptions.development()
        : IntelliToggleOptions.production();
    final provider = IntelliToggleProvider(
      clientId: clientId,
      clientSecret: clientSecret,
      tenantId: tenantId,
      options: options,
    );
    await provider.initialize();
    return provider;
  }

  final inMemory = InMemoryProvider();
  inMemory.setFlag('bool-flag', true);
  inMemory.setFlag('string-flag', 'hello');
  inMemory.setFlag('int-flag', 42);
  inMemory.setFlag('double-flag', 3.14);
  inMemory.setFlag('object-flag', {'foo': 'bar', 'enabled': true});
  return inMemory;
}

Future<void> main() async {
  final provider = await _createProvider();

  final host = Platform.environment['OREP_GRPC_HOST'] ?? '0.0.0.0';
  final port =
      int.tryParse(Platform.environment['OREP_GRPC_PORT'] ?? '50051') ?? 50051;
  final apiKey = Platform.environment['OREP_AUTH_TOKEN'] ?? 'changeme-token';

  final server = Server.create(services: [OfrepService(provider, apiKey)]);
  await server.serve(address: host, port: port);
  print('OFREP gRPC server running on $host:$port');
}
