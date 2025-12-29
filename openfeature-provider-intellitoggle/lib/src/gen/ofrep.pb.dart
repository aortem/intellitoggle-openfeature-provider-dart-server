// Generated-style protobuf classes (manually authored) compatible with package:protobuf.
// Package: ofrep.v1

// ignore_for_file: non_constant_identifier_names, library_prefixes, unused_import, annotate_overrides

import 'dart:core' as $core;
import 'package:protobuf/protobuf.dart' as $pb;
import 'package:protobuf/src/protobuf/pb_list.dart' as $pb_list;
import 'package:fixnum/fixnum.dart' as $fixnum;

class Value extends $pb.GeneratedMessage {
  factory Value({
    $core.bool? boolValue,
    $core.String? stringValue,
    $fixnum.Int64? intValue,
    $core.double? doubleValue,
    $core.String? jsonObject,
  }) {
    final _result = create();
    if (boolValue != null) { _result.boolValue = boolValue; }
    if (stringValue != null) { _result.stringValue = stringValue; }
    if (intValue != null) { _result.intValue = intValue; }
    if (doubleValue != null) { _result.doubleValue = doubleValue; }
    if (jsonObject != null) { _result.jsonObject = jsonObject; }
    return _result;
  }
  Value._() : super();
  factory Value.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory Value.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
    'Value',
    package: const $pb.PackageName('ofrep.v1'),
    createEmptyInstance: create,
  )
    ..oo(0, [1, 2, 3, 4, 5])
    ..aOB(1, 'boolValue')
     ..aOS(2, 'stringValue')
    ..aInt64(3, 'intValue')
    ..a<$core.double>(4, 'doubleValue', $pb.PbFieldType.OD)
    ..aOS(5, 'jsonObject')
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. Use [GeneratedMessageGenericExtensions.deepCopy] instead. ')
  Value clone() => Value()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. Use [GeneratedMessageGenericExtensions.rebuild] instead. ')
  Value copyWith(void Function(Value) updates) => super.copyWith((message) => updates(message as Value)) as Value;
  $pb.BuilderInfo get info_ => _i;
  @$core.pragma('dart2js:noInline')
  static Value create() => Value._();
  Value createEmptyInstance() => create();
  static $pb.PbList<Value> createRepeated() =>
      $pb_list.newPbList<Value>();
  @$core.pragma('dart2js:noInline')
  static Value getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Value>(create);
  static Value? _defaultInstance;

  Value_Kind whichKind() => _Value_KindByTag[$_whichOneof(0)]!;
  void clearKind() => clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  $core.bool get boolValue => $_getBF(0);
  @$pb.TagNumber(1)
  set boolValue($core.bool v) { $_setBool(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasBoolValue() => $_has(0);
  @$pb.TagNumber(1)
  void clearBoolValue() => clearField(1);

  @$pb.TagNumber(2)
  $core.String get stringValue => $_getSZ(1);
  @$pb.TagNumber(2)
  set stringValue($core.String v) { $_setString(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasStringValue() => $_has(1);
  @$pb.TagNumber(2)
  void clearStringValue() => clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get intValue => $_getI64(2);
  @$pb.TagNumber(3)
  set intValue($fixnum.Int64 v) { $_setInt64(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasIntValue() => $_has(2);
  @$pb.TagNumber(3)
  void clearIntValue() => clearField(3);

  @$pb.TagNumber(4)
  $core.double get doubleValue => $_getN(3);
  @$pb.TagNumber(4)
  set doubleValue($core.double v) { $_setDouble(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasDoubleValue() => $_has(3);
  @$pb.TagNumber(4)
  void clearDoubleValue() => clearField(4);

  @$pb.TagNumber(5)
  $core.String get jsonObject => $_getSZ(4);
  @$pb.TagNumber(5)
  set jsonObject($core.String v) { $_setString(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasJsonObject() => $_has(4);
  @$pb.TagNumber(5)
  void clearJsonObject() => clearField(5);
}

enum Value_Kind { boolValue, stringValue, intValue, doubleValue, jsonObject, notSet }
const _Value_KindByTag = {
  1: Value_Kind.boolValue,
  2: Value_Kind.stringValue,
  3: Value_Kind.intValue,
  4: Value_Kind.doubleValue,
  5: Value_Kind.jsonObject,
  0: Value_Kind.notSet,
};

class EvaluationRequest extends $pb.GeneratedMessage {
  factory EvaluationRequest({
    $core.String? flagKey,
    $core.Map<$core.String, $core.String>? context,
    Value? defaultValue,
  }) {
    final _result = create();
    if (flagKey != null) { _result.flagKey = flagKey; }
    if (context != null) { _result.context.addAll(context); }
    if (defaultValue != null) { _result.defaultValue = defaultValue; }
    return _result;
  }
  EvaluationRequest._() : super();
  factory EvaluationRequest.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory EvaluationRequest.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
    'EvaluationRequest',
    package: const $pb.PackageName('ofrep.v1'),
    createEmptyInstance: create,
  )
    ..aOS(1, 'flagKey')
    ..m<$core.String, $core.String>(2, 'context',
        entryClassName: 'EvaluationRequest.ContextEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OS)
    ..aOM<Value>(3, 'defaultValue', subBuilder: Value.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary.')
  EvaluationRequest clone() => EvaluationRequest()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary.')
  EvaluationRequest copyWith(void Function(EvaluationRequest) updates) => super.copyWith((m) => updates(m as EvaluationRequest)) as EvaluationRequest;
  $pb.BuilderInfo get info_ => _i;
  @$core.pragma('dart2js:noInline')
  static EvaluationRequest create() => EvaluationRequest._();
  EvaluationRequest createEmptyInstance() => create();
  static $pb.PbList<EvaluationRequest> createRepeated() =>
      $pb_list.newPbList<EvaluationRequest>();
  @$core.pragma('dart2js:noInline')
  static EvaluationRequest getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<EvaluationRequest>(create);
  static EvaluationRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get flagKey => $_getSZ(0);
  @$pb.TagNumber(1)
  set flagKey($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasFlagKey() => $_has(0);
  @$pb.TagNumber(1)
  void clearFlagKey() => clearField(1);

  @$pb.TagNumber(2)
  $core.Map<$core.String, $core.String> get context => $_getMap(1);

  @$pb.TagNumber(3)
  Value get defaultValue => $_getN(2);
  @$pb.TagNumber(3)
  set defaultValue(Value v) { setField(3, v); }
  @$pb.TagNumber(3)
  $core.bool hasDefaultValue() => $_has(2);
  @$pb.TagNumber(3)
  void clearDefaultValue() => clearField(3);
}

class EvaluationResponse extends $pb.GeneratedMessage {
  factory EvaluationResponse({
    $core.String? flagKey,
    Value? value,
    $core.String? reason,
    $core.String? evaluatorId,
    $core.String? evaluatedAt,
  }) {
    final _result = create();
    if (flagKey != null) { _result.flagKey = flagKey; }
    if (value != null) { _result.value = value; }
    if (reason != null) { _result.reason = reason; }
    if (evaluatorId != null) { _result.evaluatorId = evaluatorId; }
    if (evaluatedAt != null) { _result.evaluatedAt = evaluatedAt; }
    return _result;
  }
  EvaluationResponse._() : super();
  factory EvaluationResponse.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory EvaluationResponse.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);
  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
    'EvaluationResponse',
    package: const $pb.PackageName('ofrep.v1'),
    createEmptyInstance: create,
  )
    ..aOS(1, 'flagKey')
    ..aOM<Value>(2, 'value', subBuilder: Value.create)
    ..aOS(3, 'reason')
    ..aOS(4, 'evaluatorId')
    ..aOS(5, 'evaluatedAt')
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary.')
  EvaluationResponse clone() => EvaluationResponse()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary.')
  EvaluationResponse copyWith(void Function(EvaluationResponse) updates) => super.copyWith((m) => updates(m as EvaluationResponse)) as EvaluationResponse;
  $pb.BuilderInfo get info_ => _i;
  @$core.pragma('dart2js:noInline')
  static EvaluationResponse create() => EvaluationResponse._();
  EvaluationResponse createEmptyInstance() => create();
  static $pb.PbList<EvaluationResponse> createRepeated() =>
      $pb_list.newPbList<EvaluationResponse>();
  @$core.pragma('dart2js:noInline')
  static EvaluationResponse getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<EvaluationResponse>(create);
  static EvaluationResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get flagKey => $_getSZ(0);
  @$pb.TagNumber(1)
  set flagKey($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasFlagKey() => $_has(0);
  @$pb.TagNumber(1)
  void clearFlagKey() => clearField(1);

  @$pb.TagNumber(2)
  Value get value => $_getN(1);
  @$pb.TagNumber(2)
  set value(Value v) { setField(2, v); }
  @$pb.TagNumber(2)
  $core.bool hasValue() => $_has(1);
  @$pb.TagNumber(2)
  void clearValue() => clearField(2);

  @$pb.TagNumber(3)
  $core.String get reason => $_getSZ(2);
  @$pb.TagNumber(3)
  set reason($core.String v) { $_setString(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasReason() => $_has(2);
  @$pb.TagNumber(3)
  void clearReason() => clearField(3);

  @$pb.TagNumber(4)
  $core.String get evaluatorId => $_getSZ(3);
  @$pb.TagNumber(4)
  set evaluatorId($core.String v) { $_setString(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasEvaluatorId() => $_has(3);
  @$pb.TagNumber(4)
  void clearEvaluatorId() => clearField(4);

  @$pb.TagNumber(5)
  $core.String get evaluatedAt => $_getSZ(4);
  @$pb.TagNumber(5)
  set evaluatedAt($core.String v) { $_setString(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasEvaluatedAt() => $_has(4);
  @$pb.TagNumber(5)
  void clearEvaluatedAt() => clearField(5);
}
