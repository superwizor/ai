// This is a generated file - do not edit.
//
// Generated from ingestion/v1/ingestion.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports
// ignore_for_file: unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use createAudioUploadRequestDescriptor instead')
const CreateAudioUploadRequest$json = {
  '1': 'CreateAudioUploadRequest',
  '2': [
    {'1': 'therapist_id', '3': 1, '4': 1, '5': 9, '10': 'therapistId'},
    {'1': 'patient_file_id', '3': 2, '4': 1, '5': 9, '10': 'patientFileId'},
    {'1': 'content_type', '3': 3, '4': 1, '5': 9, '10': 'contentType'},
    {
      '1': 'estimated_size_bytes',
      '3': 4,
      '4': 1,
      '5': 3,
      '10': 'estimatedSizeBytes'
    },
    {
      '1': 'estimated_duration_seconds',
      '3': 5,
      '4': 1,
      '5': 5,
      '10': 'estimatedDurationSeconds'
    },
    {'1': 'idempotency_key', '3': 6, '4': 1, '5': 9, '10': 'idempotencyKey'},
    {
      '1': 'client_app_version',
      '3': 7,
      '4': 1,
      '5': 9,
      '10': 'clientAppVersion'
    },
    {'1': 'client_platform', '3': 8, '4': 1, '5': 9, '10': 'clientPlatform'},
  ],
};

/// Descriptor for `CreateAudioUploadRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createAudioUploadRequestDescriptor = $convert.base64Decode(
    'ChhDcmVhdGVBdWRpb1VwbG9hZFJlcXVlc3QSIQoMdGhlcmFwaXN0X2lkGAEgASgJUgt0aGVyYX'
    'Bpc3RJZBImCg9wYXRpZW50X2ZpbGVfaWQYAiABKAlSDXBhdGllbnRGaWxlSWQSIQoMY29udGVu'
    'dF90eXBlGAMgASgJUgtjb250ZW50VHlwZRIwChRlc3RpbWF0ZWRfc2l6ZV9ieXRlcxgEIAEoA1'
    'ISZXN0aW1hdGVkU2l6ZUJ5dGVzEjwKGmVzdGltYXRlZF9kdXJhdGlvbl9zZWNvbmRzGAUgASgF'
    'Uhhlc3RpbWF0ZWREdXJhdGlvblNlY29uZHMSJwoPaWRlbXBvdGVuY3lfa2V5GAYgASgJUg5pZG'
    'VtcG90ZW5jeUtleRIsChJjbGllbnRfYXBwX3ZlcnNpb24YByABKAlSEGNsaWVudEFwcFZlcnNp'
    'b24SJwoPY2xpZW50X3BsYXRmb3JtGAggASgJUg5jbGllbnRQbGF0Zm9ybQ==');

@$core.Deprecated('Use createAudioUploadResponseDescriptor instead')
const CreateAudioUploadResponse$json = {
  '1': 'CreateAudioUploadResponse',
  '2': [
    {'1': 'upload_id', '3': 1, '4': 1, '5': 9, '10': 'uploadId'},
    {'1': 'signed_url', '3': 2, '4': 1, '5': 9, '10': 'signedUrl'},
    {
      '1': 'signed_url_expires_at',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'signedUrlExpiresAt'
    },
    {'1': 'object_path', '3': 4, '4': 1, '5': 9, '10': 'objectPath'},
    {
      '1': 'required_headers',
      '3': 5,
      '4': 3,
      '5': 11,
      '6': '.ingestion.v1.CreateAudioUploadResponse.RequiredHeadersEntry',
      '10': 'requiredHeaders'
    },
  ],
  '3': [CreateAudioUploadResponse_RequiredHeadersEntry$json],
};

@$core.Deprecated('Use createAudioUploadResponseDescriptor instead')
const CreateAudioUploadResponse_RequiredHeadersEntry$json = {
  '1': 'RequiredHeadersEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 9, '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `CreateAudioUploadResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createAudioUploadResponseDescriptor = $convert.base64Decode(
    'ChlDcmVhdGVBdWRpb1VwbG9hZFJlc3BvbnNlEhsKCXVwbG9hZF9pZBgBIAEoCVIIdXBsb2FkSW'
    'QSHQoKc2lnbmVkX3VybBgCIAEoCVIJc2lnbmVkVXJsEk0KFXNpZ25lZF91cmxfZXhwaXJlc19h'
    'dBgDIAEoCzIaLmdvb2dsZS5wcm90b2J1Zi5UaW1lc3RhbXBSEnNpZ25lZFVybEV4cGlyZXNBdB'
    'IfCgtvYmplY3RfcGF0aBgEIAEoCVIKb2JqZWN0UGF0aBJnChByZXF1aXJlZF9oZWFkZXJzGAUg'
    'AygLMjwuaW5nZXN0aW9uLnYxLkNyZWF0ZUF1ZGlvVXBsb2FkUmVzcG9uc2UuUmVxdWlyZWRIZW'
    'FkZXJzRW50cnlSD3JlcXVpcmVkSGVhZGVycxpCChRSZXF1aXJlZEhlYWRlcnNFbnRyeRIQCgNr'
    'ZXkYASABKAlSA2tleRIUCgV2YWx1ZRgCIAEoCVIFdmFsdWU6AjgB');

@$core.Deprecated('Use completeAudioUploadRequestDescriptor instead')
const CompleteAudioUploadRequest$json = {
  '1': 'CompleteAudioUploadRequest',
  '2': [
    {'1': 'upload_id', '3': 1, '4': 1, '5': 9, '10': 'uploadId'},
    {
      '1': 'actual_duration_seconds',
      '3': 2,
      '4': 1,
      '5': 5,
      '10': 'actualDurationSeconds'
    },
    {'1': 'actual_size_bytes', '3': 3, '4': 1, '5': 3, '10': 'actualSizeBytes'},
    {'1': 'chunk_count', '3': 4, '4': 1, '5': 5, '10': 'chunkCount'},
    {'1': 'md5_hash', '3': 5, '4': 1, '5': 9, '10': 'md5Hash'},
  ],
};

/// Descriptor for `CompleteAudioUploadRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List completeAudioUploadRequestDescriptor = $convert.base64Decode(
    'ChpDb21wbGV0ZUF1ZGlvVXBsb2FkUmVxdWVzdBIbCgl1cGxvYWRfaWQYASABKAlSCHVwbG9hZE'
    'lkEjYKF2FjdHVhbF9kdXJhdGlvbl9zZWNvbmRzGAIgASgFUhVhY3R1YWxEdXJhdGlvblNlY29u'
    'ZHMSKgoRYWN0dWFsX3NpemVfYnl0ZXMYAyABKANSD2FjdHVhbFNpemVCeXRlcxIfCgtjaHVua1'
    '9jb3VudBgEIAEoBVIKY2h1bmtDb3VudBIZCghtZDVfaGFzaBgFIAEoCVIHbWQ1SGFzaA==');

@$core.Deprecated('Use completeAudioUploadResponseDescriptor instead')
const CompleteAudioUploadResponse$json = {
  '1': 'CompleteAudioUploadResponse',
  '2': [
    {'1': 'upload_id', '3': 1, '4': 1, '5': 9, '10': 'uploadId'},
    {'1': 'session_id', '3': 2, '4': 1, '5': 9, '10': 'sessionId'},
    {
      '1': 'processing_started',
      '3': 3,
      '4': 1,
      '5': 8,
      '10': 'processingStarted'
    },
  ],
};

/// Descriptor for `CompleteAudioUploadResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List completeAudioUploadResponseDescriptor =
    $convert.base64Decode(
        'ChtDb21wbGV0ZUF1ZGlvVXBsb2FkUmVzcG9uc2USGwoJdXBsb2FkX2lkGAEgASgJUgh1cGxvYW'
        'RJZBIdCgpzZXNzaW9uX2lkGAIgASgJUglzZXNzaW9uSWQSLQoScHJvY2Vzc2luZ19zdGFydGVk'
        'GAMgASgIUhFwcm9jZXNzaW5nU3RhcnRlZA==');

@$core.Deprecated('Use getAudioUploadStatusRequestDescriptor instead')
const GetAudioUploadStatusRequest$json = {
  '1': 'GetAudioUploadStatusRequest',
  '2': [
    {'1': 'upload_id', '3': 1, '4': 1, '5': 9, '10': 'uploadId'},
  ],
};

/// Descriptor for `GetAudioUploadStatusRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getAudioUploadStatusRequestDescriptor =
    $convert.base64Decode(
        'ChtHZXRBdWRpb1VwbG9hZFN0YXR1c1JlcXVlc3QSGwoJdXBsb2FkX2lkGAEgASgJUgh1cGxvYW'
        'RJZA==');

@$core.Deprecated('Use audioUploadStatusDescriptor instead')
const AudioUploadStatus$json = {
  '1': 'AudioUploadStatus',
  '2': [
    {'1': 'upload_id', '3': 1, '4': 1, '5': 9, '10': 'uploadId'},
    {'1': 'status', '3': 2, '4': 1, '5': 9, '10': 'status'},
    {
      '1': 'created_at',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'createdAt'
    },
    {
      '1': 'expires_at',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'expiresAt'
    },
    {'1': 'error_message', '3': 5, '4': 1, '5': 9, '10': 'errorMessage'},
  ],
};

/// Descriptor for `AudioUploadStatus`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List audioUploadStatusDescriptor = $convert.base64Decode(
    'ChFBdWRpb1VwbG9hZFN0YXR1cxIbCgl1cGxvYWRfaWQYASABKAlSCHVwbG9hZElkEhYKBnN0YX'
    'R1cxgCIAEoCVIGc3RhdHVzEjkKCmNyZWF0ZWRfYXQYAyABKAsyGi5nb29nbGUucHJvdG9idWYu'
    'VGltZXN0YW1wUgljcmVhdGVkQXQSOQoKZXhwaXJlc19hdBgEIAEoCzIaLmdvb2dsZS5wcm90b2'
    'J1Zi5UaW1lc3RhbXBSCWV4cGlyZXNBdBIjCg1lcnJvcl9tZXNzYWdlGAUgASgJUgxlcnJvck1l'
    'c3NhZ2U=');
