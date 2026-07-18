// This is a generated file - do not edit.
//
// Generated from notification/v1/notification.proto.

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

@$core.Deprecated('Use platformDescriptor instead')
const Platform$json = {
  '1': 'Platform',
  '2': [
    {'1': 'PLATFORM_UNSPECIFIED', '2': 0},
    {'1': 'PLATFORM_IOS', '2': 1},
    {'1': 'PLATFORM_ANDROID', '2': 2},
    {'1': 'PLATFORM_WEB', '2': 3},
  ],
};

/// Descriptor for `Platform`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List platformDescriptor = $convert.base64Decode(
    'CghQbGF0Zm9ybRIYChRQTEFURk9STV9VTlNQRUNJRklFRBAAEhAKDFBMQVRGT1JNX0lPUxABEh'
    'QKEFBMQVRGT1JNX0FORFJPSUQQAhIQCgxQTEFURk9STV9XRUIQAw==');

@$core.Deprecated('Use sendClientPanelEventRequestDescriptor instead')
const SendClientPanelEventRequest$json = {
  '1': 'SendClientPanelEventRequest',
  '2': [
    {'1': 'recipient_email', '3': 1, '4': 1, '5': 9, '10': 'recipientEmail'},
    {'1': 'event', '3': 2, '4': 1, '5': 9, '10': 'event'},
    {'1': 'item_kind', '3': 3, '4': 1, '5': 9, '10': 'itemKind'},
    {'1': 'locale', '3': 4, '4': 1, '5': 9, '10': 'locale'},
    {'1': 'panel_url', '3': 5, '4': 1, '5': 9, '10': 'panelUrl'},
    {'1': 'recipient_user_id', '3': 6, '4': 1, '5': 9, '10': 'recipientUserId'},
    {'1': 'patient_file_id', '3': 7, '4': 1, '5': 9, '10': 'patientFileId'},
  ],
};

/// Descriptor for `SendClientPanelEventRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sendClientPanelEventRequestDescriptor = $convert.base64Decode(
    'ChtTZW5kQ2xpZW50UGFuZWxFdmVudFJlcXVlc3QSJwoPcmVjaXBpZW50X2VtYWlsGAEgASgJUg'
    '5yZWNpcGllbnRFbWFpbBIUCgVldmVudBgCIAEoCVIFZXZlbnQSGwoJaXRlbV9raW5kGAMgASgJ'
    'UghpdGVtS2luZBIWCgZsb2NhbGUYBCABKAlSBmxvY2FsZRIbCglwYW5lbF91cmwYBSABKAlSCH'
    'BhbmVsVXJsEioKEXJlY2lwaWVudF91c2VyX2lkGAYgASgJUg9yZWNpcGllbnRVc2VySWQSJgoP'
    'cGF0aWVudF9maWxlX2lkGAcgASgJUg1wYXRpZW50RmlsZUlk');

@$core.Deprecated('Use sendContactEmailRequestDescriptor instead')
const SendContactEmailRequest$json = {
  '1': 'SendContactEmailRequest',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
    {'1': 'email', '3': 2, '4': 1, '5': 9, '10': 'email'},
    {'1': 'subject', '3': 3, '4': 1, '5': 9, '10': 'subject'},
    {'1': 'message', '3': 4, '4': 1, '5': 9, '10': 'message'},
  ],
};

/// Descriptor for `SendContactEmailRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sendContactEmailRequestDescriptor = $convert.base64Decode(
    'ChdTZW5kQ29udGFjdEVtYWlsUmVxdWVzdBISCgRuYW1lGAEgASgJUgRuYW1lEhQKBWVtYWlsGA'
    'IgASgJUgVlbWFpbBIYCgdzdWJqZWN0GAMgASgJUgdzdWJqZWN0EhgKB21lc3NhZ2UYBCABKAlS'
    'B21lc3NhZ2U=');

@$core.Deprecated('Use sendActionPlanEmailRequestDescriptor instead')
const SendActionPlanEmailRequest$json = {
  '1': 'SendActionPlanEmailRequest',
  '2': [
    {'1': 'to_email', '3': 1, '4': 1, '5': 9, '10': 'toEmail'},
    {
      '1': 'therapist_display_name',
      '3': 2,
      '4': 1,
      '5': 9,
      '10': 'therapistDisplayName'
    },
    {'1': 'action_plan_text', '3': 3, '4': 1, '5': 9, '10': 'actionPlanText'},
    {'1': 'session_date', '3': 4, '4': 1, '5': 9, '10': 'sessionDate'},
    {'1': 'locale', '3': 5, '4': 1, '5': 9, '10': 'locale'},
    {'1': 'idempotency_key', '3': 6, '4': 1, '5': 9, '10': 'idempotencyKey'},
  ],
};

/// Descriptor for `SendActionPlanEmailRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sendActionPlanEmailRequestDescriptor = $convert.base64Decode(
    'ChpTZW5kQWN0aW9uUGxhbkVtYWlsUmVxdWVzdBIZCgh0b19lbWFpbBgBIAEoCVIHdG9FbWFpbB'
    'I0ChZ0aGVyYXBpc3RfZGlzcGxheV9uYW1lGAIgASgJUhR0aGVyYXBpc3REaXNwbGF5TmFtZRIo'
    'ChBhY3Rpb25fcGxhbl90ZXh0GAMgASgJUg5hY3Rpb25QbGFuVGV4dBIhCgxzZXNzaW9uX2RhdG'
    'UYBCABKAlSC3Nlc3Npb25EYXRlEhYKBmxvY2FsZRgFIAEoCVIGbG9jYWxlEicKD2lkZW1wb3Rl'
    'bmN5X2tleRgGIAEoCVIOaWRlbXBvdGVuY3lLZXk=');

@$core.Deprecated('Use sendActionPlanEmailResponseDescriptor instead')
const SendActionPlanEmailResponse$json = {
  '1': 'SendActionPlanEmailResponse',
  '2': [
    {'1': 'delivery_id', '3': 1, '4': 1, '5': 9, '10': 'deliveryId'},
  ],
};

/// Descriptor for `SendActionPlanEmailResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sendActionPlanEmailResponseDescriptor =
    $convert.base64Decode(
        'ChtTZW5kQWN0aW9uUGxhbkVtYWlsUmVzcG9uc2USHwoLZGVsaXZlcnlfaWQYASABKAlSCmRlbG'
        'l2ZXJ5SWQ=');

@$core.Deprecated('Use sendInvitationEmailRequestDescriptor instead')
const SendInvitationEmailRequest$json = {
  '1': 'SendInvitationEmailRequest',
  '2': [
    {'1': 'recipient_email', '3': 1, '4': 1, '5': 9, '10': 'recipientEmail'},
    {
      '1': 'organization_name',
      '3': 2,
      '4': 1,
      '5': 9,
      '10': 'organizationName'
    },
    {
      '1': 'inviter_first_name',
      '3': 3,
      '4': 1,
      '5': 9,
      '10': 'inviterFirstName'
    },
    {'1': 'accept_url', '3': 4, '4': 1, '5': 9, '10': 'acceptUrl'},
    {'1': 'expires_at_iso', '3': 5, '4': 1, '5': 9, '10': 'expiresAtIso'},
    {'1': 'locale', '3': 6, '4': 1, '5': 9, '10': 'locale'},
    {'1': 'invited_role', '3': 7, '4': 1, '5': 9, '10': 'invitedRole'},
  ],
};

/// Descriptor for `SendInvitationEmailRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sendInvitationEmailRequestDescriptor = $convert.base64Decode(
    'ChpTZW5kSW52aXRhdGlvbkVtYWlsUmVxdWVzdBInCg9yZWNpcGllbnRfZW1haWwYASABKAlSDn'
    'JlY2lwaWVudEVtYWlsEisKEW9yZ2FuaXphdGlvbl9uYW1lGAIgASgJUhBvcmdhbml6YXRpb25O'
    'YW1lEiwKEmludml0ZXJfZmlyc3RfbmFtZRgDIAEoCVIQaW52aXRlckZpcnN0TmFtZRIdCgphY2'
    'NlcHRfdXJsGAQgASgJUglhY2NlcHRVcmwSJAoOZXhwaXJlc19hdF9pc28YBSABKAlSDGV4cGly'
    'ZXNBdElzbxIWCgZsb2NhbGUYBiABKAlSBmxvY2FsZRIhCgxpbnZpdGVkX3JvbGUYByABKAlSC2'
    'ludml0ZWRSb2xl');

@$core.Deprecated('Use sendEmailVerificationRequestDescriptor instead')
const SendEmailVerificationRequest$json = {
  '1': 'SendEmailVerificationRequest',
  '2': [
    {'1': 'recipient_email', '3': 1, '4': 1, '5': 9, '10': 'recipientEmail'},
    {'1': 'first_name', '3': 2, '4': 1, '5': 9, '10': 'firstName'},
    {'1': 'verify_url', '3': 3, '4': 1, '5': 9, '10': 'verifyUrl'},
    {'1': 'expires_at_iso', '3': 4, '4': 1, '5': 9, '10': 'expiresAtIso'},
    {'1': 'locale', '3': 5, '4': 1, '5': 9, '10': 'locale'},
  ],
};

/// Descriptor for `SendEmailVerificationRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sendEmailVerificationRequestDescriptor = $convert.base64Decode(
    'ChxTZW5kRW1haWxWZXJpZmljYXRpb25SZXF1ZXN0EicKD3JlY2lwaWVudF9lbWFpbBgBIAEoCV'
    'IOcmVjaXBpZW50RW1haWwSHQoKZmlyc3RfbmFtZRgCIAEoCVIJZmlyc3ROYW1lEh0KCnZlcmlm'
    'eV91cmwYAyABKAlSCXZlcmlmeVVybBIkCg5leHBpcmVzX2F0X2lzbxgEIAEoCVIMZXhwaXJlc0'
    'F0SXNvEhYKBmxvY2FsZRgFIAEoCVIGbG9jYWxl');

@$core.Deprecated('Use sendQuotaWarningRequestDescriptor instead')
const SendQuotaWarningRequest$json = {
  '1': 'SendQuotaWarningRequest',
  '2': [
    {'1': 'recipient_email', '3': 1, '4': 1, '5': 9, '10': 'recipientEmail'},
    {'1': 'first_name', '3': 2, '4': 1, '5': 9, '10': 'firstName'},
    {
      '1': 'organization_name',
      '3': 3,
      '4': 1,
      '5': 9,
      '10': 'organizationName'
    },
    {'1': 'usage_percent', '3': 4, '4': 1, '5': 5, '10': 'usagePercent'},
    {'1': 'tokens_remaining', '3': 5, '4': 1, '5': 5, '10': 'tokensRemaining'},
    {'1': 'plan_tier', '3': 6, '4': 1, '5': 9, '10': 'planTier'},
    {'1': 'plan_cycle', '3': 7, '4': 1, '5': 9, '10': 'planCycle'},
    {'1': 'period_end_iso', '3': 8, '4': 1, '5': 9, '10': 'periodEndIso'},
    {'1': 'billing_url', '3': 9, '4': 1, '5': 9, '10': 'billingUrl'},
    {'1': 'locale', '3': 10, '4': 1, '5': 9, '10': 'locale'},
  ],
};

/// Descriptor for `SendQuotaWarningRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List sendQuotaWarningRequestDescriptor = $convert.base64Decode(
    'ChdTZW5kUXVvdGFXYXJuaW5nUmVxdWVzdBInCg9yZWNpcGllbnRfZW1haWwYASABKAlSDnJlY2'
    'lwaWVudEVtYWlsEh0KCmZpcnN0X25hbWUYAiABKAlSCWZpcnN0TmFtZRIrChFvcmdhbml6YXRp'
    'b25fbmFtZRgDIAEoCVIQb3JnYW5pemF0aW9uTmFtZRIjCg11c2FnZV9wZXJjZW50GAQgASgFUg'
    'x1c2FnZVBlcmNlbnQSKQoQdG9rZW5zX3JlbWFpbmluZxgFIAEoBVIPdG9rZW5zUmVtYWluaW5n'
    'EhsKCXBsYW5fdGllchgGIAEoCVIIcGxhblRpZXISHQoKcGxhbl9jeWNsZRgHIAEoCVIJcGxhbk'
    'N5Y2xlEiQKDnBlcmlvZF9lbmRfaXNvGAggASgJUgxwZXJpb2RFbmRJc28SHwoLYmlsbGluZ191'
    'cmwYCSABKAlSCmJpbGxpbmdVcmwSFgoGbG9jYWxlGAogASgJUgZsb2NhbGU=');

@$core.Deprecated('Use registerFCMTokenRequestDescriptor instead')
const RegisterFCMTokenRequest$json = {
  '1': 'RegisterFCMTokenRequest',
  '2': [
    {'1': 'token', '3': 1, '4': 1, '5': 9, '10': 'token'},
    {
      '1': 'platform',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.notification.v1.Platform',
      '10': 'platform'
    },
    {'1': 'app_version', '3': 3, '4': 1, '5': 9, '10': 'appVersion'},
    {'1': 'device_model', '3': 4, '4': 1, '5': 9, '10': 'deviceModel'},
    {'1': 'locale', '3': 5, '4': 1, '5': 9, '10': 'locale'},
  ],
};

/// Descriptor for `RegisterFCMTokenRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List registerFCMTokenRequestDescriptor = $convert.base64Decode(
    'ChdSZWdpc3RlckZDTVRva2VuUmVxdWVzdBIUCgV0b2tlbhgBIAEoCVIFdG9rZW4SNQoIcGxhdG'
    'Zvcm0YAiABKA4yGS5ub3RpZmljYXRpb24udjEuUGxhdGZvcm1SCHBsYXRmb3JtEh8KC2FwcF92'
    'ZXJzaW9uGAMgASgJUgphcHBWZXJzaW9uEiEKDGRldmljZV9tb2RlbBgEIAEoCVILZGV2aWNlTW'
    '9kZWwSFgoGbG9jYWxlGAUgASgJUgZsb2NhbGU=');

@$core.Deprecated('Use registerFCMTokenResponseDescriptor instead')
const RegisterFCMTokenResponse$json = {
  '1': 'RegisterFCMTokenResponse',
  '2': [
    {'1': 'token_id', '3': 1, '4': 1, '5': 9, '10': 'tokenId'},
    {
      '1': 'already_registered',
      '3': 2,
      '4': 1,
      '5': 8,
      '10': 'alreadyRegistered'
    },
  ],
};

/// Descriptor for `RegisterFCMTokenResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List registerFCMTokenResponseDescriptor =
    $convert.base64Decode(
        'ChhSZWdpc3RlckZDTVRva2VuUmVzcG9uc2USGQoIdG9rZW5faWQYASABKAlSB3Rva2VuSWQSLQ'
        'oSYWxyZWFkeV9yZWdpc3RlcmVkGAIgASgIUhFhbHJlYWR5UmVnaXN0ZXJlZA==');

@$core.Deprecated('Use removeFCMTokenRequestDescriptor instead')
const RemoveFCMTokenRequest$json = {
  '1': 'RemoveFCMTokenRequest',
  '2': [
    {'1': 'token', '3': 1, '4': 1, '5': 9, '10': 'token'},
  ],
};

/// Descriptor for `RemoveFCMTokenRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List removeFCMTokenRequestDescriptor =
    $convert.base64Decode(
        'ChVSZW1vdmVGQ01Ub2tlblJlcXVlc3QSFAoFdG9rZW4YASABKAlSBXRva2Vu');

@$core.Deprecated('Use getUnreadCountResponseDescriptor instead')
const GetUnreadCountResponse$json = {
  '1': 'GetUnreadCountResponse',
  '2': [
    {'1': 'count', '3': 1, '4': 1, '5': 5, '10': 'count'},
  ],
};

/// Descriptor for `GetUnreadCountResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getUnreadCountResponseDescriptor =
    $convert.base64Decode(
        'ChZHZXRVbnJlYWRDb3VudFJlc3BvbnNlEhQKBWNvdW50GAEgASgFUgVjb3VudA==');

@$core.Deprecated('Use healthCheckResponseDescriptor instead')
const HealthCheckResponse$json = {
  '1': 'HealthCheckResponse',
  '2': [
    {'1': 'ok', '3': 1, '4': 1, '5': 8, '10': 'ok'},
    {'1': 'version', '3': 2, '4': 1, '5': 9, '10': 'version'},
  ],
};

/// Descriptor for `HealthCheckResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List healthCheckResponseDescriptor = $convert.base64Decode(
    'ChNIZWFsdGhDaGVja1Jlc3BvbnNlEg4KAm9rGAEgASgIUgJvaxIYCgd2ZXJzaW9uGAIgASgJUg'
    'd2ZXJzaW9u');
