import 'dart:async';
import 'dart:io';

import 'package:grpc/grpc.dart';
import 'package:openfeature_provider_intellitoggle/openfeature_provider_intellitoggle.dart';
import 'package:openfeature_provider_intellitoggle/src/grpc/ofrep_service.dart';

Future<void> main() async {
  final provider = InMemoryProvider();
  provider.setFlag('bool-flag', true);
  provider.setFlag('string-flag', 'hello');
  provider.setFlag('int-flag', 42);
  provider.setFlag('double-flag', 3.14);
  provider.setFlag('object-flag', {'foo': 'bar', 'enabled': true});

  final host = Platform.environment['OREP_GRPC_HOST'] ?? '0.0.0.0';
  final port = int.tryParse(Platform.environment['OREP_GRPC_PORT'] ?? '50051') ?? 50051;
  final apiKey = Platform.environment['OREP_AUTH_TOKEN'] ?? 'changeme-token';

  final server = Server([
    OfrepService(provider, apiKey),
  ]);
  await server.serve(address: host, port: port);
  print('OFREP gRPC server running on $host:$port');
}
