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
    {'1': 'USER_ROLE_ORG_ADMIN', '2': 3},
    {'1': 'USER_ROLE_SUPERWIZOR_ADMIN', '2': 4},
  ],
};

/// Descriptor for `UserRole`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List userRoleDescriptor = $convert.base64Decode(
    'CghVc2VyUm9sZRIZChVVU0VSX1JPTEVfVU5TUEVDSUZJRUQQABIXChNVU0VSX1JPTEVfVEhFUk'
    'FQSVNUEAESFQoRVVNFUl9ST0xFX1BBVElFTlQQAhIXChNVU0VSX1JPTEVfT1JHX0FETUlOEAMS'
    'HgoaVVNFUl9ST0xFX1NVUEVSV0laT1JfQURNSU4QBA==');

@$core.Deprecated('Use organizationTypeDescriptor instead')
const OrganizationType$json = {
  '1': 'OrganizationType',
  '2': [
    {'1': 'ORGANIZATION_TYPE_UNSPECIFIED', '2': 0},
    {'1': 'ORGANIZATION_TYPE_SOLO', '2': 1},
    {'1': 'ORGANIZATION_TYPE_CLINIC', '2': 2},
    {'1': 'ORGANIZATION_TYPE_ENTERPRISE', '2': 3},
  ],
};

/// Descriptor for `OrganizationType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List organizationTypeDescriptor = $convert.base64Decode(
    'ChBPcmdhbml6YXRpb25UeXBlEiEKHU9SR0FOSVpBVElPTl9UWVBFX1VOU1BFQ0lGSUVEEAASGg'
    'oWT1JHQU5JWkFUSU9OX1RZUEVfU09MTxABEhwKGE9SR0FOSVpBVElPTl9UWVBFX0NMSU5JQxAC'
    'EiAKHE9SR0FOSVpBVElPTl9UWVBFX0VOVEVSUFJJU0UQAw==');

@$core.Deprecated('Use appLoginTokenDescriptor instead')
const AppLoginToken$json = {
  '1': 'AppLoginToken',
  '2': [
    {'1': 'token', '3': 1, '4': 1, '5': 9, '10': 'token'},
  ],
};

/// Descriptor for `AppLoginToken`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List appLoginTokenDescriptor = $convert
    .base64Decode('Cg1BcHBMb2dpblRva2VuEhQKBXRva2VuGAEgASgJUgV0b2tlbg==');

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
    {'1': 'is_active', '3': 21, '4': 1, '5': 8, '10': 'isActive'},
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
    '1hcmtldGluZ19jb25zZW50GBQgASgIUhNoYXNNYXJrZXRpbmdDb25zZW50EhsKCWlzX2FjdGl2'
    'ZRgVIAEoCFIIaXNBY3RpdmU=');

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
    {'1': 'initial_plan_tier', '3': 9, '4': 1, '5': 9, '10': 'initialPlanTier'},
  ],
};

/// Descriptor for `CreateUserRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createUserRequestDescriptor = $convert.base64Decode(
    'ChFDcmVhdGVVc2VyUmVxdWVzdBIhCgxmaXJlYmFzZV91aWQYASABKAlSC2ZpcmViYXNlVWlkEh'
    'QKBWVtYWlsGAIgASgJUgVlbWFpbBIpCgRyb2xlGAMgASgOMhUuaWRlbnRpdHkudjEuVXNlclJv'
    'bGVSBHJvbGUSHQoKZmlyc3RfbmFtZRgEIAEoCVIJZmlyc3ROYW1lEhsKCWxhc3RfbmFtZRgFIA'
    'EoCVIIbGFzdE5hbWUSHwoLdWlfbGFuZ3VhZ2UYBiABKAlSCnVpTGFuZ3VhZ2USGgoIdGltZXpv'
    'bmUYByABKAlSCHRpbWV6b25lEigKEGhhc19hY2NlcHRlZF90b3MYCCABKAhSDmhhc0FjY2VwdG'
    'VkVG9zEioKEWluaXRpYWxfcGxhbl90aWVyGAkgASgJUg9pbml0aWFsUGxhblRpZXI=');

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
    {
      '1': 'avatar_url',
      '3': 8,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'avatarUrl',
      '17': true
    },
    {
      '1': 'default_modality_id',
      '3': 9,
      '4': 1,
      '5': 9,
      '9': 1,
      '10': 'defaultModalityId',
      '17': true
    },
    {
      '1': 'ui_language',
      '3': 10,
      '4': 1,
      '5': 9,
      '9': 2,
      '10': 'uiLanguage',
      '17': true
    },
    {
      '1': 'timezone',
      '3': 11,
      '4': 1,
      '5': 9,
      '9': 3,
      '10': 'timezone',
      '17': true
    },
    {
      '1': 'billing_address',
      '3': 12,
      '4': 1,
      '5': 11,
      '6': '.identity.v1.Address',
      '9': 4,
      '10': 'billingAddress',
      '17': true
    },
    {
      '1': 'has_marketing_consent',
      '3': 13,
      '4': 1,
      '5': 8,
      '9': 5,
      '10': 'hasMarketingConsent',
      '17': true
    },
  ],
  '8': [
    {'1': '_avatar_url'},
    {'1': '_default_modality_id'},
    {'1': '_ui_language'},
    {'1': '_timezone'},
    {'1': '_billing_address'},
    {'1': '_has_marketing_consent'},
  ],
};

/// Descriptor for `UpdateProfileRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateProfileRequestDescriptor = $convert.base64Decode(
    'ChRVcGRhdGVQcm9maWxlUmVxdWVzdBIXCgd1c2VyX2lkGAEgASgJUgZ1c2VySWQSHQoKZmlyc3'
    'RfbmFtZRgCIAEoCVIJZmlyc3ROYW1lEhsKCWxhc3RfbmFtZRgDIAEoCVIIbGFzdE5hbWUSLQoS'
    'cHJvZmVzc2lvbmFsX3RpdGxlGAQgASgJUhFwcm9mZXNzaW9uYWxUaXRsZRItChJjcmVkZW50aW'
    'Fsc19udW1iZXIYBSABKAlSEWNyZWRlbnRpYWxzTnVtYmVyEhwKCWJpb2dyYXBoeRgGIAEoCVIJ'
    'YmlvZ3JhcGh5EiEKDHBob25lX251bWJlchgHIAEoCVILcGhvbmVOdW1iZXISIgoKYXZhdGFyX3'
    'VybBgIIAEoCUgAUglhdmF0YXJVcmyIAQESMwoTZGVmYXVsdF9tb2RhbGl0eV9pZBgJIAEoCUgB'
    'UhFkZWZhdWx0TW9kYWxpdHlJZIgBARIkCgt1aV9sYW5ndWFnZRgKIAEoCUgCUgp1aUxhbmd1YW'
    'dliAEBEh8KCHRpbWV6b25lGAsgASgJSANSCHRpbWV6b25liAEBEkIKD2JpbGxpbmdfYWRkcmVz'
    'cxgMIAEoCzIULmlkZW50aXR5LnYxLkFkZHJlc3NIBFIOYmlsbGluZ0FkZHJlc3OIAQESNwoVaG'
    'FzX21hcmtldGluZ19jb25zZW50GA0gASgISAVSE2hhc01hcmtldGluZ0NvbnNlbnSIAQFCDQoL'
    'X2F2YXRhcl91cmxCFgoUX2RlZmF1bHRfbW9kYWxpdHlfaWRCDgoMX3VpX2xhbmd1YWdlQgsKCV'
    '90aW1lem9uZUISChBfYmlsbGluZ19hZGRyZXNzQhgKFl9oYXNfbWFya2V0aW5nX2NvbnNlbnQ=');

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

@$core.Deprecated('Use addressDescriptor instead')
const Address$json = {
  '1': 'Address',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'country_code', '3': 2, '4': 1, '5': 9, '10': 'countryCode'},
    {'1': 'region', '3': 3, '4': 1, '5': 9, '10': 'region'},
    {'1': 'city', '3': 4, '4': 1, '5': 9, '10': 'city'},
    {'1': 'postal_code', '3': 5, '4': 1, '5': 9, '10': 'postalCode'},
    {'1': 'street_line', '3': 6, '4': 1, '5': 9, '10': 'streetLine'},
    {'1': 'building_number', '3': 7, '4': 1, '5': 9, '10': 'buildingNumber'},
    {'1': 'unit_number', '3': 8, '4': 1, '5': 9, '10': 'unitNumber'},
    {'1': 'directions', '3': 9, '4': 1, '5': 9, '10': 'directions'},
  ],
};

/// Descriptor for `Address`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List addressDescriptor = $convert.base64Decode(
    'CgdBZGRyZXNzEg4KAmlkGAEgASgJUgJpZBIhCgxjb3VudHJ5X2NvZGUYAiABKAlSC2NvdW50cn'
    'lDb2RlEhYKBnJlZ2lvbhgDIAEoCVIGcmVnaW9uEhIKBGNpdHkYBCABKAlSBGNpdHkSHwoLcG9z'
    'dGFsX2NvZGUYBSABKAlSCnBvc3RhbENvZGUSHwoLc3RyZWV0X2xpbmUYBiABKAlSCnN0cmVldE'
    'xpbmUSJwoPYnVpbGRpbmdfbnVtYmVyGAcgASgJUg5idWlsZGluZ051bWJlchIfCgt1bml0X251'
    'bWJlchgIIAEoCVIKdW5pdE51bWJlchIeCgpkaXJlY3Rpb25zGAkgASgJUgpkaXJlY3Rpb25z');

@$core.Deprecated('Use organizationDescriptor instead')
const Organization$json = {
  '1': 'Organization',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'legal_name', '3': 2, '4': 1, '5': 9, '10': 'legalName'},
    {'1': 'tax_id', '3': 3, '4': 1, '5': 9, '10': 'taxId'},
    {'1': 'vat_id_eu', '3': 4, '4': 1, '5': 9, '10': 'vatIdEu'},
    {
      '1': 'type',
      '3': 5,
      '4': 1,
      '5': 14,
      '6': '.identity.v1.OrganizationType',
      '10': 'type'
    },
    {
      '1': 'headquarters_address',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.identity.v1.Address',
      '10': 'headquartersAddress'
    },
    {
      '1': 'primary_admin_user_id',
      '3': 7,
      '4': 1,
      '5': 9,
      '10': 'primaryAdminUserId'
    },
    {
      '1': 'created_at',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'createdAt'
    },
    {'1': 'is_blocked', '3': 9, '4': 1, '5': 8, '10': 'isBlocked'},
  ],
};

/// Descriptor for `Organization`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List organizationDescriptor = $convert.base64Decode(
    'CgxPcmdhbml6YXRpb24SDgoCaWQYASABKAlSAmlkEh0KCmxlZ2FsX25hbWUYAiABKAlSCWxlZ2'
    'FsTmFtZRIVCgZ0YXhfaWQYAyABKAlSBXRheElkEhoKCXZhdF9pZF9ldRgEIAEoCVIHdmF0SWRF'
    'dRIxCgR0eXBlGAUgASgOMh0uaWRlbnRpdHkudjEuT3JnYW5pemF0aW9uVHlwZVIEdHlwZRJHCh'
    'RoZWFkcXVhcnRlcnNfYWRkcmVzcxgGIAEoCzIULmlkZW50aXR5LnYxLkFkZHJlc3NSE2hlYWRx'
    'dWFydGVyc0FkZHJlc3MSMQoVcHJpbWFyeV9hZG1pbl91c2VyX2lkGAcgASgJUhJwcmltYXJ5QW'
    'RtaW5Vc2VySWQSOQoKY3JlYXRlZF9hdBgIIAEoCzIaLmdvb2dsZS5wcm90b2J1Zi5UaW1lc3Rh'
    'bXBSCWNyZWF0ZWRBdBIdCgppc19ibG9ja2VkGAkgASgIUglpc0Jsb2NrZWQ=');

@$core.Deprecated('Use registerOrganizationRequestDescriptor instead')
const RegisterOrganizationRequest$json = {
  '1': 'RegisterOrganizationRequest',
  '2': [
    {'1': 'firebase_uid', '3': 1, '4': 1, '5': 9, '10': 'firebaseUid'},
    {'1': 'email', '3': 2, '4': 1, '5': 9, '10': 'email'},
    {'1': 'first_name', '3': 3, '4': 1, '5': 9, '10': 'firstName'},
    {'1': 'last_name', '3': 4, '4': 1, '5': 9, '10': 'lastName'},
    {'1': 'phone_number', '3': 5, '4': 1, '5': 9, '10': 'phoneNumber'},
    {'1': 'ui_language', '3': 6, '4': 1, '5': 9, '10': 'uiLanguage'},
    {'1': 'timezone', '3': 7, '4': 1, '5': 9, '10': 'timezone'},
    {'1': 'has_accepted_tos', '3': 8, '4': 1, '5': 8, '10': 'hasAcceptedTos'},
    {
      '1': 'has_marketing_consent',
      '3': 9,
      '4': 1,
      '5': 8,
      '10': 'hasMarketingConsent'
    },
    {'1': 'legal_name', '3': 10, '4': 1, '5': 9, '10': 'legalName'},
    {
      '1': 'type',
      '3': 11,
      '4': 1,
      '5': 14,
      '6': '.identity.v1.OrganizationType',
      '10': 'type'
    },
    {'1': 'tax_id', '3': 12, '4': 1, '5': 9, '10': 'taxId'},
    {'1': 'vat_id_eu', '3': 13, '4': 1, '5': 9, '10': 'vatIdEu'},
    {
      '1': 'headquarters_address',
      '3': 14,
      '4': 1,
      '5': 11,
      '6': '.identity.v1.Address',
      '10': 'headquartersAddress'
    },
    {'1': 'idempotency_key', '3': 15, '4': 1, '5': 9, '10': 'idempotencyKey'},
  ],
};

/// Descriptor for `RegisterOrganizationRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List registerOrganizationRequestDescriptor = $convert.base64Decode(
    'ChtSZWdpc3Rlck9yZ2FuaXphdGlvblJlcXVlc3QSIQoMZmlyZWJhc2VfdWlkGAEgASgJUgtmaX'
    'JlYmFzZVVpZBIUCgVlbWFpbBgCIAEoCVIFZW1haWwSHQoKZmlyc3RfbmFtZRgDIAEoCVIJZmly'
    'c3ROYW1lEhsKCWxhc3RfbmFtZRgEIAEoCVIIbGFzdE5hbWUSIQoMcGhvbmVfbnVtYmVyGAUgAS'
    'gJUgtwaG9uZU51bWJlchIfCgt1aV9sYW5ndWFnZRgGIAEoCVIKdWlMYW5ndWFnZRIaCgh0aW1l'
    'em9uZRgHIAEoCVIIdGltZXpvbmUSKAoQaGFzX2FjY2VwdGVkX3RvcxgIIAEoCFIOaGFzQWNjZX'
    'B0ZWRUb3MSMgoVaGFzX21hcmtldGluZ19jb25zZW50GAkgASgIUhNoYXNNYXJrZXRpbmdDb25z'
    'ZW50Eh0KCmxlZ2FsX25hbWUYCiABKAlSCWxlZ2FsTmFtZRIxCgR0eXBlGAsgASgOMh0uaWRlbn'
    'RpdHkudjEuT3JnYW5pemF0aW9uVHlwZVIEdHlwZRIVCgZ0YXhfaWQYDCABKAlSBXRheElkEhoK'
    'CXZhdF9pZF9ldRgNIAEoCVIHdmF0SWRFdRJHChRoZWFkcXVhcnRlcnNfYWRkcmVzcxgOIAEoCz'
    'IULmlkZW50aXR5LnYxLkFkZHJlc3NSE2hlYWRxdWFydGVyc0FkZHJlc3MSJwoPaWRlbXBvdGVu'
    'Y3lfa2V5GA8gASgJUg5pZGVtcG90ZW5jeUtleQ==');

@$core.Deprecated('Use registerOrganizationResponseDescriptor instead')
const RegisterOrganizationResponse$json = {
  '1': 'RegisterOrganizationResponse',
  '2': [
    {
      '1': 'user',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.identity.v1.User',
      '10': 'user'
    },
    {
      '1': 'organization',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.identity.v1.Organization',
      '10': 'organization'
    },
  ],
};

/// Descriptor for `RegisterOrganizationResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List registerOrganizationResponseDescriptor =
    $convert.base64Decode(
        'ChxSZWdpc3Rlck9yZ2FuaXphdGlvblJlc3BvbnNlEiUKBHVzZXIYASABKAsyES5pZGVudGl0eS'
        '52MS5Vc2VyUgR1c2VyEj0KDG9yZ2FuaXphdGlvbhgCIAEoCzIZLmlkZW50aXR5LnYxLk9yZ2Fu'
        'aXphdGlvblIMb3JnYW5pemF0aW9u');

@$core.Deprecated('Use updateMyOrganizationRequestDescriptor instead')
const UpdateMyOrganizationRequest$json = {
  '1': 'UpdateMyOrganizationRequest',
  '2': [
    {
      '1': 'legal_name',
      '3': 1,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'legalName',
      '17': true
    },
    {
      '1': 'type',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.identity.v1.OrganizationType',
      '9': 1,
      '10': 'type',
      '17': true
    },
    {'1': 'tax_id', '3': 3, '4': 1, '5': 9, '9': 2, '10': 'taxId', '17': true},
    {
      '1': 'vat_id_eu',
      '3': 4,
      '4': 1,
      '5': 9,
      '9': 3,
      '10': 'vatIdEu',
      '17': true
    },
    {
      '1': 'headquarters_address',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.identity.v1.Address',
      '9': 4,
      '10': 'headquartersAddress',
      '17': true
    },
    {
      '1': 'primary_admin_user_id',
      '3': 6,
      '4': 1,
      '5': 9,
      '9': 5,
      '10': 'primaryAdminUserId',
      '17': true
    },
  ],
  '8': [
    {'1': '_legal_name'},
    {'1': '_type'},
    {'1': '_tax_id'},
    {'1': '_vat_id_eu'},
    {'1': '_headquarters_address'},
    {'1': '_primary_admin_user_id'},
  ],
};

/// Descriptor for `UpdateMyOrganizationRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateMyOrganizationRequestDescriptor = $convert.base64Decode(
    'ChtVcGRhdGVNeU9yZ2FuaXphdGlvblJlcXVlc3QSIgoKbGVnYWxfbmFtZRgBIAEoCUgAUglsZW'
    'dhbE5hbWWIAQESNgoEdHlwZRgCIAEoDjIdLmlkZW50aXR5LnYxLk9yZ2FuaXphdGlvblR5cGVI'
    'AVIEdHlwZYgBARIaCgZ0YXhfaWQYAyABKAlIAlIFdGF4SWSIAQESHwoJdmF0X2lkX2V1GAQgAS'
    'gJSANSB3ZhdElkRXWIAQESTAoUaGVhZHF1YXJ0ZXJzX2FkZHJlc3MYBSABKAsyFC5pZGVudGl0'
    'eS52MS5BZGRyZXNzSARSE2hlYWRxdWFydGVyc0FkZHJlc3OIAQESNgoVcHJpbWFyeV9hZG1pbl'
    '91c2VyX2lkGAYgASgJSAVSEnByaW1hcnlBZG1pblVzZXJJZIgBAUINCgtfbGVnYWxfbmFtZUIH'
    'CgVfdHlwZUIJCgdfdGF4X2lkQgwKCl92YXRfaWRfZXVCFwoVX2hlYWRxdWFydGVyc19hZGRyZX'
    'NzQhgKFl9wcmltYXJ5X2FkbWluX3VzZXJfaWQ=');

@$core.Deprecated('Use invitationDescriptor instead')
const Invitation$json = {
  '1': 'Invitation',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'organization_id', '3': 2, '4': 1, '5': 9, '10': 'organizationId'},
    {'1': 'invited_by_user', '3': 3, '4': 1, '5': 9, '10': 'invitedByUser'},
    {'1': 'email', '3': 4, '4': 1, '5': 9, '10': 'email'},
    {
      '1': 'expires_at',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'expiresAt'
    },
    {
      '1': 'accepted_at',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'acceptedAt'
    },
    {
      '1': 'created_at',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'createdAt'
    },
    {
      '1': 'invited_role',
      '3': 8,
      '4': 1,
      '5': 14,
      '6': '.identity.v1.UserRole',
      '10': 'invitedRole'
    },
    {'1': 'allocation_id', '3': 9, '4': 1, '5': 9, '10': 'allocationId'},
    {'1': 'first_name', '3': 10, '4': 1, '5': 9, '10': 'firstName'},
    {'1': 'last_name', '3': 11, '4': 1, '5': 9, '10': 'lastName'},
  ],
};

/// Descriptor for `Invitation`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List invitationDescriptor = $convert.base64Decode(
    'CgpJbnZpdGF0aW9uEg4KAmlkGAEgASgJUgJpZBInCg9vcmdhbml6YXRpb25faWQYAiABKAlSDm'
    '9yZ2FuaXphdGlvbklkEiYKD2ludml0ZWRfYnlfdXNlchgDIAEoCVINaW52aXRlZEJ5VXNlchIU'
    'CgVlbWFpbBgEIAEoCVIFZW1haWwSOQoKZXhwaXJlc19hdBgFIAEoCzIaLmdvb2dsZS5wcm90b2'
    'J1Zi5UaW1lc3RhbXBSCWV4cGlyZXNBdBI7CgthY2NlcHRlZF9hdBgGIAEoCzIaLmdvb2dsZS5w'
    'cm90b2J1Zi5UaW1lc3RhbXBSCmFjY2VwdGVkQXQSOQoKY3JlYXRlZF9hdBgHIAEoCzIaLmdvb2'
    'dsZS5wcm90b2J1Zi5UaW1lc3RhbXBSCWNyZWF0ZWRBdBI4CgxpbnZpdGVkX3JvbGUYCCABKA4y'
    'FS5pZGVudGl0eS52MS5Vc2VyUm9sZVILaW52aXRlZFJvbGUSIwoNYWxsb2NhdGlvbl9pZBgJIA'
    'EoCVIMYWxsb2NhdGlvbklkEh0KCmZpcnN0X25hbWUYCiABKAlSCWZpcnN0TmFtZRIbCglsYXN0'
    'X25hbWUYCyABKAlSCGxhc3ROYW1l');

@$core.Deprecated('Use inviteTherapistRequestDescriptor instead')
const InviteTherapistRequest$json = {
  '1': 'InviteTherapistRequest',
  '2': [
    {'1': 'email', '3': 1, '4': 1, '5': 9, '10': 'email'},
    {'1': 'first_name', '3': 2, '4': 1, '5': 9, '10': 'firstName'},
    {'1': 'last_name', '3': 3, '4': 1, '5': 9, '10': 'lastName'},
    {
      '1': 'default_modality_id',
      '3': 4,
      '4': 1,
      '5': 9,
      '10': 'defaultModalityId'
    },
    {'1': 'idempotency_key', '3': 5, '4': 1, '5': 9, '10': 'idempotencyKey'},
    {'1': 'allocation_id', '3': 6, '4': 1, '5': 9, '10': 'allocationId'},
  ],
};

/// Descriptor for `InviteTherapistRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List inviteTherapistRequestDescriptor = $convert.base64Decode(
    'ChZJbnZpdGVUaGVyYXBpc3RSZXF1ZXN0EhQKBWVtYWlsGAEgASgJUgVlbWFpbBIdCgpmaXJzdF'
    '9uYW1lGAIgASgJUglmaXJzdE5hbWUSGwoJbGFzdF9uYW1lGAMgASgJUghsYXN0TmFtZRIuChNk'
    'ZWZhdWx0X21vZGFsaXR5X2lkGAQgASgJUhFkZWZhdWx0TW9kYWxpdHlJZBInCg9pZGVtcG90ZW'
    '5jeV9rZXkYBSABKAlSDmlkZW1wb3RlbmN5S2V5EiMKDWFsbG9jYXRpb25faWQYBiABKAlSDGFs'
    'bG9jYXRpb25JZA==');

@$core.Deprecated('Use setTherapistStatusRequestDescriptor instead')
const SetTherapistStatusRequest$json = {
  '1': 'SetTherapistStatusRequest',
  '2': [
    {'1': 'user_id', '3': 1, '4': 1, '5': 9, '10': 'userId'},
    {'1': 'is_active', '3': 2, '4': 1, '5': 8, '10': 'isActive'},
    {'1': 'reason', '3': 3, '4': 1, '5': 9, '10': 'reason'},
  ],
};

/// Descriptor for `SetTherapistStatusRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setTherapistStatusRequestDescriptor =
    $convert.base64Decode(
        'ChlTZXRUaGVyYXBpc3RTdGF0dXNSZXF1ZXN0EhcKB3VzZXJfaWQYASABKAlSBnVzZXJJZBIbCg'
        'lpc19hY3RpdmUYAiABKAhSCGlzQWN0aXZlEhYKBnJlYXNvbhgDIAEoCVIGcmVhc29u');

@$core.Deprecated('Use acceptInvitationRequestDescriptor instead')
const AcceptInvitationRequest$json = {
  '1': 'AcceptInvitationRequest',
  '2': [
    {'1': 'token', '3': 1, '4': 1, '5': 9, '10': 'token'},
    {'1': 'firebase_uid', '3': 2, '4': 1, '5': 9, '10': 'firebaseUid'},
    {'1': 'first_name', '3': 3, '4': 1, '5': 9, '10': 'firstName'},
    {'1': 'last_name', '3': 4, '4': 1, '5': 9, '10': 'lastName'},
    {
      '1': 'default_modality_id',
      '3': 5,
      '4': 1,
      '5': 9,
      '10': 'defaultModalityId'
    },
    {'1': 'ui_language', '3': 6, '4': 1, '5': 9, '10': 'uiLanguage'},
    {'1': 'timezone', '3': 7, '4': 1, '5': 9, '10': 'timezone'},
    {'1': 'has_accepted_tos', '3': 8, '4': 1, '5': 8, '10': 'hasAcceptedTos'},
    {
      '1': 'has_marketing_consent',
      '3': 9,
      '4': 1,
      '5': 8,
      '10': 'hasMarketingConsent'
    },
  ],
};

/// Descriptor for `AcceptInvitationRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List acceptInvitationRequestDescriptor = $convert.base64Decode(
    'ChdBY2NlcHRJbnZpdGF0aW9uUmVxdWVzdBIUCgV0b2tlbhgBIAEoCVIFdG9rZW4SIQoMZmlyZW'
    'Jhc2VfdWlkGAIgASgJUgtmaXJlYmFzZVVpZBIdCgpmaXJzdF9uYW1lGAMgASgJUglmaXJzdE5h'
    'bWUSGwoJbGFzdF9uYW1lGAQgASgJUghsYXN0TmFtZRIuChNkZWZhdWx0X21vZGFsaXR5X2lkGA'
    'UgASgJUhFkZWZhdWx0TW9kYWxpdHlJZBIfCgt1aV9sYW5ndWFnZRgGIAEoCVIKdWlMYW5ndWFn'
    'ZRIaCgh0aW1lem9uZRgHIAEoCVIIdGltZXpvbmUSKAoQaGFzX2FjY2VwdGVkX3RvcxgIIAEoCF'
    'IOaGFzQWNjZXB0ZWRUb3MSMgoVaGFzX21hcmtldGluZ19jb25zZW50GAkgASgIUhNoYXNNYXJr'
    'ZXRpbmdDb25zZW50');

@$core.Deprecated('Use acceptInvitationResponseDescriptor instead')
const AcceptInvitationResponse$json = {
  '1': 'AcceptInvitationResponse',
  '2': [
    {
      '1': 'user',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.identity.v1.User',
      '10': 'user'
    },
    {
      '1': 'organization',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.identity.v1.Organization',
      '10': 'organization'
    },
  ],
};

/// Descriptor for `AcceptInvitationResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List acceptInvitationResponseDescriptor = $convert.base64Decode(
    'ChhBY2NlcHRJbnZpdGF0aW9uUmVzcG9uc2USJQoEdXNlchgBIAEoCzIRLmlkZW50aXR5LnYxLl'
    'VzZXJSBHVzZXISPQoMb3JnYW5pemF0aW9uGAIgASgLMhkuaWRlbnRpdHkudjEuT3JnYW5pemF0'
    'aW9uUgxvcmdhbml6YXRpb24=');

@$core.Deprecated('Use therapistEntryDescriptor instead')
const TherapistEntry$json = {
  '1': 'TherapistEntry',
  '2': [
    {
      '1': 'user',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.identity.v1.User',
      '10': 'user'
    },
    {
      '1': 'pending_invitation',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.identity.v1.Invitation',
      '10': 'pendingInvitation'
    },
  ],
};

/// Descriptor for `TherapistEntry`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List therapistEntryDescriptor = $convert.base64Decode(
    'Cg5UaGVyYXBpc3RFbnRyeRIlCgR1c2VyGAEgASgLMhEuaWRlbnRpdHkudjEuVXNlclIEdXNlch'
    'JGChJwZW5kaW5nX2ludml0YXRpb24YAiABKAsyFy5pZGVudGl0eS52MS5JbnZpdGF0aW9uUhFw'
    'ZW5kaW5nSW52aXRhdGlvbg==');

@$core.Deprecated('Use listTherapistsResponseDescriptor instead')
const ListTherapistsResponse$json = {
  '1': 'ListTherapistsResponse',
  '2': [
    {
      '1': 'therapists',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.identity.v1.TherapistEntry',
      '10': 'therapists'
    },
  ],
};

/// Descriptor for `ListTherapistsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listTherapistsResponseDescriptor =
    $convert.base64Decode(
        'ChZMaXN0VGhlcmFwaXN0c1Jlc3BvbnNlEjsKCnRoZXJhcGlzdHMYASADKAsyGy5pZGVudGl0eS'
        '52MS5UaGVyYXBpc3RFbnRyeVIKdGhlcmFwaXN0cw==');

@$core.Deprecated('Use removeTherapistRequestDescriptor instead')
const RemoveTherapistRequest$json = {
  '1': 'RemoveTherapistRequest',
  '2': [
    {'1': 'user_id', '3': 1, '4': 1, '5': 9, '10': 'userId'},
    {'1': 'reason', '3': 2, '4': 1, '5': 9, '10': 'reason'},
  ],
};

/// Descriptor for `RemoveTherapistRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List removeTherapistRequestDescriptor =
    $convert.base64Decode(
        'ChZSZW1vdmVUaGVyYXBpc3RSZXF1ZXN0EhcKB3VzZXJfaWQYASABKAlSBnVzZXJJZBIWCgZyZW'
        'Fzb24YAiABKAlSBnJlYXNvbg==');

@$core.Deprecated('Use adminCreateOrganizationRequestDescriptor instead')
const AdminCreateOrganizationRequest$json = {
  '1': 'AdminCreateOrganizationRequest',
  '2': [
    {'1': 'legal_name', '3': 1, '4': 1, '5': 9, '10': 'legalName'},
    {'1': 'tax_id', '3': 2, '4': 1, '5': 9, '10': 'taxId'},
    {'1': 'vat_id_eu', '3': 3, '4': 1, '5': 9, '10': 'vatIdEu'},
    {
      '1': 'headquarters',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.identity.v1.Address',
      '10': 'headquarters'
    },
    {
      '1': 'type',
      '3': 5,
      '4': 1,
      '5': 14,
      '6': '.identity.v1.OrganizationType',
      '10': 'type'
    },
    {'1': 'manager_emails', '3': 6, '4': 3, '5': 9, '10': 'managerEmails'},
    {'1': 'reason', '3': 15, '4': 1, '5': 9, '10': 'reason'},
    {'1': 'idempotency_key', '3': 16, '4': 1, '5': 9, '10': 'idempotencyKey'},
  ],
};

/// Descriptor for `AdminCreateOrganizationRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List adminCreateOrganizationRequestDescriptor = $convert.base64Decode(
    'Ch5BZG1pbkNyZWF0ZU9yZ2FuaXphdGlvblJlcXVlc3QSHQoKbGVnYWxfbmFtZRgBIAEoCVIJbG'
    'VnYWxOYW1lEhUKBnRheF9pZBgCIAEoCVIFdGF4SWQSGgoJdmF0X2lkX2V1GAMgASgJUgd2YXRJ'
    'ZEV1EjgKDGhlYWRxdWFydGVycxgEIAEoCzIULmlkZW50aXR5LnYxLkFkZHJlc3NSDGhlYWRxdW'
    'FydGVycxIxCgR0eXBlGAUgASgOMh0uaWRlbnRpdHkudjEuT3JnYW5pemF0aW9uVHlwZVIEdHlw'
    'ZRIlCg5tYW5hZ2VyX2VtYWlscxgGIAMoCVINbWFuYWdlckVtYWlscxIWCgZyZWFzb24YDyABKA'
    'lSBnJlYXNvbhInCg9pZGVtcG90ZW5jeV9rZXkYECABKAlSDmlkZW1wb3RlbmN5S2V5');

@$core.Deprecated('Use adminCreateOrganizationResponseDescriptor instead')
const AdminCreateOrganizationResponse$json = {
  '1': 'AdminCreateOrganizationResponse',
  '2': [
    {
      '1': 'organization',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.identity.v1.Organization',
      '10': 'organization'
    },
    {
      '1': 'manager_invitations',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.identity.v1.Invitation',
      '10': 'managerInvitations'
    },
  ],
};

/// Descriptor for `AdminCreateOrganizationResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List adminCreateOrganizationResponseDescriptor =
    $convert.base64Decode(
        'Ch9BZG1pbkNyZWF0ZU9yZ2FuaXphdGlvblJlc3BvbnNlEj0KDG9yZ2FuaXphdGlvbhgBIAEoCz'
        'IZLmlkZW50aXR5LnYxLk9yZ2FuaXphdGlvblIMb3JnYW5pemF0aW9uEkgKE21hbmFnZXJfaW52'
        'aXRhdGlvbnMYAiADKAsyFy5pZGVudGl0eS52MS5JbnZpdGF0aW9uUhJtYW5hZ2VySW52aXRhdG'
        'lvbnM=');

@$core.Deprecated('Use adminListOrganizationsRequestDescriptor instead')
const AdminListOrganizationsRequest$json = {
  '1': 'AdminListOrganizationsRequest',
  '2': [
    {'1': 'page_size', '3': 1, '4': 1, '5': 5, '10': 'pageSize'},
    {'1': 'page_token', '3': 2, '4': 1, '5': 9, '10': 'pageToken'},
    {'1': 'search', '3': 3, '4': 1, '5': 9, '10': 'search'},
  ],
};

/// Descriptor for `AdminListOrganizationsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List adminListOrganizationsRequestDescriptor =
    $convert.base64Decode(
        'Ch1BZG1pbkxpc3RPcmdhbml6YXRpb25zUmVxdWVzdBIbCglwYWdlX3NpemUYASABKAVSCHBhZ2'
        'VTaXplEh0KCnBhZ2VfdG9rZW4YAiABKAlSCXBhZ2VUb2tlbhIWCgZzZWFyY2gYAyABKAlSBnNl'
        'YXJjaA==');

@$core.Deprecated('Use organizationSummaryDescriptor instead')
const OrganizationSummary$json = {
  '1': 'OrganizationSummary',
  '2': [
    {
      '1': 'organization',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.identity.v1.Organization',
      '10': 'organization'
    },
    {'1': 'therapists_count', '3': 2, '4': 1, '5': 5, '10': 'therapistsCount'},
    {
      '1': 'last_session_at',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'lastSessionAt'
    },
  ],
};

/// Descriptor for `OrganizationSummary`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List organizationSummaryDescriptor = $convert.base64Decode(
    'ChNPcmdhbml6YXRpb25TdW1tYXJ5Ej0KDG9yZ2FuaXphdGlvbhgBIAEoCzIZLmlkZW50aXR5Ln'
    'YxLk9yZ2FuaXphdGlvblIMb3JnYW5pemF0aW9uEikKEHRoZXJhcGlzdHNfY291bnQYAiABKAVS'
    'D3RoZXJhcGlzdHNDb3VudBJCCg9sYXN0X3Nlc3Npb25fYXQYAyABKAsyGi5nb29nbGUucHJvdG'
    '9idWYuVGltZXN0YW1wUg1sYXN0U2Vzc2lvbkF0');

@$core.Deprecated('Use adminListOrganizationsResponseDescriptor instead')
const AdminListOrganizationsResponse$json = {
  '1': 'AdminListOrganizationsResponse',
  '2': [
    {
      '1': 'organizations',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.identity.v1.OrganizationSummary',
      '10': 'organizations'
    },
    {'1': 'next_page_token', '3': 2, '4': 1, '5': 9, '10': 'nextPageToken'},
  ],
};

/// Descriptor for `AdminListOrganizationsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List adminListOrganizationsResponseDescriptor =
    $convert.base64Decode(
        'Ch5BZG1pbkxpc3RPcmdhbml6YXRpb25zUmVzcG9uc2USRgoNb3JnYW5pemF0aW9ucxgBIAMoCz'
        'IgLmlkZW50aXR5LnYxLk9yZ2FuaXphdGlvblN1bW1hcnlSDW9yZ2FuaXphdGlvbnMSJgoPbmV4'
        'dF9wYWdlX3Rva2VuGAIgASgJUg1uZXh0UGFnZVRva2Vu');

@$core.Deprecated('Use adminGetOrganizationRequestDescriptor instead')
const AdminGetOrganizationRequest$json = {
  '1': 'AdminGetOrganizationRequest',
  '2': [
    {'1': 'organization_id', '3': 1, '4': 1, '5': 9, '10': 'organizationId'},
  ],
};

/// Descriptor for `AdminGetOrganizationRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List adminGetOrganizationRequestDescriptor =
    $convert.base64Decode(
        'ChtBZG1pbkdldE9yZ2FuaXphdGlvblJlcXVlc3QSJwoPb3JnYW5pemF0aW9uX2lkGAEgASgJUg'
        '5vcmdhbml6YXRpb25JZA==');

@$core.Deprecated('Use organizationDetailsDescriptor instead')
const OrganizationDetails$json = {
  '1': 'OrganizationDetails',
  '2': [
    {
      '1': 'organization',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.identity.v1.Organization',
      '10': 'organization'
    },
    {
      '1': 'therapists',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.identity.v1.User',
      '10': 'therapists'
    },
    {
      '1': 'recent_audit',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.identity.v1.AuditEntry',
      '10': 'recentAudit'
    },
  ],
};

/// Descriptor for `OrganizationDetails`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List organizationDetailsDescriptor = $convert.base64Decode(
    'ChNPcmdhbml6YXRpb25EZXRhaWxzEj0KDG9yZ2FuaXphdGlvbhgBIAEoCzIZLmlkZW50aXR5Ln'
    'YxLk9yZ2FuaXphdGlvblIMb3JnYW5pemF0aW9uEjEKCnRoZXJhcGlzdHMYAiADKAsyES5pZGVu'
    'dGl0eS52MS5Vc2VyUgp0aGVyYXBpc3RzEjoKDHJlY2VudF9hdWRpdBgDIAMoCzIXLmlkZW50aX'
    'R5LnYxLkF1ZGl0RW50cnlSC3JlY2VudEF1ZGl0');

@$core.Deprecated('Use auditEntryDescriptor instead')
const AuditEntry$json = {
  '1': 'AuditEntry',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {
      '1': 'occurred_at',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'occurredAt'
    },
    {'1': 'actor_email', '3': 3, '4': 1, '5': 9, '10': 'actorEmail'},
    {'1': 'action', '3': 4, '4': 1, '5': 9, '10': 'action'},
    {'1': 'reason', '3': 5, '4': 1, '5': 9, '10': 'reason'},
    {'1': 'resource_type', '3': 6, '4': 1, '5': 9, '10': 'resourceType'},
    {'1': 'resource_id', '3': 7, '4': 1, '5': 9, '10': 'resourceId'},
  ],
};

/// Descriptor for `AuditEntry`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List auditEntryDescriptor = $convert.base64Decode(
    'CgpBdWRpdEVudHJ5Eg4KAmlkGAEgASgJUgJpZBI7CgtvY2N1cnJlZF9hdBgCIAEoCzIaLmdvb2'
    'dsZS5wcm90b2J1Zi5UaW1lc3RhbXBSCm9jY3VycmVkQXQSHwoLYWN0b3JfZW1haWwYAyABKAlS'
    'CmFjdG9yRW1haWwSFgoGYWN0aW9uGAQgASgJUgZhY3Rpb24SFgoGcmVhc29uGAUgASgJUgZyZW'
    'Fzb24SIwoNcmVzb3VyY2VfdHlwZRgGIAEoCVIMcmVzb3VyY2VUeXBlEh8KC3Jlc291cmNlX2lk'
    'GAcgASgJUgpyZXNvdXJjZUlk');

@$core.Deprecated('Use adminSetOrganizationStatusRequestDescriptor instead')
const AdminSetOrganizationStatusRequest$json = {
  '1': 'AdminSetOrganizationStatusRequest',
  '2': [
    {'1': 'organization_id', '3': 1, '4': 1, '5': 9, '10': 'organizationId'},
    {'1': 'desired_status', '3': 2, '4': 1, '5': 9, '10': 'desiredStatus'},
    {'1': 'reason', '3': 3, '4': 1, '5': 9, '10': 'reason'},
  ],
};

/// Descriptor for `AdminSetOrganizationStatusRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List adminSetOrganizationStatusRequestDescriptor =
    $convert.base64Decode(
        'CiFBZG1pblNldE9yZ2FuaXphdGlvblN0YXR1c1JlcXVlc3QSJwoPb3JnYW5pemF0aW9uX2lkGA'
        'EgASgJUg5vcmdhbml6YXRpb25JZBIlCg5kZXNpcmVkX3N0YXR1cxgCIAEoCVINZGVzaXJlZFN0'
        'YXR1cxIWCgZyZWFzb24YAyABKAlSBnJlYXNvbg==');

@$core.Deprecated('Use adminUpdateOrganizationRequestDescriptor instead')
const AdminUpdateOrganizationRequest$json = {
  '1': 'AdminUpdateOrganizationRequest',
  '2': [
    {'1': 'organization_id', '3': 1, '4': 1, '5': 9, '10': 'organizationId'},
    {
      '1': 'legal_name',
      '3': 2,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'legalName',
      '17': true
    },
    {
      '1': 'type',
      '3': 3,
      '4': 1,
      '5': 14,
      '6': '.identity.v1.OrganizationType',
      '9': 1,
      '10': 'type',
      '17': true
    },
    {'1': 'tax_id', '3': 4, '4': 1, '5': 9, '9': 2, '10': 'taxId', '17': true},
    {
      '1': 'vat_id_eu',
      '3': 5,
      '4': 1,
      '5': 9,
      '9': 3,
      '10': 'vatIdEu',
      '17': true
    },
    {
      '1': 'headquarters_address',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.identity.v1.Address',
      '9': 4,
      '10': 'headquartersAddress',
      '17': true
    },
    {
      '1': 'primary_admin_user_id',
      '3': 7,
      '4': 1,
      '5': 9,
      '9': 5,
      '10': 'primaryAdminUserId',
      '17': true
    },
    {'1': 'reason', '3': 8, '4': 1, '5': 9, '10': 'reason'},
  ],
  '8': [
    {'1': '_legal_name'},
    {'1': '_type'},
    {'1': '_tax_id'},
    {'1': '_vat_id_eu'},
    {'1': '_headquarters_address'},
    {'1': '_primary_admin_user_id'},
  ],
};

/// Descriptor for `AdminUpdateOrganizationRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List adminUpdateOrganizationRequestDescriptor = $convert.base64Decode(
    'Ch5BZG1pblVwZGF0ZU9yZ2FuaXphdGlvblJlcXVlc3QSJwoPb3JnYW5pemF0aW9uX2lkGAEgAS'
    'gJUg5vcmdhbml6YXRpb25JZBIiCgpsZWdhbF9uYW1lGAIgASgJSABSCWxlZ2FsTmFtZYgBARI2'
    'CgR0eXBlGAMgASgOMh0uaWRlbnRpdHkudjEuT3JnYW5pemF0aW9uVHlwZUgBUgR0eXBliAEBEh'
    'oKBnRheF9pZBgEIAEoCUgCUgV0YXhJZIgBARIfCgl2YXRfaWRfZXUYBSABKAlIA1IHdmF0SWRF'
    'dYgBARJMChRoZWFkcXVhcnRlcnNfYWRkcmVzcxgGIAEoCzIULmlkZW50aXR5LnYxLkFkZHJlc3'
    'NIBFITaGVhZHF1YXJ0ZXJzQWRkcmVzc4gBARI2ChVwcmltYXJ5X2FkbWluX3VzZXJfaWQYByAB'
    'KAlIBVIScHJpbWFyeUFkbWluVXNlcklkiAEBEhYKBnJlYXNvbhgIIAEoCVIGcmVhc29uQg0KC1'
    '9sZWdhbF9uYW1lQgcKBV90eXBlQgkKB190YXhfaWRCDAoKX3ZhdF9pZF9ldUIXChVfaGVhZHF1'
    'YXJ0ZXJzX2FkZHJlc3NCGAoWX3ByaW1hcnlfYWRtaW5fdXNlcl9pZA==');

@$core.Deprecated('Use adminListUsersRequestDescriptor instead')
const AdminListUsersRequest$json = {
  '1': 'AdminListUsersRequest',
  '2': [
    {'1': 'page_size', '3': 1, '4': 1, '5': 5, '10': 'pageSize'},
    {'1': 'page_token', '3': 2, '4': 1, '5': 9, '10': 'pageToken'},
    {'1': 'organization_id', '3': 3, '4': 1, '5': 9, '10': 'organizationId'},
    {
      '1': 'role',
      '3': 4,
      '4': 1,
      '5': 14,
      '6': '.identity.v1.UserRole',
      '10': 'role'
    },
    {'1': 'search', '3': 5, '4': 1, '5': 9, '10': 'search'},
  ],
};

/// Descriptor for `AdminListUsersRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List adminListUsersRequestDescriptor = $convert.base64Decode(
    'ChVBZG1pbkxpc3RVc2Vyc1JlcXVlc3QSGwoJcGFnZV9zaXplGAEgASgFUghwYWdlU2l6ZRIdCg'
    'pwYWdlX3Rva2VuGAIgASgJUglwYWdlVG9rZW4SJwoPb3JnYW5pemF0aW9uX2lkGAMgASgJUg5v'
    'cmdhbml6YXRpb25JZBIpCgRyb2xlGAQgASgOMhUuaWRlbnRpdHkudjEuVXNlclJvbGVSBHJvbG'
    'USFgoGc2VhcmNoGAUgASgJUgZzZWFyY2g=');

@$core.Deprecated('Use adminListUsersResponseDescriptor instead')
const AdminListUsersResponse$json = {
  '1': 'AdminListUsersResponse',
  '2': [
    {
      '1': 'users',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.identity.v1.User',
      '10': 'users'
    },
    {'1': 'next_page_token', '3': 2, '4': 1, '5': 9, '10': 'nextPageToken'},
  ],
};

/// Descriptor for `AdminListUsersResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List adminListUsersResponseDescriptor =
    $convert.base64Decode(
        'ChZBZG1pbkxpc3RVc2Vyc1Jlc3BvbnNlEicKBXVzZXJzGAEgAygLMhEuaWRlbnRpdHkudjEuVX'
        'NlclIFdXNlcnMSJgoPbmV4dF9wYWdlX3Rva2VuGAIgASgJUg1uZXh0UGFnZVRva2Vu');

@$core.Deprecated('Use adminGetUserRequestDescriptor instead')
const AdminGetUserRequest$json = {
  '1': 'AdminGetUserRequest',
  '2': [
    {'1': 'user_id', '3': 1, '4': 1, '5': 9, '10': 'userId'},
  ],
};

/// Descriptor for `AdminGetUserRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List adminGetUserRequestDescriptor =
    $convert.base64Decode(
        'ChNBZG1pbkdldFVzZXJSZXF1ZXN0EhcKB3VzZXJfaWQYASABKAlSBnVzZXJJZA==');

@$core.Deprecated('Use adminUpdateUserRequestDescriptor instead')
const AdminUpdateUserRequest$json = {
  '1': 'AdminUpdateUserRequest',
  '2': [
    {'1': 'user_id', '3': 1, '4': 1, '5': 9, '10': 'userId'},
    {'1': 'email', '3': 2, '4': 1, '5': 9, '9': 0, '10': 'email', '17': true},
    {
      '1': 'first_name',
      '3': 3,
      '4': 1,
      '5': 9,
      '9': 1,
      '10': 'firstName',
      '17': true
    },
    {
      '1': 'last_name',
      '3': 4,
      '4': 1,
      '5': 9,
      '9': 2,
      '10': 'lastName',
      '17': true
    },
    {
      '1': 'phone_number',
      '3': 5,
      '4': 1,
      '5': 9,
      '9': 3,
      '10': 'phoneNumber',
      '17': true
    },
    {
      '1': 'role',
      '3': 6,
      '4': 1,
      '5': 14,
      '6': '.identity.v1.UserRole',
      '9': 4,
      '10': 'role',
      '17': true
    },
    {
      '1': 'organization_id',
      '3': 7,
      '4': 1,
      '5': 9,
      '9': 5,
      '10': 'organizationId',
      '17': true
    },
    {
      '1': 'default_modality_id',
      '3': 8,
      '4': 1,
      '5': 9,
      '9': 6,
      '10': 'defaultModalityId',
      '17': true
    },
    {
      '1': 'ui_language',
      '3': 9,
      '4': 1,
      '5': 9,
      '9': 7,
      '10': 'uiLanguage',
      '17': true
    },
    {
      '1': 'timezone',
      '3': 10,
      '4': 1,
      '5': 9,
      '9': 8,
      '10': 'timezone',
      '17': true
    },
    {
      '1': 'professional_title',
      '3': 11,
      '4': 1,
      '5': 9,
      '9': 9,
      '10': 'professionalTitle',
      '17': true
    },
    {
      '1': 'credentials_number',
      '3': 12,
      '4': 1,
      '5': 9,
      '9': 10,
      '10': 'credentialsNumber',
      '17': true
    },
    {
      '1': 'biography',
      '3': 13,
      '4': 1,
      '5': 9,
      '9': 11,
      '10': 'biography',
      '17': true
    },
    {
      '1': 'avatar_url',
      '3': 14,
      '4': 1,
      '5': 9,
      '9': 12,
      '10': 'avatarUrl',
      '17': true
    },
    {
      '1': 'billing_address',
      '3': 15,
      '4': 1,
      '5': 11,
      '6': '.identity.v1.Address',
      '9': 13,
      '10': 'billingAddress',
      '17': true
    },
    {
      '1': 'is_email_verified',
      '3': 16,
      '4': 1,
      '5': 8,
      '9': 14,
      '10': 'isEmailVerified',
      '17': true
    },
    {'1': 'reason', '3': 17, '4': 1, '5': 9, '10': 'reason'},
  ],
  '8': [
    {'1': '_email'},
    {'1': '_first_name'},
    {'1': '_last_name'},
    {'1': '_phone_number'},
    {'1': '_role'},
    {'1': '_organization_id'},
    {'1': '_default_modality_id'},
    {'1': '_ui_language'},
    {'1': '_timezone'},
    {'1': '_professional_title'},
    {'1': '_credentials_number'},
    {'1': '_biography'},
    {'1': '_avatar_url'},
    {'1': '_billing_address'},
    {'1': '_is_email_verified'},
  ],
};

/// Descriptor for `AdminUpdateUserRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List adminUpdateUserRequestDescriptor = $convert.base64Decode(
    'ChZBZG1pblVwZGF0ZVVzZXJSZXF1ZXN0EhcKB3VzZXJfaWQYASABKAlSBnVzZXJJZBIZCgVlbW'
    'FpbBgCIAEoCUgAUgVlbWFpbIgBARIiCgpmaXJzdF9uYW1lGAMgASgJSAFSCWZpcnN0TmFtZYgB'
    'ARIgCglsYXN0X25hbWUYBCABKAlIAlIIbGFzdE5hbWWIAQESJgoMcGhvbmVfbnVtYmVyGAUgAS'
    'gJSANSC3Bob25lTnVtYmVyiAEBEi4KBHJvbGUYBiABKA4yFS5pZGVudGl0eS52MS5Vc2VyUm9s'
    'ZUgEUgRyb2xliAEBEiwKD29yZ2FuaXphdGlvbl9pZBgHIAEoCUgFUg5vcmdhbml6YXRpb25JZI'
    'gBARIzChNkZWZhdWx0X21vZGFsaXR5X2lkGAggASgJSAZSEWRlZmF1bHRNb2RhbGl0eUlkiAEB'
    'EiQKC3VpX2xhbmd1YWdlGAkgASgJSAdSCnVpTGFuZ3VhZ2WIAQESHwoIdGltZXpvbmUYCiABKA'
    'lICFIIdGltZXpvbmWIAQESMgoScHJvZmVzc2lvbmFsX3RpdGxlGAsgASgJSAlSEXByb2Zlc3Np'
    'b25hbFRpdGxliAEBEjIKEmNyZWRlbnRpYWxzX251bWJlchgMIAEoCUgKUhFjcmVkZW50aWFsc0'
    '51bWJlcogBARIhCgliaW9ncmFwaHkYDSABKAlIC1IJYmlvZ3JhcGh5iAEBEiIKCmF2YXRhcl91'
    'cmwYDiABKAlIDFIJYXZhdGFyVXJsiAEBEkIKD2JpbGxpbmdfYWRkcmVzcxgPIAEoCzIULmlkZW'
    '50aXR5LnYxLkFkZHJlc3NIDVIOYmlsbGluZ0FkZHJlc3OIAQESLwoRaXNfZW1haWxfdmVyaWZp'
    'ZWQYECABKAhIDlIPaXNFbWFpbFZlcmlmaWVkiAEBEhYKBnJlYXNvbhgRIAEoCVIGcmVhc29uQg'
    'gKBl9lbWFpbEINCgtfZmlyc3RfbmFtZUIMCgpfbGFzdF9uYW1lQg8KDV9waG9uZV9udW1iZXJC'
    'BwoFX3JvbGVCEgoQX29yZ2FuaXphdGlvbl9pZEIWChRfZGVmYXVsdF9tb2RhbGl0eV9pZEIOCg'
    'xfdWlfbGFuZ3VhZ2VCCwoJX3RpbWV6b25lQhUKE19wcm9mZXNzaW9uYWxfdGl0bGVCFQoTX2Ny'
    'ZWRlbnRpYWxzX251bWJlckIMCgpfYmlvZ3JhcGh5Qg0KC19hdmF0YXJfdXJsQhIKEF9iaWxsaW'
    '5nX2FkZHJlc3NCFAoSX2lzX2VtYWlsX3ZlcmlmaWVk');

@$core.Deprecated('Use adminDeleteUserRequestDescriptor instead')
const AdminDeleteUserRequest$json = {
  '1': 'AdminDeleteUserRequest',
  '2': [
    {'1': 'user_id', '3': 1, '4': 1, '5': 9, '10': 'userId'},
    {'1': 'reason', '3': 2, '4': 1, '5': 9, '10': 'reason'},
  ],
};

/// Descriptor for `AdminDeleteUserRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List adminDeleteUserRequestDescriptor =
    $convert.base64Decode(
        'ChZBZG1pbkRlbGV0ZVVzZXJSZXF1ZXN0EhcKB3VzZXJfaWQYASABKAlSBnVzZXJJZBIWCgZyZW'
        'Fzb24YAiABKAlSBnJlYXNvbg==');

@$core.Deprecated('Use adminListAuditEventsRequestDescriptor instead')
const AdminListAuditEventsRequest$json = {
  '1': 'AdminListAuditEventsRequest',
  '2': [
    {'1': 'page_size', '3': 1, '4': 1, '5': 5, '10': 'pageSize'},
    {'1': 'page_token', '3': 2, '4': 1, '5': 9, '10': 'pageToken'},
    {'1': 'actor_email', '3': 3, '4': 1, '5': 9, '10': 'actorEmail'},
    {'1': 'action', '3': 4, '4': 1, '5': 9, '10': 'action'},
    {
      '1': 'since',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'since'
    },
    {
      '1': 'until',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'until'
    },
  ],
};

/// Descriptor for `AdminListAuditEventsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List adminListAuditEventsRequestDescriptor = $convert.base64Decode(
    'ChtBZG1pbkxpc3RBdWRpdEV2ZW50c1JlcXVlc3QSGwoJcGFnZV9zaXplGAEgASgFUghwYWdlU2'
    'l6ZRIdCgpwYWdlX3Rva2VuGAIgASgJUglwYWdlVG9rZW4SHwoLYWN0b3JfZW1haWwYAyABKAlS'
    'CmFjdG9yRW1haWwSFgoGYWN0aW9uGAQgASgJUgZhY3Rpb24SMAoFc2luY2UYBSABKAsyGi5nb2'
    '9nbGUucHJvdG9idWYuVGltZXN0YW1wUgVzaW5jZRIwCgV1bnRpbBgGIAEoCzIaLmdvb2dsZS5w'
    'cm90b2J1Zi5UaW1lc3RhbXBSBXVudGls');

@$core.Deprecated('Use adminListAuditEventsResponseDescriptor instead')
const AdminListAuditEventsResponse$json = {
  '1': 'AdminListAuditEventsResponse',
  '2': [
    {
      '1': 'events',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.identity.v1.AuditEntry',
      '10': 'events'
    },
    {'1': 'next_page_token', '3': 2, '4': 1, '5': 9, '10': 'nextPageToken'},
  ],
};

/// Descriptor for `AdminListAuditEventsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List adminListAuditEventsResponseDescriptor =
    $convert.base64Decode(
        'ChxBZG1pbkxpc3RBdWRpdEV2ZW50c1Jlc3BvbnNlEi8KBmV2ZW50cxgBIAMoCzIXLmlkZW50aX'
        'R5LnYxLkF1ZGl0RW50cnlSBmV2ZW50cxImCg9uZXh0X3BhZ2VfdG9rZW4YAiABKAlSDW5leHRQ'
        'YWdlVG9rZW4=');

@$core.Deprecated('Use recordConsentRequestDescriptor instead')
const RecordConsentRequest$json = {
  '1': 'RecordConsentRequest',
  '2': [
    {'1': 'user_id', '3': 1, '4': 1, '5': 9, '10': 'userId'},
    {'1': 'consent_type', '3': 2, '4': 1, '5': 9, '10': 'consentType'},
    {'1': 'granted', '3': 3, '4': 1, '5': 8, '10': 'granted'},
    {'1': 'consent_version', '3': 4, '4': 1, '5': 9, '10': 'consentVersion'},
    {'1': 'ip_address', '3': 5, '4': 1, '5': 9, '10': 'ipAddress'},
    {'1': 'user_agent', '3': 6, '4': 1, '5': 9, '10': 'userAgent'},
  ],
};

/// Descriptor for `RecordConsentRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List recordConsentRequestDescriptor = $convert.base64Decode(
    'ChRSZWNvcmRDb25zZW50UmVxdWVzdBIXCgd1c2VyX2lkGAEgASgJUgZ1c2VySWQSIQoMY29uc2'
    'VudF90eXBlGAIgASgJUgtjb25zZW50VHlwZRIYCgdncmFudGVkGAMgASgIUgdncmFudGVkEicK'
    'D2NvbnNlbnRfdmVyc2lvbhgEIAEoCVIOY29uc2VudFZlcnNpb24SHQoKaXBfYWRkcmVzcxgFIA'
    'EoCVIJaXBBZGRyZXNzEh0KCnVzZXJfYWdlbnQYBiABKAlSCXVzZXJBZ2VudA==');

@$core.Deprecated('Use recordConsentResponseDescriptor instead')
const RecordConsentResponse$json = {
  '1': 'RecordConsentResponse',
  '2': [
    {'1': 'consent_record_id', '3': 1, '4': 1, '5': 9, '10': 'consentRecordId'},
    {
      '1': 'recorded_at',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'recordedAt'
    },
  ],
};

/// Descriptor for `RecordConsentResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List recordConsentResponseDescriptor = $convert.base64Decode(
    'ChVSZWNvcmRDb25zZW50UmVzcG9uc2USKgoRY29uc2VudF9yZWNvcmRfaWQYASABKAlSD2Nvbn'
    'NlbnRSZWNvcmRJZBI7CgtyZWNvcmRlZF9hdBgCIAEoCzIaLmdvb2dsZS5wcm90b2J1Zi5UaW1l'
    'c3RhbXBSCnJlY29yZGVkQXQ=');

@$core.Deprecated('Use checkEmailExistsRequestDescriptor instead')
const CheckEmailExistsRequest$json = {
  '1': 'CheckEmailExistsRequest',
  '2': [
    {'1': 'email', '3': 1, '4': 1, '5': 9, '10': 'email'},
  ],
};

/// Descriptor for `CheckEmailExistsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List checkEmailExistsRequestDescriptor =
    $convert.base64Decode(
        'ChdDaGVja0VtYWlsRXhpc3RzUmVxdWVzdBIUCgVlbWFpbBgBIAEoCVIFZW1haWw=');

@$core.Deprecated('Use checkEmailExistsResponseDescriptor instead')
const CheckEmailExistsResponse$json = {
  '1': 'CheckEmailExistsResponse',
  '2': [
    {'1': 'exists', '3': 2, '4': 1, '5': 8, '10': 'exists'},
    {
      '1': 'is_pending_deletion',
      '3': 3,
      '4': 1,
      '5': 8,
      '10': 'isPendingDeletion'
    },
  ],
};

/// Descriptor for `CheckEmailExistsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List checkEmailExistsResponseDescriptor =
    $convert.base64Decode(
        'ChhDaGVja0VtYWlsRXhpc3RzUmVzcG9uc2USFgoGZXhpc3RzGAIgASgIUgZleGlzdHMSLgoTaX'
        'NfcGVuZGluZ19kZWxldGlvbhgDIAEoCFIRaXNQZW5kaW5nRGVsZXRpb24=');
