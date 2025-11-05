import 'dart:async';
import 'dart:convert' as $convert;
import 'dart:io';

import 'package:grpc/grpc.dart';
import 'package:openfeature_provider_intellitoggle/openfeature_provider_intellitoggle.dart';
import 'package:openfeature_provider_intellitoggle/src/gen/ofrep.pb.dart' as ofrep;
import 'package:openfeature_provider_intellitoggle/src/gen/ofrep.pbgrpc.dart' as ofrepgrpc;
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:fixnum/fixnum.dart' as $fixnum;

class OfrepService extends ofrepgrpc.OfrepServiceBase {
  final InMemoryProvider provider;
  final String apiKey;
  final String? hsSecret;
  final String? expectedAud;
  final String? expectedIss;

  OfrepService(this.provider, this.apiKey)
      : hsSecret = Platform.environment['OAUTH_JWT_HS256_SECRET'],
        expectedAud = Platform.environment['OAUTH_EXPECTED_AUD'],
        expectedIss = Platform.environment['OAUTH_EXPECTED_ISS'];

  @override
  Future<ofrep.EvaluationResponse> getEvaluation(
      ServiceCall call, ofrep.EvaluationRequest request) async {
    final ok = _isAuthorized(call.clientMetadata);
    if (!ok) {
      throw GrpcError.unauthenticated('Unauthorized');
    }

    final flagKey = request.flagKey;
    if (!provider.hasFlag(flagKey)) {
      throw GrpcError.notFound('Flag not found: $flagKey');
    }

    final ctx = <String, dynamic>{};
    ctx.addAll(request.context);

    final dv = request.defaultValue;
    final kind = dv.whichKind();
    dynamic result;
    switch (kind) {
      case ofrep.Value_Kind.boolValue:
        result = await provider.getBooleanFlag(flagKey, dv.boolValue,
            context: ctx);
        break;
      case ofrep.Value_Kind.stringValue:
        result = await provider.getStringFlag(flagKey, dv.stringValue,
            context: ctx);
        break;
      case ofrep.Value_Kind.intValue:
        result = await provider.getIntegerFlag(flagKey, dv.intValue.toInt(),
            context: ctx);
        break;
      case ofrep.Value_Kind.doubleValue:
        result = await provider.getDoubleFlag(flagKey, dv.doubleValue,
            context: ctx);
        break;
      case ofrep.Value_Kind.jsonObject:
        result = await provider.getObjectFlag(flagKey, $convert.jsonDecode(dv.jsonObject) as Map<String, dynamic>, context: ctx);
        break;
      case ofrep.Value_Kind.notSet:
        throw GrpcError.invalidArgument('defaultValue not set');
    }

    final resp = ofrep.EvaluationResponse()
      ..flagKey = result.flagKey
      ..value = _toValue(result.value)
      ..reason = result.reason
      ..evaluatorId = result.evaluatorId
      ..evaluatedAt = result.evaluatedAt.toIso8601String();
    return resp;
  }

  ofrep.Value _toValue(dynamic v) {
    final val = ofrep.Value();
    if (v is bool) val.boolValue = v;
    else if (v is String) val.stringValue = v;
    else if (v is int) val.intValue = $fixnum.Int64(v);
    else if (v is double) val.doubleValue = v;
    else if (v is Map<String, dynamic>) val.jsonObject = $convert.jsonEncode(v);
    else val.stringValue = v?.toString() ?? '';
    return val;
  }

  bool _isAuthorized(Map<String, String>? md) {
    final auth = md?['authorization'] ?? md?['Authorization'];
    if (auth == null || !auth.toLowerCase().startsWith('bearer ')) {
      return false;
    }
    final token = auth.substring(7);
    if (token == apiKey && apiKey.isNotEmpty) return true;
    if (hsSecret != null && hsSecret!.isNotEmpty) {
      try {
        final jwt = JWT.verify(token, SecretKey(hsSecret!));
        if (expectedAud != null && jwt.payload['aud'] != expectedAud) {
          return false;
        }
        if (expectedIss != null && jwt.payload['iss'] != expectedIss) {
          return false;
        }
        return true;
      } catch (_) {
        return false;
      }
    }
    return false;
  }
}
