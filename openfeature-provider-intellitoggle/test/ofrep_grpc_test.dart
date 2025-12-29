import 'dart:io';

import 'package:grpc/grpc.dart';
import 'package:test/test.dart';

import 'package:openfeature_provider_intellitoggle/openfeature_provider_intellitoggle.dart';
import 'package:openfeature_provider_intellitoggle/src/grpc/ofrep_service.dart';
import 'package:openfeature_provider_intellitoggle/src/gen/ofrep.pb.dart' as ofrep;
import 'package:openfeature_provider_intellitoggle/src/gen/ofrep.pbgrpc.dart' as ofrepgrpc;

void main() {
  late Server server;
  late int port;
  final token = Platform.environment['OREP_AUTH_TOKEN'] ?? 'changeme-token';

  setUpAll(() async {
    final provider = InMemoryProvider();
    provider.setFlag('bool-flag', true);
    provider.setFlag('string-flag', 'hello');
    server = Server([
      OfrepService(provider, token),
    ]);
    port = 50052;
    await server.serve(address: '127.0.0.1', port: port);
  });

  tearDownAll(() async {
    await server.shutdown();
  });

  test('gRPC: valid API key returns EvaluationResponse', () async {
    final channel = ClientChannel('127.0.0.1',
        port: port, options: const ChannelOptions(credentials: ChannelCredentials.insecure()));
    final client = ofrepgrpc.OfrepServiceClient(channel);
    final req = ofrep.EvaluationRequest()
      ..flagKey = 'bool-flag'
      ..defaultValue = (ofrep.Value()..boolValue = false);
    final resp = await client.getEvaluation(req,
        options: CallOptions(metadata: {'authorization': 'Bearer $token'}));
    expect(resp.flagKey, 'bool-flag');
    expect(resp.value.boolValue, true);
    await channel.shutdown();
  });

  test('gRPC: unauthorized returns UNAUTHENTICATED', () async {
    final channel = ClientChannel('127.0.0.1',
        port: port, options: const ChannelOptions(credentials: ChannelCredentials.insecure()));
    final client = ofrepgrpc.OfrepServiceClient(channel);
    final req = ofrep.EvaluationRequest()
      ..flagKey = 'bool-flag'
      ..defaultValue = (ofrep.Value()..boolValue = false);
    await expectLater(
        client.getEvaluation(req,
            options: CallOptions(metadata: {'authorization': 'Bearer wrong'})),
        throwsA(isA<GrpcError>().having((e) => e.code, 'code', StatusCode.unauthenticated)));
    await channel.shutdown();
  });

  test('gRPC: invalid flag returns NOT_FOUND', () async {
    final channel = ClientChannel('127.0.0.1',
        port: port, options: const ChannelOptions(credentials: ChannelCredentials.insecure()));
    final client = ofrepgrpc.OfrepServiceClient(channel);
    final req = ofrep.EvaluationRequest()
      ..flagKey = 'does-not-exist'
      ..defaultValue = (ofrep.Value()..boolValue = false);
    await expectLater(
        client.getEvaluation(req,
            options: CallOptions(metadata: {'authorization': 'Bearer $token'})),
        throwsA(isA<GrpcError>().having((e) => e.code, 'code', StatusCode.notFound)));
    await channel.shutdown();
  });
}
