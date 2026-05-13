// This is a generated file - do not edit.
//
// Generated from clinical/v1/clinical.proto.

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

@$core.Deprecated('Use processTypeDescriptor instead')
const ProcessType$json = {
  '1': 'ProcessType',
  '2': [
    {'1': 'PROCESS_TYPE_UNSPECIFIED', '2': 0},
    {'1': 'PROCESS_TYPE_INDIVIDUAL', '2': 1},
    {'1': 'PROCESS_TYPE_COUPLE', '2': 2},
    {'1': 'PROCESS_TYPE_FAMILY', '2': 3},
    {'1': 'PROCESS_TYPE_GROUP', '2': 4},
  ],
};

/// Descriptor for `ProcessType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List processTypeDescriptor = $convert.base64Decode(
    'CgtQcm9jZXNzVHlwZRIcChhQUk9DRVNTX1RZUEVfVU5TUEVDSUZJRUQQABIbChdQUk9DRVNTX1'
    'RZUEVfSU5ESVZJRFVBTBABEhcKE1BST0NFU1NfVFlQRV9DT1VQTEUQAhIXChNQUk9DRVNTX1RZ'
    'UEVfRkFNSUxZEAMSFgoSUFJPQ0VTU19UWVBFX0dST1VQEAQ=');

@$core.Deprecated('Use patientFileDescriptor instead')
const PatientFile$json = {
  '1': 'PatientFile',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'therapist_id', '3': 2, '4': 1, '5': 9, '10': 'therapistId'},
    {'1': 'patient_id', '3': 3, '4': 1, '5': 9, '10': 'patientId'},
    {'1': 'modality_id', '3': 4, '4': 1, '5': 9, '10': 'modalityId'},
    {'1': 'modality_code', '3': 5, '4': 1, '5': 9, '10': 'modalityCode'},
    {'1': 'working_alias', '3': 6, '4': 1, '5': 9, '10': 'workingAlias'},
    {
      '1': 'process_type',
      '3': 7,
      '4': 1,
      '5': 14,
      '6': '.clinical.v1.ProcessType',
      '10': 'processType'
    },
    {
      '1': 'initial_complaint',
      '3': 8,
      '4': 1,
      '5': 9,
      '10': 'initialComplaint'
    },
    {'1': 'is_process_closed', '3': 9, '4': 1, '5': 8, '10': 'isProcessClosed'},
    {
      '1': 'has_recording_consent',
      '3': 10,
      '4': 1,
      '5': 8,
      '10': 'hasRecordingConsent'
    },
    {
      '1': 'consent_given_at',
      '3': 11,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'consentGivenAt'
    },
    {
      '1': 'first_consultation_at',
      '3': 12,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'firstConsultationAt'
    },
    {
      '1': 'private_therapist_notes',
      '3': 13,
      '4': 1,
      '5': 9,
      '10': 'privateTherapistNotes'
    },
    {
      '1': 'created_at',
      '3': 14,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'createdAt'
    },
    {
      '1': 'updated_at',
      '3': 15,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'updatedAt'
    },
    {
      '1': 'patient_first_name',
      '3': 16,
      '4': 1,
      '5': 9,
      '10': 'patientFirstName'
    },
    {
      '1': 'patient_last_name',
      '3': 17,
      '4': 1,
      '5': 9,
      '10': 'patientLastName'
    },
    {
      '1': 'patient_language_code',
      '3': 18,
      '4': 1,
      '5': 9,
      '10': 'patientLanguageCode'
    },
  ],
};

/// Descriptor for `PatientFile`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List patientFileDescriptor = $convert.base64Decode(
    'CgtQYXRpZW50RmlsZRIOCgJpZBgBIAEoCVICaWQSIQoMdGhlcmFwaXN0X2lkGAIgASgJUgt0aG'
    'VyYXBpc3RJZBIdCgpwYXRpZW50X2lkGAMgASgJUglwYXRpZW50SWQSHwoLbW9kYWxpdHlfaWQY'
    'BCABKAlSCm1vZGFsaXR5SWQSIwoNbW9kYWxpdHlfY29kZRgFIAEoCVIMbW9kYWxpdHlDb2RlEi'
    'MKDXdvcmtpbmdfYWxpYXMYBiABKAlSDHdvcmtpbmdBbGlhcxI7Cgxwcm9jZXNzX3R5cGUYByAB'
    'KA4yGC5jbGluaWNhbC52MS5Qcm9jZXNzVHlwZVILcHJvY2Vzc1R5cGUSKwoRaW5pdGlhbF9jb2'
    '1wbGFpbnQYCCABKAlSEGluaXRpYWxDb21wbGFpbnQSKgoRaXNfcHJvY2Vzc19jbG9zZWQYCSAB'
    'KAhSD2lzUHJvY2Vzc0Nsb3NlZBIyChVoYXNfcmVjb3JkaW5nX2NvbnNlbnQYCiABKAhSE2hhc1'
    'JlY29yZGluZ0NvbnNlbnQSRAoQY29uc2VudF9naXZlbl9hdBgLIAEoCzIaLmdvb2dsZS5wcm90'
    'b2J1Zi5UaW1lc3RhbXBSDmNvbnNlbnRHaXZlbkF0Ek4KFWZpcnN0X2NvbnN1bHRhdGlvbl9hdB'
    'gMIAEoCzIaLmdvb2dsZS5wcm90b2J1Zi5UaW1lc3RhbXBSE2ZpcnN0Q29uc3VsdGF0aW9uQXQS'
    'NgoXcHJpdmF0ZV90aGVyYXBpc3Rfbm90ZXMYDSABKAlSFXByaXZhdGVUaGVyYXBpc3ROb3Rlcx'
    'I5CgpjcmVhdGVkX2F0GA4gASgLMhouZ29vZ2xlLnByb3RvYnVmLlRpbWVzdGFtcFIJY3JlYXRl'
    'ZEF0EjkKCnVwZGF0ZWRfYXQYDyABKAsyGi5nb29nbGUucHJvdG9idWYuVGltZXN0YW1wUgl1cG'
    'RhdGVkQXQSLAoScGF0aWVudF9maXJzdF9uYW1lGBAgASgJUhBwYXRpZW50Rmlyc3ROYW1lEioK'
    'EXBhdGllbnRfbGFzdF9uYW1lGBEgASgJUg9wYXRpZW50TGFzdE5hbWUSMgoVcGF0aWVudF9sYW'
    '5ndWFnZV9jb2RlGBIgASgJUhNwYXRpZW50TGFuZ3VhZ2VDb2Rl');

@$core.Deprecated('Use modalityDescriptor instead')
const Modality$json = {
  '1': 'Modality',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'system_code', '3': 2, '4': 1, '5': 9, '10': 'systemCode'},
    {'1': 'display_name', '3': 3, '4': 1, '5': 9, '10': 'displayName'},
    {'1': 'is_supported', '3': 4, '4': 1, '5': 8, '10': 'isSupported'},
  ],
};

/// Descriptor for `Modality`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List modalityDescriptor = $convert.base64Decode(
    'CghNb2RhbGl0eRIOCgJpZBgBIAEoCVICaWQSHwoLc3lzdGVtX2NvZGUYAiABKAlSCnN5c3RlbU'
    'NvZGUSIQoMZGlzcGxheV9uYW1lGAMgASgJUgtkaXNwbGF5TmFtZRIhCgxpc19zdXBwb3J0ZWQY'
    'BCABKAhSC2lzU3VwcG9ydGVk');

@$core.Deprecated('Use createPatientFileRequestDescriptor instead')
const CreatePatientFileRequest$json = {
  '1': 'CreatePatientFileRequest',
  '2': [
    {'1': 'therapist_id', '3': 1, '4': 1, '5': 9, '10': 'therapistId'},
    {'1': 'modality_code', '3': 2, '4': 1, '5': 9, '10': 'modalityCode'},
    {'1': 'working_alias', '3': 3, '4': 1, '5': 9, '10': 'workingAlias'},
    {
      '1': 'process_type',
      '3': 4,
      '4': 1,
      '5': 14,
      '6': '.clinical.v1.ProcessType',
      '10': 'processType'
    },
    {
      '1': 'initial_complaint',
      '3': 5,
      '4': 1,
      '5': 9,
      '10': 'initialComplaint'
    },
    {
      '1': 'has_recording_consent',
      '3': 6,
      '4': 1,
      '5': 8,
      '10': 'hasRecordingConsent'
    },
    {'1': 'idempotency_key', '3': 7, '4': 1, '5': 9, '10': 'idempotencyKey'},
    {
      '1': 'patient_first_name',
      '3': 8,
      '4': 1,
      '5': 9,
      '10': 'patientFirstName'
    },
    {'1': 'patient_last_name', '3': 9, '4': 1, '5': 9, '10': 'patientLastName'},
    {
      '1': 'patient_language_code',
      '3': 10,
      '4': 1,
      '5': 9,
      '10': 'patientLanguageCode'
    },
  ],
};

/// Descriptor for `CreatePatientFileRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createPatientFileRequestDescriptor = $convert.base64Decode(
    'ChhDcmVhdGVQYXRpZW50RmlsZVJlcXVlc3QSIQoMdGhlcmFwaXN0X2lkGAEgASgJUgt0aGVyYX'
    'Bpc3RJZBIjCg1tb2RhbGl0eV9jb2RlGAIgASgJUgxtb2RhbGl0eUNvZGUSIwoNd29ya2luZ19h'
    'bGlhcxgDIAEoCVIMd29ya2luZ0FsaWFzEjsKDHByb2Nlc3NfdHlwZRgEIAEoDjIYLmNsaW5pY2'
    'FsLnYxLlByb2Nlc3NUeXBlUgtwcm9jZXNzVHlwZRIrChFpbml0aWFsX2NvbXBsYWludBgFIAEo'
    'CVIQaW5pdGlhbENvbXBsYWludBIyChVoYXNfcmVjb3JkaW5nX2NvbnNlbnQYBiABKAhSE2hhc1'
    'JlY29yZGluZ0NvbnNlbnQSJwoPaWRlbXBvdGVuY3lfa2V5GAcgASgJUg5pZGVtcG90ZW5jeUtl'
    'eRIsChJwYXRpZW50X2ZpcnN0X25hbWUYCCABKAlSEHBhdGllbnRGaXJzdE5hbWUSKgoRcGF0aW'
    'VudF9sYXN0X25hbWUYCSABKAlSD3BhdGllbnRMYXN0TmFtZRIyChVwYXRpZW50X2xhbmd1YWdl'
    'X2NvZGUYCiABKAlSE3BhdGllbnRMYW5ndWFnZUNvZGU=');

@$core.Deprecated('Use getPatientFileRequestDescriptor instead')
const GetPatientFileRequest$json = {
  '1': 'GetPatientFileRequest',
  '2': [
    {'1': 'patient_file_id', '3': 1, '4': 1, '5': 9, '10': 'patientFileId'},
  ],
};

/// Descriptor for `GetPatientFileRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getPatientFileRequestDescriptor = $convert.base64Decode(
    'ChVHZXRQYXRpZW50RmlsZVJlcXVlc3QSJgoPcGF0aWVudF9maWxlX2lkGAEgASgJUg1wYXRpZW'
    '50RmlsZUlk');

@$core.Deprecated('Use listPatientFilesRequestDescriptor instead')
const ListPatientFilesRequest$json = {
  '1': 'ListPatientFilesRequest',
  '2': [
    {'1': 'therapist_id', '3': 1, '4': 1, '5': 9, '10': 'therapistId'},
    {'1': 'page_size', '3': 2, '4': 1, '5': 5, '10': 'pageSize'},
    {'1': 'page_token', '3': 3, '4': 1, '5': 9, '10': 'pageToken'},
  ],
};

/// Descriptor for `ListPatientFilesRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listPatientFilesRequestDescriptor = $convert.base64Decode(
    'ChdMaXN0UGF0aWVudEZpbGVzUmVxdWVzdBIhCgx0aGVyYXBpc3RfaWQYASABKAlSC3RoZXJhcG'
    'lzdElkEhsKCXBhZ2Vfc2l6ZRgCIAEoBVIIcGFnZVNpemUSHQoKcGFnZV90b2tlbhgDIAEoCVIJ'
    'cGFnZVRva2Vu');

@$core.Deprecated('Use listPatientFilesResponseDescriptor instead')
const ListPatientFilesResponse$json = {
  '1': 'ListPatientFilesResponse',
  '2': [
    {
      '1': 'patient_files',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.clinical.v1.PatientFile',
      '10': 'patientFiles'
    },
    {'1': 'next_page_token', '3': 2, '4': 1, '5': 9, '10': 'nextPageToken'},
  ],
};

/// Descriptor for `ListPatientFilesResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listPatientFilesResponseDescriptor = $convert.base64Decode(
    'ChhMaXN0UGF0aWVudEZpbGVzUmVzcG9uc2USPQoNcGF0aWVudF9maWxlcxgBIAMoCzIYLmNsaW'
    '5pY2FsLnYxLlBhdGllbnRGaWxlUgxwYXRpZW50RmlsZXMSJgoPbmV4dF9wYWdlX3Rva2VuGAIg'
    'ASgJUg1uZXh0UGFnZVRva2Vu');

@$core.Deprecated('Use updatePatientFileRequestDescriptor instead')
const UpdatePatientFileRequest$json = {
  '1': 'UpdatePatientFileRequest',
  '2': [
    {'1': 'patient_file_id', '3': 1, '4': 1, '5': 9, '10': 'patientFileId'},
    {'1': 'working_alias', '3': 2, '4': 1, '5': 9, '10': 'workingAlias'},
    {
      '1': 'initial_complaint',
      '3': 3,
      '4': 1,
      '5': 9,
      '10': 'initialComplaint'
    },
    {
      '1': 'private_therapist_notes',
      '3': 4,
      '4': 1,
      '5': 9,
      '10': 'privateTherapistNotes'
    },
    {'1': 'is_process_closed', '3': 5, '4': 1, '5': 8, '10': 'isProcessClosed'},
  ],
};

/// Descriptor for `UpdatePatientFileRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updatePatientFileRequestDescriptor = $convert.base64Decode(
    'ChhVcGRhdGVQYXRpZW50RmlsZVJlcXVlc3QSJgoPcGF0aWVudF9maWxlX2lkGAEgASgJUg1wYX'
    'RpZW50RmlsZUlkEiMKDXdvcmtpbmdfYWxpYXMYAiABKAlSDHdvcmtpbmdBbGlhcxIrChFpbml0'
    'aWFsX2NvbXBsYWludBgDIAEoCVIQaW5pdGlhbENvbXBsYWludBI2Chdwcml2YXRlX3RoZXJhcG'
    'lzdF9ub3RlcxgEIAEoCVIVcHJpdmF0ZVRoZXJhcGlzdE5vdGVzEioKEWlzX3Byb2Nlc3NfY2xv'
    'c2VkGAUgASgIUg9pc1Byb2Nlc3NDbG9zZWQ=');

@$core.Deprecated('Use deletePatientFileRequestDescriptor instead')
const DeletePatientFileRequest$json = {
  '1': 'DeletePatientFileRequest',
  '2': [
    {'1': 'patient_file_id', '3': 1, '4': 1, '5': 9, '10': 'patientFileId'},
  ],
};

/// Descriptor for `DeletePatientFileRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deletePatientFileRequestDescriptor =
    $convert.base64Decode(
        'ChhEZWxldGVQYXRpZW50RmlsZVJlcXVlc3QSJgoPcGF0aWVudF9maWxlX2lkGAEgASgJUg1wYX'
        'RpZW50RmlsZUlk');

@$core.Deprecated('Use updatePatientUserRequestDescriptor instead')
const UpdatePatientUserRequest$json = {
  '1': 'UpdatePatientUserRequest',
  '2': [
    {'1': 'patient_file_id', '3': 1, '4': 1, '5': 9, '10': 'patientFileId'},
    {'1': 'first_name', '3': 2, '4': 1, '5': 9, '10': 'firstName'},
    {'1': 'last_name', '3': 3, '4': 1, '5': 9, '10': 'lastName'},
    {'1': 'language_code', '3': 4, '4': 1, '5': 9, '10': 'languageCode'},
  ],
};

/// Descriptor for `UpdatePatientUserRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updatePatientUserRequestDescriptor = $convert.base64Decode(
    'ChhVcGRhdGVQYXRpZW50VXNlclJlcXVlc3QSJgoPcGF0aWVudF9maWxlX2lkGAEgASgJUg1wYX'
    'RpZW50RmlsZUlkEh0KCmZpcnN0X25hbWUYAiABKAlSCWZpcnN0TmFtZRIbCglsYXN0X25hbWUY'
    'AyABKAlSCGxhc3ROYW1lEiMKDWxhbmd1YWdlX2NvZGUYBCABKAlSDGxhbmd1YWdlQ29kZQ==');

@$core.Deprecated('Use deletePatientUserRequestDescriptor instead')
const DeletePatientUserRequest$json = {
  '1': 'DeletePatientUserRequest',
  '2': [
    {'1': 'patient_file_id', '3': 1, '4': 1, '5': 9, '10': 'patientFileId'},
  ],
};

/// Descriptor for `DeletePatientUserRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deletePatientUserRequestDescriptor =
    $convert.base64Decode(
        'ChhEZWxldGVQYXRpZW50VXNlclJlcXVlc3QSJgoPcGF0aWVudF9maWxlX2lkGAEgASgJUg1wYX'
        'RpZW50RmlsZUlk');

@$core.Deprecated('Use listModalitiesResponseDescriptor instead')
const ListModalitiesResponse$json = {
  '1': 'ListModalitiesResponse',
  '2': [
    {
      '1': 'modalities',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.clinical.v1.Modality',
      '10': 'modalities'
    },
  ],
};

/// Descriptor for `ListModalitiesResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listModalitiesResponseDescriptor =
    $convert.base64Decode(
        'ChZMaXN0TW9kYWxpdGllc1Jlc3BvbnNlEjUKCm1vZGFsaXRpZXMYASADKAsyFS5jbGluaWNhbC'
        '52MS5Nb2RhbGl0eVIKbW9kYWxpdGllcw==');

@$core.Deprecated('Use healthCheckResponseDescriptor instead')
const HealthCheckResponse$json = {
  '1': 'HealthCheckResponse',
  '2': [
    {'1': 'status', '3': 1, '4': 1, '5': 9, '10': 'status'},
    {'1': 'version', '3': 2, '4': 1, '5': 9, '10': 'version'},
  ],
};

/// Descriptor for `HealthCheckResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List healthCheckResponseDescriptor = $convert.base64Decode(
    'ChNIZWFsdGhDaGVja1Jlc3BvbnNlEhYKBnN0YXR1cxgBIAEoCVIGc3RhdHVzEhgKB3ZlcnNpb2'
    '4YAiABKAlSB3ZlcnNpb24=');

@$core.Deprecated('Use updateSpeakerLabelsRequestDescriptor instead')
const UpdateSpeakerLabelsRequest$json = {
  '1': 'UpdateSpeakerLabelsRequest',
  '2': [
    {'1': 'session_id', '3': 1, '4': 1, '5': 9, '10': 'sessionId'},
    {
      '1': 'label_mapping',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.clinical.v1.UpdateSpeakerLabelsRequest.LabelMappingEntry',
      '10': 'labelMapping'
    },
  ],
  '3': [UpdateSpeakerLabelsRequest_LabelMappingEntry$json],
};

@$core.Deprecated('Use updateSpeakerLabelsRequestDescriptor instead')
const UpdateSpeakerLabelsRequest_LabelMappingEntry$json = {
  '1': 'LabelMappingEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 9, '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `UpdateSpeakerLabelsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateSpeakerLabelsRequestDescriptor = $convert.base64Decode(
    'ChpVcGRhdGVTcGVha2VyTGFiZWxzUmVxdWVzdBIdCgpzZXNzaW9uX2lkGAEgASgJUglzZXNzaW'
    '9uSWQSXgoNbGFiZWxfbWFwcGluZxgCIAMoCzI5LmNsaW5pY2FsLnYxLlVwZGF0ZVNwZWFrZXJM'
    'YWJlbHNSZXF1ZXN0LkxhYmVsTWFwcGluZ0VudHJ5UgxsYWJlbE1hcHBpbmcaPwoRTGFiZWxNYX'
    'BwaW5nRW50cnkSEAoDa2V5GAEgASgJUgNrZXkSFAoFdmFsdWUYAiABKAlSBXZhbHVlOgI4AQ==');

@$core.Deprecated('Use updateSpeakerLabelsResponseDescriptor instead')
const UpdateSpeakerLabelsResponse$json = {
  '1': 'UpdateSpeakerLabelsResponse',
  '2': [
    {'1': 'session_id', '3': 1, '4': 1, '5': 9, '10': 'sessionId'},
    {'1': 'transcript_id', '3': 2, '4': 1, '5': 9, '10': 'transcriptId'},
    {'1': 'segments_updated', '3': 3, '4': 1, '5': 5, '10': 'segmentsUpdated'},
    {'1': 'blob_rebuilt', '3': 4, '4': 1, '5': 8, '10': 'blobRebuilt'},
  ],
};

/// Descriptor for `UpdateSpeakerLabelsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateSpeakerLabelsResponseDescriptor = $convert.base64Decode(
    'ChtVcGRhdGVTcGVha2VyTGFiZWxzUmVzcG9uc2USHQoKc2Vzc2lvbl9pZBgBIAEoCVIJc2Vzc2'
    'lvbklkEiMKDXRyYW5zY3JpcHRfaWQYAiABKAlSDHRyYW5zY3JpcHRJZBIpChBzZWdtZW50c191'
    'cGRhdGVkGAMgASgFUg9zZWdtZW50c1VwZGF0ZWQSIQoMYmxvYl9yZWJ1aWx0GAQgASgIUgtibG'
    '9iUmVidWlsdA==');

@$core.Deprecated('Use sessionDescriptor instead')
const Session$json = {
  '1': 'Session',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'therapist_id', '3': 2, '4': 1, '5': 9, '10': 'therapistId'},
    {'1': 'patient_file_id', '3': 3, '4': 1, '5': 9, '10': 'patientFileId'},
    {'1': 'audio_upload_id', '3': 4, '4': 1, '5': 9, '10': 'audioUploadId'},
    {'1': 'session_date', '3': 5, '4': 1, '5': 9, '10': 'sessionDate'},
    {'1': 'session_number', '3': 6, '4': 1, '5': 5, '10': 'sessionNumber'},
    {'1': 'duration_seconds', '3': 7, '4': 1, '5': 5, '10': 'durationSeconds'},
    {'1': 'contact_form', '3': 8, '4': 1, '5': 9, '10': 'contactForm'},
    {
      '1': 'speaker_label_mapping',
      '3': 9,
      '4': 3,
      '5': 11,
      '6': '.clinical.v1.Session.SpeakerLabelMappingEntry',
      '10': 'speakerLabelMapping'
    },
    {'1': 'status', '3': 10, '4': 1, '5': 9, '10': 'status'},
    {
      '1': 'created_at',
      '3': 11,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'createdAt'
    },
    {'1': 'name', '3': 12, '4': 1, '5': 9, '10': 'name'},
  ],
  '3': [Session_SpeakerLabelMappingEntry$json],
};

@$core.Deprecated('Use sessionDescriptor instead')
const Session_SpeakerLabelMappingEntry$json = {
  '1': 'SpeakerLabelMappingEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 9, '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `Session`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sessionDescriptor = $convert.base64Decode(
    'CgdTZXNzaW9uEg4KAmlkGAEgASgJUgJpZBIhCgx0aGVyYXBpc3RfaWQYAiABKAlSC3RoZXJhcG'
    'lzdElkEiYKD3BhdGllbnRfZmlsZV9pZBgDIAEoCVINcGF0aWVudEZpbGVJZBImCg9hdWRpb191'
    'cGxvYWRfaWQYBCABKAlSDWF1ZGlvVXBsb2FkSWQSIQoMc2Vzc2lvbl9kYXRlGAUgASgJUgtzZX'
    'NzaW9uRGF0ZRIlCg5zZXNzaW9uX251bWJlchgGIAEoBVINc2Vzc2lvbk51bWJlchIpChBkdXJh'
    'dGlvbl9zZWNvbmRzGAcgASgFUg9kdXJhdGlvblNlY29uZHMSIQoMY29udGFjdF9mb3JtGAggAS'
    'gJUgtjb250YWN0Rm9ybRJhChVzcGVha2VyX2xhYmVsX21hcHBpbmcYCSADKAsyLS5jbGluaWNh'
    'bC52MS5TZXNzaW9uLlNwZWFrZXJMYWJlbE1hcHBpbmdFbnRyeVITc3BlYWtlckxhYmVsTWFwcG'
    'luZxIWCgZzdGF0dXMYCiABKAlSBnN0YXR1cxI5CgpjcmVhdGVkX2F0GAsgASgLMhouZ29vZ2xl'
    'LnByb3RvYnVmLlRpbWVzdGFtcFIJY3JlYXRlZEF0EhIKBG5hbWUYDCABKAlSBG5hbWUaRgoYU3'
    'BlYWtlckxhYmVsTWFwcGluZ0VudHJ5EhAKA2tleRgBIAEoCVIDa2V5EhQKBXZhbHVlGAIgASgJ'
    'UgV2YWx1ZToCOAE=');

@$core.Deprecated('Use listSessionsRequestDescriptor instead')
const ListSessionsRequest$json = {
  '1': 'ListSessionsRequest',
  '2': [
    {'1': 'patient_file_id', '3': 1, '4': 1, '5': 9, '10': 'patientFileId'},
  ],
};

/// Descriptor for `ListSessionsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listSessionsRequestDescriptor = $convert.base64Decode(
    'ChNMaXN0U2Vzc2lvbnNSZXF1ZXN0EiYKD3BhdGllbnRfZmlsZV9pZBgBIAEoCVINcGF0aWVudE'
    'ZpbGVJZA==');

@$core.Deprecated('Use updateSessionRequestDescriptor instead')
const UpdateSessionRequest$json = {
  '1': 'UpdateSessionRequest',
  '2': [
    {'1': 'session_id', '3': 1, '4': 1, '5': 9, '10': 'sessionId'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
  ],
};

/// Descriptor for `UpdateSessionRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateSessionRequestDescriptor = $convert.base64Decode(
    'ChRVcGRhdGVTZXNzaW9uUmVxdWVzdBIdCgpzZXNzaW9uX2lkGAEgASgJUglzZXNzaW9uSWQSEg'
    'oEbmFtZRgCIAEoCVIEbmFtZQ==');

@$core.Deprecated('Use deleteSessionRequestDescriptor instead')
const DeleteSessionRequest$json = {
  '1': 'DeleteSessionRequest',
  '2': [
    {'1': 'session_id', '3': 1, '4': 1, '5': 9, '10': 'sessionId'},
  ],
};

/// Descriptor for `DeleteSessionRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteSessionRequestDescriptor = $convert.base64Decode(
    'ChREZWxldGVTZXNzaW9uUmVxdWVzdBIdCgpzZXNzaW9uX2lkGAEgASgJUglzZXNzaW9uSWQ=');

@$core.Deprecated('Use listSessionsResponseDescriptor instead')
const ListSessionsResponse$json = {
  '1': 'ListSessionsResponse',
  '2': [
    {
      '1': 'sessions',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.clinical.v1.Session',
      '10': 'sessions'
    },
  ],
};

/// Descriptor for `ListSessionsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listSessionsResponseDescriptor = $convert.base64Decode(
    'ChRMaXN0U2Vzc2lvbnNSZXNwb25zZRIwCghzZXNzaW9ucxgBIAMoCzIULmNsaW5pY2FsLnYxLl'
    'Nlc3Npb25SCHNlc3Npb25z');

@$core.Deprecated('Use transcriptSegmentDescriptor instead')
const TranscriptSegment$json = {
  '1': 'TranscriptSegment',
  '2': [
    {'1': 'speaker_tag', '3': 1, '4': 1, '5': 5, '10': 'speakerTag'},
    {'1': 'speaker_label', '3': 2, '4': 1, '5': 9, '10': 'speakerLabel'},
    {'1': 'start_offset_ms', '3': 3, '4': 1, '5': 5, '10': 'startOffsetMs'},
    {'1': 'end_offset_ms', '3': 4, '4': 1, '5': 5, '10': 'endOffsetMs'},
    {'1': 'text', '3': 5, '4': 1, '5': 9, '10': 'text'},
    {'1': 'confidence', '3': 6, '4': 1, '5': 2, '10': 'confidence'},
  ],
};

/// Descriptor for `TranscriptSegment`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List transcriptSegmentDescriptor = $convert.base64Decode(
    'ChFUcmFuc2NyaXB0U2VnbWVudBIfCgtzcGVha2VyX3RhZxgBIAEoBVIKc3BlYWtlclRhZxIjCg'
    '1zcGVha2VyX2xhYmVsGAIgASgJUgxzcGVha2VyTGFiZWwSJgoPc3RhcnRfb2Zmc2V0X21zGAMg'
    'ASgFUg1zdGFydE9mZnNldE1zEiIKDWVuZF9vZmZzZXRfbXMYBCABKAVSC2VuZE9mZnNldE1zEh'
    'IKBHRleHQYBSABKAlSBHRleHQSHgoKY29uZmlkZW5jZRgGIAEoAlIKY29uZmlkZW5jZQ==');

@$core.Deprecated('Use transcriptDescriptor instead')
const Transcript$json = {
  '1': 'Transcript',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {
      '1': 'segments',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.clinical.v1.TranscriptSegment',
      '10': 'segments'
    },
    {
      '1': 'turns',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.clinical.v1.SpeakerTurn',
      '10': 'turns'
    },
  ],
};

/// Descriptor for `Transcript`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List transcriptDescriptor = $convert.base64Decode(
    'CgpUcmFuc2NyaXB0Eg4KAmlkGAEgASgJUgJpZBI6CghzZWdtZW50cxgCIAMoCzIeLmNsaW5pY2'
    'FsLnYxLlRyYW5zY3JpcHRTZWdtZW50UghzZWdtZW50cxIuCgV0dXJucxgDIAMoCzIYLmNsaW5p'
    'Y2FsLnYxLlNwZWFrZXJUdXJuUgV0dXJucw==');

@$core.Deprecated('Use speakerTurnDescriptor instead')
const SpeakerTurn$json = {
  '1': 'SpeakerTurn',
  '2': [
    {'1': 'speaker_tag', '3': 1, '4': 1, '5': 5, '10': 'speakerTag'},
    {'1': 'speaker_label', '3': 2, '4': 1, '5': 9, '10': 'speakerLabel'},
    {'1': 'start_offset_ms', '3': 3, '4': 1, '5': 5, '10': 'startOffsetMs'},
    {'1': 'end_offset_ms', '3': 4, '4': 1, '5': 5, '10': 'endOffsetMs'},
    {'1': 'text', '3': 5, '4': 1, '5': 9, '10': 'text'},
    {'1': 'segment_count', '3': 6, '4': 1, '5': 5, '10': 'segmentCount'},
    {'1': 'confidence_avg', '3': 7, '4': 1, '5': 2, '10': 'confidenceAvg'},
  ],
};

/// Descriptor for `SpeakerTurn`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List speakerTurnDescriptor = $convert.base64Decode(
    'CgtTcGVha2VyVHVybhIfCgtzcGVha2VyX3RhZxgBIAEoBVIKc3BlYWtlclRhZxIjCg1zcGVha2'
    'VyX2xhYmVsGAIgASgJUgxzcGVha2VyTGFiZWwSJgoPc3RhcnRfb2Zmc2V0X21zGAMgASgFUg1z'
    'dGFydE9mZnNldE1zEiIKDWVuZF9vZmZzZXRfbXMYBCABKAVSC2VuZE9mZnNldE1zEhIKBHRleH'
    'QYBSABKAlSBHRleHQSIwoNc2VnbWVudF9jb3VudBgGIAEoBVIMc2VnbWVudENvdW50EiUKDmNv'
    'bmZpZGVuY2VfYXZnGAcgASgCUg1jb25maWRlbmNlQXZn');

@$core.Deprecated('Use reportDescriptor instead')
const Report$json = {
  '1': 'Report',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'title', '3': 2, '4': 1, '5': 9, '10': 'title'},
    {'1': 'summary_short', '3': 3, '4': 1, '5': 9, '10': 'summaryShort'},
    {'1': 'content', '3': 4, '4': 1, '5': 9, '10': 'content'},
    {'1': 'sentiment_label', '3': 5, '4': 1, '5': 9, '10': 'sentimentLabel'},
    {'1': 'risk_level', '3': 6, '4': 1, '5': 9, '10': 'riskLevel'},
  ],
};

/// Descriptor for `Report`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List reportDescriptor = $convert.base64Decode(
    'CgZSZXBvcnQSDgoCaWQYASABKAlSAmlkEhQKBXRpdGxlGAIgASgJUgV0aXRsZRIjCg1zdW1tYX'
    'J5X3Nob3J0GAMgASgJUgxzdW1tYXJ5U2hvcnQSGAoHY29udGVudBgEIAEoCVIHY29udGVudBIn'
    'Cg9zZW50aW1lbnRfbGFiZWwYBSABKAlSDnNlbnRpbWVudExhYmVsEh0KCnJpc2tfbGV2ZWwYBi'
    'ABKAlSCXJpc2tMZXZlbA==');

@$core.Deprecated('Use getSessionDetailsRequestDescriptor instead')
const GetSessionDetailsRequest$json = {
  '1': 'GetSessionDetailsRequest',
  '2': [
    {'1': 'session_id', '3': 1, '4': 1, '5': 9, '10': 'sessionId'},
  ],
};

/// Descriptor for `GetSessionDetailsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getSessionDetailsRequestDescriptor =
    $convert.base64Decode(
        'ChhHZXRTZXNzaW9uRGV0YWlsc1JlcXVlc3QSHQoKc2Vzc2lvbl9pZBgBIAEoCVIJc2Vzc2lvbk'
        'lk');

@$core.Deprecated('Use getSessionDetailsResponseDescriptor instead')
const GetSessionDetailsResponse$json = {
  '1': 'GetSessionDetailsResponse',
  '2': [
    {
      '1': 'session',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.clinical.v1.Session',
      '10': 'session'
    },
    {
      '1': 'transcript',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.clinical.v1.Transcript',
      '10': 'transcript'
    },
    {
      '1': 'reports',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.clinical.v1.Report',
      '10': 'reports'
    },
  ],
};

/// Descriptor for `GetSessionDetailsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getSessionDetailsResponseDescriptor = $convert.base64Decode(
    'ChlHZXRTZXNzaW9uRGV0YWlsc1Jlc3BvbnNlEi4KB3Nlc3Npb24YASABKAsyFC5jbGluaWNhbC'
    '52MS5TZXNzaW9uUgdzZXNzaW9uEjcKCnRyYW5zY3JpcHQYAiABKAsyFy5jbGluaWNhbC52MS5U'
    'cmFuc2NyaXB0Ugp0cmFuc2NyaXB0Ei0KB3JlcG9ydHMYAyADKAsyEy5jbGluaWNhbC52MS5SZX'
    'BvcnRSB3JlcG9ydHM=');
