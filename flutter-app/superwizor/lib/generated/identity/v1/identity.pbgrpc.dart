// This is a generated file - do not edit.
//
// Generated from identity/v1/identity.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:async' as $async;
import 'dart:core' as $core;

import 'package:grpc/service_api.dart' as $grpc;
import 'package:protobuf/protobuf.dart' as $pb;
import 'package:protobuf/well_known_types/google/protobuf/empty.pb.dart' as $1;

import 'identity.pb.dart' as $0;

export 'identity.pb.dart';

@$pb.GrpcServiceName('identity.v1.IdentityService')
class IdentityServiceClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  IdentityServiceClient(super.channel, {super.options, super.interceptors});

  /// Validates Firebase JWT and returns user context
  $grpc.ResponseFuture<$0.UserContext> validateToken(
    $0.ValidateTokenRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$validateToken, request, options: options);
  }

  /// Returns user profile by ID
  $grpc.ResponseFuture<$0.User> getUser(
    $0.GetUserRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getUser, request, options: options);
  }

  /// Returns user profile by Firebase UID (after login)
  $grpc.ResponseFuture<$0.User> getUserByFirebaseUID(
    $0.GetUserByFirebaseUIDRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getUserByFirebaseUID, request, options: options);
  }

  /// Creates user on first login (called from Firebase Auth trigger)
  $grpc.ResponseFuture<$0.User> createUser(
    $0.CreateUserRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$createUser, request, options: options);
  }

  /// Updates own profile
  $grpc.ResponseFuture<$0.User> updateProfile(
    $0.UpdateProfileRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$updateProfile, request, options: options);
  }

  /// RBAC: check permission on resource
  $grpc.ResponseFuture<$0.PermissionDecision> checkPermission(
    $0.CheckPermissionRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$checkPermission, request, options: options);
  }

  /// ─── Report customization (docs/10_REPORT_CUSTOMIZATION.md) ───
  /// Returns the therapist's report style preferences. The active
  /// suggestion banner (if any) is fetched separately from
  /// clinical-svc.GetActiveSuggestion — identity-svc has no
  /// dependency on clinical data tables (it's the bottom of the
  /// service dep tree).
  $grpc.ResponseFuture<$0.ReportPreferences> getReportPreferences(
    $0.GetReportPreferencesRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getReportPreferences, request, options: options);
  }

  /// Updates the therapist's preferences. Idempotent: re-sending the
  /// same payload is a no-op past the first write.
  $grpc.ResponseFuture<$0.ReportPreferences> updateReportPreferences(
    $0.UpdateReportPreferencesRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$updateReportPreferences, request,
        options: options);
  }

  /// Health check
  $grpc.ResponseFuture<$0.HealthCheckResponse> healthCheck(
    $1.Empty request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$healthCheck, request, options: options);
  }

  // method descriptors

  static final _$validateToken =
      $grpc.ClientMethod<$0.ValidateTokenRequest, $0.UserContext>(
          '/identity.v1.IdentityService/ValidateToken',
          ($0.ValidateTokenRequest value) => value.writeToBuffer(),
          $0.UserContext.fromBuffer);
  static final _$getUser = $grpc.ClientMethod<$0.GetUserRequest, $0.User>(
      '/identity.v1.IdentityService/GetUser',
      ($0.GetUserRequest value) => value.writeToBuffer(),
      $0.User.fromBuffer);
  static final _$getUserByFirebaseUID =
      $grpc.ClientMethod<$0.GetUserByFirebaseUIDRequest, $0.User>(
          '/identity.v1.IdentityService/GetUserByFirebaseUID',
          ($0.GetUserByFirebaseUIDRequest value) => value.writeToBuffer(),
          $0.User.fromBuffer);
  static final _$createUser = $grpc.ClientMethod<$0.CreateUserRequest, $0.User>(
      '/identity.v1.IdentityService/CreateUser',
      ($0.CreateUserRequest value) => value.writeToBuffer(),
      $0.User.fromBuffer);
  static final _$updateProfile =
      $grpc.ClientMethod<$0.UpdateProfileRequest, $0.User>(
          '/identity.v1.IdentityService/UpdateProfile',
          ($0.UpdateProfileRequest value) => value.writeToBuffer(),
          $0.User.fromBuffer);
  static final _$checkPermission =
      $grpc.ClientMethod<$0.CheckPermissionRequest, $0.PermissionDecision>(
          '/identity.v1.IdentityService/CheckPermission',
          ($0.CheckPermissionRequest value) => value.writeToBuffer(),
          $0.PermissionDecision.fromBuffer);
  static final _$getReportPreferences =
      $grpc.ClientMethod<$0.GetReportPreferencesRequest, $0.ReportPreferences>(
          '/identity.v1.IdentityService/GetReportPreferences',
          ($0.GetReportPreferencesRequest value) => value.writeToBuffer(),
          $0.ReportPreferences.fromBuffer);
  static final _$updateReportPreferences = $grpc.ClientMethod<
          $0.UpdateReportPreferencesRequest, $0.ReportPreferences>(
      '/identity.v1.IdentityService/UpdateReportPreferences',
      ($0.UpdateReportPreferencesRequest value) => value.writeToBuffer(),
      $0.ReportPreferences.fromBuffer);
  static final _$healthCheck =
      $grpc.ClientMethod<$1.Empty, $0.HealthCheckResponse>(
          '/identity.v1.IdentityService/HealthCheck',
          ($1.Empty value) => value.writeToBuffer(),
          $0.HealthCheckResponse.fromBuffer);
}

@$pb.GrpcServiceName('identity.v1.IdentityService')
abstract class IdentityServiceBase extends $grpc.Service {
  $core.String get $name => 'identity.v1.IdentityService';

  IdentityServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.ValidateTokenRequest, $0.UserContext>(
        'ValidateToken',
        validateToken_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.ValidateTokenRequest.fromBuffer(value),
        ($0.UserContext value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GetUserRequest, $0.User>(
        'GetUser',
        getUser_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.GetUserRequest.fromBuffer(value),
        ($0.User value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GetUserByFirebaseUIDRequest, $0.User>(
        'GetUserByFirebaseUID',
        getUserByFirebaseUID_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.GetUserByFirebaseUIDRequest.fromBuffer(value),
        ($0.User value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.CreateUserRequest, $0.User>(
        'CreateUser',
        createUser_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.CreateUserRequest.fromBuffer(value),
        ($0.User value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.UpdateProfileRequest, $0.User>(
        'UpdateProfile',
        updateProfile_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.UpdateProfileRequest.fromBuffer(value),
        ($0.User value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.CheckPermissionRequest, $0.PermissionDecision>(
            'CheckPermission',
            checkPermission_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.CheckPermissionRequest.fromBuffer(value),
            ($0.PermissionDecision value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GetReportPreferencesRequest,
            $0.ReportPreferences>(
        'GetReportPreferences',
        getReportPreferences_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.GetReportPreferencesRequest.fromBuffer(value),
        ($0.ReportPreferences value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.UpdateReportPreferencesRequest,
            $0.ReportPreferences>(
        'UpdateReportPreferences',
        updateReportPreferences_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.UpdateReportPreferencesRequest.fromBuffer(value),
        ($0.ReportPreferences value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$1.Empty, $0.HealthCheckResponse>(
        'HealthCheck',
        healthCheck_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $1.Empty.fromBuffer(value),
        ($0.HealthCheckResponse value) => value.writeToBuffer()));
  }

  $async.Future<$0.UserContext> validateToken_Pre($grpc.ServiceCall $call,
      $async.Future<$0.ValidateTokenRequest> $request) async {
    return validateToken($call, await $request);
  }

  $async.Future<$0.UserContext> validateToken(
      $grpc.ServiceCall call, $0.ValidateTokenRequest request);

  $async.Future<$0.User> getUser_Pre($grpc.ServiceCall $call,
      $async.Future<$0.GetUserRequest> $request) async {
    return getUser($call, await $request);
  }

  $async.Future<$0.User> getUser(
      $grpc.ServiceCall call, $0.GetUserRequest request);

  $async.Future<$0.User> getUserByFirebaseUID_Pre($grpc.ServiceCall $call,
      $async.Future<$0.GetUserByFirebaseUIDRequest> $request) async {
    return getUserByFirebaseUID($call, await $request);
  }

  $async.Future<$0.User> getUserByFirebaseUID(
      $grpc.ServiceCall call, $0.GetUserByFirebaseUIDRequest request);

  $async.Future<$0.User> createUser_Pre($grpc.ServiceCall $call,
      $async.Future<$0.CreateUserRequest> $request) async {
    return createUser($call, await $request);
  }

  $async.Future<$0.User> createUser(
      $grpc.ServiceCall call, $0.CreateUserRequest request);

  $async.Future<$0.User> updateProfile_Pre($grpc.ServiceCall $call,
      $async.Future<$0.UpdateProfileRequest> $request) async {
    return updateProfile($call, await $request);
  }

  $async.Future<$0.User> updateProfile(
      $grpc.ServiceCall call, $0.UpdateProfileRequest request);

  $async.Future<$0.PermissionDecision> checkPermission_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.CheckPermissionRequest> $request) async {
    return checkPermission($call, await $request);
  }

  $async.Future<$0.PermissionDecision> checkPermission(
      $grpc.ServiceCall call, $0.CheckPermissionRequest request);

  $async.Future<$0.ReportPreferences> getReportPreferences_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.GetReportPreferencesRequest> $request) async {
    return getReportPreferences($call, await $request);
  }

  $async.Future<$0.ReportPreferences> getReportPreferences(
      $grpc.ServiceCall call, $0.GetReportPreferencesRequest request);

  $async.Future<$0.ReportPreferences> updateReportPreferences_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.UpdateReportPreferencesRequest> $request) async {
    return updateReportPreferences($call, await $request);
  }

  $async.Future<$0.ReportPreferences> updateReportPreferences(
      $grpc.ServiceCall call, $0.UpdateReportPreferencesRequest request);

  $async.Future<$0.HealthCheckResponse> healthCheck_Pre(
      $grpc.ServiceCall $call, $async.Future<$1.Empty> $request) async {
    return healthCheck($call, await $request);
  }

  $async.Future<$0.HealthCheckResponse> healthCheck(
      $grpc.ServiceCall call, $1.Empty request);
}
