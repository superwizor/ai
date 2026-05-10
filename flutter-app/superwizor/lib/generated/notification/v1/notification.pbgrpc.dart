// This is a generated file - do not edit.
//
// Generated from notification/v1/notification.proto.

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

import 'notification.pb.dart' as $0;

export 'notification.pb.dart';

/// NotificationService is the Flutter-facing API for FCM token lifecycle and
/// inbox queries. The actual notification *delivery* happens out-of-band in the
/// Cloud Functions Gen2 worker (`cmd/worker/`) which subscribes to Pub/Sub.
///
/// Inbox listing is NOT a gRPC call — Flutter subscribes directly to Firestore
/// `user_notifications/{uid}/inbox/` for live updates with offline cache.
/// Backend (this service) is the only writer of those Firestore docs.
@$pb.GrpcServiceName('notification.v1.NotificationService')
class NotificationServiceClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  NotificationServiceClient(super.channel, {super.options, super.interceptors});

  /// FCM device token lifecycle.
  $grpc.ResponseFuture<$0.RegisterFCMTokenResponse> registerFCMToken(
    $0.RegisterFCMTokenRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$registerFCMToken, request, options: options);
  }

  $grpc.ResponseFuture<$1.Empty> removeFCMToken(
    $0.RemoveFCMTokenRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$removeFCMToken, request, options: options);
  }

  /// Inbox count (badge support). Detail listing is Firestore-direct from Flutter.
  $grpc.ResponseFuture<$0.GetUnreadCountResponse> getUnreadCount(
    $1.Empty request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getUnreadCount, request, options: options);
  }

  $grpc.ResponseFuture<$0.HealthCheckResponse> healthCheck(
    $1.Empty request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$healthCheck, request, options: options);
  }

  // method descriptors

  static final _$registerFCMToken = $grpc.ClientMethod<
          $0.RegisterFCMTokenRequest, $0.RegisterFCMTokenResponse>(
      '/notification.v1.NotificationService/RegisterFCMToken',
      ($0.RegisterFCMTokenRequest value) => value.writeToBuffer(),
      $0.RegisterFCMTokenResponse.fromBuffer);
  static final _$removeFCMToken =
      $grpc.ClientMethod<$0.RemoveFCMTokenRequest, $1.Empty>(
          '/notification.v1.NotificationService/RemoveFCMToken',
          ($0.RemoveFCMTokenRequest value) => value.writeToBuffer(),
          $1.Empty.fromBuffer);
  static final _$getUnreadCount =
      $grpc.ClientMethod<$1.Empty, $0.GetUnreadCountResponse>(
          '/notification.v1.NotificationService/GetUnreadCount',
          ($1.Empty value) => value.writeToBuffer(),
          $0.GetUnreadCountResponse.fromBuffer);
  static final _$healthCheck =
      $grpc.ClientMethod<$1.Empty, $0.HealthCheckResponse>(
          '/notification.v1.NotificationService/HealthCheck',
          ($1.Empty value) => value.writeToBuffer(),
          $0.HealthCheckResponse.fromBuffer);
}

@$pb.GrpcServiceName('notification.v1.NotificationService')
abstract class NotificationServiceBase extends $grpc.Service {
  $core.String get $name => 'notification.v1.NotificationService';

  NotificationServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.RegisterFCMTokenRequest,
            $0.RegisterFCMTokenResponse>(
        'RegisterFCMToken',
        registerFCMToken_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.RegisterFCMTokenRequest.fromBuffer(value),
        ($0.RegisterFCMTokenResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.RemoveFCMTokenRequest, $1.Empty>(
        'RemoveFCMToken',
        removeFCMToken_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.RemoveFCMTokenRequest.fromBuffer(value),
        ($1.Empty value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$1.Empty, $0.GetUnreadCountResponse>(
        'GetUnreadCount',
        getUnreadCount_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $1.Empty.fromBuffer(value),
        ($0.GetUnreadCountResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$1.Empty, $0.HealthCheckResponse>(
        'HealthCheck',
        healthCheck_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $1.Empty.fromBuffer(value),
        ($0.HealthCheckResponse value) => value.writeToBuffer()));
  }

  $async.Future<$0.RegisterFCMTokenResponse> registerFCMToken_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.RegisterFCMTokenRequest> $request) async {
    return registerFCMToken($call, await $request);
  }

  $async.Future<$0.RegisterFCMTokenResponse> registerFCMToken(
      $grpc.ServiceCall call, $0.RegisterFCMTokenRequest request);

  $async.Future<$1.Empty> removeFCMToken_Pre($grpc.ServiceCall $call,
      $async.Future<$0.RemoveFCMTokenRequest> $request) async {
    return removeFCMToken($call, await $request);
  }

  $async.Future<$1.Empty> removeFCMToken(
      $grpc.ServiceCall call, $0.RemoveFCMTokenRequest request);

  $async.Future<$0.GetUnreadCountResponse> getUnreadCount_Pre(
      $grpc.ServiceCall $call, $async.Future<$1.Empty> $request) async {
    return getUnreadCount($call, await $request);
  }

  $async.Future<$0.GetUnreadCountResponse> getUnreadCount(
      $grpc.ServiceCall call, $1.Empty request);

  $async.Future<$0.HealthCheckResponse> healthCheck_Pre(
      $grpc.ServiceCall $call, $async.Future<$1.Empty> $request) async {
    return healthCheck($call, await $request);
  }

  $async.Future<$0.HealthCheckResponse> healthCheck(
      $grpc.ServiceCall call, $1.Empty request);
}
