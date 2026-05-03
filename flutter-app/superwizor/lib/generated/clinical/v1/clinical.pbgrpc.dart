// This is a generated file - do not edit.
//
// Generated from clinical/v1/clinical.proto.

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

import 'clinical.pb.dart' as $0;

export 'clinical.pb.dart';

@$pb.GrpcServiceName('clinical.v1.ClinicalService')
class ClinicalServiceClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  ClinicalServiceClient(super.channel, {super.options, super.interceptors});

  $grpc.ResponseFuture<$0.PatientFile> createPatientFile(
    $0.CreatePatientFileRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$createPatientFile, request, options: options);
  }

  $grpc.ResponseFuture<$0.PatientFile> getPatientFile(
    $0.GetPatientFileRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getPatientFile, request, options: options);
  }

  $grpc.ResponseFuture<$0.ListPatientFilesResponse> listPatientFiles(
    $0.ListPatientFilesRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$listPatientFiles, request, options: options);
  }

  $grpc.ResponseFuture<$0.PatientFile> updatePatientFile(
    $0.UpdatePatientFileRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$updatePatientFile, request, options: options);
  }

  $grpc.ResponseFuture<$1.Empty> deletePatientFile(
    $0.DeletePatientFileRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$deletePatientFile, request, options: options);
  }

  $grpc.ResponseFuture<$0.ListModalitiesResponse> listModalities(
    $1.Empty request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$listModalities, request, options: options);
  }

  $grpc.ResponseFuture<$0.HealthCheckResponse> healthCheck(
    $1.Empty request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$healthCheck, request, options: options);
  }

  $grpc.ResponseFuture<$0.UpdateSpeakerLabelsResponse> updateSpeakerLabels(
    $0.UpdateSpeakerLabelsRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$updateSpeakerLabels, request, options: options);
  }

  // method descriptors

  static final _$createPatientFile =
      $grpc.ClientMethod<$0.CreatePatientFileRequest, $0.PatientFile>(
          '/clinical.v1.ClinicalService/CreatePatientFile',
          ($0.CreatePatientFileRequest value) => value.writeToBuffer(),
          $0.PatientFile.fromBuffer);
  static final _$getPatientFile =
      $grpc.ClientMethod<$0.GetPatientFileRequest, $0.PatientFile>(
          '/clinical.v1.ClinicalService/GetPatientFile',
          ($0.GetPatientFileRequest value) => value.writeToBuffer(),
          $0.PatientFile.fromBuffer);
  static final _$listPatientFiles = $grpc.ClientMethod<
          $0.ListPatientFilesRequest, $0.ListPatientFilesResponse>(
      '/clinical.v1.ClinicalService/ListPatientFiles',
      ($0.ListPatientFilesRequest value) => value.writeToBuffer(),
      $0.ListPatientFilesResponse.fromBuffer);
  static final _$updatePatientFile =
      $grpc.ClientMethod<$0.UpdatePatientFileRequest, $0.PatientFile>(
          '/clinical.v1.ClinicalService/UpdatePatientFile',
          ($0.UpdatePatientFileRequest value) => value.writeToBuffer(),
          $0.PatientFile.fromBuffer);
  static final _$deletePatientFile =
      $grpc.ClientMethod<$0.DeletePatientFileRequest, $1.Empty>(
          '/clinical.v1.ClinicalService/DeletePatientFile',
          ($0.DeletePatientFileRequest value) => value.writeToBuffer(),
          $1.Empty.fromBuffer);
  static final _$listModalities =
      $grpc.ClientMethod<$1.Empty, $0.ListModalitiesResponse>(
          '/clinical.v1.ClinicalService/ListModalities',
          ($1.Empty value) => value.writeToBuffer(),
          $0.ListModalitiesResponse.fromBuffer);
  static final _$healthCheck =
      $grpc.ClientMethod<$1.Empty, $0.HealthCheckResponse>(
          '/clinical.v1.ClinicalService/HealthCheck',
          ($1.Empty value) => value.writeToBuffer(),
          $0.HealthCheckResponse.fromBuffer);
  static final _$updateSpeakerLabels = $grpc.ClientMethod<
          $0.UpdateSpeakerLabelsRequest, $0.UpdateSpeakerLabelsResponse>(
      '/clinical.v1.ClinicalService/UpdateSpeakerLabels',
      ($0.UpdateSpeakerLabelsRequest value) => value.writeToBuffer(),
      $0.UpdateSpeakerLabelsResponse.fromBuffer);
}

@$pb.GrpcServiceName('clinical.v1.ClinicalService')
abstract class ClinicalServiceBase extends $grpc.Service {
  $core.String get $name => 'clinical.v1.ClinicalService';

  ClinicalServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.CreatePatientFileRequest, $0.PatientFile>(
        'CreatePatientFile',
        createPatientFile_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.CreatePatientFileRequest.fromBuffer(value),
        ($0.PatientFile value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GetPatientFileRequest, $0.PatientFile>(
        'GetPatientFile',
        getPatientFile_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.GetPatientFileRequest.fromBuffer(value),
        ($0.PatientFile value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ListPatientFilesRequest,
            $0.ListPatientFilesResponse>(
        'ListPatientFiles',
        listPatientFiles_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.ListPatientFilesRequest.fromBuffer(value),
        ($0.ListPatientFilesResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.UpdatePatientFileRequest, $0.PatientFile>(
        'UpdatePatientFile',
        updatePatientFile_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.UpdatePatientFileRequest.fromBuffer(value),
        ($0.PatientFile value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.DeletePatientFileRequest, $1.Empty>(
        'DeletePatientFile',
        deletePatientFile_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.DeletePatientFileRequest.fromBuffer(value),
        ($1.Empty value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$1.Empty, $0.ListModalitiesResponse>(
        'ListModalities',
        listModalities_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $1.Empty.fromBuffer(value),
        ($0.ListModalitiesResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$1.Empty, $0.HealthCheckResponse>(
        'HealthCheck',
        healthCheck_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $1.Empty.fromBuffer(value),
        ($0.HealthCheckResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.UpdateSpeakerLabelsRequest,
            $0.UpdateSpeakerLabelsResponse>(
        'UpdateSpeakerLabels',
        updateSpeakerLabels_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.UpdateSpeakerLabelsRequest.fromBuffer(value),
        ($0.UpdateSpeakerLabelsResponse value) => value.writeToBuffer()));
  }

  $async.Future<$0.PatientFile> createPatientFile_Pre($grpc.ServiceCall $call,
      $async.Future<$0.CreatePatientFileRequest> $request) async {
    return createPatientFile($call, await $request);
  }

  $async.Future<$0.PatientFile> createPatientFile(
      $grpc.ServiceCall call, $0.CreatePatientFileRequest request);

  $async.Future<$0.PatientFile> getPatientFile_Pre($grpc.ServiceCall $call,
      $async.Future<$0.GetPatientFileRequest> $request) async {
    return getPatientFile($call, await $request);
  }

  $async.Future<$0.PatientFile> getPatientFile(
      $grpc.ServiceCall call, $0.GetPatientFileRequest request);

  $async.Future<$0.ListPatientFilesResponse> listPatientFiles_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.ListPatientFilesRequest> $request) async {
    return listPatientFiles($call, await $request);
  }

  $async.Future<$0.ListPatientFilesResponse> listPatientFiles(
      $grpc.ServiceCall call, $0.ListPatientFilesRequest request);

  $async.Future<$0.PatientFile> updatePatientFile_Pre($grpc.ServiceCall $call,
      $async.Future<$0.UpdatePatientFileRequest> $request) async {
    return updatePatientFile($call, await $request);
  }

  $async.Future<$0.PatientFile> updatePatientFile(
      $grpc.ServiceCall call, $0.UpdatePatientFileRequest request);

  $async.Future<$1.Empty> deletePatientFile_Pre($grpc.ServiceCall $call,
      $async.Future<$0.DeletePatientFileRequest> $request) async {
    return deletePatientFile($call, await $request);
  }

  $async.Future<$1.Empty> deletePatientFile(
      $grpc.ServiceCall call, $0.DeletePatientFileRequest request);

  $async.Future<$0.ListModalitiesResponse> listModalities_Pre(
      $grpc.ServiceCall $call, $async.Future<$1.Empty> $request) async {
    return listModalities($call, await $request);
  }

  $async.Future<$0.ListModalitiesResponse> listModalities(
      $grpc.ServiceCall call, $1.Empty request);

  $async.Future<$0.HealthCheckResponse> healthCheck_Pre(
      $grpc.ServiceCall $call, $async.Future<$1.Empty> $request) async {
    return healthCheck($call, await $request);
  }

  $async.Future<$0.HealthCheckResponse> healthCheck(
      $grpc.ServiceCall call, $1.Empty request);

  $async.Future<$0.UpdateSpeakerLabelsResponse> updateSpeakerLabels_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.UpdateSpeakerLabelsRequest> $request) async {
    return updateSpeakerLabels($call, await $request);
  }

  $async.Future<$0.UpdateSpeakerLabelsResponse> updateSpeakerLabels(
      $grpc.ServiceCall call, $0.UpdateSpeakerLabelsRequest request);
}
