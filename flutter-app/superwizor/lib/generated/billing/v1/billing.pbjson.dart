// This is a generated file - do not edit.
//
// Generated from billing/v1/billing.proto.

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

@$core.Deprecated('Use checkQuotaRequestDescriptor instead')
const CheckQuotaRequest$json = {
  '1': 'CheckQuotaRequest',
  '2': [
    {'1': 'organization_id', '3': 1, '4': 1, '5': 9, '10': 'organizationId'},
    {'1': 'therapist_id', '3': 2, '4': 1, '5': 9, '10': 'therapistId'},
    {'1': 'usage_type', '3': 3, '4': 1, '5': 9, '10': 'usageType'},
    {'1': 'amount', '3': 4, '4': 1, '5': 5, '10': 'amount'},
  ],
};

/// Descriptor for `CheckQuotaRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List checkQuotaRequestDescriptor = $convert.base64Decode(
    'ChFDaGVja1F1b3RhUmVxdWVzdBInCg9vcmdhbml6YXRpb25faWQYASABKAlSDm9yZ2FuaXphdG'
    'lvbklkEiEKDHRoZXJhcGlzdF9pZBgCIAEoCVILdGhlcmFwaXN0SWQSHQoKdXNhZ2VfdHlwZRgD'
    'IAEoCVIJdXNhZ2VUeXBlEhYKBmFtb3VudBgEIAEoBVIGYW1vdW50');

@$core.Deprecated('Use quotaDecisionDescriptor instead')
const QuotaDecision$json = {
  '1': 'QuotaDecision',
  '2': [
    {'1': 'allowed', '3': 1, '4': 1, '5': 8, '10': 'allowed'},
    {'1': 'reason', '3': 2, '4': 1, '5': 9, '10': 'reason'},
    {'1': 'remaining', '3': 3, '4': 1, '5': 5, '10': 'remaining'},
    {'1': 'limit', '3': 4, '4': 1, '5': 5, '10': 'limit'},
  ],
};

/// Descriptor for `QuotaDecision`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List quotaDecisionDescriptor = $convert.base64Decode(
    'Cg1RdW90YURlY2lzaW9uEhgKB2FsbG93ZWQYASABKAhSB2FsbG93ZWQSFgoGcmVhc29uGAIgAS'
    'gJUgZyZWFzb24SHAoJcmVtYWluaW5nGAMgASgFUglyZW1haW5pbmcSFAoFbGltaXQYBCABKAVS'
    'BWxpbWl0');

@$core.Deprecated('Use incrementUsageRequestDescriptor instead')
const IncrementUsageRequest$json = {
  '1': 'IncrementUsageRequest',
  '2': [
    {'1': 'organization_id', '3': 1, '4': 1, '5': 9, '10': 'organizationId'},
    {'1': 'therapist_id', '3': 2, '4': 1, '5': 9, '10': 'therapistId'},
    {'1': 'usage_type', '3': 3, '4': 1, '5': 9, '10': 'usageType'},
    {'1': 'amount', '3': 4, '4': 1, '5': 5, '10': 'amount'},
    {'1': 'session_id', '3': 5, '4': 1, '5': 9, '10': 'sessionId'},
    {'1': 'idempotency_key', '3': 6, '4': 1, '5': 9, '10': 'idempotencyKey'},
  ],
};

/// Descriptor for `IncrementUsageRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List incrementUsageRequestDescriptor = $convert.base64Decode(
    'ChVJbmNyZW1lbnRVc2FnZVJlcXVlc3QSJwoPb3JnYW5pemF0aW9uX2lkGAEgASgJUg5vcmdhbm'
    'l6YXRpb25JZBIhCgx0aGVyYXBpc3RfaWQYAiABKAlSC3RoZXJhcGlzdElkEh0KCnVzYWdlX3R5'
    'cGUYAyABKAlSCXVzYWdlVHlwZRIWCgZhbW91bnQYBCABKAVSBmFtb3VudBIdCgpzZXNzaW9uX2'
    'lkGAUgASgJUglzZXNzaW9uSWQSJwoPaWRlbXBvdGVuY3lfa2V5GAYgASgJUg5pZGVtcG90ZW5j'
    'eUtleQ==');

@$core.Deprecated('Use getSubscriptionRequestDescriptor instead')
const GetSubscriptionRequest$json = {
  '1': 'GetSubscriptionRequest',
  '2': [
    {'1': 'organization_id', '3': 1, '4': 1, '5': 9, '10': 'organizationId'},
  ],
};

/// Descriptor for `GetSubscriptionRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getSubscriptionRequestDescriptor =
    $convert.base64Decode(
        'ChZHZXRTdWJzY3JpcHRpb25SZXF1ZXN0EicKD29yZ2FuaXphdGlvbl9pZBgBIAEoCVIOb3JnYW'
        '5pemF0aW9uSWQ=');

@$core.Deprecated('Use subscriptionDescriptor instead')
const Subscription$json = {
  '1': 'Subscription',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'plan_tier', '3': 2, '4': 1, '5': 9, '10': 'planTier'},
    {'1': 'status', '3': 3, '4': 1, '5': 9, '10': 'status'},
    {
      '1': 'sessions_per_month_limit',
      '3': 4,
      '4': 1,
      '5': 5,
      '10': 'sessionsPerMonthLimit'
    },
    {
      '1': 'sessions_used_this_period',
      '3': 5,
      '4': 1,
      '5': 5,
      '10': 'sessionsUsedThisPeriod'
    },
  ],
};

/// Descriptor for `Subscription`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List subscriptionDescriptor = $convert.base64Decode(
    'CgxTdWJzY3JpcHRpb24SDgoCaWQYASABKAlSAmlkEhsKCXBsYW5fdGllchgCIAEoCVIIcGxhbl'
    'RpZXISFgoGc3RhdHVzGAMgASgJUgZzdGF0dXMSNwoYc2Vzc2lvbnNfcGVyX21vbnRoX2xpbWl0'
    'GAQgASgFUhVzZXNzaW9uc1Blck1vbnRoTGltaXQSOQoZc2Vzc2lvbnNfdXNlZF90aGlzX3Blcm'
    'lvZBgFIAEoBVIWc2Vzc2lvbnNVc2VkVGhpc1BlcmlvZA==');
