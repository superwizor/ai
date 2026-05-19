// This is a generated file - do not edit.
//
// Generated from identity/v1/identity.proto.

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

@$core.Deprecated('Use userRoleDescriptor instead')
const UserRole$json = {
  '1': 'UserRole',
  '2': [
    {'1': 'USER_ROLE_UNSPECIFIED', '2': 0},
    {'1': 'USER_ROLE_THERAPIST', '2': 1},
    {'1': 'USER_ROLE_PATIENT', '2': 2},
  ],
};

/// Descriptor for `UserRole`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List userRoleDescriptor = $convert.base64Decode(
    'CghVc2VyUm9sZRIZChVVU0VSX1JPTEVfVU5TUEVDSUZJRUQQABIXChNVU0VSX1JPTEVfVEhFUk'
    'FQSVNUEAESFQoRVVNFUl9ST0xFX1BBVElFTlQQAg==');

@$core.Deprecated('Use userDescriptor instead')
const User$json = {
  '1': 'User',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {
      '1': 'role',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.identity.v1.UserRole',
      '10': 'role'
    },
    {'1': 'organization_id', '3': 3, '4': 1, '5': 9, '10': 'organizationId'},
    {'1': 'firebase_uid', '3': 4, '4': 1, '5': 9, '10': 'firebaseUid'},
    {'1': 'email', '3': 5, '4': 1, '5': 9, '10': 'email'},
    {'1': 'phone_number', '3': 6, '4': 1, '5': 9, '10': 'phoneNumber'},
    {'1': 'is_email_verified', '3': 7, '4': 1, '5': 8, '10': 'isEmailVerified'},
    {'1': 'first_name', '3': 8, '4': 1, '5': 9, '10': 'firstName'},
    {'1': 'last_name', '3': 9, '4': 1, '5': 9, '10': 'lastName'},
    {
      '1': 'professional_title',
      '3': 10,
      '4': 1,
      '5': 9,
      '10': 'professionalTitle'
    },
    {
      '1': 'credentials_number',
      '3': 11,
      '4': 1,
      '5': 9,
      '10': 'credentialsNumber'
    },
    {'1': 'ui_language', '3': 12, '4': 1, '5': 9, '10': 'uiLanguage'},
    {'1': 'timezone', '3': 13, '4': 1, '5': 9, '10': 'timezone'},
    {'1': 'has_accepted_tos', '3': 14, '4': 1, '5': 8, '10': 'hasAcceptedTos'},
    {
      '1': 'created_at',
      '3': 15,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'createdAt'
    },
    {'1': 'biography', '3': 16, '4': 1, '5': 9, '10': 'biography'},
    {'1': 'avatar_url', '3': 17, '4': 1, '5': 9, '10': 'avatarUrl'},
    {
      '1': 'default_modality_id',
      '3': 18,
      '4': 1,
      '5': 9,
      '10': 'defaultModalityId'
    },
    {
      '1': 'billing_address_id',
      '3': 19,
      '4': 1,
      '5': 9,
      '10': 'billingAddressId'
    },
    {
      '1': 'has_marketing_consent',
      '3': 20,
      '4': 1,
      '5': 8,
      '10': 'hasMarketingConsent'
    },
  ],
};

/// Descriptor for `User`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List userDescriptor = $convert.base64Decode(
    'CgRVc2VyEg4KAmlkGAEgASgJUgJpZBIpCgRyb2xlGAIgASgOMhUuaWRlbnRpdHkudjEuVXNlcl'
    'JvbGVSBHJvbGUSJwoPb3JnYW5pemF0aW9uX2lkGAMgASgJUg5vcmdhbml6YXRpb25JZBIhCgxm'
    'aXJlYmFzZV91aWQYBCABKAlSC2ZpcmViYXNlVWlkEhQKBWVtYWlsGAUgASgJUgVlbWFpbBIhCg'
    'xwaG9uZV9udW1iZXIYBiABKAlSC3Bob25lTnVtYmVyEioKEWlzX2VtYWlsX3ZlcmlmaWVkGAcg'
    'ASgIUg9pc0VtYWlsVmVyaWZpZWQSHQoKZmlyc3RfbmFtZRgIIAEoCVIJZmlyc3ROYW1lEhsKCW'
    'xhc3RfbmFtZRgJIAEoCVIIbGFzdE5hbWUSLQoScHJvZmVzc2lvbmFsX3RpdGxlGAogASgJUhFw'
    'cm9mZXNzaW9uYWxUaXRsZRItChJjcmVkZW50aWFsc19udW1iZXIYCyABKAlSEWNyZWRlbnRpYW'
    'xzTnVtYmVyEh8KC3VpX2xhbmd1YWdlGAwgASgJUgp1aUxhbmd1YWdlEhoKCHRpbWV6b25lGA0g'
    'ASgJUgh0aW1lem9uZRIoChBoYXNfYWNjZXB0ZWRfdG9zGA4gASgIUg5oYXNBY2NlcHRlZFRvcx'
    'I5CgpjcmVhdGVkX2F0GA8gASgLMhouZ29vZ2xlLnByb3RvYnVmLlRpbWVzdGFtcFIJY3JlYXRl'
    'ZEF0EhwKCWJpb2dyYXBoeRgQIAEoCVIJYmlvZ3JhcGh5Eh0KCmF2YXRhcl91cmwYESABKAlSCW'
    'F2YXRhclVybBIuChNkZWZhdWx0X21vZGFsaXR5X2lkGBIgASgJUhFkZWZhdWx0TW9kYWxpdHlJ'
    'ZBIsChJiaWxsaW5nX2FkZHJlc3NfaWQYEyABKAlSEGJpbGxpbmdBZGRyZXNzSWQSMgoVaGFzX2'
    '1hcmtldGluZ19jb25zZW50GBQgASgIUhNoYXNNYXJrZXRpbmdDb25zZW50');

@$core.Deprecated('Use userContextDescriptor instead')
const UserContext$json = {
  '1': 'UserContext',
  '2': [
    {'1': 'user_id', '3': 1, '4': 1, '5': 9, '10': 'userId'},
    {'1': 'firebase_uid', '3': 2, '4': 1, '5': 9, '10': 'firebaseUid'},
    {
      '1': 'role',
      '3': 3,
      '4': 1,
      '5': 14,
      '6': '.identity.v1.UserRole',
      '10': 'role'
    },
    {'1': 'organization_id', '3': 4, '4': 1, '5': 9, '10': 'organizationId'},
    {'1': 'email', '3': 5, '4': 1, '5': 9, '10': 'email'},
  ],
};

/// Descriptor for `UserContext`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List userContextDescriptor = $convert.base64Decode(
    'CgtVc2VyQ29udGV4dBIXCgd1c2VyX2lkGAEgASgJUgZ1c2VySWQSIQoMZmlyZWJhc2VfdWlkGA'
    'IgASgJUgtmaXJlYmFzZVVpZBIpCgRyb2xlGAMgASgOMhUuaWRlbnRpdHkudjEuVXNlclJvbGVS'
    'BHJvbGUSJwoPb3JnYW5pemF0aW9uX2lkGAQgASgJUg5vcmdhbml6YXRpb25JZBIUCgVlbWFpbB'
    'gFIAEoCVIFZW1haWw=');

@$core.Deprecated('Use validateTokenRequestDescriptor instead')
const ValidateTokenRequest$json = {
  '1': 'ValidateTokenRequest',
  '2': [
    {'1': 'firebase_id_token', '3': 1, '4': 1, '5': 9, '10': 'firebaseIdToken'},
  ],
};

/// Descriptor for `ValidateTokenRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List validateTokenRequestDescriptor = $convert.base64Decode(
    'ChRWYWxpZGF0ZVRva2VuUmVxdWVzdBIqChFmaXJlYmFzZV9pZF90b2tlbhgBIAEoCVIPZmlyZW'
    'Jhc2VJZFRva2Vu');

@$core.Deprecated('Use getUserRequestDescriptor instead')
const GetUserRequest$json = {
  '1': 'GetUserRequest',
  '2': [
    {'1': 'user_id', '3': 1, '4': 1, '5': 9, '10': 'userId'},
  ],
};

/// Descriptor for `GetUserRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getUserRequestDescriptor = $convert
    .base64Decode('Cg5HZXRVc2VyUmVxdWVzdBIXCgd1c2VyX2lkGAEgASgJUgZ1c2VySWQ=');

@$core.Deprecated('Use getUserByFirebaseUIDRequestDescriptor instead')
const GetUserByFirebaseUIDRequest$json = {
  '1': 'GetUserByFirebaseUIDRequest',
  '2': [
    {'1': 'firebase_uid', '3': 1, '4': 1, '5': 9, '10': 'firebaseUid'},
  ],
};

/// Descriptor for `GetUserByFirebaseUIDRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getUserByFirebaseUIDRequestDescriptor =
    $convert.base64Decode(
        'ChtHZXRVc2VyQnlGaXJlYmFzZVVJRFJlcXVlc3QSIQoMZmlyZWJhc2VfdWlkGAEgASgJUgtmaX'
        'JlYmFzZVVpZA==');

@$core.Deprecated('Use createUserRequestDescriptor instead')
const CreateUserRequest$json = {
  '1': 'CreateUserRequest',
  '2': [
    {'1': 'firebase_uid', '3': 1, '4': 1, '5': 9, '10': 'firebaseUid'},
    {'1': 'email', '3': 2, '4': 1, '5': 9, '10': 'email'},
    {
      '1': 'role',
      '3': 3,
      '4': 1,
      '5': 14,
      '6': '.identity.v1.UserRole',
      '10': 'role'
    },
    {'1': 'first_name', '3': 4, '4': 1, '5': 9, '10': 'firstName'},
    {'1': 'last_name', '3': 5, '4': 1, '5': 9, '10': 'lastName'},
    {'1': 'ui_language', '3': 6, '4': 1, '5': 9, '10': 'uiLanguage'},
    {'1': 'timezone', '3': 7, '4': 1, '5': 9, '10': 'timezone'},
    {'1': 'has_accepted_tos', '3': 8, '4': 1, '5': 8, '10': 'hasAcceptedTos'},
  ],
};

/// Descriptor for `CreateUserRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createUserRequestDescriptor = $convert.base64Decode(
    'ChFDcmVhdGVVc2VyUmVxdWVzdBIhCgxmaXJlYmFzZV91aWQYASABKAlSC2ZpcmViYXNlVWlkEh'
    'QKBWVtYWlsGAIgASgJUgVlbWFpbBIpCgRyb2xlGAMgASgOMhUuaWRlbnRpdHkudjEuVXNlclJv'
    'bGVSBHJvbGUSHQoKZmlyc3RfbmFtZRgEIAEoCVIJZmlyc3ROYW1lEhsKCWxhc3RfbmFtZRgFIA'
    'EoCVIIbGFzdE5hbWUSHwoLdWlfbGFuZ3VhZ2UYBiABKAlSCnVpTGFuZ3VhZ2USGgoIdGltZXpv'
    'bmUYByABKAlSCHRpbWV6b25lEigKEGhhc19hY2NlcHRlZF90b3MYCCABKAhSDmhhc0FjY2VwdG'
    'VkVG9z');

@$core.Deprecated('Use updateProfileRequestDescriptor instead')
const UpdateProfileRequest$json = {
  '1': 'UpdateProfileRequest',
  '2': [
    {'1': 'user_id', '3': 1, '4': 1, '5': 9, '10': 'userId'},
    {'1': 'first_name', '3': 2, '4': 1, '5': 9, '10': 'firstName'},
    {'1': 'last_name', '3': 3, '4': 1, '5': 9, '10': 'lastName'},
    {
      '1': 'professional_title',
      '3': 4,
      '4': 1,
      '5': 9,
      '10': 'professionalTitle'
    },
    {
      '1': 'credentials_number',
      '3': 5,
      '4': 1,
      '5': 9,
      '10': 'credentialsNumber'
    },
    {'1': 'biography', '3': 6, '4': 1, '5': 9, '10': 'biography'},
    {'1': 'phone_number', '3': 7, '4': 1, '5': 9, '10': 'phoneNumber'},
  ],
};

/// Descriptor for `UpdateProfileRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateProfileRequestDescriptor = $convert.base64Decode(
    'ChRVcGRhdGVQcm9maWxlUmVxdWVzdBIXCgd1c2VyX2lkGAEgASgJUgZ1c2VySWQSHQoKZmlyc3'
    'RfbmFtZRgCIAEoCVIJZmlyc3ROYW1lEhsKCWxhc3RfbmFtZRgDIAEoCVIIbGFzdE5hbWUSLQoS'
    'cHJvZmVzc2lvbmFsX3RpdGxlGAQgASgJUhFwcm9mZXNzaW9uYWxUaXRsZRItChJjcmVkZW50aW'
    'Fsc19udW1iZXIYBSABKAlSEWNyZWRlbnRpYWxzTnVtYmVyEhwKCWJpb2dyYXBoeRgGIAEoCVIJ'
    'YmlvZ3JhcGh5EiEKDHBob25lX251bWJlchgHIAEoCVILcGhvbmVOdW1iZXI=');

@$core.Deprecated('Use checkPermissionRequestDescriptor instead')
const CheckPermissionRequest$json = {
  '1': 'CheckPermissionRequest',
  '2': [
    {'1': 'user_id', '3': 1, '4': 1, '5': 9, '10': 'userId'},
    {'1': 'resource_type', '3': 2, '4': 1, '5': 9, '10': 'resourceType'},
    {'1': 'resource_id', '3': 3, '4': 1, '5': 9, '10': 'resourceId'},
    {'1': 'action', '3': 4, '4': 1, '5': 9, '10': 'action'},
  ],
};

/// Descriptor for `CheckPermissionRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List checkPermissionRequestDescriptor = $convert.base64Decode(
    'ChZDaGVja1Blcm1pc3Npb25SZXF1ZXN0EhcKB3VzZXJfaWQYASABKAlSBnVzZXJJZBIjCg1yZX'
    'NvdXJjZV90eXBlGAIgASgJUgxyZXNvdXJjZVR5cGUSHwoLcmVzb3VyY2VfaWQYAyABKAlSCnJl'
    'c291cmNlSWQSFgoGYWN0aW9uGAQgASgJUgZhY3Rpb24=');

@$core.Deprecated('Use permissionDecisionDescriptor instead')
const PermissionDecision$json = {
  '1': 'PermissionDecision',
  '2': [
    {'1': 'allowed', '3': 1, '4': 1, '5': 8, '10': 'allowed'},
    {'1': 'reason', '3': 2, '4': 1, '5': 9, '10': 'reason'},
  ],
};

/// Descriptor for `PermissionDecision`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List permissionDecisionDescriptor = $convert.base64Decode(
    'ChJQZXJtaXNzaW9uRGVjaXNpb24SGAoHYWxsb3dlZBgBIAEoCFIHYWxsb3dlZBIWCgZyZWFzb2'
    '4YAiABKAlSBnJlYXNvbg==');

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

@$core.Deprecated('Use reportPreferencesDescriptor instead')
const ReportPreferences$json = {
  '1': 'ReportPreferences',
  '2': [
    {'1': 'version', '3': 1, '4': 1, '5': 5, '10': 'version'},
    {'1': 'length', '3': 2, '4': 1, '5': 9, '10': 'length'},
    {'1': 'tone', '3': 3, '4': 1, '5': 9, '10': 'tone'},
    {'1': 'quote_density', '3': 4, '4': 1, '5': 9, '10': 'quoteDensity'},
    {
      '1': 'diagnostic_language',
      '3': 5,
      '4': 1,
      '5': 9,
      '10': 'diagnosticLanguage'
    },
    {
      '1': 'hypothesis_hedging',
      '3': 6,
      '4': 1,
      '5': 9,
      '10': 'hypothesisHedging'
    },
    {'1': 'section_emphasis', '3': 7, '4': 3, '5': 9, '10': 'sectionEmphasis'},
    {
      '1': 'strengths_framing',
      '3': 8,
      '4': 1,
      '5': 9,
      '10': 'strengthsFraming'
    },
    {'1': 'free_text', '3': 9, '4': 1, '5': 9, '10': 'freeText'},
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

/// Descriptor for `ReportPreferences`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List reportPreferencesDescriptor = $convert.base64Decode(
    'ChFSZXBvcnRQcmVmZXJlbmNlcxIYCgd2ZXJzaW9uGAEgASgFUgd2ZXJzaW9uEhYKBmxlbmd0aB'
    'gCIAEoCVIGbGVuZ3RoEhIKBHRvbmUYAyABKAlSBHRvbmUSIwoNcXVvdGVfZGVuc2l0eRgEIAEo'
    'CVIMcXVvdGVEZW5zaXR5Ei8KE2RpYWdub3N0aWNfbGFuZ3VhZ2UYBSABKAlSEmRpYWdub3N0aW'
    'NMYW5ndWFnZRItChJoeXBvdGhlc2lzX2hlZGdpbmcYBiABKAlSEWh5cG90aGVzaXNIZWRnaW5n'
    'EikKEHNlY3Rpb25fZW1waGFzaXMYByADKAlSD3NlY3Rpb25FbXBoYXNpcxIrChFzdHJlbmd0aH'
    'NfZnJhbWluZxgIIAEoCVIQc3RyZW5ndGhzRnJhbWluZxIbCglmcmVlX3RleHQYCSABKAlSCGZy'
    'ZWVUZXh0EjkKCnVwZGF0ZWRfYXQYCiABKAsyGi5nb29nbGUucHJvdG9idWYuVGltZXN0YW1wUg'
    'l1cGRhdGVkQXQ=');

@$core.Deprecated('Use getReportPreferencesRequestDescriptor instead')
const GetReportPreferencesRequest$json = {
  '1': 'GetReportPreferencesRequest',
  '2': [
    {'1': 'therapist_id', '3': 1, '4': 1, '5': 9, '10': 'therapistId'},
  ],
};

/// Descriptor for `GetReportPreferencesRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getReportPreferencesRequestDescriptor =
    $convert.base64Decode(
        'ChtHZXRSZXBvcnRQcmVmZXJlbmNlc1JlcXVlc3QSIQoMdGhlcmFwaXN0X2lkGAEgASgJUgt0aG'
        'VyYXBpc3RJZA==');

@$core.Deprecated('Use updateReportPreferencesRequestDescriptor instead')
const UpdateReportPreferencesRequest$json = {
  '1': 'UpdateReportPreferencesRequest',
  '2': [
    {'1': 'therapist_id', '3': 1, '4': 1, '5': 9, '10': 'therapistId'},
    {
      '1': 'preferences',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.identity.v1.ReportPreferences',
      '10': 'preferences'
    },
    {'1': 'idempotency_key', '3': 3, '4': 1, '5': 9, '10': 'idempotencyKey'},
  ],
};

/// Descriptor for `UpdateReportPreferencesRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateReportPreferencesRequestDescriptor =
    $convert.base64Decode(
        'Ch5VcGRhdGVSZXBvcnRQcmVmZXJlbmNlc1JlcXVlc3QSIQoMdGhlcmFwaXN0X2lkGAEgASgJUg'
        't0aGVyYXBpc3RJZBJACgtwcmVmZXJlbmNlcxgCIAEoCzIeLmlkZW50aXR5LnYxLlJlcG9ydFBy'
        'ZWZlcmVuY2VzUgtwcmVmZXJlbmNlcxInCg9pZGVtcG90ZW5jeV9rZXkYAyABKAlSDmlkZW1wb3'
        'RlbmN5S2V5');
