// This is a generated file - do not edit.
//
// Generated from ingestion/v1/ingestion.proto.

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

import 'ingestion.pb.dart' as $0;

export 'ingestion.pb.dart';

@$pb.GrpcServiceName('ingestion.v1.IngestionService')
class IngestionServiceClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  IngestionServiceClient(super.channel, {super.options, super.interceptors});

  /// Inicjuje upload — zwraca signed URL i upload ID
  $grpc.ResponseFuture<$0.CreateAudioUploadResponse> createAudioUpload(
    $0.CreateAudioUploadRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$createAudioUpload, request, options: options);
  }

  /// Notyfikuje że upload się zakończył (Flutter wysyła po PUT do GCS)
  $grpc.ResponseFuture<$0.CompleteAudioUploadResponse> completeAudioUpload(
    $0.CompleteAudioUploadRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$completeAudioUpload, request, options: options);
  }

  /// Stan uploadu
  $grpc.ResponseFuture<$0.AudioUploadStatus> getAudioUploadStatus(
    $0.GetAudioUploadStatusRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getAudioUploadStatus, request, options: options);
  }

  // method descriptors

  static final _$createAudioUpload = $grpc.ClientMethod<
          $0.CreateAudioUploadRequest, $0.CreateAudioUploadResponse>(
      '/ingestion.v1.IngestionService/CreateAudioUpload',
      ($0.CreateAudioUploadRequest value) => value.writeToBuffer(),
      $0.CreateAudioUploadResponse.fromBuffer);
  static final _$completeAudioUpload = $grpc.ClientMethod<
          $0.CompleteAudioUploadRequest, $0.CompleteAudioUploadResponse>(
      '/ingestion.v1.IngestionService/CompleteAudioUpload',
      ($0.CompleteAudioUploadRequest value) => value.writeToBuffer(),
      $0.CompleteAudioUploadResponse.fromBuffer);
  static final _$getAudioUploadStatus =
      $grpc.ClientMethod<$0.GetAudioUploadStatusRequest, $0.AudioUploadStatus>(
          '/ingestion.v1.IngestionService/GetAudioUploadStatus',
          ($0.GetAudioUploadStatusRequest value) => value.writeToBuffer(),
          $0.AudioUploadStatus.fromBuffer);
}

@$pb.GrpcServiceName('ingestion.v1.IngestionService')
abstract class IngestionServiceBase extends $grpc.Service {
  $core.String get $name => 'ingestion.v1.IngestionService';

  IngestionServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.CreateAudioUploadRequest,
            $0.CreateAudioUploadResponse>(
        'CreateAudioUpload',
        createAudioUpload_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.CreateAudioUploadRequest.fromBuffer(value),
        ($0.CreateAudioUploadResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.CompleteAudioUploadRequest,
            $0.CompleteAudioUploadResponse>(
        'CompleteAudioUpload',
        completeAudioUpload_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.CompleteAudioUploadRequest.fromBuffer(value),
        ($0.CompleteAudioUploadResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GetAudioUploadStatusRequest,
            $0.AudioUploadStatus>(
        'GetAudioUploadStatus',
        getAudioUploadStatus_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.GetAudioUploadStatusRequest.fromBuffer(value),
        ($0.AudioUploadStatus value) => value.writeToBuffer()));
  }

  $async.Future<$0.CreateAudioUploadResponse> createAudioUpload_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.CreateAudioUploadRequest> $request) async {
    return createAudioUpload($call, await $request);
  }

  $async.Future<$0.CreateAudioUploadResponse> createAudioUpload(
      $grpc.ServiceCall call, $0.CreateAudioUploadRequest request);

  $async.Future<$0.CompleteAudioUploadResponse> completeAudioUpload_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.CompleteAudioUploadRequest> $request) async {
    return completeAudioUpload($call, await $request);
  }

  $async.Future<$0.CompleteAudioUploadResponse> completeAudioUpload(
      $grpc.ServiceCall call, $0.CompleteAudioUploadRequest request);

  $async.Future<$0.AudioUploadStatus> getAudioUploadStatus_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.GetAudioUploadStatusRequest> $request) async {
    return getAudioUploadStatus($call, await $request);
  }

  $async.Future<$0.AudioUploadStatus> getAudioUploadStatus(
      $grpc.ServiceCall call, $0.GetAudioUploadStatusRequest request);
}
