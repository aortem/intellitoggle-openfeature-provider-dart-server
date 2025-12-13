// Protobuf gRPC service/client for ofrep.v1.OfrepService (manually authored).
import 'dart:async' as $async;
import 'dart:core' as $core;
import 'package:grpc/grpc.dart' as $grpc;
import 'ofrep.pb.dart' as $msg;

class OfrepServiceClient extends $grpc.Client {
  static final _$getEvaluation = $grpc.ClientMethod<$msg.EvaluationRequest, $msg.EvaluationResponse>(
    '/ofrep.v1.OfrepService/GetEvaluation',
    ($msg.EvaluationRequest value) => value.writeToBuffer(),
    ($core.List<$core.int> value) => $msg.EvaluationResponse.fromBuffer(value),
  );

  OfrepServiceClient($grpc.ClientChannel channel, { $grpc.CallOptions? options })
      : super(channel, options: options);

  $grpc.ResponseFuture<$msg.EvaluationResponse> getEvaluation($msg.EvaluationRequest request, { $grpc.CallOptions? options }) {
    return $createUnaryCall(_$getEvaluation, request, options: options);
  }
}

abstract class OfrepServiceBase extends $grpc.Service {
  $core.String get $name => 'ofrep.v1.OfrepService';

  OfrepServiceBase() {
    $addMethod($grpc.ServiceMethod<$msg.EvaluationRequest, $msg.EvaluationResponse>(
      'GetEvaluation',
      getEvaluation_Pre,
      false,
      false,
      ($core.List<$core.int> value) => $msg.EvaluationRequest.fromBuffer(value),
      ($msg.EvaluationResponse value) => value.writeToBuffer(),
    ));
  }

  $async.Future<$msg.EvaluationResponse> getEvaluation_Pre($grpc.ServiceCall call, $async.Future<$msg.EvaluationRequest> request) async {
    return getEvaluation(call, await request);
  }

  $async.Future<$msg.EvaluationResponse> getEvaluation($grpc.ServiceCall call, $msg.EvaluationRequest request);
}
