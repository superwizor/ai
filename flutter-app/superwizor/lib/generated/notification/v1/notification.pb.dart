// This is a generated file - do not edit.
//
// Generated from notification/v1/notification.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

import 'notification.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'notification.pbenum.dart';

/// RegisterFCMToken upserts an FCM token for the authenticated user.
///
/// user_id is resolved from the Firebase ID token in gRPC metadata server-side;
/// it is NEVER trusted from the client.
///
/// Idempotent: re-registering an active (user_id, token) pair updates
/// last_used_at + app_version + device_model + locale and returns
/// already_registered=true. Token rotation handled by Firebase SDK on the
/// client; on rotation the client calls this with the new token.
class RegisterFCMTokenRequest extends $pb.GeneratedMessage {
  factory RegisterFCMTokenRequest({
    $core.String? token,
    Platform? platform,
    $core.String? appVersion,
    $core.String? deviceModel,
    $core.String? locale,
  }) {
    final result = create();
    if (token != null) result.token = token;
    if (platform != null) result.platform = platform;
    if (appVersion != null) result.appVersion = appVersion;
    if (deviceModel != null) result.deviceModel = deviceModel;
    if (locale != null) result.locale = locale;
    return result;
  }

  RegisterFCMTokenRequest._();

  factory RegisterFCMTokenRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RegisterFCMTokenRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RegisterFCMTokenRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'notification.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'token')
    ..aE<Platform>(2, _omitFieldNames ? '' : 'platform',
        enumValues: Platform.values)
    ..aOS(3, _omitFieldNames ? '' : 'appVersion')
    ..aOS(4, _omitFieldNames ? '' : 'deviceModel')
    ..aOS(5, _omitFieldNames ? '' : 'locale')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RegisterFCMTokenRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RegisterFCMTokenRequest copyWith(
          void Function(RegisterFCMTokenRequest) updates) =>
      super.copyWith((message) => updates(message as RegisterFCMTokenRequest))
          as RegisterFCMTokenRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RegisterFCMTokenRequest create() => RegisterFCMTokenRequest._();
  @$core.override
  RegisterFCMTokenRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RegisterFCMTokenRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RegisterFCMTokenRequest>(create);
  static RegisterFCMTokenRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get token => $_getSZ(0);
  @$pb.TagNumber(1)
  set token($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasToken() => $_has(0);
  @$pb.TagNumber(1)
  void clearToken() => $_clearField(1);

  @$pb.TagNumber(2)
  Platform get platform => $_getN(1);
  @$pb.TagNumber(2)
  set platform(Platform value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasPlatform() => $_has(1);
  @$pb.TagNumber(2)
  void clearPlatform() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get appVersion => $_getSZ(2);
  @$pb.TagNumber(3)
  set appVersion($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasAppVersion() => $_has(2);
  @$pb.TagNumber(3)
  void clearAppVersion() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get deviceModel => $_getSZ(3);
  @$pb.TagNumber(4)
  set deviceModel($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasDeviceModel() => $_has(3);
  @$pb.TagNumber(4)
  void clearDeviceModel() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get locale => $_getSZ(4);
  @$pb.TagNumber(5)
  set locale($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasLocale() => $_has(4);
  @$pb.TagNumber(5)
  void clearLocale() => $_clearField(5);
}

class RegisterFCMTokenResponse extends $pb.GeneratedMessage {
  factory RegisterFCMTokenResponse({
    $core.String? tokenId,
    $core.bool? alreadyRegistered,
  }) {
    final result = create();
    if (tokenId != null) result.tokenId = tokenId;
    if (alreadyRegistered != null) result.alreadyRegistered = alreadyRegistered;
    return result;
  }

  RegisterFCMTokenResponse._();

  factory RegisterFCMTokenResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RegisterFCMTokenResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RegisterFCMTokenResponse',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'notification.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'tokenId')
    ..aOB(2, _omitFieldNames ? '' : 'alreadyRegistered')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RegisterFCMTokenResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RegisterFCMTokenResponse copyWith(
          void Function(RegisterFCMTokenResponse) updates) =>
      super.copyWith((message) => updates(message as RegisterFCMTokenResponse))
          as RegisterFCMTokenResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RegisterFCMTokenResponse create() => RegisterFCMTokenResponse._();
  @$core.override
  RegisterFCMTokenResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RegisterFCMTokenResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RegisterFCMTokenResponse>(create);
  static RegisterFCMTokenResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get tokenId => $_getSZ(0);
  @$pb.TagNumber(1)
  set tokenId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTokenId() => $_has(0);
  @$pb.TagNumber(1)
  void clearTokenId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get alreadyRegistered => $_getBF(1);
  @$pb.TagNumber(2)
  set alreadyRegistered($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasAlreadyRegistered() => $_has(1);
  @$pb.TagNumber(2)
  void clearAlreadyRegistered() => $_clearField(2);
}

/// RemoveFCMToken soft-deletes a token (sets invalidated_at). Called on user
/// logout from a device. Idempotent: removing an already-removed token is a
/// no-op success.
class RemoveFCMTokenRequest extends $pb.GeneratedMessage {
  factory RemoveFCMTokenRequest({
    $core.String? token,
  }) {
    final result = create();
    if (token != null) result.token = token;
    return result;
  }

  RemoveFCMTokenRequest._();

  factory RemoveFCMTokenRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RemoveFCMTokenRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RemoveFCMTokenRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'notification.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'token')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RemoveFCMTokenRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RemoveFCMTokenRequest copyWith(
          void Function(RemoveFCMTokenRequest) updates) =>
      super.copyWith((message) => updates(message as RemoveFCMTokenRequest))
          as RemoveFCMTokenRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RemoveFCMTokenRequest create() => RemoveFCMTokenRequest._();
  @$core.override
  RemoveFCMTokenRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RemoveFCMTokenRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RemoveFCMTokenRequest>(create);
  static RemoveFCMTokenRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get token => $_getSZ(0);
  @$pb.TagNumber(1)
  set token($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasToken() => $_has(0);
  @$pb.TagNumber(1)
  void clearToken() => $_clearField(1);
}

class GetUnreadCountResponse extends $pb.GeneratedMessage {
  factory GetUnreadCountResponse({
    $core.int? count,
  }) {
    final result = create();
    if (count != null) result.count = count;
    return result;
  }

  GetUnreadCountResponse._();

  factory GetUnreadCountResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetUnreadCountResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetUnreadCountResponse',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'notification.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'count')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetUnreadCountResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetUnreadCountResponse copyWith(
          void Function(GetUnreadCountResponse) updates) =>
      super.copyWith((message) => updates(message as GetUnreadCountResponse))
          as GetUnreadCountResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetUnreadCountResponse create() => GetUnreadCountResponse._();
  @$core.override
  GetUnreadCountResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetUnreadCountResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetUnreadCountResponse>(create);
  static GetUnreadCountResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get count => $_getIZ(0);
  @$pb.TagNumber(1)
  set count($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCount() => $_has(0);
  @$pb.TagNumber(1)
  void clearCount() => $_clearField(1);
}

class HealthCheckResponse extends $pb.GeneratedMessage {
  factory HealthCheckResponse({
    $core.bool? ok,
    $core.String? version,
  }) {
    final result = create();
    if (ok != null) result.ok = ok;
    if (version != null) result.version = version;
    return result;
  }

  HealthCheckResponse._();

  factory HealthCheckResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory HealthCheckResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'HealthCheckResponse',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'notification.v1'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'ok')
    ..aOS(2, _omitFieldNames ? '' : 'version')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HealthCheckResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HealthCheckResponse copyWith(void Function(HealthCheckResponse) updates) =>
      super.copyWith((message) => updates(message as HealthCheckResponse))
          as HealthCheckResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static HealthCheckResponse create() => HealthCheckResponse._();
  @$core.override
  HealthCheckResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static HealthCheckResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<HealthCheckResponse>(create);
  static HealthCheckResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get ok => $_getBF(0);
  @$pb.TagNumber(1)
  set ok($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasOk() => $_has(0);
  @$pb.TagNumber(1)
  void clearOk() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get version => $_getSZ(1);
  @$pb.TagNumber(2)
  set version($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasVersion() => $_has(1);
  @$pb.TagNumber(2)
  void clearVersion() => $_clearField(2);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
