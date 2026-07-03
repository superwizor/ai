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
    {'1': 'patient_email', '3': 19, '4': 1, '5': 9, '10': 'patientEmail'},
    {'1': 'lifecycle_status', '3': 20, '4': 1, '5': 9, '10': 'lifecycleStatus'},
    {'1': 'avatar_config', '3': 21, '4': 1, '5': 9, '10': 'avatarConfig'},
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
    '5ndWFnZV9jb2RlGBIgASgJUhNwYXRpZW50TGFuZ3VhZ2VDb2RlEiMKDXBhdGllbnRfZW1haWwY'
    'EyABKAlSDHBhdGllbnRFbWFpbBIpChBsaWZlY3ljbGVfc3RhdHVzGBQgASgJUg9saWZlY3ljbG'
    'VTdGF0dXMSIwoNYXZhdGFyX2NvbmZpZxgVIAEoCVIMYXZhdGFyQ29uZmln');

@$core.Deprecated('Use modalityDescriptor instead')
const Modality$json = {
  '1': 'Modality',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'system_code', '3': 2, '4': 1, '5': 9, '10': 'systemCode'},
    {'1': 'display_name', '3': 3, '4': 1, '5': 9, '10': 'displayName'},
    {'1': 'is_supported', '3': 4, '4': 1, '5': 8, '10': 'isSupported'},
    {'1': 'modality_type', '3': 5, '4': 1, '5': 9, '10': 'modalityType'},
  ],
};

/// Descriptor for `Modality`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List modalityDescriptor = $convert.base64Decode(
    'CghNb2RhbGl0eRIOCgJpZBgBIAEoCVICaWQSHwoLc3lzdGVtX2NvZGUYAiABKAlSCnN5c3RlbU'
    'NvZGUSIQoMZGlzcGxheV9uYW1lGAMgASgJUgtkaXNwbGF5TmFtZRIhCgxpc19zdXBwb3J0ZWQY'
    'BCABKAhSC2lzU3VwcG9ydGVkEiMKDW1vZGFsaXR5X3R5cGUYBSABKAlSDG1vZGFsaXR5VHlwZQ'
    '==');

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
    {'1': 'patient_email', '3': 11, '4': 1, '5': 9, '10': 'patientEmail'},
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
    'X2NvZGUYCiABKAlSE3BhdGllbnRMYW5ndWFnZUNvZGUSIwoNcGF0aWVudF9lbWFpbBgLIAEoCV'
    'IMcGF0aWVudEVtYWls');

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
    {'1': 'lifecycle_status', '3': 6, '4': 1, '5': 9, '10': 'lifecycleStatus'},
  ],
};

/// Descriptor for `UpdatePatientFileRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updatePatientFileRequestDescriptor = $convert.base64Decode(
    'ChhVcGRhdGVQYXRpZW50RmlsZVJlcXVlc3QSJgoPcGF0aWVudF9maWxlX2lkGAEgASgJUg1wYX'
    'RpZW50RmlsZUlkEiMKDXdvcmtpbmdfYWxpYXMYAiABKAlSDHdvcmtpbmdBbGlhcxIrChFpbml0'
    'aWFsX2NvbXBsYWludBgDIAEoCVIQaW5pdGlhbENvbXBsYWludBI2Chdwcml2YXRlX3RoZXJhcG'
    'lzdF9ub3RlcxgEIAEoCVIVcHJpdmF0ZVRoZXJhcGlzdE5vdGVzEioKEWlzX3Byb2Nlc3NfY2xv'
    'c2VkGAUgASgIUg9pc1Byb2Nlc3NDbG9zZWQSKQoQbGlmZWN5Y2xlX3N0YXR1cxgGIAEoCVIPbG'
    'lmZWN5Y2xlU3RhdHVz');

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
    {'1': 'patient_email', '3': 5, '4': 1, '5': 9, '10': 'patientEmail'},
  ],
};

/// Descriptor for `UpdatePatientUserRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updatePatientUserRequestDescriptor = $convert.base64Decode(
    'ChhVcGRhdGVQYXRpZW50VXNlclJlcXVlc3QSJgoPcGF0aWVudF9maWxlX2lkGAEgASgJUg1wYX'
    'RpZW50RmlsZUlkEh0KCmZpcnN0X25hbWUYAiABKAlSCWZpcnN0TmFtZRIbCglsYXN0X25hbWUY'
    'AyABKAlSCGxhc3ROYW1lEiMKDWxhbmd1YWdlX2NvZGUYBCABKAlSDGxhbmd1YWdlQ29kZRIjCg'
    '1wYXRpZW50X2VtYWlsGAUgASgJUgxwYXRpZW50RW1haWw=');

@$core.Deprecated('Use patientNoteDescriptor instead')
const PatientNote$json = {
  '1': 'PatientNote',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'patient_file_id', '3': 2, '4': 1, '5': 9, '10': 'patientFileId'},
    {'1': 'kind', '3': 3, '4': 1, '5': 9, '10': 'kind'},
    {'1': 'source_session_id', '3': 4, '4': 1, '5': 9, '10': 'sourceSessionId'},
    {'1': 'title', '3': 5, '4': 1, '5': 9, '10': 'title'},
    {'1': 'text', '3': 6, '4': 1, '5': 9, '10': 'text'},
    {
      '1': 'sent_to_patient_at',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'sentToPatientAt'
    },
    {'1': 'sent_to_email', '3': 8, '4': 1, '5': 9, '10': 'sentToEmail'},
    {
      '1': 'created_at',
      '3': 9,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'createdAt'
    },
    {
      '1': 'updated_at',
      '3': 10,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'updatedAt'
    },
  ],
};

/// Descriptor for `PatientNote`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List patientNoteDescriptor = $convert.base64Decode(
    'CgtQYXRpZW50Tm90ZRIOCgJpZBgBIAEoCVICaWQSJgoPcGF0aWVudF9maWxlX2lkGAIgASgJUg'
    '1wYXRpZW50RmlsZUlkEhIKBGtpbmQYAyABKAlSBGtpbmQSKgoRc291cmNlX3Nlc3Npb25faWQY'
    'BCABKAlSD3NvdXJjZVNlc3Npb25JZBIUCgV0aXRsZRgFIAEoCVIFdGl0bGUSEgoEdGV4dBgGIA'
    'EoCVIEdGV4dBJHChJzZW50X3RvX3BhdGllbnRfYXQYByABKAsyGi5nb29nbGUucHJvdG9idWYu'
    'VGltZXN0YW1wUg9zZW50VG9QYXRpZW50QXQSIgoNc2VudF90b19lbWFpbBgIIAEoCVILc2VudF'
    'RvRW1haWwSOQoKY3JlYXRlZF9hdBgJIAEoCzIaLmdvb2dsZS5wcm90b2J1Zi5UaW1lc3RhbXBS'
    'CWNyZWF0ZWRBdBI5Cgp1cGRhdGVkX2F0GAogASgLMhouZ29vZ2xlLnByb3RvYnVmLlRpbWVzdG'
    'FtcFIJdXBkYXRlZEF0');

@$core.Deprecated('Use createPatientNoteRequestDescriptor instead')
const CreatePatientNoteRequest$json = {
  '1': 'CreatePatientNoteRequest',
  '2': [
    {'1': 'patient_file_id', '3': 1, '4': 1, '5': 9, '10': 'patientFileId'},
    {'1': 'title', '3': 2, '4': 1, '5': 9, '10': 'title'},
    {'1': 'text', '3': 3, '4': 1, '5': 9, '10': 'text'},
    {'1': 'kind', '3': 4, '4': 1, '5': 9, '10': 'kind'},
    {'1': 'source_session_id', '3': 5, '4': 1, '5': 9, '10': 'sourceSessionId'},
  ],
};

/// Descriptor for `CreatePatientNoteRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createPatientNoteRequestDescriptor = $convert.base64Decode(
    'ChhDcmVhdGVQYXRpZW50Tm90ZVJlcXVlc3QSJgoPcGF0aWVudF9maWxlX2lkGAEgASgJUg1wYX'
    'RpZW50RmlsZUlkEhQKBXRpdGxlGAIgASgJUgV0aXRsZRISCgR0ZXh0GAMgASgJUgR0ZXh0EhIK'
    'BGtpbmQYBCABKAlSBGtpbmQSKgoRc291cmNlX3Nlc3Npb25faWQYBSABKAlSD3NvdXJjZVNlc3'
    'Npb25JZA==');

@$core.Deprecated('Use listPatientNotesRequestDescriptor instead')
const ListPatientNotesRequest$json = {
  '1': 'ListPatientNotesRequest',
  '2': [
    {'1': 'patient_file_id', '3': 1, '4': 1, '5': 9, '10': 'patientFileId'},
  ],
};

/// Descriptor for `ListPatientNotesRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listPatientNotesRequestDescriptor =
    $convert.base64Decode(
        'ChdMaXN0UGF0aWVudE5vdGVzUmVxdWVzdBImCg9wYXRpZW50X2ZpbGVfaWQYASABKAlSDXBhdG'
        'llbnRGaWxlSWQ=');

@$core.Deprecated('Use listPatientNotesResponseDescriptor instead')
const ListPatientNotesResponse$json = {
  '1': 'ListPatientNotesResponse',
  '2': [
    {
      '1': 'notes',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.clinical.v1.PatientNote',
      '10': 'notes'
    },
  ],
};

/// Descriptor for `ListPatientNotesResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listPatientNotesResponseDescriptor =
    $convert.base64Decode(
        'ChhMaXN0UGF0aWVudE5vdGVzUmVzcG9uc2USLgoFbm90ZXMYASADKAsyGC5jbGluaWNhbC52MS'
        '5QYXRpZW50Tm90ZVIFbm90ZXM=');

@$core.Deprecated('Use updatePatientNoteRequestDescriptor instead')
const UpdatePatientNoteRequest$json = {
  '1': 'UpdatePatientNoteRequest',
  '2': [
    {'1': 'note_id', '3': 1, '4': 1, '5': 9, '10': 'noteId'},
    {'1': 'title', '3': 2, '4': 1, '5': 9, '10': 'title'},
    {'1': 'text', '3': 3, '4': 1, '5': 9, '10': 'text'},
  ],
};

/// Descriptor for `UpdatePatientNoteRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updatePatientNoteRequestDescriptor =
    $convert.base64Decode(
        'ChhVcGRhdGVQYXRpZW50Tm90ZVJlcXVlc3QSFwoHbm90ZV9pZBgBIAEoCVIGbm90ZUlkEhQKBX'
        'RpdGxlGAIgASgJUgV0aXRsZRISCgR0ZXh0GAMgASgJUgR0ZXh0');

@$core.Deprecated('Use deletePatientNoteRequestDescriptor instead')
const DeletePatientNoteRequest$json = {
  '1': 'DeletePatientNoteRequest',
  '2': [
    {'1': 'note_id', '3': 1, '4': 1, '5': 9, '10': 'noteId'},
  ],
};

/// Descriptor for `DeletePatientNoteRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deletePatientNoteRequestDescriptor =
    $convert.base64Decode(
        'ChhEZWxldGVQYXRpZW50Tm90ZVJlcXVlc3QSFwoHbm90ZV9pZBgBIAEoCVIGbm90ZUlk');

@$core.Deprecated('Use getActionPlanDraftRequestDescriptor instead')
const GetActionPlanDraftRequest$json = {
  '1': 'GetActionPlanDraftRequest',
  '2': [
    {'1': 'session_id', '3': 1, '4': 1, '5': 9, '10': 'sessionId'},
  ],
};

/// Descriptor for `GetActionPlanDraftRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getActionPlanDraftRequestDescriptor =
    $convert.base64Decode(
        'ChlHZXRBY3Rpb25QbGFuRHJhZnRSZXF1ZXN0Eh0KCnNlc3Npb25faWQYASABKAlSCXNlc3Npb2'
        '5JZA==');

@$core.Deprecated('Use actionPlanDraftDescriptor instead')
const ActionPlanDraft$json = {
  '1': 'ActionPlanDraft',
  '2': [
    {'1': 'suggested_title', '3': 1, '4': 1, '5': 9, '10': 'suggestedTitle'},
    {'1': 'suggested_text', '3': 2, '4': 1, '5': 9, '10': 'suggestedText'},
    {'1': 'patient_has_email', '3': 3, '4': 1, '5': 8, '10': 'patientHasEmail'},
    {
      '1': 'patient_email_masked',
      '3': 4,
      '4': 1,
      '5': 9,
      '10': 'patientEmailMasked'
    },
  ],
};

/// Descriptor for `ActionPlanDraft`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List actionPlanDraftDescriptor = $convert.base64Decode(
    'Cg9BY3Rpb25QbGFuRHJhZnQSJwoPc3VnZ2VzdGVkX3RpdGxlGAEgASgJUg5zdWdnZXN0ZWRUaX'
    'RsZRIlCg5zdWdnZXN0ZWRfdGV4dBgCIAEoCVINc3VnZ2VzdGVkVGV4dBIqChFwYXRpZW50X2hh'
    'c19lbWFpbBgDIAEoCFIPcGF0aWVudEhhc0VtYWlsEjAKFHBhdGllbnRfZW1haWxfbWFza2VkGA'
    'QgASgJUhJwYXRpZW50RW1haWxNYXNrZWQ=');

@$core.Deprecated('Use savePatientNoteRequestDescriptor instead')
const SavePatientNoteRequest$json = {
  '1': 'SavePatientNoteRequest',
  '2': [
    {'1': 'patient_file_id', '3': 1, '4': 1, '5': 9, '10': 'patientFileId'},
    {'1': 'note_id', '3': 2, '4': 1, '5': 9, '10': 'noteId'},
    {'1': 'title', '3': 3, '4': 1, '5': 9, '10': 'title'},
    {'1': 'text', '3': 4, '4': 1, '5': 9, '10': 'text'},
    {'1': 'kind', '3': 5, '4': 1, '5': 9, '10': 'kind'},
    {'1': 'source_session_id', '3': 6, '4': 1, '5': 9, '10': 'sourceSessionId'},
    {'1': 'send_to_patient', '3': 7, '4': 1, '5': 8, '10': 'sendToPatient'},
  ],
};

/// Descriptor for `SavePatientNoteRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List savePatientNoteRequestDescriptor = $convert.base64Decode(
    'ChZTYXZlUGF0aWVudE5vdGVSZXF1ZXN0EiYKD3BhdGllbnRfZmlsZV9pZBgBIAEoCVINcGF0aW'
    'VudEZpbGVJZBIXCgdub3RlX2lkGAIgASgJUgZub3RlSWQSFAoFdGl0bGUYAyABKAlSBXRpdGxl'
    'EhIKBHRleHQYBCABKAlSBHRleHQSEgoEa2luZBgFIAEoCVIEa2luZBIqChFzb3VyY2Vfc2Vzc2'
    'lvbl9pZBgGIAEoCVIPc291cmNlU2Vzc2lvbklkEiYKD3NlbmRfdG9fcGF0aWVudBgHIAEoCFIN'
    'c2VuZFRvUGF0aWVudA==');

@$core.Deprecated('Use savePatientNoteResponseDescriptor instead')
const SavePatientNoteResponse$json = {
  '1': 'SavePatientNoteResponse',
  '2': [
    {
      '1': 'note',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.clinical.v1.PatientNote',
      '10': 'note'
    },
    {'1': 'sent', '3': 2, '4': 1, '5': 8, '10': 'sent'},
    {'1': 'send_error', '3': 3, '4': 1, '5': 9, '10': 'sendError'},
  ],
};

/// Descriptor for `SavePatientNoteResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List savePatientNoteResponseDescriptor = $convert.base64Decode(
    'ChdTYXZlUGF0aWVudE5vdGVSZXNwb25zZRIsCgRub3RlGAEgASgLMhguY2xpbmljYWwudjEuUG'
    'F0aWVudE5vdGVSBG5vdGUSEgoEc2VudBgCIAEoCFIEc2VudBIdCgpzZW5kX2Vycm9yGAMgASgJ'
    'UglzZW5kRXJyb3I=');

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
    {
      '1': 'report_viewed_at',
      '3': 13,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'reportViewedAt'
    },
    {'1': 'file_size_bytes', '3': 14, '4': 1, '5': 3, '10': 'fileSizeBytes'},
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
    'LnByb3RvYnVmLlRpbWVzdGFtcFIJY3JlYXRlZEF0EhIKBG5hbWUYDCABKAlSBG5hbWUSRAoQcm'
    'Vwb3J0X3ZpZXdlZF9hdBgNIAEoCzIaLmdvb2dsZS5wcm90b2J1Zi5UaW1lc3RhbXBSDnJlcG9y'
    'dFZpZXdlZEF0EiYKD2ZpbGVfc2l6ZV9ieXRlcxgOIAEoA1INZmlsZVNpemVCeXRlcxpGChhTcG'
    'Vha2VyTGFiZWxNYXBwaW5nRW50cnkSEAoDa2V5GAEgASgJUgNrZXkSFAoFdmFsdWUYAiABKAlS'
    'BXZhbHVlOgI4AQ==');

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

@$core.Deprecated('Use cancelSessionRequestDescriptor instead')
const CancelSessionRequest$json = {
  '1': 'CancelSessionRequest',
  '2': [
    {'1': 'session_id', '3': 1, '4': 1, '5': 9, '10': 'sessionId'},
  ],
};

/// Descriptor for `CancelSessionRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List cancelSessionRequestDescriptor = $convert.base64Decode(
    'ChRDYW5jZWxTZXNzaW9uUmVxdWVzdBIdCgpzZXNzaW9uX2lkGAEgASgJUglzZXNzaW9uSWQ=');

@$core.Deprecated('Use markReportViewedRequestDescriptor instead')
const MarkReportViewedRequest$json = {
  '1': 'MarkReportViewedRequest',
  '2': [
    {'1': 'session_id', '3': 1, '4': 1, '5': 9, '10': 'sessionId'},
  ],
};

/// Descriptor for `MarkReportViewedRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List markReportViewedRequestDescriptor =
    $convert.base64Decode(
        'ChdNYXJrUmVwb3J0Vmlld2VkUmVxdWVzdBIdCgpzZXNzaW9uX2lkGAEgASgJUglzZXNzaW9uSW'
        'Q=');

@$core.Deprecated('Use setAvatarConfigRequestDescriptor instead')
const SetAvatarConfigRequest$json = {
  '1': 'SetAvatarConfigRequest',
  '2': [
    {'1': 'patient_file_id', '3': 1, '4': 1, '5': 9, '10': 'patientFileId'},
    {'1': 'avatar_config', '3': 2, '4': 1, '5': 9, '10': 'avatarConfig'},
  ],
};

/// Descriptor for `SetAvatarConfigRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setAvatarConfigRequestDescriptor =
    $convert.base64Decode(
        'ChZTZXRBdmF0YXJDb25maWdSZXF1ZXN0EiYKD3BhdGllbnRfZmlsZV9pZBgBIAEoCVINcGF0aW'
        'VudEZpbGVJZBIjCg1hdmF0YXJfY29uZmlnGAIgASgJUgxhdmF0YXJDb25maWc=');

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

@$core.Deprecated('Use reportRatingDescriptor instead')
const ReportRating$json = {
  '1': 'ReportRating',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'report_id', '3': 2, '4': 1, '5': 9, '10': 'reportId'},
    {'1': 'therapist_id', '3': 3, '4': 1, '5': 9, '10': 'therapistId'},
    {'1': 'rating', '3': 4, '4': 1, '5': 9, '10': 'rating'},
    {'1': 'issues', '3': 5, '4': 3, '5': 9, '10': 'issues'},
    {'1': 'notes', '3': 6, '4': 1, '5': 9, '10': 'notes'},
    {'1': 'source', '3': 7, '4': 1, '5': 9, '10': 'source'},
    {
      '1': 'created_at',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'createdAt'
    },
    {
      '1': 'updated_at',
      '3': 9,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'updatedAt'
    },
  ],
};

/// Descriptor for `ReportRating`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List reportRatingDescriptor = $convert.base64Decode(
    'CgxSZXBvcnRSYXRpbmcSDgoCaWQYASABKAlSAmlkEhsKCXJlcG9ydF9pZBgCIAEoCVIIcmVwb3'
    'J0SWQSIQoMdGhlcmFwaXN0X2lkGAMgASgJUgt0aGVyYXBpc3RJZBIWCgZyYXRpbmcYBCABKAlS'
    'BnJhdGluZxIWCgZpc3N1ZXMYBSADKAlSBmlzc3VlcxIUCgVub3RlcxgGIAEoCVIFbm90ZXMSFg'
    'oGc291cmNlGAcgASgJUgZzb3VyY2USOQoKY3JlYXRlZF9hdBgIIAEoCzIaLmdvb2dsZS5wcm90'
    'b2J1Zi5UaW1lc3RhbXBSCWNyZWF0ZWRBdBI5Cgp1cGRhdGVkX2F0GAkgASgLMhouZ29vZ2xlLn'
    'Byb3RvYnVmLlRpbWVzdGFtcFIJdXBkYXRlZEF0');

@$core.Deprecated('Use rateReportRequestDescriptor instead')
const RateReportRequest$json = {
  '1': 'RateReportRequest',
  '2': [
    {'1': 'report_id', '3': 1, '4': 1, '5': 9, '10': 'reportId'},
    {'1': 'therapist_id', '3': 2, '4': 1, '5': 9, '10': 'therapistId'},
    {'1': 'rating', '3': 3, '4': 1, '5': 9, '10': 'rating'},
    {'1': 'issues', '3': 4, '4': 3, '5': 9, '10': 'issues'},
    {'1': 'notes', '3': 5, '4': 1, '5': 9, '10': 'notes'},
    {'1': 'source', '3': 6, '4': 1, '5': 9, '10': 'source'},
    {'1': 'idempotency_key', '3': 7, '4': 1, '5': 9, '10': 'idempotencyKey'},
  ],
};

/// Descriptor for `RateReportRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List rateReportRequestDescriptor = $convert.base64Decode(
    'ChFSYXRlUmVwb3J0UmVxdWVzdBIbCglyZXBvcnRfaWQYASABKAlSCHJlcG9ydElkEiEKDHRoZX'
    'JhcGlzdF9pZBgCIAEoCVILdGhlcmFwaXN0SWQSFgoGcmF0aW5nGAMgASgJUgZyYXRpbmcSFgoG'
    'aXNzdWVzGAQgAygJUgZpc3N1ZXMSFAoFbm90ZXMYBSABKAlSBW5vdGVzEhYKBnNvdXJjZRgGIA'
    'EoCVIGc291cmNlEicKD2lkZW1wb3RlbmN5X2tleRgHIAEoCVIOaWRlbXBvdGVuY3lLZXk=');

@$core.Deprecated('Use rateReportResponseDescriptor instead')
const RateReportResponse$json = {
  '1': 'RateReportResponse',
  '2': [
    {
      '1': 'rating',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.clinical.v1.ReportRating',
      '10': 'rating'
    },
  ],
};

/// Descriptor for `RateReportResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List rateReportResponseDescriptor = $convert.base64Decode(
    'ChJSYXRlUmVwb3J0UmVzcG9uc2USMQoGcmF0aW5nGAEgASgLMhkuY2xpbmljYWwudjEuUmVwb3'
    'J0UmF0aW5nUgZyYXRpbmc=');

@$core.Deprecated('Use getReportRatingRequestDescriptor instead')
const GetReportRatingRequest$json = {
  '1': 'GetReportRatingRequest',
  '2': [
    {'1': 'report_id', '3': 1, '4': 1, '5': 9, '10': 'reportId'},
    {'1': 'therapist_id', '3': 2, '4': 1, '5': 9, '10': 'therapistId'},
  ],
};

/// Descriptor for `GetReportRatingRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getReportRatingRequestDescriptor =
    $convert.base64Decode(
        'ChZHZXRSZXBvcnRSYXRpbmdSZXF1ZXN0EhsKCXJlcG9ydF9pZBgBIAEoCVIIcmVwb3J0SWQSIQ'
        'oMdGhlcmFwaXN0X2lkGAIgASgJUgt0aGVyYXBpc3RJZA==');

@$core.Deprecated('Use getActiveSuggestionRequestDescriptor instead')
const GetActiveSuggestionRequest$json = {
  '1': 'GetActiveSuggestionRequest',
  '2': [
    {'1': 'therapist_id', '3': 1, '4': 1, '5': 9, '10': 'therapistId'},
  ],
};

/// Descriptor for `GetActiveSuggestionRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getActiveSuggestionRequestDescriptor =
    $convert.base64Decode(
        'ChpHZXRBY3RpdmVTdWdnZXN0aW9uUmVxdWVzdBIhCgx0aGVyYXBpc3RfaWQYASABKAlSC3RoZX'
        'JhcGlzdElk');

@$core.Deprecated('Use preferenceSuggestionDescriptor instead')
const PreferenceSuggestion$json = {
  '1': 'PreferenceSuggestion',
  '2': [
    {'1': 'suggestion_id', '3': 1, '4': 1, '5': 9, '10': 'suggestionId'},
    {'1': 'dimension', '3': 2, '4': 1, '5': 9, '10': 'dimension'},
    {'1': 'from_value', '3': 3, '4': 1, '5': 9, '10': 'fromValue'},
    {'1': 'to_value', '3': 4, '4': 1, '5': 9, '10': 'toValue'},
    {'1': 'reason_label', '3': 5, '4': 1, '5': 9, '10': 'reasonLabel'},
    {'1': 'trigger_count', '3': 6, '4': 1, '5': 5, '10': 'triggerCount'},
    {
      '1': 'alternatives',
      '3': 7,
      '4': 3,
      '5': 11,
      '6': '.clinical.v1.PreferenceSuggestionCandidate',
      '10': 'alternatives'
    },
  ],
};

/// Descriptor for `PreferenceSuggestion`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List preferenceSuggestionDescriptor = $convert.base64Decode(
    'ChRQcmVmZXJlbmNlU3VnZ2VzdGlvbhIjCg1zdWdnZXN0aW9uX2lkGAEgASgJUgxzdWdnZXN0aW'
    '9uSWQSHAoJZGltZW5zaW9uGAIgASgJUglkaW1lbnNpb24SHQoKZnJvbV92YWx1ZRgDIAEoCVIJ'
    'ZnJvbVZhbHVlEhkKCHRvX3ZhbHVlGAQgASgJUgd0b1ZhbHVlEiEKDHJlYXNvbl9sYWJlbBgFIA'
    'EoCVILcmVhc29uTGFiZWwSIwoNdHJpZ2dlcl9jb3VudBgGIAEoBVIMdHJpZ2dlckNvdW50Ek4K'
    'DGFsdGVybmF0aXZlcxgHIAMoCzIqLmNsaW5pY2FsLnYxLlByZWZlcmVuY2VTdWdnZXN0aW9uQ2'
    'FuZGlkYXRlUgxhbHRlcm5hdGl2ZXM=');

@$core.Deprecated('Use preferenceSuggestionCandidateDescriptor instead')
const PreferenceSuggestionCandidate$json = {
  '1': 'PreferenceSuggestionCandidate',
  '2': [
    {'1': 'dimension', '3': 1, '4': 1, '5': 9, '10': 'dimension'},
    {'1': 'from_value', '3': 2, '4': 1, '5': 9, '10': 'fromValue'},
    {'1': 'to_value', '3': 3, '4': 1, '5': 9, '10': 'toValue'},
    {'1': 'reason_label', '3': 4, '4': 1, '5': 9, '10': 'reasonLabel'},
    {'1': 'trigger_count', '3': 5, '4': 1, '5': 5, '10': 'triggerCount'},
  ],
};

/// Descriptor for `PreferenceSuggestionCandidate`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List preferenceSuggestionCandidateDescriptor = $convert.base64Decode(
    'Ch1QcmVmZXJlbmNlU3VnZ2VzdGlvbkNhbmRpZGF0ZRIcCglkaW1lbnNpb24YASABKAlSCWRpbW'
    'Vuc2lvbhIdCgpmcm9tX3ZhbHVlGAIgASgJUglmcm9tVmFsdWUSGQoIdG9fdmFsdWUYAyABKAlS'
    'B3RvVmFsdWUSIQoMcmVhc29uX2xhYmVsGAQgASgJUgtyZWFzb25MYWJlbBIjCg10cmlnZ2VyX2'
    'NvdW50GAUgASgFUgx0cmlnZ2VyQ291bnQ=');

@$core.Deprecated('Use logPreferenceSuggestionRequestDescriptor instead')
const LogPreferenceSuggestionRequest$json = {
  '1': 'LogPreferenceSuggestionRequest',
  '2': [
    {'1': 'therapist_id', '3': 1, '4': 1, '5': 9, '10': 'therapistId'},
    {'1': 'suggestion_id', '3': 2, '4': 1, '5': 9, '10': 'suggestionId'},
    {'1': 'dimension', '3': 3, '4': 1, '5': 9, '10': 'dimension'},
    {'1': 'from_value', '3': 4, '4': 1, '5': 9, '10': 'fromValue'},
    {'1': 'to_value', '3': 5, '4': 1, '5': 9, '10': 'toValue'},
    {'1': 'trigger_count', '3': 6, '4': 1, '5': 5, '10': 'triggerCount'},
    {'1': 'action', '3': 7, '4': 1, '5': 9, '10': 'action'},
  ],
};

/// Descriptor for `LogPreferenceSuggestionRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List logPreferenceSuggestionRequestDescriptor = $convert.base64Decode(
    'Ch5Mb2dQcmVmZXJlbmNlU3VnZ2VzdGlvblJlcXVlc3QSIQoMdGhlcmFwaXN0X2lkGAEgASgJUg'
    't0aGVyYXBpc3RJZBIjCg1zdWdnZXN0aW9uX2lkGAIgASgJUgxzdWdnZXN0aW9uSWQSHAoJZGlt'
    'ZW5zaW9uGAMgASgJUglkaW1lbnNpb24SHQoKZnJvbV92YWx1ZRgEIAEoCVIJZnJvbVZhbHVlEh'
    'kKCHRvX3ZhbHVlGAUgASgJUgd0b1ZhbHVlEiMKDXRyaWdnZXJfY291bnQYBiABKAVSDHRyaWdn'
    'ZXJDb3VudBIWCgZhY3Rpb24YByABKAlSBmFjdGlvbg==');

@$core.Deprecated('Use adminListSessionsRequestDescriptor instead')
const AdminListSessionsRequest$json = {
  '1': 'AdminListSessionsRequest',
  '2': [
    {
      '1': 'start_time',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'startTime'
    },
    {
      '1': 'end_time',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'endTime'
    },
    {'1': 'therapist_filter', '3': 3, '4': 1, '5': 9, '10': 'therapistFilter'},
    {'1': 'page_size', '3': 4, '4': 1, '5': 5, '10': 'pageSize'},
    {'1': 'page', '3': 5, '4': 1, '5': 5, '10': 'page'},
    {'1': 'sort_by', '3': 6, '4': 1, '5': 9, '10': 'sortBy'},
    {'1': 'sort_order', '3': 7, '4': 1, '5': 9, '10': 'sortOrder'},
  ],
};

/// Descriptor for `AdminListSessionsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List adminListSessionsRequestDescriptor = $convert.base64Decode(
    'ChhBZG1pbkxpc3RTZXNzaW9uc1JlcXVlc3QSOQoKc3RhcnRfdGltZRgBIAEoCzIaLmdvb2dsZS'
    '5wcm90b2J1Zi5UaW1lc3RhbXBSCXN0YXJ0VGltZRI1CghlbmRfdGltZRgCIAEoCzIaLmdvb2ds'
    'ZS5wcm90b2J1Zi5UaW1lc3RhbXBSB2VuZFRpbWUSKQoQdGhlcmFwaXN0X2ZpbHRlchgDIAEoCV'
    'IPdGhlcmFwaXN0RmlsdGVyEhsKCXBhZ2Vfc2l6ZRgEIAEoBVIIcGFnZVNpemUSEgoEcGFnZRgF'
    'IAEoBVIEcGFnZRIXCgdzb3J0X2J5GAYgASgJUgZzb3J0QnkSHQoKc29ydF9vcmRlchgHIAEoCV'
    'IJc29ydE9yZGVy');

@$core.Deprecated('Use adminListSessionsResponseDescriptor instead')
const AdminListSessionsResponse$json = {
  '1': 'AdminListSessionsResponse',
  '2': [
    {
      '1': 'sessions',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.clinical.v1.AdminSessionRow',
      '10': 'sessions'
    },
    {'1': 'has_more', '3': 2, '4': 1, '5': 8, '10': 'hasMore'},
  ],
};

/// Descriptor for `AdminListSessionsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List adminListSessionsResponseDescriptor = $convert.base64Decode(
    'ChlBZG1pbkxpc3RTZXNzaW9uc1Jlc3BvbnNlEjgKCHNlc3Npb25zGAEgAygLMhwuY2xpbmljYW'
    'wudjEuQWRtaW5TZXNzaW9uUm93UghzZXNzaW9ucxIZCghoYXNfbW9yZRgCIAEoCFIHaGFzTW9y'
    'ZQ==');

@$core.Deprecated('Use adminSessionRowDescriptor instead')
const AdminSessionRow$json = {
  '1': 'AdminSessionRow',
  '2': [
    {'1': 'session_id', '3': 1, '4': 1, '5': 9, '10': 'sessionId'},
    {'1': 'therapist_id', '3': 2, '4': 1, '5': 9, '10': 'therapistId'},
    {
      '1': 'therapist_first_name',
      '3': 3,
      '4': 1,
      '5': 9,
      '10': 'therapistFirstName'
    },
    {
      '1': 'therapist_last_name',
      '3': 4,
      '4': 1,
      '5': 9,
      '10': 'therapistLastName'
    },
    {'1': 'therapist_email', '3': 5, '4': 1, '5': 9, '10': 'therapistEmail'},
    {'1': 'organization_id', '3': 6, '4': 1, '5': 9, '10': 'organizationId'},
    {
      '1': 'organization_name',
      '3': 7,
      '4': 1,
      '5': 9,
      '10': 'organizationName'
    },
    {
      '1': 'created_at',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'createdAt'
    },
    {
      '1': 'session_date',
      '3': 9,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'sessionDate'
    },
    {'1': 'duration_seconds', '3': 10, '4': 1, '5': 5, '10': 'durationSeconds'},
    {'1': 'status', '3': 11, '4': 1, '5': 9, '10': 'status'},
    {
      '1': 'subscription_plan_name',
      '3': 12,
      '4': 1,
      '5': 9,
      '10': 'subscriptionPlanName'
    },
    {
      '1': 'subscription_period_end',
      '3': 13,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'subscriptionPeriodEnd'
    },
    {
      '1': 'subscription_tokens_used',
      '3': 14,
      '4': 1,
      '5': 5,
      '10': 'subscriptionTokensUsed'
    },
  ],
};

/// Descriptor for `AdminSessionRow`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List adminSessionRowDescriptor = $convert.base64Decode(
    'Cg9BZG1pblNlc3Npb25Sb3cSHQoKc2Vzc2lvbl9pZBgBIAEoCVIJc2Vzc2lvbklkEiEKDHRoZX'
    'JhcGlzdF9pZBgCIAEoCVILdGhlcmFwaXN0SWQSMAoUdGhlcmFwaXN0X2ZpcnN0X25hbWUYAyAB'
    'KAlSEnRoZXJhcGlzdEZpcnN0TmFtZRIuChN0aGVyYXBpc3RfbGFzdF9uYW1lGAQgASgJUhF0aG'
    'VyYXBpc3RMYXN0TmFtZRInCg90aGVyYXBpc3RfZW1haWwYBSABKAlSDnRoZXJhcGlzdEVtYWls'
    'EicKD29yZ2FuaXphdGlvbl9pZBgGIAEoCVIOb3JnYW5pemF0aW9uSWQSKwoRb3JnYW5pemF0aW'
    '9uX25hbWUYByABKAlSEG9yZ2FuaXphdGlvbk5hbWUSOQoKY3JlYXRlZF9hdBgIIAEoCzIaLmdv'
    'b2dsZS5wcm90b2J1Zi5UaW1lc3RhbXBSCWNyZWF0ZWRBdBI9CgxzZXNzaW9uX2RhdGUYCSABKA'
    'syGi5nb29nbGUucHJvdG9idWYuVGltZXN0YW1wUgtzZXNzaW9uRGF0ZRIpChBkdXJhdGlvbl9z'
    'ZWNvbmRzGAogASgFUg9kdXJhdGlvblNlY29uZHMSFgoGc3RhdHVzGAsgASgJUgZzdGF0dXMSNA'
    'oWc3Vic2NyaXB0aW9uX3BsYW5fbmFtZRgMIAEoCVIUc3Vic2NyaXB0aW9uUGxhbk5hbWUSUgoX'
    'c3Vic2NyaXB0aW9uX3BlcmlvZF9lbmQYDSABKAsyGi5nb29nbGUucHJvdG9idWYuVGltZXN0YW'
    '1wUhVzdWJzY3JpcHRpb25QZXJpb2RFbmQSOAoYc3Vic2NyaXB0aW9uX3Rva2Vuc191c2VkGA4g'
    'ASgFUhZzdWJzY3JpcHRpb25Ub2tlbnNVc2Vk');

@$core.Deprecated('Use adminModalityPromptDescriptor instead')
const AdminModalityPrompt$json = {
  '1': 'AdminModalityPrompt',
  '2': [
    {'1': 'modality_id', '3': 1, '4': 1, '5': 9, '10': 'modalityId'},
    {'1': 'system_code', '3': 2, '4': 1, '5': 9, '10': 'systemCode'},
    {'1': 'display_name', '3': 3, '4': 1, '5': 9, '10': 'displayName'},
    {'1': 'modality_type', '3': 4, '4': 1, '5': 9, '10': 'modalityType'},
    {'1': 'is_supported', '3': 5, '4': 1, '5': 8, '10': 'isSupported'},
    {'1': 'system_prompt', '3': 6, '4': 1, '5': 9, '10': 'systemPrompt'},
    {'1': 'version', '3': 7, '4': 1, '5': 5, '10': 'version'},
    {'1': 'updated_by_email', '3': 8, '4': 1, '5': 9, '10': 'updatedByEmail'},
    {
      '1': 'updated_at',
      '3': 9,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'updatedAt'
    },
  ],
};

/// Descriptor for `AdminModalityPrompt`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List adminModalityPromptDescriptor = $convert.base64Decode(
    'ChNBZG1pbk1vZGFsaXR5UHJvbXB0Eh8KC21vZGFsaXR5X2lkGAEgASgJUgptb2RhbGl0eUlkEh'
    '8KC3N5c3RlbV9jb2RlGAIgASgJUgpzeXN0ZW1Db2RlEiEKDGRpc3BsYXlfbmFtZRgDIAEoCVIL'
    'ZGlzcGxheU5hbWUSIwoNbW9kYWxpdHlfdHlwZRgEIAEoCVIMbW9kYWxpdHlUeXBlEiEKDGlzX3'
    'N1cHBvcnRlZBgFIAEoCFILaXNTdXBwb3J0ZWQSIwoNc3lzdGVtX3Byb21wdBgGIAEoCVIMc3lz'
    'dGVtUHJvbXB0EhgKB3ZlcnNpb24YByABKAVSB3ZlcnNpb24SKAoQdXBkYXRlZF9ieV9lbWFpbB'
    'gIIAEoCVIOdXBkYXRlZEJ5RW1haWwSOQoKdXBkYXRlZF9hdBgJIAEoCzIaLmdvb2dsZS5wcm90'
    'b2J1Zi5UaW1lc3RhbXBSCXVwZGF0ZWRBdA==');

@$core.Deprecated('Use adminListModalityPromptsResponseDescriptor instead')
const AdminListModalityPromptsResponse$json = {
  '1': 'AdminListModalityPromptsResponse',
  '2': [
    {
      '1': 'prompts',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.clinical.v1.AdminModalityPrompt',
      '10': 'prompts'
    },
  ],
};

/// Descriptor for `AdminListModalityPromptsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List adminListModalityPromptsResponseDescriptor =
    $convert.base64Decode(
        'CiBBZG1pbkxpc3RNb2RhbGl0eVByb21wdHNSZXNwb25zZRI6Cgdwcm9tcHRzGAEgAygLMiAuY2'
        'xpbmljYWwudjEuQWRtaW5Nb2RhbGl0eVByb21wdFIHcHJvbXB0cw==');

@$core.Deprecated('Use adminGetModalityPromptHistoryRequestDescriptor instead')
const AdminGetModalityPromptHistoryRequest$json = {
  '1': 'AdminGetModalityPromptHistoryRequest',
  '2': [
    {'1': 'modality_id', '3': 1, '4': 1, '5': 9, '10': 'modalityId'},
    {'1': 'page_size', '3': 2, '4': 1, '5': 5, '10': 'pageSize'},
    {'1': 'page_offset', '3': 3, '4': 1, '5': 5, '10': 'pageOffset'},
  ],
};

/// Descriptor for `AdminGetModalityPromptHistoryRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List adminGetModalityPromptHistoryRequestDescriptor =
    $convert.base64Decode(
        'CiRBZG1pbkdldE1vZGFsaXR5UHJvbXB0SGlzdG9yeVJlcXVlc3QSHwoLbW9kYWxpdHlfaWQYAS'
        'ABKAlSCm1vZGFsaXR5SWQSGwoJcGFnZV9zaXplGAIgASgFUghwYWdlU2l6ZRIfCgtwYWdlX29m'
        'ZnNldBgDIAEoBVIKcGFnZU9mZnNldA==');

@$core.Deprecated('Use adminModalityPromptVersionDescriptor instead')
const AdminModalityPromptVersion$json = {
  '1': 'AdminModalityPromptVersion',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'version', '3': 2, '4': 1, '5': 5, '10': 'version'},
    {'1': 'system_prompt', '3': 3, '4': 1, '5': 9, '10': 'systemPrompt'},
    {'1': 'change_note', '3': 4, '4': 1, '5': 9, '10': 'changeNote'},
    {'1': 'created_by_email', '3': 5, '4': 1, '5': 9, '10': 'createdByEmail'},
    {
      '1': 'created_at',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'createdAt'
    },
  ],
};

/// Descriptor for `AdminModalityPromptVersion`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List adminModalityPromptVersionDescriptor = $convert.base64Decode(
    'ChpBZG1pbk1vZGFsaXR5UHJvbXB0VmVyc2lvbhIOCgJpZBgBIAEoCVICaWQSGAoHdmVyc2lvbh'
    'gCIAEoBVIHdmVyc2lvbhIjCg1zeXN0ZW1fcHJvbXB0GAMgASgJUgxzeXN0ZW1Qcm9tcHQSHwoL'
    'Y2hhbmdlX25vdGUYBCABKAlSCmNoYW5nZU5vdGUSKAoQY3JlYXRlZF9ieV9lbWFpbBgFIAEoCV'
    'IOY3JlYXRlZEJ5RW1haWwSOQoKY3JlYXRlZF9hdBgGIAEoCzIaLmdvb2dsZS5wcm90b2J1Zi5U'
    'aW1lc3RhbXBSCWNyZWF0ZWRBdA==');

@$core.Deprecated('Use adminGetModalityPromptHistoryResponseDescriptor instead')
const AdminGetModalityPromptHistoryResponse$json = {
  '1': 'AdminGetModalityPromptHistoryResponse',
  '2': [
    {
      '1': 'versions',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.clinical.v1.AdminModalityPromptVersion',
      '10': 'versions'
    },
    {'1': 'has_more', '3': 2, '4': 1, '5': 8, '10': 'hasMore'},
  ],
};

/// Descriptor for `AdminGetModalityPromptHistoryResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List adminGetModalityPromptHistoryResponseDescriptor =
    $convert.base64Decode(
        'CiVBZG1pbkdldE1vZGFsaXR5UHJvbXB0SGlzdG9yeVJlc3BvbnNlEkMKCHZlcnNpb25zGAEgAy'
        'gLMicuY2xpbmljYWwudjEuQWRtaW5Nb2RhbGl0eVByb21wdFZlcnNpb25SCHZlcnNpb25zEhkK'
        'CGhhc19tb3JlGAIgASgIUgdoYXNNb3Jl');

@$core.Deprecated('Use adminUpdateModalityPromptRequestDescriptor instead')
const AdminUpdateModalityPromptRequest$json = {
  '1': 'AdminUpdateModalityPromptRequest',
  '2': [
    {'1': 'modality_id', '3': 1, '4': 1, '5': 9, '10': 'modalityId'},
    {'1': 'system_prompt', '3': 2, '4': 1, '5': 9, '10': 'systemPrompt'},
    {'1': 'change_note', '3': 3, '4': 1, '5': 9, '10': 'changeNote'},
    {'1': 'expected_version', '3': 4, '4': 1, '5': 5, '10': 'expectedVersion'},
  ],
};

/// Descriptor for `AdminUpdateModalityPromptRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List adminUpdateModalityPromptRequestDescriptor =
    $convert.base64Decode(
        'CiBBZG1pblVwZGF0ZU1vZGFsaXR5UHJvbXB0UmVxdWVzdBIfCgttb2RhbGl0eV9pZBgBIAEoCV'
        'IKbW9kYWxpdHlJZBIjCg1zeXN0ZW1fcHJvbXB0GAIgASgJUgxzeXN0ZW1Qcm9tcHQSHwoLY2hh'
        'bmdlX25vdGUYAyABKAlSCmNoYW5nZU5vdGUSKQoQZXhwZWN0ZWRfdmVyc2lvbhgEIAEoBVIPZX'
        'hwZWN0ZWRWZXJzaW9u');

@$core.Deprecated('Use adminUpdateModalityPromptResponseDescriptor instead')
const AdminUpdateModalityPromptResponse$json = {
  '1': 'AdminUpdateModalityPromptResponse',
  '2': [
    {
      '1': 'prompt',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.clinical.v1.AdminModalityPrompt',
      '10': 'prompt'
    },
  ],
};

/// Descriptor for `AdminUpdateModalityPromptResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List adminUpdateModalityPromptResponseDescriptor =
    $convert.base64Decode(
        'CiFBZG1pblVwZGF0ZU1vZGFsaXR5UHJvbXB0UmVzcG9uc2USOAoGcHJvbXB0GAEgASgLMiAuY2'
        'xpbmljYWwudjEuQWRtaW5Nb2RhbGl0eVByb21wdFIGcHJvbXB0');

@$core.Deprecated('Use trackEventsRequestDescriptor instead')
const TrackEventsRequest$json = {
  '1': 'TrackEventsRequest',
  '2': [
    {
      '1': 'events',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.clinical.v1.ClientEvent',
      '10': 'events'
    },
  ],
};

/// Descriptor for `TrackEventsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List trackEventsRequestDescriptor = $convert.base64Decode(
    'ChJUcmFja0V2ZW50c1JlcXVlc3QSMAoGZXZlbnRzGAEgAygLMhguY2xpbmljYWwudjEuQ2xpZW'
    '50RXZlbnRSBmV2ZW50cw==');

@$core.Deprecated('Use clientEventDescriptor instead')
const ClientEvent$json = {
  '1': 'ClientEvent',
  '2': [
    {'1': 'event_name', '3': 1, '4': 1, '5': 9, '10': 'eventName'},
    {
      '1': 'properties',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Struct',
      '10': 'properties'
    },
    {
      '1': 'occurred_at',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'occurredAt'
    },
    {'1': 'client_platform', '3': 4, '4': 1, '5': 9, '10': 'clientPlatform'},
    {'1': 'client_version', '3': 5, '4': 1, '5': 9, '10': 'clientVersion'},
  ],
};

/// Descriptor for `ClientEvent`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List clientEventDescriptor = $convert.base64Decode(
    'CgtDbGllbnRFdmVudBIdCgpldmVudF9uYW1lGAEgASgJUglldmVudE5hbWUSNwoKcHJvcGVydG'
    'llcxgCIAEoCzIXLmdvb2dsZS5wcm90b2J1Zi5TdHJ1Y3RSCnByb3BlcnRpZXMSOwoLb2NjdXJy'
    'ZWRfYXQYAyABKAsyGi5nb29nbGUucHJvdG9idWYuVGltZXN0YW1wUgpvY2N1cnJlZEF0EicKD2'
    'NsaWVudF9wbGF0Zm9ybRgEIAEoCVIOY2xpZW50UGxhdGZvcm0SJQoOY2xpZW50X3ZlcnNpb24Y'
    'BSABKAlSDWNsaWVudFZlcnNpb24=');

@$core.Deprecated('Use trackEventsResponseDescriptor instead')
const TrackEventsResponse$json = {
  '1': 'TrackEventsResponse',
};

/// Descriptor for `TrackEventsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List trackEventsResponseDescriptor =
    $convert.base64Decode('ChNUcmFja0V2ZW50c1Jlc3BvbnNl');

@$core.Deprecated('Use getAdminAnalyticsRequestDescriptor instead')
const GetAdminAnalyticsRequest$json = {
  '1': 'GetAdminAnalyticsRequest',
  '2': [
    {'1': 'time_range', '3': 1, '4': 1, '5': 9, '10': 'timeRange'},
  ],
};

/// Descriptor for `GetAdminAnalyticsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getAdminAnalyticsRequestDescriptor =
    $convert.base64Decode(
        'ChhHZXRBZG1pbkFuYWx5dGljc1JlcXVlc3QSHQoKdGltZV9yYW5nZRgBIAEoCVIJdGltZVJhbm'
        'dl');

@$core.Deprecated('Use getAdminAnalyticsResponseDescriptor instead')
const GetAdminAnalyticsResponse$json = {
  '1': 'GetAdminAnalyticsResponse',
  '2': [
    {'1': 'kpi_wau', '3': 1, '4': 1, '5': 3, '10': 'kpiWau'},
    {
      '1': 'kpi_sessions_this_week',
      '3': 2,
      '4': 1,
      '5': 3,
      '10': 'kpiSessionsThisWeek'
    },
    {
      '1': 'kpi_activation_rate',
      '3': 3,
      '4': 1,
      '5': 1,
      '10': 'kpiActivationRate'
    },
    {
      '1': 'kpi_satisfaction_rate',
      '3': 4,
      '4': 1,
      '5': 1,
      '10': 'kpiSatisfactionRate'
    },
    {
      '1': 'wau_trend',
      '3': 5,
      '4': 3,
      '5': 11,
      '6': '.clinical.v1.TrendPoint',
      '10': 'wauTrend'
    },
    {
      '1': 'sessions_trend',
      '3': 6,
      '4': 3,
      '5': 11,
      '6': '.clinical.v1.TrendPoint',
      '10': 'sessionsTrend'
    },
    {
      '1': 'registrations_trend',
      '3': 7,
      '4': 3,
      '5': 11,
      '6': '.clinical.v1.TrendPoint',
      '10': 'registrationsTrend'
    },
    {
      '1': 'plan_distribution',
      '3': 8,
      '4': 3,
      '5': 11,
      '6': '.clinical.v1.PlanDistribution',
      '10': 'planDistribution'
    },
    {
      '1': 'kpi_avg_cost_per_session',
      '3': 9,
      '4': 1,
      '5': 1,
      '10': 'kpiAvgCostPerSession'
    },
    {
      '1': 'kpi_monthly_stt_cost',
      '3': 10,
      '4': 1,
      '5': 1,
      '10': 'kpiMonthlySttCost'
    },
    {
      '1': 'kpi_monthly_llm_cost',
      '3': 11,
      '4': 1,
      '5': 1,
      '10': 'kpiMonthlyLlmCost'
    },
    {
      '1': 'kpi_avg_token_utilization',
      '3': 12,
      '4': 1,
      '5': 1,
      '10': 'kpiAvgTokenUtilization'
    },
    {
      '1': 'cost_trend',
      '3': 13,
      '4': 3,
      '5': 11,
      '6': '.clinical.v1.CostTrendPoint',
      '10': 'costTrend'
    },
    {
      '1': 'token_utilization_heatmap',
      '3': 14,
      '4': 3,
      '5': 11,
      '6': '.clinical.v1.TokenUtilizationHeatmapPoint',
      '10': 'tokenUtilizationHeatmap'
    },
    {
      '1': 'revenue_trend',
      '3': 15,
      '4': 3,
      '5': 11,
      '6': '.clinical.v1.RevenueTrendPoint',
      '10': 'revenueTrend'
    },
    {
      '1': 'token_usage_trend',
      '3': 16,
      '4': 3,
      '5': 11,
      '6': '.clinical.v1.TokenUsageTrendPoint',
      '10': 'tokenUsageTrend'
    },
    {
      '1': 'kpi_avg_pipeline_latency',
      '3': 17,
      '4': 1,
      '5': 1,
      '10': 'kpiAvgPipelineLatency'
    },
    {
      '1': 'kpi_failure_rate_7d',
      '3': 18,
      '4': 1,
      '5': 1,
      '10': 'kpiFailureRate7d'
    },
    {'1': 'kpi_relabel_rate', '3': 19, '4': 1, '5': 1, '10': 'kpiRelabelRate'},
    {
      '1': 'satisfaction_trend',
      '3': 20,
      '4': 3,
      '5': 11,
      '6': '.clinical.v1.SatisfactionTrendPoint',
      '10': 'satisfactionTrend'
    },
    {
      '1': 'issue_categories',
      '3': 21,
      '4': 3,
      '5': 11,
      '6': '.clinical.v1.IssueCategory',
      '10': 'issueCategories'
    },
    {
      '1': 'latency_trend',
      '3': 22,
      '4': 3,
      '5': 11,
      '6': '.clinical.v1.LatencyTrendPoint',
      '10': 'latencyTrend'
    },
    {
      '1': 'failure_rate_trend',
      '3': 23,
      '4': 3,
      '5': 11,
      '6': '.clinical.v1.FailureRatePoint',
      '10': 'failureRateTrend'
    },
    {
      '1': 'kpi_30d_retention',
      '3': 24,
      '4': 1,
      '5': 1,
      '10': 'kpi30dRetention'
    },
    {
      '1': 'funnel_steps',
      '3': 25,
      '4': 3,
      '5': 11,
      '6': '.clinical.v1.FunnelStep',
      '10': 'funnelSteps'
    },
    {
      '1': 'cohort_retention',
      '3': 26,
      '4': 3,
      '5': 11,
      '6': '.clinical.v1.CohortRetentionPoint',
      '10': 'cohortRetention'
    },
    {
      '1': 'activation_time_histogram',
      '3': 27,
      '4': 3,
      '5': 11,
      '6': '.clinical.v1.HistogramBucket',
      '10': 'activationTimeHistogram'
    },
    {
      '1': 'hourly_heatmap',
      '3': 28,
      '4': 3,
      '5': 11,
      '6': '.clinical.v1.HourlyHeatmapPoint',
      '10': 'hourlyHeatmap'
    },
    {
      '1': 'upload_failures_trend',
      '3': 29,
      '4': 3,
      '5': 11,
      '6': '.clinical.v1.FailureRatePoint',
      '10': 'uploadFailuresTrend'
    },
    {
      '1': 'modality_distribution',
      '3': 30,
      '4': 3,
      '5': 11,
      '6': '.clinical.v1.ModalityDistribution',
      '10': 'modalityDistribution'
    },
    {
      '1': 'kpi_avg_session_duration',
      '3': 31,
      '4': 1,
      '5': 1,
      '10': 'kpiAvgSessionDuration'
    },
    {
      '1': 'session_duration_trend',
      '3': 32,
      '4': 3,
      '5': 11,
      '6': '.clinical.v1.TrendPoint',
      '10': 'sessionDurationTrend'
    },
    {
      '1': 'platform_fixed_costs',
      '3': 33,
      '4': 3,
      '5': 11,
      '6': '.clinical.v1.PlatformFixedCost',
      '10': 'platformFixedCosts'
    },
  ],
};

/// Descriptor for `GetAdminAnalyticsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getAdminAnalyticsResponseDescriptor = $convert.base64Decode(
    'ChlHZXRBZG1pbkFuYWx5dGljc1Jlc3BvbnNlEhcKB2twaV93YXUYASABKANSBmtwaVdhdRIzCh'
    'ZrcGlfc2Vzc2lvbnNfdGhpc193ZWVrGAIgASgDUhNrcGlTZXNzaW9uc1RoaXNXZWVrEi4KE2tw'
    'aV9hY3RpdmF0aW9uX3JhdGUYAyABKAFSEWtwaUFjdGl2YXRpb25SYXRlEjIKFWtwaV9zYXRpc2'
    'ZhY3Rpb25fcmF0ZRgEIAEoAVITa3BpU2F0aXNmYWN0aW9uUmF0ZRI0Cgl3YXVfdHJlbmQYBSAD'
    'KAsyFy5jbGluaWNhbC52MS5UcmVuZFBvaW50Ugh3YXVUcmVuZBI+Cg5zZXNzaW9uc190cmVuZB'
    'gGIAMoCzIXLmNsaW5pY2FsLnYxLlRyZW5kUG9pbnRSDXNlc3Npb25zVHJlbmQSSAoTcmVnaXN0'
    'cmF0aW9uc190cmVuZBgHIAMoCzIXLmNsaW5pY2FsLnYxLlRyZW5kUG9pbnRSEnJlZ2lzdHJhdG'
    'lvbnNUcmVuZBJKChFwbGFuX2Rpc3RyaWJ1dGlvbhgIIAMoCzIdLmNsaW5pY2FsLnYxLlBsYW5E'
    'aXN0cmlidXRpb25SEHBsYW5EaXN0cmlidXRpb24SNgoYa3BpX2F2Z19jb3N0X3Blcl9zZXNzaW'
    '9uGAkgASgBUhRrcGlBdmdDb3N0UGVyU2Vzc2lvbhIvChRrcGlfbW9udGhseV9zdHRfY29zdBgK'
    'IAEoAVIRa3BpTW9udGhseVN0dENvc3QSLwoUa3BpX21vbnRobHlfbGxtX2Nvc3QYCyABKAFSEW'
    'twaU1vbnRobHlMbG1Db3N0EjkKGWtwaV9hdmdfdG9rZW5fdXRpbGl6YXRpb24YDCABKAFSFmtw'
    'aUF2Z1Rva2VuVXRpbGl6YXRpb24SOgoKY29zdF90cmVuZBgNIAMoCzIbLmNsaW5pY2FsLnYxLk'
    'Nvc3RUcmVuZFBvaW50Ugljb3N0VHJlbmQSZQoZdG9rZW5fdXRpbGl6YXRpb25faGVhdG1hcBgO'
    'IAMoCzIpLmNsaW5pY2FsLnYxLlRva2VuVXRpbGl6YXRpb25IZWF0bWFwUG9pbnRSF3Rva2VuVX'
    'RpbGl6YXRpb25IZWF0bWFwEkMKDXJldmVudWVfdHJlbmQYDyADKAsyHi5jbGluaWNhbC52MS5S'
    'ZXZlbnVlVHJlbmRQb2ludFIMcmV2ZW51ZVRyZW5kEk0KEXRva2VuX3VzYWdlX3RyZW5kGBAgAy'
    'gLMiEuY2xpbmljYWwudjEuVG9rZW5Vc2FnZVRyZW5kUG9pbnRSD3Rva2VuVXNhZ2VUcmVuZBI3'
    'ChhrcGlfYXZnX3BpcGVsaW5lX2xhdGVuY3kYESABKAFSFWtwaUF2Z1BpcGVsaW5lTGF0ZW5jeR'
    'ItChNrcGlfZmFpbHVyZV9yYXRlXzdkGBIgASgBUhBrcGlGYWlsdXJlUmF0ZTdkEigKEGtwaV9y'
    'ZWxhYmVsX3JhdGUYEyABKAFSDmtwaVJlbGFiZWxSYXRlElIKEnNhdGlzZmFjdGlvbl90cmVuZB'
    'gUIAMoCzIjLmNsaW5pY2FsLnYxLlNhdGlzZmFjdGlvblRyZW5kUG9pbnRSEXNhdGlzZmFjdGlv'
    'blRyZW5kEkUKEGlzc3VlX2NhdGVnb3JpZXMYFSADKAsyGi5jbGluaWNhbC52MS5Jc3N1ZUNhdG'
    'Vnb3J5Ug9pc3N1ZUNhdGVnb3JpZXMSQwoNbGF0ZW5jeV90cmVuZBgWIAMoCzIeLmNsaW5pY2Fs'
    'LnYxLkxhdGVuY3lUcmVuZFBvaW50UgxsYXRlbmN5VHJlbmQSSwoSZmFpbHVyZV9yYXRlX3RyZW'
    '5kGBcgAygLMh0uY2xpbmljYWwudjEuRmFpbHVyZVJhdGVQb2ludFIQZmFpbHVyZVJhdGVUcmVu'
    'ZBIqChFrcGlfMzBkX3JldGVudGlvbhgYIAEoAVIPa3BpMzBkUmV0ZW50aW9uEjoKDGZ1bm5lbF'
    '9zdGVwcxgZIAMoCzIXLmNsaW5pY2FsLnYxLkZ1bm5lbFN0ZXBSC2Z1bm5lbFN0ZXBzEkwKEGNv'
    'aG9ydF9yZXRlbnRpb24YGiADKAsyIS5jbGluaWNhbC52MS5Db2hvcnRSZXRlbnRpb25Qb2ludF'
    'IPY29ob3J0UmV0ZW50aW9uElgKGWFjdGl2YXRpb25fdGltZV9oaXN0b2dyYW0YGyADKAsyHC5j'
    'bGluaWNhbC52MS5IaXN0b2dyYW1CdWNrZXRSF2FjdGl2YXRpb25UaW1lSGlzdG9ncmFtEkYKDm'
    'hvdXJseV9oZWF0bWFwGBwgAygLMh8uY2xpbmljYWwudjEuSG91cmx5SGVhdG1hcFBvaW50Ug1o'
    'b3VybHlIZWF0bWFwElEKFXVwbG9hZF9mYWlsdXJlc190cmVuZBgdIAMoCzIdLmNsaW5pY2FsLn'
    'YxLkZhaWx1cmVSYXRlUG9pbnRSE3VwbG9hZEZhaWx1cmVzVHJlbmQSVgoVbW9kYWxpdHlfZGlz'
    'dHJpYnV0aW9uGB4gAygLMiEuY2xpbmljYWwudjEuTW9kYWxpdHlEaXN0cmlidXRpb25SFG1vZG'
    'FsaXR5RGlzdHJpYnV0aW9uEjcKGGtwaV9hdmdfc2Vzc2lvbl9kdXJhdGlvbhgfIAEoAVIVa3Bp'
    'QXZnU2Vzc2lvbkR1cmF0aW9uEk0KFnNlc3Npb25fZHVyYXRpb25fdHJlbmQYICADKAsyFy5jbG'
    'luaWNhbC52MS5UcmVuZFBvaW50UhRzZXNzaW9uRHVyYXRpb25UcmVuZBJQChRwbGF0Zm9ybV9m'
    'aXhlZF9jb3N0cxghIAMoCzIeLmNsaW5pY2FsLnYxLlBsYXRmb3JtRml4ZWRDb3N0UhJwbGF0Zm'
    '9ybUZpeGVkQ29zdHM=');

@$core.Deprecated('Use trendPointDescriptor instead')
const TrendPoint$json = {
  '1': 'TrendPoint',
  '2': [
    {'1': 'label', '3': 1, '4': 1, '5': 9, '10': 'label'},
    {'1': 'value', '3': 2, '4': 1, '5': 1, '10': 'value'},
  ],
};

/// Descriptor for `TrendPoint`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List trendPointDescriptor = $convert.base64Decode(
    'CgpUcmVuZFBvaW50EhQKBWxhYmVsGAEgASgJUgVsYWJlbBIUCgV2YWx1ZRgCIAEoAVIFdmFsdW'
    'U=');

@$core.Deprecated('Use planDistributionDescriptor instead')
const PlanDistribution$json = {
  '1': 'PlanDistribution',
  '2': [
    {'1': 'plan_name', '3': 1, '4': 1, '5': 9, '10': 'planName'},
    {'1': 'count', '3': 2, '4': 1, '5': 3, '10': 'count'},
  ],
};

/// Descriptor for `PlanDistribution`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List planDistributionDescriptor = $convert.base64Decode(
    'ChBQbGFuRGlzdHJpYnV0aW9uEhsKCXBsYW5fbmFtZRgBIAEoCVIIcGxhbk5hbWUSFAoFY291bn'
    'QYAiABKANSBWNvdW50');

@$core.Deprecated('Use modalityDistributionDescriptor instead')
const ModalityDistribution$json = {
  '1': 'ModalityDistribution',
  '2': [
    {'1': 'modality_name', '3': 1, '4': 1, '5': 9, '10': 'modalityName'},
    {'1': 'count', '3': 2, '4': 1, '5': 3, '10': 'count'},
  ],
};

/// Descriptor for `ModalityDistribution`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List modalityDistributionDescriptor = $convert.base64Decode(
    'ChRNb2RhbGl0eURpc3RyaWJ1dGlvbhIjCg1tb2RhbGl0eV9uYW1lGAEgASgJUgxtb2RhbGl0eU'
    '5hbWUSFAoFY291bnQYAiABKANSBWNvdW50');

@$core.Deprecated('Use costTrendPointDescriptor instead')
const CostTrendPoint$json = {
  '1': 'CostTrendPoint',
  '2': [
    {'1': 'label', '3': 1, '4': 1, '5': 9, '10': 'label'},
    {'1': 'stt_cost', '3': 2, '4': 1, '5': 1, '10': 'sttCost'},
    {'1': 'llm_cost', '3': 3, '4': 1, '5': 1, '10': 'llmCost'},
    {'1': 'total_cost', '3': 4, '4': 1, '5': 1, '10': 'totalCost'},
  ],
};

/// Descriptor for `CostTrendPoint`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List costTrendPointDescriptor = $convert.base64Decode(
    'Cg5Db3N0VHJlbmRQb2ludBIUCgVsYWJlbBgBIAEoCVIFbGFiZWwSGQoIc3R0X2Nvc3QYAiABKA'
    'FSB3N0dENvc3QSGQoIbGxtX2Nvc3QYAyABKAFSB2xsbUNvc3QSHQoKdG90YWxfY29zdBgEIAEo'
    'AVIJdG90YWxDb3N0');

@$core.Deprecated('Use tokenUtilizationHeatmapPointDescriptor instead')
const TokenUtilizationHeatmapPoint$json = {
  '1': 'TokenUtilizationHeatmapPoint',
  '2': [
    {'1': 'org_name', '3': 1, '4': 1, '5': 9, '10': 'orgName'},
    {'1': 'week', '3': 2, '4': 1, '5': 9, '10': 'week'},
    {'1': 'value', '3': 3, '4': 1, '5': 1, '10': 'value'},
  ],
};

/// Descriptor for `TokenUtilizationHeatmapPoint`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List tokenUtilizationHeatmapPointDescriptor =
    $convert.base64Decode(
        'ChxUb2tlblV0aWxpemF0aW9uSGVhdG1hcFBvaW50EhkKCG9yZ19uYW1lGAEgASgJUgdvcmdOYW'
        '1lEhIKBHdlZWsYAiABKAlSBHdlZWsSFAoFdmFsdWUYAyABKAFSBXZhbHVl');

@$core.Deprecated('Use revenueTrendPointDescriptor instead')
const RevenueTrendPoint$json = {
  '1': 'RevenueTrendPoint',
  '2': [
    {'1': 'label', '3': 1, '4': 1, '5': 9, '10': 'label'},
    {'1': 'solo_revenue', '3': 2, '4': 1, '5': 1, '10': 'soloRevenue'},
    {'1': 'pro_revenue', '3': 3, '4': 1, '5': 1, '10': 'proRevenue'},
    {'1': 'total_revenue', '3': 4, '4': 1, '5': 1, '10': 'totalRevenue'},
  ],
};

/// Descriptor for `RevenueTrendPoint`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List revenueTrendPointDescriptor = $convert.base64Decode(
    'ChFSZXZlbnVlVHJlbmRQb2ludBIUCgVsYWJlbBgBIAEoCVIFbGFiZWwSIQoMc29sb19yZXZlbn'
    'VlGAIgASgBUgtzb2xvUmV2ZW51ZRIfCgtwcm9fcmV2ZW51ZRgDIAEoAVIKcHJvUmV2ZW51ZRIj'
    'Cg10b3RhbF9yZXZlbnVlGAQgASgBUgx0b3RhbFJldmVudWU=');

@$core.Deprecated('Use tokenUsageTrendPointDescriptor instead')
const TokenUsageTrendPoint$json = {
  '1': 'TokenUsageTrendPoint',
  '2': [
    {'1': 'label', '3': 1, '4': 1, '5': 9, '10': 'label'},
    {'1': 'input_tokens', '3': 2, '4': 1, '5': 3, '10': 'inputTokens'},
    {'1': 'output_tokens', '3': 3, '4': 1, '5': 3, '10': 'outputTokens'},
  ],
};

/// Descriptor for `TokenUsageTrendPoint`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List tokenUsageTrendPointDescriptor = $convert.base64Decode(
    'ChRUb2tlblVzYWdlVHJlbmRQb2ludBIUCgVsYWJlbBgBIAEoCVIFbGFiZWwSIQoMaW5wdXRfdG'
    '9rZW5zGAIgASgDUgtpbnB1dFRva2VucxIjCg1vdXRwdXRfdG9rZW5zGAMgASgDUgxvdXRwdXRU'
    'b2tlbnM=');

@$core.Deprecated('Use satisfactionTrendPointDescriptor instead')
const SatisfactionTrendPoint$json = {
  '1': 'SatisfactionTrendPoint',
  '2': [
    {'1': 'label', '3': 1, '4': 1, '5': 9, '10': 'label'},
    {'1': 'satisfaction_pct', '3': 2, '4': 1, '5': 1, '10': 'satisfactionPct'},
  ],
};

/// Descriptor for `SatisfactionTrendPoint`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List satisfactionTrendPointDescriptor =
    $convert.base64Decode(
        'ChZTYXRpc2ZhY3Rpb25UcmVuZFBvaW50EhQKBWxhYmVsGAEgASgJUgVsYWJlbBIpChBzYXRpc2'
        'ZhY3Rpb25fcGN0GAIgASgBUg9zYXRpc2ZhY3Rpb25QY3Q=');

@$core.Deprecated('Use issueCategoryDescriptor instead')
const IssueCategory$json = {
  '1': 'IssueCategory',
  '2': [
    {'1': 'category', '3': 1, '4': 1, '5': 9, '10': 'category'},
    {'1': 'count', '3': 2, '4': 1, '5': 3, '10': 'count'},
  ],
};

/// Descriptor for `IssueCategory`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List issueCategoryDescriptor = $convert.base64Decode(
    'Cg1Jc3N1ZUNhdGVnb3J5EhoKCGNhdGVnb3J5GAEgASgJUghjYXRlZ29yeRIUCgVjb3VudBgCIA'
    'EoA1IFY291bnQ=');

@$core.Deprecated('Use latencyTrendPointDescriptor instead')
const LatencyTrendPoint$json = {
  '1': 'LatencyTrendPoint',
  '2': [
    {'1': 'label', '3': 1, '4': 1, '5': 9, '10': 'label'},
    {'1': 'p50', '3': 2, '4': 1, '5': 1, '10': 'p50'},
    {'1': 'p95', '3': 3, '4': 1, '5': 1, '10': 'p95'},
  ],
};

/// Descriptor for `LatencyTrendPoint`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List latencyTrendPointDescriptor = $convert.base64Decode(
    'ChFMYXRlbmN5VHJlbmRQb2ludBIUCgVsYWJlbBgBIAEoCVIFbGFiZWwSEAoDcDUwGAIgASgBUg'
    'NwNTASEAoDcDk1GAMgASgBUgNwOTU=');

@$core.Deprecated('Use failureRatePointDescriptor instead')
const FailureRatePoint$json = {
  '1': 'FailureRatePoint',
  '2': [
    {'1': 'label', '3': 1, '4': 1, '5': 9, '10': 'label'},
    {'1': 'failure_rate', '3': 2, '4': 1, '5': 1, '10': 'failureRate'},
    {'1': 'total', '3': 3, '4': 1, '5': 3, '10': 'total'},
    {'1': 'failed', '3': 4, '4': 1, '5': 3, '10': 'failed'},
  ],
};

/// Descriptor for `FailureRatePoint`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List failureRatePointDescriptor = $convert.base64Decode(
    'ChBGYWlsdXJlUmF0ZVBvaW50EhQKBWxhYmVsGAEgASgJUgVsYWJlbBIhCgxmYWlsdXJlX3JhdG'
    'UYAiABKAFSC2ZhaWx1cmVSYXRlEhQKBXRvdGFsGAMgASgDUgV0b3RhbBIWCgZmYWlsZWQYBCAB'
    'KANSBmZhaWxlZA==');

@$core.Deprecated('Use funnelStepDescriptor instead')
const FunnelStep$json = {
  '1': 'FunnelStep',
  '2': [
    {'1': 'step_name', '3': 1, '4': 1, '5': 9, '10': 'stepName'},
    {'1': 'count', '3': 2, '4': 1, '5': 3, '10': 'count'},
    {'1': 'pct_of_previous', '3': 3, '4': 1, '5': 1, '10': 'pctOfPrevious'},
  ],
};

/// Descriptor for `FunnelStep`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List funnelStepDescriptor = $convert.base64Decode(
    'CgpGdW5uZWxTdGVwEhsKCXN0ZXBfbmFtZRgBIAEoCVIIc3RlcE5hbWUSFAoFY291bnQYAiABKA'
    'NSBWNvdW50EiYKD3BjdF9vZl9wcmV2aW91cxgDIAEoAVINcGN0T2ZQcmV2aW91cw==');

@$core.Deprecated('Use cohortRetentionPointDescriptor instead')
const CohortRetentionPoint$json = {
  '1': 'CohortRetentionPoint',
  '2': [
    {'1': 'cohort', '3': 1, '4': 1, '5': 9, '10': 'cohort'},
    {'1': 'week', '3': 2, '4': 1, '5': 9, '10': 'week'},
    {'1': 'pct', '3': 3, '4': 1, '5': 1, '10': 'pct'},
  ],
};

/// Descriptor for `CohortRetentionPoint`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List cohortRetentionPointDescriptor = $convert.base64Decode(
    'ChRDb2hvcnRSZXRlbnRpb25Qb2ludBIWCgZjb2hvcnQYASABKAlSBmNvaG9ydBISCgR3ZWVrGA'
    'IgASgJUgR3ZWVrEhAKA3BjdBgDIAEoAVIDcGN0');

@$core.Deprecated('Use histogramBucketDescriptor instead')
const HistogramBucket$json = {
  '1': 'HistogramBucket',
  '2': [
    {'1': 'bucket_label', '3': 1, '4': 1, '5': 9, '10': 'bucketLabel'},
    {'1': 'count', '3': 2, '4': 1, '5': 3, '10': 'count'},
  ],
};

/// Descriptor for `HistogramBucket`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List histogramBucketDescriptor = $convert.base64Decode(
    'Cg9IaXN0b2dyYW1CdWNrZXQSIQoMYnVja2V0X2xhYmVsGAEgASgJUgtidWNrZXRMYWJlbBIUCg'
    'Vjb3VudBgCIAEoA1IFY291bnQ=');

@$core.Deprecated('Use hourlyHeatmapPointDescriptor instead')
const HourlyHeatmapPoint$json = {
  '1': 'HourlyHeatmapPoint',
  '2': [
    {'1': 'day_of_week', '3': 1, '4': 1, '5': 5, '10': 'dayOfWeek'},
    {'1': 'hour', '3': 2, '4': 1, '5': 5, '10': 'hour'},
    {'1': 'count', '3': 3, '4': 1, '5': 3, '10': 'count'},
  ],
};

/// Descriptor for `HourlyHeatmapPoint`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List hourlyHeatmapPointDescriptor = $convert.base64Decode(
    'ChJIb3VybHlIZWF0bWFwUG9pbnQSHgoLZGF5X29mX3dlZWsYASABKAVSCWRheU9mV2VlaxISCg'
    'Rob3VyGAIgASgFUgRob3VyEhQKBWNvdW50GAMgASgDUgVjb3VudA==');

@$core.Deprecated('Use exportPatientDataRequestDescriptor instead')
const ExportPatientDataRequest$json = {
  '1': 'ExportPatientDataRequest',
  '2': [
    {'1': 'patient_file_id', '3': 1, '4': 1, '5': 9, '10': 'patientFileId'},
  ],
};

/// Descriptor for `ExportPatientDataRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List exportPatientDataRequestDescriptor =
    $convert.base64Decode(
        'ChhFeHBvcnRQYXRpZW50RGF0YVJlcXVlc3QSJgoPcGF0aWVudF9maWxlX2lkGAEgASgJUg1wYX'
        'RpZW50RmlsZUlk');

@$core.Deprecated('Use decryptedReportDescriptor instead')
const DecryptedReport$json = {
  '1': 'DecryptedReport',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'title', '3': 2, '4': 1, '5': 9, '10': 'title'},
    {'1': 'summary_short', '3': 3, '4': 1, '5': 9, '10': 'summaryShort'},
    {'1': 'content', '3': 4, '4': 1, '5': 9, '10': 'content'},
    {'1': 'sentiment_label', '3': 5, '4': 1, '5': 9, '10': 'sentimentLabel'},
    {'1': 'risk_level', '3': 6, '4': 1, '5': 9, '10': 'riskLevel'},
    {
      '1': 'created_at',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'createdAt'
    },
  ],
};

/// Descriptor for `DecryptedReport`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List decryptedReportDescriptor = $convert.base64Decode(
    'Cg9EZWNyeXB0ZWRSZXBvcnQSDgoCaWQYASABKAlSAmlkEhQKBXRpdGxlGAIgASgJUgV0aXRsZR'
    'IjCg1zdW1tYXJ5X3Nob3J0GAMgASgJUgxzdW1tYXJ5U2hvcnQSGAoHY29udGVudBgEIAEoCVIH'
    'Y29udGVudBInCg9zZW50aW1lbnRfbGFiZWwYBSABKAlSDnNlbnRpbWVudExhYmVsEh0KCnJpc2'
    'tfbGV2ZWwYBiABKAlSCXJpc2tMZXZlbBI5CgpjcmVhdGVkX2F0GAcgASgLMhouZ29vZ2xlLnBy'
    'b3RvYnVmLlRpbWVzdGFtcFIJY3JlYXRlZEF0');

@$core.Deprecated('Use decryptedSessionSegmentDescriptor instead')
const DecryptedSessionSegment$json = {
  '1': 'DecryptedSessionSegment',
  '2': [
    {'1': 'speaker_tag', '3': 1, '4': 1, '5': 5, '10': 'speakerTag'},
    {'1': 'speaker_label', '3': 2, '4': 1, '5': 9, '10': 'speakerLabel'},
    {'1': 'start_offset_ms', '3': 3, '4': 1, '5': 5, '10': 'startOffsetMs'},
    {'1': 'end_offset_ms', '3': 4, '4': 1, '5': 5, '10': 'endOffsetMs'},
    {'1': 'text', '3': 5, '4': 1, '5': 9, '10': 'text'},
    {'1': 'confidence', '3': 6, '4': 1, '5': 2, '10': 'confidence'},
  ],
};

/// Descriptor for `DecryptedSessionSegment`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List decryptedSessionSegmentDescriptor = $convert.base64Decode(
    'ChdEZWNyeXB0ZWRTZXNzaW9uU2VnbWVudBIfCgtzcGVha2VyX3RhZxgBIAEoBVIKc3BlYWtlcl'
    'RhZxIjCg1zcGVha2VyX2xhYmVsGAIgASgJUgxzcGVha2VyTGFiZWwSJgoPc3RhcnRfb2Zmc2V0'
    'X21zGAMgASgFUg1zdGFydE9mZnNldE1zEiIKDWVuZF9vZmZzZXRfbXMYBCABKAVSC2VuZE9mZn'
    'NldE1zEhIKBHRleHQYBSABKAlSBHRleHQSHgoKY29uZmlkZW5jZRgGIAEoAlIKY29uZmlkZW5j'
    'ZQ==');

@$core.Deprecated('Use decryptedSessionTurnDescriptor instead')
const DecryptedSessionTurn$json = {
  '1': 'DecryptedSessionTurn',
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

/// Descriptor for `DecryptedSessionTurn`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List decryptedSessionTurnDescriptor = $convert.base64Decode(
    'ChREZWNyeXB0ZWRTZXNzaW9uVHVybhIfCgtzcGVha2VyX3RhZxgBIAEoBVIKc3BlYWtlclRhZx'
    'IjCg1zcGVha2VyX2xhYmVsGAIgASgJUgxzcGVha2VyTGFiZWwSJgoPc3RhcnRfb2Zmc2V0X21z'
    'GAMgASgFUg1zdGFydE9mZnNldE1zEiIKDWVuZF9vZmZzZXRfbXMYBCABKAVSC2VuZE9mZnNldE'
    '1zEhIKBHRleHQYBSABKAlSBHRleHQSIwoNc2VnbWVudF9jb3VudBgGIAEoBVIMc2VnbWVudENv'
    'dW50EiUKDmNvbmZpZGVuY2VfYXZnGAcgASgCUg1jb25maWRlbmNlQXZn');

@$core.Deprecated('Use decryptedSessionTranscriptDescriptor instead')
const DecryptedSessionTranscript$json = {
  '1': 'DecryptedSessionTranscript',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {
      '1': 'segments',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.clinical.v1.DecryptedSessionSegment',
      '10': 'segments'
    },
    {
      '1': 'turns',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.clinical.v1.DecryptedSessionTurn',
      '10': 'turns'
    },
  ],
};

/// Descriptor for `DecryptedSessionTranscript`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List decryptedSessionTranscriptDescriptor = $convert.base64Decode(
    'ChpEZWNyeXB0ZWRTZXNzaW9uVHJhbnNjcmlwdBIOCgJpZBgBIAEoCVICaWQSQAoIc2VnbWVudH'
    'MYAiADKAsyJC5jbGluaWNhbC52MS5EZWNyeXB0ZWRTZXNzaW9uU2VnbWVudFIIc2VnbWVudHMS'
    'NwoFdHVybnMYAyADKAsyIS5jbGluaWNhbC52MS5EZWNyeXB0ZWRTZXNzaW9uVHVyblIFdHVybn'
    'M=');

@$core.Deprecated('Use decryptedSessionDescriptor instead')
const DecryptedSession$json = {
  '1': 'DecryptedSession',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'session_date', '3': 3, '4': 1, '5': 9, '10': 'sessionDate'},
    {'1': 'session_number', '3': 4, '4': 1, '5': 5, '10': 'sessionNumber'},
    {'1': 'duration_seconds', '3': 5, '4': 1, '5': 5, '10': 'durationSeconds'},
    {'1': 'status', '3': 6, '4': 1, '5': 9, '10': 'status'},
    {
      '1': 'created_at',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'createdAt'
    },
    {
      '1': 'transcript',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.clinical.v1.DecryptedSessionTranscript',
      '10': 'transcript'
    },
    {
      '1': 'reports',
      '3': 9,
      '4': 3,
      '5': 11,
      '6': '.clinical.v1.DecryptedReport',
      '10': 'reports'
    },
  ],
};

/// Descriptor for `DecryptedSession`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List decryptedSessionDescriptor = $convert.base64Decode(
    'ChBEZWNyeXB0ZWRTZXNzaW9uEg4KAmlkGAEgASgJUgJpZBISCgRuYW1lGAIgASgJUgRuYW1lEi'
    'EKDHNlc3Npb25fZGF0ZRgDIAEoCVILc2Vzc2lvbkRhdGUSJQoOc2Vzc2lvbl9udW1iZXIYBCAB'
    'KAVSDXNlc3Npb25OdW1iZXISKQoQZHVyYXRpb25fc2Vjb25kcxgFIAEoBVIPZHVyYXRpb25TZW'
    'NvbmRzEhYKBnN0YXR1cxgGIAEoCVIGc3RhdHVzEjkKCmNyZWF0ZWRfYXQYByABKAsyGi5nb29n'
    'bGUucHJvdG9idWYuVGltZXN0YW1wUgljcmVhdGVkQXQSRwoKdHJhbnNjcmlwdBgIIAEoCzInLm'
    'NsaW5pY2FsLnYxLkRlY3J5cHRlZFNlc3Npb25UcmFuc2NyaXB0Ugp0cmFuc2NyaXB0EjYKB3Jl'
    'cG9ydHMYCSADKAsyHC5jbGluaWNhbC52MS5EZWNyeXB0ZWRSZXBvcnRSB3JlcG9ydHM=');

@$core.Deprecated('Use decryptedPatientNoteDescriptor instead')
const DecryptedPatientNote$json = {
  '1': 'DecryptedPatientNote',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'kind', '3': 2, '4': 1, '5': 9, '10': 'kind'},
    {'1': 'title', '3': 3, '4': 1, '5': 9, '10': 'title'},
    {'1': 'text', '3': 4, '4': 1, '5': 9, '10': 'text'},
    {
      '1': 'sent_to_patient_at',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'sentToPatientAt'
    },
    {'1': 'sent_to_email', '3': 6, '4': 1, '5': 9, '10': 'sentToEmail'},
    {
      '1': 'created_at',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'createdAt'
    },
  ],
};

/// Descriptor for `DecryptedPatientNote`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List decryptedPatientNoteDescriptor = $convert.base64Decode(
    'ChREZWNyeXB0ZWRQYXRpZW50Tm90ZRIOCgJpZBgBIAEoCVICaWQSEgoEa2luZBgCIAEoCVIEa2'
    'luZBIUCgV0aXRsZRgDIAEoCVIFdGl0bGUSEgoEdGV4dBgEIAEoCVIEdGV4dBJHChJzZW50X3Rv'
    'X3BhdGllbnRfYXQYBSABKAsyGi5nb29nbGUucHJvdG9idWYuVGltZXN0YW1wUg9zZW50VG9QYX'
    'RpZW50QXQSIgoNc2VudF90b19lbWFpbBgGIAEoCVILc2VudFRvRW1haWwSOQoKY3JlYXRlZF9h'
    'dBgHIAEoCzIaLmdvb2dsZS5wcm90b2J1Zi5UaW1lc3RhbXBSCWNyZWF0ZWRBdA==');

@$core.Deprecated('Use exportPatientDataResponseDescriptor instead')
const ExportPatientDataResponse$json = {
  '1': 'ExportPatientDataResponse',
  '2': [
    {
      '1': 'patient_file',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.clinical.v1.PatientFile',
      '10': 'patientFile'
    },
    {
      '1': 'notes',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.clinical.v1.DecryptedPatientNote',
      '10': 'notes'
    },
    {
      '1': 'sessions',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.clinical.v1.DecryptedSession',
      '10': 'sessions'
    },
  ],
};

/// Descriptor for `ExportPatientDataResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List exportPatientDataResponseDescriptor = $convert.base64Decode(
    'ChlFeHBvcnRQYXRpZW50RGF0YVJlc3BvbnNlEjsKDHBhdGllbnRfZmlsZRgBIAEoCzIYLmNsaW'
    '5pY2FsLnYxLlBhdGllbnRGaWxlUgtwYXRpZW50RmlsZRI3CgVub3RlcxgCIAMoCzIhLmNsaW5p'
    'Y2FsLnYxLkRlY3J5cHRlZFBhdGllbnROb3RlUgVub3RlcxI5CghzZXNzaW9ucxgDIAMoCzIdLm'
    'NsaW5pY2FsLnYxLkRlY3J5cHRlZFNlc3Npb25SCHNlc3Npb25z');

@$core.Deprecated('Use deletePatientDataRequestDescriptor instead')
const DeletePatientDataRequest$json = {
  '1': 'DeletePatientDataRequest',
  '2': [
    {'1': 'patient_file_id', '3': 1, '4': 1, '5': 9, '10': 'patientFileId'},
  ],
};

/// Descriptor for `DeletePatientDataRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deletePatientDataRequestDescriptor =
    $convert.base64Decode(
        'ChhEZWxldGVQYXRpZW50RGF0YVJlcXVlc3QSJgoPcGF0aWVudF9maWxlX2lkGAEgASgJUg1wYX'
        'RpZW50RmlsZUlk');

@$core.Deprecated('Use platformFixedCostDescriptor instead')
const PlatformFixedCost$json = {
  '1': 'PlatformFixedCost',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'provider', '3': 3, '4': 1, '5': 9, '10': 'provider'},
    {'1': 'amount_usd', '3': 4, '4': 1, '5': 1, '10': 'amountUsd'},
    {'1': 'billing_period', '3': 5, '4': 1, '5': 9, '10': 'billingPeriod'},
  ],
};

/// Descriptor for `PlatformFixedCost`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List platformFixedCostDescriptor = $convert.base64Decode(
    'ChFQbGF0Zm9ybUZpeGVkQ29zdBIOCgJpZBgBIAEoCVICaWQSEgoEbmFtZRgCIAEoCVIEbmFtZR'
    'IaCghwcm92aWRlchgDIAEoCVIIcHJvdmlkZXISHQoKYW1vdW50X3VzZBgEIAEoAVIJYW1vdW50'
    'VXNkEiUKDmJpbGxpbmdfcGVyaW9kGAUgASgJUg1iaWxsaW5nUGVyaW9k');

@$core.Deprecated('Use getOrgTherapistMetricsRequestDescriptor instead')
const GetOrgTherapistMetricsRequest$json = {
  '1': 'GetOrgTherapistMetricsRequest',
  '2': [
    {'1': 'period_days', '3': 1, '4': 1, '5': 5, '10': 'periodDays'},
  ],
};

/// Descriptor for `GetOrgTherapistMetricsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getOrgTherapistMetricsRequestDescriptor =
    $convert.base64Decode(
        'Ch1HZXRPcmdUaGVyYXBpc3RNZXRyaWNzUmVxdWVzdBIfCgtwZXJpb2RfZGF5cxgBIAEoBVIKcG'
        'VyaW9kRGF5cw==');

@$core.Deprecated('Use therapistMetricsDescriptor instead')
const TherapistMetrics$json = {
  '1': 'TherapistMetrics',
  '2': [
    {'1': 'therapist_id', '3': 1, '4': 1, '5': 9, '10': 'therapistId'},
    {'1': 'first_name', '3': 2, '4': 1, '5': 9, '10': 'firstName'},
    {'1': 'last_name', '3': 3, '4': 1, '5': 9, '10': 'lastName'},
    {'1': 'is_active', '3': 4, '4': 1, '5': 8, '10': 'isActive'},
    {
      '1': 'sessions_completed',
      '3': 5,
      '4': 1,
      '5': 5,
      '10': 'sessionsCompleted'
    },
    {'1': 'sessions_failed', '3': 6, '4': 1, '5': 5, '10': 'sessionsFailed'},
    {
      '1': 'sessions_cancelled',
      '3': 7,
      '4': 1,
      '5': 5,
      '10': 'sessionsCancelled'
    },
    {
      '1': 'total_duration_seconds',
      '3': 8,
      '4': 1,
      '5': 3,
      '10': 'totalDurationSeconds'
    },
    {
      '1': 'avg_duration_seconds',
      '3': 9,
      '4': 1,
      '5': 5,
      '10': 'avgDurationSeconds'
    },
    {
      '1': 'sessions_report_viewed',
      '3': 10,
      '4': 1,
      '5': 5,
      '10': 'sessionsReportViewed'
    },
    {
      '1': 'last_session_date',
      '3': 11,
      '4': 1,
      '5': 9,
      '10': 'lastSessionDate'
    },
    {'1': 'active_patients', '3': 12, '4': 1, '5': 5, '10': 'activePatients'},
    {'1': 'new_patients', '3': 13, '4': 1, '5': 5, '10': 'newPatients'},
    {'1': 'ratings_positive', '3': 14, '4': 1, '5': 5, '10': 'ratingsPositive'},
    {'1': 'ratings_negative', '3': 15, '4': 1, '5': 5, '10': 'ratingsNegative'},
  ],
};

/// Descriptor for `TherapistMetrics`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List therapistMetricsDescriptor = $convert.base64Decode(
    'ChBUaGVyYXBpc3RNZXRyaWNzEiEKDHRoZXJhcGlzdF9pZBgBIAEoCVILdGhlcmFwaXN0SWQSHQ'
    'oKZmlyc3RfbmFtZRgCIAEoCVIJZmlyc3ROYW1lEhsKCWxhc3RfbmFtZRgDIAEoCVIIbGFzdE5h'
    'bWUSGwoJaXNfYWN0aXZlGAQgASgIUghpc0FjdGl2ZRItChJzZXNzaW9uc19jb21wbGV0ZWQYBS'
    'ABKAVSEXNlc3Npb25zQ29tcGxldGVkEicKD3Nlc3Npb25zX2ZhaWxlZBgGIAEoBVIOc2Vzc2lv'
    'bnNGYWlsZWQSLQoSc2Vzc2lvbnNfY2FuY2VsbGVkGAcgASgFUhFzZXNzaW9uc0NhbmNlbGxlZB'
    'I0ChZ0b3RhbF9kdXJhdGlvbl9zZWNvbmRzGAggASgDUhR0b3RhbER1cmF0aW9uU2Vjb25kcxIw'
    'ChRhdmdfZHVyYXRpb25fc2Vjb25kcxgJIAEoBVISYXZnRHVyYXRpb25TZWNvbmRzEjQKFnNlc3'
    'Npb25zX3JlcG9ydF92aWV3ZWQYCiABKAVSFHNlc3Npb25zUmVwb3J0Vmlld2VkEioKEWxhc3Rf'
    'c2Vzc2lvbl9kYXRlGAsgASgJUg9sYXN0U2Vzc2lvbkRhdGUSJwoPYWN0aXZlX3BhdGllbnRzGA'
    'wgASgFUg5hY3RpdmVQYXRpZW50cxIhCgxuZXdfcGF0aWVudHMYDSABKAVSC25ld1BhdGllbnRz'
    'EikKEHJhdGluZ3NfcG9zaXRpdmUYDiABKAVSD3JhdGluZ3NQb3NpdGl2ZRIpChByYXRpbmdzX2'
    '5lZ2F0aXZlGA8gASgFUg9yYXRpbmdzTmVnYXRpdmU=');

@$core.Deprecated('Use orgTherapistMetricsResponseDescriptor instead')
const OrgTherapistMetricsResponse$json = {
  '1': 'OrgTherapistMetricsResponse',
  '2': [
    {
      '1': 'therapists',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.clinical.v1.TherapistMetrics',
      '10': 'therapists'
    },
    {
      '1': 'totals',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.clinical.v1.TherapistMetrics',
      '10': 'totals'
    },
    {'1': 'period_days', '3': 3, '4': 1, '5': 5, '10': 'periodDays'},
  ],
};

/// Descriptor for `OrgTherapistMetricsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List orgTherapistMetricsResponseDescriptor = $convert.base64Decode(
    'ChtPcmdUaGVyYXBpc3RNZXRyaWNzUmVzcG9uc2USPQoKdGhlcmFwaXN0cxgBIAMoCzIdLmNsaW'
    '5pY2FsLnYxLlRoZXJhcGlzdE1ldHJpY3NSCnRoZXJhcGlzdHMSNQoGdG90YWxzGAIgASgLMh0u'
    'Y2xpbmljYWwudjEuVGhlcmFwaXN0TWV0cmljc1IGdG90YWxzEh8KC3BlcmlvZF9kYXlzGAMgAS'
    'gFUgpwZXJpb2REYXlz');
