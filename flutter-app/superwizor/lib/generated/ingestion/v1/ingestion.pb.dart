// This is a generated file - do not edit.
//
// Generated from ingestion/v1/ingestion.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;
import 'package:protobuf/well_known_types/google/protobuf/timestamp.pb.dart'
    as $1;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

class CreateAudioUploadRequest extends $pb.GeneratedMessage {
  factory CreateAudioUploadRequest({
    $core.String? therapistId,
    $core.String? patientFileId,
    $core.String? contentType,
    $fixnum.Int64? estimatedSizeBytes,
    $core.int? estimatedDurationSeconds,
    $core.String? idempotencyKey,
    $core.String? clientAppVersion,
    $core.String? clientPlatform,
  }) {
    final result = create();
    if (therapistId != null) result.therapistId = therapistId;
    if (patientFileId != null) result.patientFileId = patientFileId;
    if (contentType != null) result.contentType = contentType;
    if (estimatedSizeBytes != null)
      result.estimatedSizeBytes = estimatedSizeBytes;
    if (estimatedDurationSeconds != null)
      result.estimatedDurationSeconds = estimatedDurationSeconds;
    if (idempotencyKey != null) result.idempotencyKey = idempotencyKey;
    if (clientAppVersion != null) result.clientAppVersion = clientAppVersion;
    if (clientPlatform != null) result.clientPlatform = clientPlatform;
    return result;
  }

  CreateAudioUploadRequest._();

  factory CreateAudioUploadRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CreateAudioUploadRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CreateAudioUploadRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ingestion.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'therapistId')
    ..aOS(2, _omitFieldNames ? '' : 'patientFileId')
    ..aOS(3, _omitFieldNames ? '' : 'contentType')
    ..aInt64(4, _omitFieldNames ? '' : 'estimatedSizeBytes')
    ..aI(5, _omitFieldNames ? '' : 'estimatedDurationSeconds')
    ..aOS(6, _omitFieldNames ? '' : 'idempotencyKey')
    ..aOS(7, _omitFieldNames ? '' : 'clientAppVersion')
    ..aOS(8, _omitFieldNames ? '' : 'clientPlatform')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateAudioUploadRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateAudioUploadRequest copyWith(
          void Function(CreateAudioUploadRequest) updates) =>
      super.copyWith((message) => updates(message as CreateAudioUploadRequest))
          as CreateAudioUploadRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CreateAudioUploadRequest create() => CreateAudioUploadRequest._();
  @$core.override
  CreateAudioUploadRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CreateAudioUploadRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CreateAudioUploadRequest>(create);
  static CreateAudioUploadRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get therapistId => $_getSZ(0);
  @$pb.TagNumber(1)
  set therapistId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTherapistId() => $_has(0);
  @$pb.TagNumber(1)
  void clearTherapistId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get patientFileId => $_getSZ(1);
  @$pb.TagNumber(2)
  set patientFileId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPatientFileId() => $_has(1);
  @$pb.TagNumber(2)
  void clearPatientFileId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get contentType => $_getSZ(2);
  @$pb.TagNumber(3)
  set contentType($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasContentType() => $_has(2);
  @$pb.TagNumber(3)
  void clearContentType() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get estimatedSizeBytes => $_getI64(3);
  @$pb.TagNumber(4)
  set estimatedSizeBytes($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasEstimatedSizeBytes() => $_has(3);
  @$pb.TagNumber(4)
  void clearEstimatedSizeBytes() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get estimatedDurationSeconds => $_getIZ(4);
  @$pb.TagNumber(5)
  set estimatedDurationSeconds($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasEstimatedDurationSeconds() => $_has(4);
  @$pb.TagNumber(5)
  void clearEstimatedDurationSeconds() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get idempotencyKey => $_getSZ(5);
  @$pb.TagNumber(6)
  set idempotencyKey($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasIdempotencyKey() => $_has(5);
  @$pb.TagNumber(6)
  void clearIdempotencyKey() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get clientAppVersion => $_getSZ(6);
  @$pb.TagNumber(7)
  set clientAppVersion($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasClientAppVersion() => $_has(6);
  @$pb.TagNumber(7)
  void clearClientAppVersion() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get clientPlatform => $_getSZ(7);
  @$pb.TagNumber(8)
  set clientPlatform($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasClientPlatform() => $_has(7);
  @$pb.TagNumber(8)
  void clearClientPlatform() => $_clearField(8);
}

class CreateAudioUploadResponse extends $pb.GeneratedMessage {
  factory CreateAudioUploadResponse({
    $core.String? uploadId,
    $core.String? signedUrl,
    $1.Timestamp? signedUrlExpiresAt,
    $core.String? objectPath,
    $core.Iterable<$core.MapEntry<$core.String, $core.String>>? requiredHeaders,
  }) {
    final result = create();
    if (uploadId != null) result.uploadId = uploadId;
    if (signedUrl != null) result.signedUrl = signedUrl;
    if (signedUrlExpiresAt != null)
      result.signedUrlExpiresAt = signedUrlExpiresAt;
    if (objectPath != null) result.objectPath = objectPath;
    if (requiredHeaders != null)
      result.requiredHeaders.addEntries(requiredHeaders);
    return result;
  }

  CreateAudioUploadResponse._();

  factory CreateAudioUploadResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CreateAudioUploadResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CreateAudioUploadResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ingestion.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'uploadId')
    ..aOS(2, _omitFieldNames ? '' : 'signedUrl')
    ..aOM<$1.Timestamp>(3, _omitFieldNames ? '' : 'signedUrlExpiresAt',
        subBuilder: $1.Timestamp.create)
    ..aOS(4, _omitFieldNames ? '' : 'objectPath')
    ..m<$core.String, $core.String>(5, _omitFieldNames ? '' : 'requiredHeaders',
        entryClassName: 'CreateAudioUploadResponse.RequiredHeadersEntry',
        keyFieldType: $pb.PbFieldType.OS,
        valueFieldType: $pb.PbFieldType.OS,
        packageName: const $pb.PackageName('ingestion.v1'))
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateAudioUploadResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateAudioUploadResponse copyWith(
          void Function(CreateAudioUploadResponse) updates) =>
      super.copyWith((message) => updates(message as CreateAudioUploadResponse))
          as CreateAudioUploadResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CreateAudioUploadResponse create() => CreateAudioUploadResponse._();
  @$core.override
  CreateAudioUploadResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CreateAudioUploadResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CreateAudioUploadResponse>(create);
  static CreateAudioUploadResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get uploadId => $_getSZ(0);
  @$pb.TagNumber(1)
  set uploadId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUploadId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUploadId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get signedUrl => $_getSZ(1);
  @$pb.TagNumber(2)
  set signedUrl($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSignedUrl() => $_has(1);
  @$pb.TagNumber(2)
  void clearSignedUrl() => $_clearField(2);

  @$pb.TagNumber(3)
  $1.Timestamp get signedUrlExpiresAt => $_getN(2);
  @$pb.TagNumber(3)
  set signedUrlExpiresAt($1.Timestamp value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasSignedUrlExpiresAt() => $_has(2);
  @$pb.TagNumber(3)
  void clearSignedUrlExpiresAt() => $_clearField(3);
  @$pb.TagNumber(3)
  $1.Timestamp ensureSignedUrlExpiresAt() => $_ensure(2);

  @$pb.TagNumber(4)
  $core.String get objectPath => $_getSZ(3);
  @$pb.TagNumber(4)
  set objectPath($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasObjectPath() => $_has(3);
  @$pb.TagNumber(4)
  void clearObjectPath() => $_clearField(4);

  @$pb.TagNumber(5)
  $pb.PbMap<$core.String, $core.String> get requiredHeaders => $_getMap(4);
}

class CompleteAudioUploadRequest extends $pb.GeneratedMessage {
  factory CompleteAudioUploadRequest({
    $core.String? uploadId,
    $core.int? actualDurationSeconds,
    $fixnum.Int64? actualSizeBytes,
    $core.int? chunkCount,
    $core.String? md5Hash,
  }) {
    final result = create();
    if (uploadId != null) result.uploadId = uploadId;
    if (actualDurationSeconds != null)
      result.actualDurationSeconds = actualDurationSeconds;
    if (actualSizeBytes != null) result.actualSizeBytes = actualSizeBytes;
    if (chunkCount != null) result.chunkCount = chunkCount;
    if (md5Hash != null) result.md5Hash = md5Hash;
    return result;
  }

  CompleteAudioUploadRequest._();

  factory CompleteAudioUploadRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CompleteAudioUploadRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CompleteAudioUploadRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ingestion.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'uploadId')
    ..aI(2, _omitFieldNames ? '' : 'actualDurationSeconds')
    ..aInt64(3, _omitFieldNames ? '' : 'actualSizeBytes')
    ..aI(4, _omitFieldNames ? '' : 'chunkCount')
    ..aOS(5, _omitFieldNames ? '' : 'md5Hash')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CompleteAudioUploadRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CompleteAudioUploadRequest copyWith(
          void Function(CompleteAudioUploadRequest) updates) =>
      super.copyWith(
              (message) => updates(message as CompleteAudioUploadRequest))
          as CompleteAudioUploadRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CompleteAudioUploadRequest create() => CompleteAudioUploadRequest._();
  @$core.override
  CompleteAudioUploadRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CompleteAudioUploadRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CompleteAudioUploadRequest>(create);
  static CompleteAudioUploadRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get uploadId => $_getSZ(0);
  @$pb.TagNumber(1)
  set uploadId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUploadId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUploadId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get actualDurationSeconds => $_getIZ(1);
  @$pb.TagNumber(2)
  set actualDurationSeconds($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasActualDurationSeconds() => $_has(1);
  @$pb.TagNumber(2)
  void clearActualDurationSeconds() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get actualSizeBytes => $_getI64(2);
  @$pb.TagNumber(3)
  set actualSizeBytes($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasActualSizeBytes() => $_has(2);
  @$pb.TagNumber(3)
  void clearActualSizeBytes() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get chunkCount => $_getIZ(3);
  @$pb.TagNumber(4)
  set chunkCount($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasChunkCount() => $_has(3);
  @$pb.TagNumber(4)
  void clearChunkCount() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get md5Hash => $_getSZ(4);
  @$pb.TagNumber(5)
  set md5Hash($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasMd5Hash() => $_has(4);
  @$pb.TagNumber(5)
  void clearMd5Hash() => $_clearField(5);
}

class CompleteAudioUploadResponse extends $pb.GeneratedMessage {
  factory CompleteAudioUploadResponse({
    $core.String? uploadId,
    $core.String? sessionId,
    $core.bool? processingStarted,
  }) {
    final result = create();
    if (uploadId != null) result.uploadId = uploadId;
    if (sessionId != null) result.sessionId = sessionId;
    if (processingStarted != null) result.processingStarted = processingStarted;
    return result;
  }

  CompleteAudioUploadResponse._();

  factory CompleteAudioUploadResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CompleteAudioUploadResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CompleteAudioUploadResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ingestion.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'uploadId')
    ..aOS(2, _omitFieldNames ? '' : 'sessionId')
    ..aOB(3, _omitFieldNames ? '' : 'processingStarted')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CompleteAudioUploadResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CompleteAudioUploadResponse copyWith(
          void Function(CompleteAudioUploadResponse) updates) =>
      super.copyWith(
              (message) => updates(message as CompleteAudioUploadResponse))
          as CompleteAudioUploadResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CompleteAudioUploadResponse create() =>
      CompleteAudioUploadResponse._();
  @$core.override
  CompleteAudioUploadResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CompleteAudioUploadResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CompleteAudioUploadResponse>(create);
  static CompleteAudioUploadResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get uploadId => $_getSZ(0);
  @$pb.TagNumber(1)
  set uploadId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUploadId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUploadId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get sessionId => $_getSZ(1);
  @$pb.TagNumber(2)
  set sessionId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSessionId() => $_has(1);
  @$pb.TagNumber(2)
  void clearSessionId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get processingStarted => $_getBF(2);
  @$pb.TagNumber(3)
  set processingStarted($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasProcessingStarted() => $_has(2);
  @$pb.TagNumber(3)
  void clearProcessingStarted() => $_clearField(3);
}

class GetAudioUploadStatusRequest extends $pb.GeneratedMessage {
  factory GetAudioUploadStatusRequest({
    $core.String? uploadId,
  }) {
    final result = create();
    if (uploadId != null) result.uploadId = uploadId;
    return result;
  }

  GetAudioUploadStatusRequest._();

  factory GetAudioUploadStatusRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetAudioUploadStatusRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetAudioUploadStatusRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ingestion.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'uploadId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetAudioUploadStatusRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetAudioUploadStatusRequest copyWith(
          void Function(GetAudioUploadStatusRequest) updates) =>
      super.copyWith(
              (message) => updates(message as GetAudioUploadStatusRequest))
          as GetAudioUploadStatusRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetAudioUploadStatusRequest create() =>
      GetAudioUploadStatusRequest._();
  @$core.override
  GetAudioUploadStatusRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetAudioUploadStatusRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetAudioUploadStatusRequest>(create);
  static GetAudioUploadStatusRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get uploadId => $_getSZ(0);
  @$pb.TagNumber(1)
  set uploadId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUploadId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUploadId() => $_clearField(1);
}

class AudioUploadStatus extends $pb.GeneratedMessage {
  factory AudioUploadStatus({
    $core.String? uploadId,
    $core.String? status,
    $1.Timestamp? createdAt,
    $1.Timestamp? expiresAt,
    $core.String? errorMessage,
  }) {
    final result = create();
    if (uploadId != null) result.uploadId = uploadId;
    if (status != null) result.status = status;
    if (createdAt != null) result.createdAt = createdAt;
    if (expiresAt != null) result.expiresAt = expiresAt;
    if (errorMessage != null) result.errorMessage = errorMessage;
    return result;
  }

  AudioUploadStatus._();

  factory AudioUploadStatus.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AudioUploadStatus.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AudioUploadStatus',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ingestion.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'uploadId')
    ..aOS(2, _omitFieldNames ? '' : 'status')
    ..aOM<$1.Timestamp>(3, _omitFieldNames ? '' : 'createdAt',
        subBuilder: $1.Timestamp.create)
    ..aOM<$1.Timestamp>(4, _omitFieldNames ? '' : 'expiresAt',
        subBuilder: $1.Timestamp.create)
    ..aOS(5, _omitFieldNames ? '' : 'errorMessage')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AudioUploadStatus clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AudioUploadStatus copyWith(void Function(AudioUploadStatus) updates) =>
      super.copyWith((message) => updates(message as AudioUploadStatus))
          as AudioUploadStatus;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AudioUploadStatus create() => AudioUploadStatus._();
  @$core.override
  AudioUploadStatus createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AudioUploadStatus getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AudioUploadStatus>(create);
  static AudioUploadStatus? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get uploadId => $_getSZ(0);
  @$pb.TagNumber(1)
  set uploadId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasUploadId() => $_has(0);
  @$pb.TagNumber(1)
  void clearUploadId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get status => $_getSZ(1);
  @$pb.TagNumber(2)
  set status($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasStatus() => $_has(1);
  @$pb.TagNumber(2)
  void clearStatus() => $_clearField(2);

  @$pb.TagNumber(3)
  $1.Timestamp get createdAt => $_getN(2);
  @$pb.TagNumber(3)
  set createdAt($1.Timestamp value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasCreatedAt() => $_has(2);
  @$pb.TagNumber(3)
  void clearCreatedAt() => $_clearField(3);
  @$pb.TagNumber(3)
  $1.Timestamp ensureCreatedAt() => $_ensure(2);

  @$pb.TagNumber(4)
  $1.Timestamp get expiresAt => $_getN(3);
  @$pb.TagNumber(4)
  set expiresAt($1.Timestamp value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasExpiresAt() => $_has(3);
  @$pb.TagNumber(4)
  void clearExpiresAt() => $_clearField(4);
  @$pb.TagNumber(4)
  $1.Timestamp ensureExpiresAt() => $_ensure(3);

  @$pb.TagNumber(5)
  $core.String get errorMessage => $_getSZ(4);
  @$pb.TagNumber(5)
  set errorMessage($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasErrorMessage() => $_has(4);
  @$pb.TagNumber(5)
  void clearErrorMessage() => $_clearField(5);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
