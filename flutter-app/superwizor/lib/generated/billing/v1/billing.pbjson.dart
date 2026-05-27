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
    {'1': 'remaining_tokens', '3': 5, '4': 1, '5': 5, '10': 'remainingTokens'},
    {'1': 'limit_tokens', '3': 6, '4': 1, '5': 5, '10': 'limitTokens'},
    {
      '1': 'period_end',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'periodEnd'
    },
  ],
};

/// Descriptor for `QuotaDecision`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List quotaDecisionDescriptor = $convert.base64Decode(
    'Cg1RdW90YURlY2lzaW9uEhgKB2FsbG93ZWQYASABKAhSB2FsbG93ZWQSFgoGcmVhc29uGAIgAS'
    'gJUgZyZWFzb24SHAoJcmVtYWluaW5nGAMgASgFUglyZW1haW5pbmcSFAoFbGltaXQYBCABKAVS'
    'BWxpbWl0EikKEHJlbWFpbmluZ190b2tlbnMYBSABKAVSD3JlbWFpbmluZ1Rva2VucxIhCgxsaW'
    '1pdF90b2tlbnMYBiABKAVSC2xpbWl0VG9rZW5zEjkKCnBlcmlvZF9lbmQYByABKAsyGi5nb29n'
    'bGUucHJvdG9idWYuVGltZXN0YW1wUglwZXJpb2RFbmQ=');

@$core.Deprecated('Use reserveCreditRequestDescriptor instead')
const ReserveCreditRequest$json = {
  '1': 'ReserveCreditRequest',
  '2': [
    {'1': 'session_id', '3': 1, '4': 1, '5': 9, '10': 'sessionId'},
    {'1': 'organization_id', '3': 2, '4': 1, '5': 9, '10': 'organizationId'},
    {'1': 'therapist_id', '3': 3, '4': 1, '5': 9, '10': 'therapistId'},
    {'1': 'estimated_tokens', '3': 4, '4': 1, '5': 5, '10': 'estimatedTokens'},
    {'1': 'idempotency_key', '3': 5, '4': 1, '5': 9, '10': 'idempotencyKey'},
  ],
};

/// Descriptor for `ReserveCreditRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List reserveCreditRequestDescriptor = $convert.base64Decode(
    'ChRSZXNlcnZlQ3JlZGl0UmVxdWVzdBIdCgpzZXNzaW9uX2lkGAEgASgJUglzZXNzaW9uSWQSJw'
    'oPb3JnYW5pemF0aW9uX2lkGAIgASgJUg5vcmdhbml6YXRpb25JZBIhCgx0aGVyYXBpc3RfaWQY'
    'AyABKAlSC3RoZXJhcGlzdElkEikKEGVzdGltYXRlZF90b2tlbnMYBCABKAVSD2VzdGltYXRlZF'
    'Rva2VucxInCg9pZGVtcG90ZW5jeV9rZXkYBSABKAlSDmlkZW1wb3RlbmN5S2V5');

@$core.Deprecated('Use reservationDescriptor instead')
const Reservation$json = {
  '1': 'Reservation',
  '2': [
    {'1': 'reservation_id', '3': 1, '4': 1, '5': 9, '10': 'reservationId'},
    {'1': 'session_id', '3': 2, '4': 1, '5': 9, '10': 'sessionId'},
    {'1': 'tokens_reserved', '3': 3, '4': 1, '5': 5, '10': 'tokensReserved'},
    {
      '1': 'expires_at',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'expiresAt'
    },
    {
      '1': 'state_after',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.billing.v1.Subscription',
      '10': 'stateAfter'
    },
  ],
};

/// Descriptor for `Reservation`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List reservationDescriptor = $convert.base64Decode(
    'CgtSZXNlcnZhdGlvbhIlCg5yZXNlcnZhdGlvbl9pZBgBIAEoCVINcmVzZXJ2YXRpb25JZBIdCg'
    'pzZXNzaW9uX2lkGAIgASgJUglzZXNzaW9uSWQSJwoPdG9rZW5zX3Jlc2VydmVkGAMgASgFUg50'
    'b2tlbnNSZXNlcnZlZBI5CgpleHBpcmVzX2F0GAQgASgLMhouZ29vZ2xlLnByb3RvYnVmLlRpbW'
    'VzdGFtcFIJZXhwaXJlc0F0EjkKC3N0YXRlX2FmdGVyGAUgASgLMhguYmlsbGluZy52MS5TdWJz'
    'Y3JpcHRpb25SCnN0YXRlQWZ0ZXI=');

@$core.Deprecated('Use commitUsageRequestDescriptor instead')
const CommitUsageRequest$json = {
  '1': 'CommitUsageRequest',
  '2': [
    {'1': 'session_id', '3': 1, '4': 1, '5': 9, '10': 'sessionId'},
    {'1': 'organization_id', '3': 2, '4': 1, '5': 9, '10': 'organizationId'},
    {'1': 'therapist_id', '3': 3, '4': 1, '5': 9, '10': 'therapistId'},
    {'1': 'duration_seconds', '3': 4, '4': 1, '5': 5, '10': 'durationSeconds'},
    {'1': 'usage_type', '3': 5, '4': 1, '5': 9, '10': 'usageType'},
    {'1': 'idempotency_key', '3': 6, '4': 1, '5': 9, '10': 'idempotencyKey'},
  ],
};

/// Descriptor for `CommitUsageRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List commitUsageRequestDescriptor = $convert.base64Decode(
    'ChJDb21taXRVc2FnZVJlcXVlc3QSHQoKc2Vzc2lvbl9pZBgBIAEoCVIJc2Vzc2lvbklkEicKD2'
    '9yZ2FuaXphdGlvbl9pZBgCIAEoCVIOb3JnYW5pemF0aW9uSWQSIQoMdGhlcmFwaXN0X2lkGAMg'
    'ASgJUgt0aGVyYXBpc3RJZBIpChBkdXJhdGlvbl9zZWNvbmRzGAQgASgFUg9kdXJhdGlvblNlY2'
    '9uZHMSHQoKdXNhZ2VfdHlwZRgFIAEoCVIJdXNhZ2VUeXBlEicKD2lkZW1wb3RlbmN5X2tleRgG'
    'IAEoCVIOaWRlbXBvdGVuY3lLZXk=');

@$core.Deprecated('Use usageCommitDescriptor instead')
const UsageCommit$json = {
  '1': 'UsageCommit',
  '2': [
    {'1': 'tokens_consumed', '3': 1, '4': 1, '5': 5, '10': 'tokensConsumed'},
    {'1': 'remaining_tokens', '3': 2, '4': 1, '5': 5, '10': 'remainingTokens'},
    {'1': 'limit_tokens', '3': 3, '4': 1, '5': 5, '10': 'limitTokens'},
    {
      '1': 'state_after',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.billing.v1.Subscription',
      '10': 'stateAfter'
    },
  ],
};

/// Descriptor for `UsageCommit`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List usageCommitDescriptor = $convert.base64Decode(
    'CgtVc2FnZUNvbW1pdBInCg90b2tlbnNfY29uc3VtZWQYASABKAVSDnRva2Vuc0NvbnN1bWVkEi'
    'kKEHJlbWFpbmluZ190b2tlbnMYAiABKAVSD3JlbWFpbmluZ1Rva2VucxIhCgxsaW1pdF90b2tl'
    'bnMYAyABKAVSC2xpbWl0VG9rZW5zEjkKC3N0YXRlX2FmdGVyGAQgASgLMhguYmlsbGluZy52MS'
    '5TdWJzY3JpcHRpb25SCnN0YXRlQWZ0ZXI=');

@$core.Deprecated('Use releaseCreditRequestDescriptor instead')
const ReleaseCreditRequest$json = {
  '1': 'ReleaseCreditRequest',
  '2': [
    {'1': 'session_id', '3': 1, '4': 1, '5': 9, '10': 'sessionId'},
    {'1': 'organization_id', '3': 2, '4': 1, '5': 9, '10': 'organizationId'},
    {'1': 'reason', '3': 3, '4': 1, '5': 9, '10': 'reason'},
  ],
};

/// Descriptor for `ReleaseCreditRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List releaseCreditRequestDescriptor = $convert.base64Decode(
    'ChRSZWxlYXNlQ3JlZGl0UmVxdWVzdBIdCgpzZXNzaW9uX2lkGAEgASgJUglzZXNzaW9uSWQSJw'
    'oPb3JnYW5pemF0aW9uX2lkGAIgASgJUg5vcmdhbml6YXRpb25JZBIWCgZyZWFzb24YAyABKAlS'
    'BnJlYXNvbg==');

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
  '7': {'3': true},
};

/// Descriptor for `IncrementUsageRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List incrementUsageRequestDescriptor = $convert.base64Decode(
    'ChVJbmNyZW1lbnRVc2FnZVJlcXVlc3QSJwoPb3JnYW5pemF0aW9uX2lkGAEgASgJUg5vcmdhbm'
    'l6YXRpb25JZBIhCgx0aGVyYXBpc3RfaWQYAiABKAlSC3RoZXJhcGlzdElkEh0KCnVzYWdlX3R5'
    'cGUYAyABKAlSCXVzYWdlVHlwZRIWCgZhbW91bnQYBCABKAVSBmFtb3VudBIdCgpzZXNzaW9uX2'
    'lkGAUgASgJUglzZXNzaW9uSWQSJwoPaWRlbXBvdGVuY3lfa2V5GAYgASgJUg5pZGVtcG90ZW5j'
    'eUtleToCGAE=');

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
    {'1': 'tokens_per_period', '3': 6, '4': 1, '5': 5, '10': 'tokensPerPeriod'},
    {
      '1': 'tokens_used_this_period',
      '3': 7,
      '4': 1,
      '5': 5,
      '10': 'tokensUsedThisPeriod'
    },
    {
      '1': 'tokens_reserved_this_period',
      '3': 8,
      '4': 1,
      '5': 5,
      '10': 'tokensReservedThisPeriod'
    },
    {
      '1': 'current_period_start',
      '3': 9,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'currentPeriodStart'
    },
    {
      '1': 'current_period_end',
      '3': 10,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'currentPeriodEnd'
    },
    {'1': 'plan_cycle', '3': 11, '4': 1, '5': 9, '10': 'planCycle'},
    {'1': 'tokens_remaining', '3': 12, '4': 1, '5': 5, '10': 'tokensRemaining'},
  ],
};

/// Descriptor for `Subscription`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List subscriptionDescriptor = $convert.base64Decode(
    'CgxTdWJzY3JpcHRpb24SDgoCaWQYASABKAlSAmlkEhsKCXBsYW5fdGllchgCIAEoCVIIcGxhbl'
    'RpZXISFgoGc3RhdHVzGAMgASgJUgZzdGF0dXMSNwoYc2Vzc2lvbnNfcGVyX21vbnRoX2xpbWl0'
    'GAQgASgFUhVzZXNzaW9uc1Blck1vbnRoTGltaXQSOQoZc2Vzc2lvbnNfdXNlZF90aGlzX3Blcm'
    'lvZBgFIAEoBVIWc2Vzc2lvbnNVc2VkVGhpc1BlcmlvZBIqChF0b2tlbnNfcGVyX3BlcmlvZBgG'
    'IAEoBVIPdG9rZW5zUGVyUGVyaW9kEjUKF3Rva2Vuc191c2VkX3RoaXNfcGVyaW9kGAcgASgFUh'
    'R0b2tlbnNVc2VkVGhpc1BlcmlvZBI9Cht0b2tlbnNfcmVzZXJ2ZWRfdGhpc19wZXJpb2QYCCAB'
    'KAVSGHRva2Vuc1Jlc2VydmVkVGhpc1BlcmlvZBJMChRjdXJyZW50X3BlcmlvZF9zdGFydBgJIA'
    'EoCzIaLmdvb2dsZS5wcm90b2J1Zi5UaW1lc3RhbXBSEmN1cnJlbnRQZXJpb2RTdGFydBJIChJj'
    'dXJyZW50X3BlcmlvZF9lbmQYCiABKAsyGi5nb29nbGUucHJvdG9idWYuVGltZXN0YW1wUhBjdX'
    'JyZW50UGVyaW9kRW5kEh0KCnBsYW5fY3ljbGUYCyABKAlSCXBsYW5DeWNsZRIpChB0b2tlbnNf'
    'cmVtYWluaW5nGAwgASgFUg90b2tlbnNSZW1haW5pbmc=');
