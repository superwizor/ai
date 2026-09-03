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
    {'1': 'therapist_id', '3': 2, '4': 1, '5': 9, '10': 'therapistId'},
  ],
};

/// Descriptor for `GetSubscriptionRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getSubscriptionRequestDescriptor =
    $convert.base64Decode(
        'ChZHZXRTdWJzY3JpcHRpb25SZXF1ZXN0EicKD29yZ2FuaXphdGlvbl9pZBgBIAEoCVIOb3JnYW'
        '5pemF0aW9uSWQSIQoMdGhlcmFwaXN0X2lkGAIgASgJUgt0aGVyYXBpc3RJZA==');

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
    {
      '1': 'cancel_at_period_end',
      '3': 13,
      '4': 1,
      '5': 8,
      '10': 'cancelAtPeriodEnd'
    },
    {
      '1': 'canceled_at',
      '3': 14,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'canceledAt'
    },
    {'1': 'billing_provider', '3': 15, '4': 1, '5': 9, '10': 'billingProvider'},
    {
      '1': 'grace_until',
      '3': 16,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'graceUntil'
    },
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
    'cmVtYWluaW5nGAwgASgFUg90b2tlbnNSZW1haW5pbmcSLwoUY2FuY2VsX2F0X3BlcmlvZF9lbm'
    'QYDSABKAhSEWNhbmNlbEF0UGVyaW9kRW5kEjsKC2NhbmNlbGVkX2F0GA4gASgLMhouZ29vZ2xl'
    'LnByb3RvYnVmLlRpbWVzdGFtcFIKY2FuY2VsZWRBdBIpChBiaWxsaW5nX3Byb3ZpZGVyGA8gAS'
    'gJUg9iaWxsaW5nUHJvdmlkZXISOwoLZ3JhY2VfdW50aWwYECABKAsyGi5nb29nbGUucHJvdG9i'
    'dWYuVGltZXN0YW1wUgpncmFjZVVudGls');

@$core.Deprecated('Use adminResetTokensRequestDescriptor instead')
const AdminResetTokensRequest$json = {
  '1': 'AdminResetTokensRequest',
  '2': [
    {'1': 'organization_id', '3': 1, '4': 1, '5': 9, '10': 'organizationId'},
    {'1': 'tokens_used', '3': 2, '4': 1, '5': 5, '10': 'tokensUsed'},
    {'1': 'tokens_limit', '3': 3, '4': 1, '5': 5, '10': 'tokensLimit'},
    {'1': 'reason', '3': 4, '4': 1, '5': 9, '10': 'reason'},
    {'1': 'idempotency_key', '3': 5, '4': 1, '5': 9, '10': 'idempotencyKey'},
    {'1': 'therapist_id', '3': 6, '4': 1, '5': 9, '10': 'therapistId'},
  ],
};

/// Descriptor for `AdminResetTokensRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List adminResetTokensRequestDescriptor = $convert.base64Decode(
    'ChdBZG1pblJlc2V0VG9rZW5zUmVxdWVzdBInCg9vcmdhbml6YXRpb25faWQYASABKAlSDm9yZ2'
    'FuaXphdGlvbklkEh8KC3Rva2Vuc191c2VkGAIgASgFUgp0b2tlbnNVc2VkEiEKDHRva2Vuc19s'
    'aW1pdBgDIAEoBVILdG9rZW5zTGltaXQSFgoGcmVhc29uGAQgASgJUgZyZWFzb24SJwoPaWRlbX'
    'BvdGVuY3lfa2V5GAUgASgJUg5pZGVtcG90ZW5jeUtleRIhCgx0aGVyYXBpc3RfaWQYBiABKAlS'
    'C3RoZXJhcGlzdElk');

@$core.Deprecated('Use planInfoDescriptor instead')
const PlanInfo$json = {
  '1': 'PlanInfo',
  '2': [
    {'1': 'plan_id', '3': 1, '4': 1, '5': 9, '10': 'planId'},
    {'1': 'tier', '3': 2, '4': 1, '5': 9, '10': 'tier'},
    {'1': 'cycle', '3': 3, '4': 1, '5': 9, '10': 'cycle'},
    {'1': 'display_name', '3': 4, '4': 1, '5': 9, '10': 'displayName'},
    {'1': 'price_gross', '3': 5, '4': 1, '5': 9, '10': 'priceGross'},
    {'1': 'currency_code', '3': 6, '4': 1, '5': 9, '10': 'currencyCode'},
    {'1': 'tokens_per_period', '3': 7, '4': 1, '5': 5, '10': 'tokensPerPeriod'},
  ],
};

/// Descriptor for `PlanInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List planInfoDescriptor = $convert.base64Decode(
    'CghQbGFuSW5mbxIXCgdwbGFuX2lkGAEgASgJUgZwbGFuSWQSEgoEdGllchgCIAEoCVIEdGllch'
    'IUCgVjeWNsZRgDIAEoCVIFY3ljbGUSIQoMZGlzcGxheV9uYW1lGAQgASgJUgtkaXNwbGF5TmFt'
    'ZRIfCgtwcmljZV9ncm9zcxgFIAEoCVIKcHJpY2VHcm9zcxIjCg1jdXJyZW5jeV9jb2RlGAYgAS'
    'gJUgxjdXJyZW5jeUNvZGUSKgoRdG9rZW5zX3Blcl9wZXJpb2QYByABKAVSD3Rva2Vuc1BlclBl'
    'cmlvZA==');

@$core.Deprecated('Use adminListPlansResponseDescriptor instead')
const AdminListPlansResponse$json = {
  '1': 'AdminListPlansResponse',
  '2': [
    {
      '1': 'plans',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.billing.v1.PlanInfo',
      '10': 'plans'
    },
  ],
};

/// Descriptor for `AdminListPlansResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List adminListPlansResponseDescriptor =
    $convert.base64Decode(
        'ChZBZG1pbkxpc3RQbGFuc1Jlc3BvbnNlEioKBXBsYW5zGAEgAygLMhQuYmlsbGluZy52MS5QbG'
        'FuSW5mb1IFcGxhbnM=');

@$core.Deprecated('Use adminGetOrgSeatUsageRequestDescriptor instead')
const AdminGetOrgSeatUsageRequest$json = {
  '1': 'AdminGetOrgSeatUsageRequest',
  '2': [
    {'1': 'organization_id', '3': 1, '4': 1, '5': 9, '10': 'organizationId'},
  ],
};

/// Descriptor for `AdminGetOrgSeatUsageRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List adminGetOrgSeatUsageRequestDescriptor =
    $convert.base64Decode(
        'ChtBZG1pbkdldE9yZ1NlYXRVc2FnZVJlcXVlc3QSJwoPb3JnYW5pemF0aW9uX2lkGAEgASgJUg'
        '5vcmdhbml6YXRpb25JZA==');

@$core.Deprecated('Use seatAllocationSpecDescriptor instead')
const SeatAllocationSpec$json = {
  '1': 'SeatAllocationSpec',
  '2': [
    {'1': 'plan_id', '3': 1, '4': 1, '5': 9, '10': 'planId'},
    {'1': 'seats', '3': 2, '4': 1, '5': 5, '10': 'seats'},
    {
      '1': 'price_gross_per_seat',
      '3': 3,
      '4': 1,
      '5': 9,
      '10': 'priceGrossPerSeat'
    },
  ],
};

/// Descriptor for `SeatAllocationSpec`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List seatAllocationSpecDescriptor = $convert.base64Decode(
    'ChJTZWF0QWxsb2NhdGlvblNwZWMSFwoHcGxhbl9pZBgBIAEoCVIGcGxhbklkEhQKBXNlYXRzGA'
    'IgASgFUgVzZWF0cxIvChRwcmljZV9ncm9zc19wZXJfc2VhdBgDIAEoCVIRcHJpY2VHcm9zc1Bl'
    'clNlYXQ=');

@$core.Deprecated('Use adminSetSeatAllocationsRequestDescriptor instead')
const AdminSetSeatAllocationsRequest$json = {
  '1': 'AdminSetSeatAllocationsRequest',
  '2': [
    {'1': 'organization_id', '3': 1, '4': 1, '5': 9, '10': 'organizationId'},
    {
      '1': 'allocations',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.billing.v1.SeatAllocationSpec',
      '10': 'allocations'
    },
    {
      '1': 'subscription_start',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'subscriptionStart'
    },
    {'1': 'reason', '3': 15, '4': 1, '5': 9, '10': 'reason'},
    {'1': 'idempotency_key', '3': 16, '4': 1, '5': 9, '10': 'idempotencyKey'},
  ],
};

/// Descriptor for `AdminSetSeatAllocationsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List adminSetSeatAllocationsRequestDescriptor = $convert.base64Decode(
    'Ch5BZG1pblNldFNlYXRBbGxvY2F0aW9uc1JlcXVlc3QSJwoPb3JnYW5pemF0aW9uX2lkGAEgAS'
    'gJUg5vcmdhbml6YXRpb25JZBJACgthbGxvY2F0aW9ucxgCIAMoCzIeLmJpbGxpbmcudjEuU2Vh'
    'dEFsbG9jYXRpb25TcGVjUgthbGxvY2F0aW9ucxJJChJzdWJzY3JpcHRpb25fc3RhcnQYAyABKA'
    'syGi5nb29nbGUucHJvdG9idWYuVGltZXN0YW1wUhFzdWJzY3JpcHRpb25TdGFydBIWCgZyZWFz'
    'b24YDyABKAlSBnJlYXNvbhInCg9pZGVtcG90ZW5jeV9rZXkYECABKAlSDmlkZW1wb3RlbmN5S2'
    'V5');

@$core.Deprecated('Use seatAllocationInfoDescriptor instead')
const SeatAllocationInfo$json = {
  '1': 'SeatAllocationInfo',
  '2': [
    {'1': 'allocation_id', '3': 1, '4': 1, '5': 9, '10': 'allocationId'},
    {'1': 'plan_id', '3': 2, '4': 1, '5': 9, '10': 'planId'},
    {'1': 'plan_tier', '3': 3, '4': 1, '5': 9, '10': 'planTier'},
    {'1': 'plan_cycle', '3': 4, '4': 1, '5': 9, '10': 'planCycle'},
    {'1': 'seats', '3': 5, '4': 1, '5': 5, '10': 'seats'},
    {'1': 'seats_assigned', '3': 6, '4': 1, '5': 5, '10': 'seatsAssigned'},
    {'1': 'seats_pending', '3': 7, '4': 1, '5': 5, '10': 'seatsPending'},
    {
      '1': 'price_gross_per_seat',
      '3': 8,
      '4': 1,
      '5': 9,
      '10': 'priceGrossPerSeat'
    },
    {'1': 'currency_code', '3': 9, '4': 1, '5': 9, '10': 'currencyCode'},
    {'1': 'tokens_per_seat', '3': 10, '4': 1, '5': 5, '10': 'tokensPerSeat'},
  ],
};

/// Descriptor for `SeatAllocationInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List seatAllocationInfoDescriptor = $convert.base64Decode(
    'ChJTZWF0QWxsb2NhdGlvbkluZm8SIwoNYWxsb2NhdGlvbl9pZBgBIAEoCVIMYWxsb2NhdGlvbk'
    'lkEhcKB3BsYW5faWQYAiABKAlSBnBsYW5JZBIbCglwbGFuX3RpZXIYAyABKAlSCHBsYW5UaWVy'
    'Eh0KCnBsYW5fY3ljbGUYBCABKAlSCXBsYW5DeWNsZRIUCgVzZWF0cxgFIAEoBVIFc2VhdHMSJQ'
    'oOc2VhdHNfYXNzaWduZWQYBiABKAVSDXNlYXRzQXNzaWduZWQSIwoNc2VhdHNfcGVuZGluZxgH'
    'IAEoBVIMc2VhdHNQZW5kaW5nEi8KFHByaWNlX2dyb3NzX3Blcl9zZWF0GAggASgJUhFwcmljZU'
    'dyb3NzUGVyU2VhdBIjCg1jdXJyZW5jeV9jb2RlGAkgASgJUgxjdXJyZW5jeUNvZGUSJgoPdG9r'
    'ZW5zX3Blcl9zZWF0GAogASgFUg10b2tlbnNQZXJTZWF0');

@$core.Deprecated('Use therapistSeatUsageDescriptor instead')
const TherapistSeatUsage$json = {
  '1': 'TherapistSeatUsage',
  '2': [
    {'1': 'therapist_id', '3': 1, '4': 1, '5': 9, '10': 'therapistId'},
    {'1': 'first_name', '3': 2, '4': 1, '5': 9, '10': 'firstName'},
    {'1': 'last_name', '3': 3, '4': 1, '5': 9, '10': 'lastName'},
    {'1': 'plan_tier', '3': 4, '4': 1, '5': 9, '10': 'planTier'},
    {'1': 'tokens_used', '3': 5, '4': 1, '5': 5, '10': 'tokensUsed'},
    {'1': 'tokens_reserved', '3': 6, '4': 1, '5': 5, '10': 'tokensReserved'},
    {'1': 'tokens_limit', '3': 7, '4': 1, '5': 5, '10': 'tokensLimit'},
    {'1': 'is_active', '3': 8, '4': 1, '5': 8, '10': 'isActive'},
  ],
};

/// Descriptor for `TherapistSeatUsage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List therapistSeatUsageDescriptor = $convert.base64Decode(
    'ChJUaGVyYXBpc3RTZWF0VXNhZ2USIQoMdGhlcmFwaXN0X2lkGAEgASgJUgt0aGVyYXBpc3RJZB'
    'IdCgpmaXJzdF9uYW1lGAIgASgJUglmaXJzdE5hbWUSGwoJbGFzdF9uYW1lGAMgASgJUghsYXN0'
    'TmFtZRIbCglwbGFuX3RpZXIYBCABKAlSCHBsYW5UaWVyEh8KC3Rva2Vuc191c2VkGAUgASgFUg'
    'p0b2tlbnNVc2VkEicKD3Rva2Vuc19yZXNlcnZlZBgGIAEoBVIOdG9rZW5zUmVzZXJ2ZWQSIQoM'
    'dG9rZW5zX2xpbWl0GAcgASgFUgt0b2tlbnNMaW1pdBIbCglpc19hY3RpdmUYCCABKAhSCGlzQW'
    'N0aXZl');

@$core.Deprecated('Use orgSeatSummaryDescriptor instead')
const OrgSeatSummary$json = {
  '1': 'OrgSeatSummary',
  '2': [
    {'1': 'organization_id', '3': 1, '4': 1, '5': 9, '10': 'organizationId'},
    {
      '1': 'allocations',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.billing.v1.SeatAllocationInfo',
      '10': 'allocations'
    },
    {
      '1': 'therapist_usage',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.billing.v1.TherapistSeatUsage',
      '10': 'therapistUsage'
    },
    {
      '1': 'period_start',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'periodStart'
    },
    {
      '1': 'period_end',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'periodEnd'
    },
    {
      '1': 'subscription_status',
      '3': 6,
      '4': 1,
      '5': 9,
      '10': 'subscriptionStatus'
    },
  ],
};

/// Descriptor for `OrgSeatSummary`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List orgSeatSummaryDescriptor = $convert.base64Decode(
    'Cg5PcmdTZWF0U3VtbWFyeRInCg9vcmdhbml6YXRpb25faWQYASABKAlSDm9yZ2FuaXphdGlvbk'
    'lkEkAKC2FsbG9jYXRpb25zGAIgAygLMh4uYmlsbGluZy52MS5TZWF0QWxsb2NhdGlvbkluZm9S'
    'C2FsbG9jYXRpb25zEkcKD3RoZXJhcGlzdF91c2FnZRgDIAMoCzIeLmJpbGxpbmcudjEuVGhlcm'
    'FwaXN0U2VhdFVzYWdlUg50aGVyYXBpc3RVc2FnZRI9CgxwZXJpb2Rfc3RhcnQYBCABKAsyGi5n'
    'b29nbGUucHJvdG9idWYuVGltZXN0YW1wUgtwZXJpb2RTdGFydBI5CgpwZXJpb2RfZW5kGAUgAS'
    'gLMhouZ29vZ2xlLnByb3RvYnVmLlRpbWVzdGFtcFIJcGVyaW9kRW5kEi8KE3N1YnNjcmlwdGlv'
    'bl9zdGF0dXMYBiABKAlSEnN1YnNjcmlwdGlvblN0YXR1cw==');

@$core.Deprecated('Use adminChangePlanRequestDescriptor instead')
const AdminChangePlanRequest$json = {
  '1': 'AdminChangePlanRequest',
  '2': [
    {'1': 'organization_id', '3': 1, '4': 1, '5': 9, '10': 'organizationId'},
    {'1': 'plan_tier', '3': 2, '4': 1, '5': 9, '10': 'planTier'},
    {'1': 'plan_cycle', '3': 3, '4': 1, '5': 9, '10': 'planCycle'},
    {'1': 'reason', '3': 4, '4': 1, '5': 9, '10': 'reason'},
    {'1': 'idempotency_key', '3': 5, '4': 1, '5': 9, '10': 'idempotencyKey'},
  ],
};

/// Descriptor for `AdminChangePlanRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List adminChangePlanRequestDescriptor = $convert.base64Decode(
    'ChZBZG1pbkNoYW5nZVBsYW5SZXF1ZXN0EicKD29yZ2FuaXphdGlvbl9pZBgBIAEoCVIOb3JnYW'
    '5pemF0aW9uSWQSGwoJcGxhbl90aWVyGAIgASgJUghwbGFuVGllchIdCgpwbGFuX2N5Y2xlGAMg'
    'ASgJUglwbGFuQ3ljbGUSFgoGcmVhc29uGAQgASgJUgZyZWFzb24SJwoPaWRlbXBvdGVuY3lfa2'
    'V5GAUgASgJUg5pZGVtcG90ZW5jeUtleQ==');

@$core.Deprecated('Use listInvoicesRequestDescriptor instead')
const ListInvoicesRequest$json = {
  '1': 'ListInvoicesRequest',
  '2': [
    {'1': 'organization_id', '3': 1, '4': 1, '5': 9, '10': 'organizationId'},
  ],
};

/// Descriptor for `ListInvoicesRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listInvoicesRequestDescriptor = $convert.base64Decode(
    'ChNMaXN0SW52b2ljZXNSZXF1ZXN0EicKD29yZ2FuaXphdGlvbl9pZBgBIAEoCVIOb3JnYW5pem'
    'F0aW9uSWQ=');

@$core.Deprecated('Use listInvoicesResponseDescriptor instead')
const ListInvoicesResponse$json = {
  '1': 'ListInvoicesResponse',
  '2': [
    {
      '1': 'invoices',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.billing.v1.Invoice',
      '10': 'invoices'
    },
  ],
};

/// Descriptor for `ListInvoicesResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listInvoicesResponseDescriptor = $convert.base64Decode(
    'ChRMaXN0SW52b2ljZXNSZXNwb25zZRIvCghpbnZvaWNlcxgBIAMoCzITLmJpbGxpbmcudjEuSW'
    '52b2ljZVIIaW52b2ljZXM=');

@$core.Deprecated('Use invoiceDescriptor instead')
const Invoice$json = {
  '1': 'Invoice',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'stripe_invoice_id', '3': 2, '4': 1, '5': 9, '10': 'stripeInvoiceId'},
    {'1': 'amount_paid', '3': 3, '4': 1, '5': 1, '10': 'amountPaid'},
    {'1': 'currency', '3': 4, '4': 1, '5': 9, '10': 'currency'},
    {'1': 'invoice_pdf', '3': 5, '4': 1, '5': 9, '10': 'invoicePdf'},
    {
      '1': 'hosted_invoice_url',
      '3': 6,
      '4': 1,
      '5': 9,
      '10': 'hostedInvoiceUrl'
    },
    {
      '1': 'period_start',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'periodStart'
    },
    {
      '1': 'period_end',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'periodEnd'
    },
    {
      '1': 'created_at',
      '3': 9,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'createdAt'
    },
  ],
};

/// Descriptor for `Invoice`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List invoiceDescriptor = $convert.base64Decode(
    'CgdJbnZvaWNlEg4KAmlkGAEgASgJUgJpZBIqChFzdHJpcGVfaW52b2ljZV9pZBgCIAEoCVIPc3'
    'RyaXBlSW52b2ljZUlkEh8KC2Ftb3VudF9wYWlkGAMgASgBUgphbW91bnRQYWlkEhoKCGN1cnJl'
    'bmN5GAQgASgJUghjdXJyZW5jeRIfCgtpbnZvaWNlX3BkZhgFIAEoCVIKaW52b2ljZVBkZhIsCh'
    'Job3N0ZWRfaW52b2ljZV91cmwYBiABKAlSEGhvc3RlZEludm9pY2VVcmwSPQoMcGVyaW9kX3N0'
    'YXJ0GAcgASgLMhouZ29vZ2xlLnByb3RvYnVmLlRpbWVzdGFtcFILcGVyaW9kU3RhcnQSOQoKcG'
    'VyaW9kX2VuZBgIIAEoCzIaLmdvb2dsZS5wcm90b2J1Zi5UaW1lc3RhbXBSCXBlcmlvZEVuZBI5'
    'CgpjcmVhdGVkX2F0GAkgASgLMhouZ29vZ2xlLnByb3RvYnVmLlRpbWVzdGFtcFIJY3JlYXRlZE'
    'F0');

@$core.Deprecated('Use discountCodeDescriptor instead')
const DiscountCode$json = {
  '1': 'DiscountCode',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'code', '3': 2, '4': 1, '5': 9, '10': 'code'},
    {'1': 'name', '3': 3, '4': 1, '5': 9, '10': 'name'},
    {'1': 'percent_off', '3': 4, '4': 1, '5': 9, '10': 'percentOff'},
    {'1': 'duration', '3': 5, '4': 1, '5': 9, '10': 'duration'},
    {'1': 'duration_periods', '3': 6, '4': 1, '5': 5, '10': 'durationPeriods'},
    {
      '1': 'valid_from',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'validFrom'
    },
    {
      '1': 'valid_until',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'validUntil'
    },
    {'1': 'max_redemptions', '3': 9, '4': 1, '5': 5, '10': 'maxRedemptions'},
    {
      '1': 'redemptions_count',
      '3': 10,
      '4': 1,
      '5': 5,
      '10': 'redemptionsCount'
    },
    {'1': 'applies_to_tiers', '3': 11, '4': 3, '5': 9, '10': 'appliesToTiers'},
    {
      '1': 'applies_to_cycles',
      '3': 12,
      '4': 3,
      '5': 9,
      '10': 'appliesToCycles'
    },
    {
      '1': 'new_customers_only',
      '3': 13,
      '4': 1,
      '5': 8,
      '10': 'newCustomersOnly'
    },
    {'1': 'channels', '3': 14, '4': 3, '5': 9, '10': 'channels'},
    {'1': 'is_active', '3': 15, '4': 1, '5': 8, '10': 'isActive'},
    {
      '1': 'stripe_promotion_code_id',
      '3': 16,
      '4': 1,
      '5': 9,
      '10': 'stripePromotionCodeId'
    },
    {
      '1': 'created_at',
      '3': 17,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'createdAt'
    },
  ],
};

/// Descriptor for `DiscountCode`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List discountCodeDescriptor = $convert.base64Decode(
    'CgxEaXNjb3VudENvZGUSDgoCaWQYASABKAlSAmlkEhIKBGNvZGUYAiABKAlSBGNvZGUSEgoEbm'
    'FtZRgDIAEoCVIEbmFtZRIfCgtwZXJjZW50X29mZhgEIAEoCVIKcGVyY2VudE9mZhIaCghkdXJh'
    'dGlvbhgFIAEoCVIIZHVyYXRpb24SKQoQZHVyYXRpb25fcGVyaW9kcxgGIAEoBVIPZHVyYXRpb2'
    '5QZXJpb2RzEjkKCnZhbGlkX2Zyb20YByABKAsyGi5nb29nbGUucHJvdG9idWYuVGltZXN0YW1w'
    'Ugl2YWxpZEZyb20SOwoLdmFsaWRfdW50aWwYCCABKAsyGi5nb29nbGUucHJvdG9idWYuVGltZX'
    'N0YW1wUgp2YWxpZFVudGlsEicKD21heF9yZWRlbXB0aW9ucxgJIAEoBVIObWF4UmVkZW1wdGlv'
    'bnMSKwoRcmVkZW1wdGlvbnNfY291bnQYCiABKAVSEHJlZGVtcHRpb25zQ291bnQSKAoQYXBwbG'
    'llc190b190aWVycxgLIAMoCVIOYXBwbGllc1RvVGllcnMSKgoRYXBwbGllc190b19jeWNsZXMY'
    'DCADKAlSD2FwcGxpZXNUb0N5Y2xlcxIsChJuZXdfY3VzdG9tZXJzX29ubHkYDSABKAhSEG5ld0'
    'N1c3RvbWVyc09ubHkSGgoIY2hhbm5lbHMYDiADKAlSCGNoYW5uZWxzEhsKCWlzX2FjdGl2ZRgP'
    'IAEoCFIIaXNBY3RpdmUSNwoYc3RyaXBlX3Byb21vdGlvbl9jb2RlX2lkGBAgASgJUhVzdHJpcG'
    'VQcm9tb3Rpb25Db2RlSWQSOQoKY3JlYXRlZF9hdBgRIAEoCzIaLmdvb2dsZS5wcm90b2J1Zi5U'
    'aW1lc3RhbXBSCWNyZWF0ZWRBdA==');

@$core.Deprecated('Use adminCreateDiscountCodeRequestDescriptor instead')
const AdminCreateDiscountCodeRequest$json = {
  '1': 'AdminCreateDiscountCodeRequest',
  '2': [
    {'1': 'code', '3': 1, '4': 1, '5': 9, '10': 'code'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'percent_off', '3': 3, '4': 1, '5': 9, '10': 'percentOff'},
    {'1': 'duration', '3': 4, '4': 1, '5': 9, '10': 'duration'},
    {'1': 'duration_periods', '3': 5, '4': 1, '5': 5, '10': 'durationPeriods'},
    {
      '1': 'valid_until',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'validUntil'
    },
    {'1': 'max_redemptions', '3': 7, '4': 1, '5': 5, '10': 'maxRedemptions'},
    {'1': 'applies_to_tiers', '3': 8, '4': 3, '5': 9, '10': 'appliesToTiers'},
    {'1': 'applies_to_cycles', '3': 9, '4': 3, '5': 9, '10': 'appliesToCycles'},
    {
      '1': 'new_customers_only',
      '3': 10,
      '4': 1,
      '5': 8,
      '10': 'newCustomersOnly'
    },
    {'1': 'channels', '3': 11, '4': 3, '5': 9, '10': 'channels'},
    {'1': 'reason', '3': 15, '4': 1, '5': 9, '10': 'reason'},
    {'1': 'idempotency_key', '3': 16, '4': 1, '5': 9, '10': 'idempotencyKey'},
  ],
};

/// Descriptor for `AdminCreateDiscountCodeRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List adminCreateDiscountCodeRequestDescriptor = $convert.base64Decode(
    'Ch5BZG1pbkNyZWF0ZURpc2NvdW50Q29kZVJlcXVlc3QSEgoEY29kZRgBIAEoCVIEY29kZRISCg'
    'RuYW1lGAIgASgJUgRuYW1lEh8KC3BlcmNlbnRfb2ZmGAMgASgJUgpwZXJjZW50T2ZmEhoKCGR1'
    'cmF0aW9uGAQgASgJUghkdXJhdGlvbhIpChBkdXJhdGlvbl9wZXJpb2RzGAUgASgFUg9kdXJhdG'
    'lvblBlcmlvZHMSOwoLdmFsaWRfdW50aWwYBiABKAsyGi5nb29nbGUucHJvdG9idWYuVGltZXN0'
    'YW1wUgp2YWxpZFVudGlsEicKD21heF9yZWRlbXB0aW9ucxgHIAEoBVIObWF4UmVkZW1wdGlvbn'
    'MSKAoQYXBwbGllc190b190aWVycxgIIAMoCVIOYXBwbGllc1RvVGllcnMSKgoRYXBwbGllc190'
    'b19jeWNsZXMYCSADKAlSD2FwcGxpZXNUb0N5Y2xlcxIsChJuZXdfY3VzdG9tZXJzX29ubHkYCi'
    'ABKAhSEG5ld0N1c3RvbWVyc09ubHkSGgoIY2hhbm5lbHMYCyADKAlSCGNoYW5uZWxzEhYKBnJl'
    'YXNvbhgPIAEoCVIGcmVhc29uEicKD2lkZW1wb3RlbmN5X2tleRgQIAEoCVIOaWRlbXBvdGVuY3'
    'lLZXk=');

@$core.Deprecated('Use adminUpdateDiscountCodeRequestDescriptor instead')
const AdminUpdateDiscountCodeRequest$json = {
  '1': 'AdminUpdateDiscountCodeRequest',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {
      '1': 'valid_until',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'validUntil'
    },
    {'1': 'max_redemptions', '3': 4, '4': 1, '5': 5, '10': 'maxRedemptions'},
    {'1': 'set_active', '3': 5, '4': 1, '5': 5, '10': 'setActive'},
    {'1': 'reason', '3': 15, '4': 1, '5': 9, '10': 'reason'},
    {'1': 'idempotency_key', '3': 16, '4': 1, '5': 9, '10': 'idempotencyKey'},
  ],
};

/// Descriptor for `AdminUpdateDiscountCodeRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List adminUpdateDiscountCodeRequestDescriptor = $convert.base64Decode(
    'Ch5BZG1pblVwZGF0ZURpc2NvdW50Q29kZVJlcXVlc3QSDgoCaWQYASABKAlSAmlkEhIKBG5hbW'
    'UYAiABKAlSBG5hbWUSOwoLdmFsaWRfdW50aWwYAyABKAsyGi5nb29nbGUucHJvdG9idWYuVGlt'
    'ZXN0YW1wUgp2YWxpZFVudGlsEicKD21heF9yZWRlbXB0aW9ucxgEIAEoBVIObWF4UmVkZW1wdG'
    'lvbnMSHQoKc2V0X2FjdGl2ZRgFIAEoBVIJc2V0QWN0aXZlEhYKBnJlYXNvbhgPIAEoCVIGcmVh'
    'c29uEicKD2lkZW1wb3RlbmN5X2tleRgQIAEoCVIOaWRlbXBvdGVuY3lLZXk=');

@$core.Deprecated('Use adminListDiscountCodesRequestDescriptor instead')
const AdminListDiscountCodesRequest$json = {
  '1': 'AdminListDiscountCodesRequest',
  '2': [
    {'1': 'include_inactive', '3': 1, '4': 1, '5': 8, '10': 'includeInactive'},
  ],
};

/// Descriptor for `AdminListDiscountCodesRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List adminListDiscountCodesRequestDescriptor =
    $convert.base64Decode(
        'Ch1BZG1pbkxpc3REaXNjb3VudENvZGVzUmVxdWVzdBIpChBpbmNsdWRlX2luYWN0aXZlGAEgAS'
        'gIUg9pbmNsdWRlSW5hY3RpdmU=');

@$core.Deprecated('Use adminListDiscountCodesResponseDescriptor instead')
const AdminListDiscountCodesResponse$json = {
  '1': 'AdminListDiscountCodesResponse',
  '2': [
    {
      '1': 'codes',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.billing.v1.DiscountCode',
      '10': 'codes'
    },
  ],
};

/// Descriptor for `AdminListDiscountCodesResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List adminListDiscountCodesResponseDescriptor =
    $convert.base64Decode(
        'Ch5BZG1pbkxpc3REaXNjb3VudENvZGVzUmVzcG9uc2USLgoFY29kZXMYASADKAsyGC5iaWxsaW'
        '5nLnYxLkRpc2NvdW50Q29kZVIFY29kZXM=');

@$core.Deprecated('Use adminGetDiscountCodeRequestDescriptor instead')
const AdminGetDiscountCodeRequest$json = {
  '1': 'AdminGetDiscountCodeRequest',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
  ],
};

/// Descriptor for `AdminGetDiscountCodeRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List adminGetDiscountCodeRequestDescriptor =
    $convert.base64Decode(
        'ChtBZG1pbkdldERpc2NvdW50Q29kZVJlcXVlc3QSDgoCaWQYASABKAlSAmlk');

@$core.Deprecated('Use discountCodeRedemptionDescriptor instead')
const DiscountCodeRedemption$json = {
  '1': 'DiscountCodeRedemption',
  '2': [
    {'1': 'organization_id', '3': 1, '4': 1, '5': 9, '10': 'organizationId'},
    {
      '1': 'organization_name',
      '3': 2,
      '4': 1,
      '5': 9,
      '10': 'organizationName'
    },
    {'1': 'channel', '3': 3, '4': 1, '5': 9, '10': 'channel'},
    {'1': 'status', '3': 4, '4': 1, '5': 9, '10': 'status'},
    {
      '1': 'reserved_at',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'reservedAt'
    },
    {
      '1': 'committed_at',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'committedAt'
    },
  ],
};

/// Descriptor for `DiscountCodeRedemption`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List discountCodeRedemptionDescriptor = $convert.base64Decode(
    'ChZEaXNjb3VudENvZGVSZWRlbXB0aW9uEicKD29yZ2FuaXphdGlvbl9pZBgBIAEoCVIOb3JnYW'
    '5pemF0aW9uSWQSKwoRb3JnYW5pemF0aW9uX25hbWUYAiABKAlSEG9yZ2FuaXphdGlvbk5hbWUS'
    'GAoHY2hhbm5lbBgDIAEoCVIHY2hhbm5lbBIWCgZzdGF0dXMYBCABKAlSBnN0YXR1cxI7CgtyZX'
    'NlcnZlZF9hdBgFIAEoCzIaLmdvb2dsZS5wcm90b2J1Zi5UaW1lc3RhbXBSCnJlc2VydmVkQXQS'
    'PQoMY29tbWl0dGVkX2F0GAYgASgLMhouZ29vZ2xlLnByb3RvYnVmLlRpbWVzdGFtcFILY29tbW'
    'l0dGVkQXQ=');

@$core.Deprecated('Use discountCodeDetailsDescriptor instead')
const DiscountCodeDetails$json = {
  '1': 'DiscountCodeDetails',
  '2': [
    {
      '1': 'code',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.billing.v1.DiscountCode',
      '10': 'code'
    },
    {
      '1': 'redemptions',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.billing.v1.DiscountCodeRedemption',
      '10': 'redemptions'
    },
  ],
};

/// Descriptor for `DiscountCodeDetails`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List discountCodeDetailsDescriptor = $convert.base64Decode(
    'ChNEaXNjb3VudENvZGVEZXRhaWxzEiwKBGNvZGUYASABKAsyGC5iaWxsaW5nLnYxLkRpc2NvdW'
    '50Q29kZVIEY29kZRJECgtyZWRlbXB0aW9ucxgCIAMoCzIiLmJpbGxpbmcudjEuRGlzY291bnRD'
    'b2RlUmVkZW1wdGlvblILcmVkZW1wdGlvbnM=');

@$core.Deprecated('Use validateDiscountCodeRequestDescriptor instead')
const ValidateDiscountCodeRequest$json = {
  '1': 'ValidateDiscountCodeRequest',
  '2': [
    {'1': 'code', '3': 1, '4': 1, '5': 9, '10': 'code'},
    {'1': 'plan_tier', '3': 2, '4': 1, '5': 9, '10': 'planTier'},
    {'1': 'plan_cycle', '3': 3, '4': 1, '5': 9, '10': 'planCycle'},
    {'1': 'channel', '3': 4, '4': 1, '5': 9, '10': 'channel'},
  ],
};

/// Descriptor for `ValidateDiscountCodeRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List validateDiscountCodeRequestDescriptor =
    $convert.base64Decode(
        'ChtWYWxpZGF0ZURpc2NvdW50Q29kZVJlcXVlc3QSEgoEY29kZRgBIAEoCVIEY29kZRIbCglwbG'
        'FuX3RpZXIYAiABKAlSCHBsYW5UaWVyEh0KCnBsYW5fY3ljbGUYAyABKAlSCXBsYW5DeWNsZRIY'
        'CgdjaGFubmVsGAQgASgJUgdjaGFubmVs');

@$core.Deprecated('Use discountCodeQuoteDescriptor instead')
const DiscountCodeQuote$json = {
  '1': 'DiscountCodeQuote',
  '2': [
    {'1': 'valid', '3': 1, '4': 1, '5': 8, '10': 'valid'},
    {'1': 'reason', '3': 2, '4': 1, '5': 9, '10': 'reason'},
    {'1': 'code', '3': 3, '4': 1, '5': 9, '10': 'code'},
    {'1': 'name', '3': 4, '4': 1, '5': 9, '10': 'name'},
    {'1': 'percent_off', '3': 5, '4': 1, '5': 9, '10': 'percentOff'},
    {'1': 'price_before', '3': 6, '4': 1, '5': 9, '10': 'priceBefore'},
    {'1': 'price_after', '3': 7, '4': 1, '5': 9, '10': 'priceAfter'},
    {'1': 'currency_code', '3': 8, '4': 1, '5': 9, '10': 'currencyCode'},
    {'1': 'duration', '3': 9, '4': 1, '5': 9, '10': 'duration'},
    {'1': 'duration_periods', '3': 10, '4': 1, '5': 5, '10': 'durationPeriods'},
    {'1': 'redemptions_left', '3': 11, '4': 1, '5': 5, '10': 'redemptionsLeft'},
  ],
};

/// Descriptor for `DiscountCodeQuote`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List discountCodeQuoteDescriptor = $convert.base64Decode(
    'ChFEaXNjb3VudENvZGVRdW90ZRIUCgV2YWxpZBgBIAEoCFIFdmFsaWQSFgoGcmVhc29uGAIgAS'
    'gJUgZyZWFzb24SEgoEY29kZRgDIAEoCVIEY29kZRISCgRuYW1lGAQgASgJUgRuYW1lEh8KC3Bl'
    'cmNlbnRfb2ZmGAUgASgJUgpwZXJjZW50T2ZmEiEKDHByaWNlX2JlZm9yZRgGIAEoCVILcHJpY2'
    'VCZWZvcmUSHwoLcHJpY2VfYWZ0ZXIYByABKAlSCnByaWNlQWZ0ZXISIwoNY3VycmVuY3lfY29k'
    'ZRgIIAEoCVIMY3VycmVuY3lDb2RlEhoKCGR1cmF0aW9uGAkgASgJUghkdXJhdGlvbhIpChBkdX'
    'JhdGlvbl9wZXJpb2RzGAogASgFUg9kdXJhdGlvblBlcmlvZHMSKQoQcmVkZW1wdGlvbnNfbGVm'
    'dBgLIAEoBVIPcmVkZW1wdGlvbnNMZWZ0');

@$core.Deprecated('Use storeProductDescriptor instead')
const StoreProduct$json = {
  '1': 'StoreProduct',
  '2': [
    {'1': 'product_id', '3': 1, '4': 1, '5': 9, '10': 'productId'},
    {'1': 'plan_tier', '3': 2, '4': 1, '5': 9, '10': 'planTier'},
    {'1': 'plan_cycle', '3': 3, '4': 1, '5': 9, '10': 'planCycle'},
    {'1': 'tokens_per_period', '3': 4, '4': 1, '5': 5, '10': 'tokensPerPeriod'},
    {
      '1': 'reference_price_gross',
      '3': 5,
      '4': 1,
      '5': 9,
      '10': 'referencePriceGross'
    },
    {'1': 'currency_code', '3': 6, '4': 1, '5': 9, '10': 'currencyCode'},
  ],
};

/// Descriptor for `StoreProduct`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List storeProductDescriptor = $convert.base64Decode(
    'CgxTdG9yZVByb2R1Y3QSHQoKcHJvZHVjdF9pZBgBIAEoCVIJcHJvZHVjdElkEhsKCXBsYW5fdG'
    'llchgCIAEoCVIIcGxhblRpZXISHQoKcGxhbl9jeWNsZRgDIAEoCVIJcGxhbkN5Y2xlEioKEXRv'
    'a2Vuc19wZXJfcGVyaW9kGAQgASgFUg90b2tlbnNQZXJQZXJpb2QSMgoVcmVmZXJlbmNlX3ByaW'
    'NlX2dyb3NzGAUgASgJUhNyZWZlcmVuY2VQcmljZUdyb3NzEiMKDWN1cnJlbmN5X2NvZGUYBiAB'
    'KAlSDGN1cnJlbmN5Q29kZQ==');

@$core.Deprecated('Use billingSurfaceDescriptor instead')
const BillingSurface$json = {
  '1': 'BillingSurface',
  '2': [
    {'1': 'active_provider', '3': 1, '4': 1, '5': 9, '10': 'activeProvider'},
    {'1': 'plan_tier', '3': 2, '4': 1, '5': 9, '10': 'planTier'},
    {'1': 'status', '3': 3, '4': 1, '5': 9, '10': 'status'},
    {'1': 'can_purchase', '3': 4, '4': 1, '5': 8, '10': 'canPurchase'},
    {'1': 'block_reason', '3': 5, '4': 1, '5': 9, '10': 'blockReason'},
    {
      '1': 'blocked_until',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'blockedUntil'
    },
    {
      '1': 'products',
      '3': 7,
      '4': 3,
      '5': 11,
      '6': '.billing.v1.StoreProduct',
      '10': 'products'
    },
    {'1': 'web_link_mode', '3': 8, '4': 1, '5': 9, '10': 'webLinkMode'},
    {'1': 'show_restore', '3': 9, '4': 1, '5': 8, '10': 'showRestore'},
    {'1': 'manage_url', '3': 10, '4': 1, '5': 9, '10': 'manageUrl'},
  ],
};

/// Descriptor for `BillingSurface`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List billingSurfaceDescriptor = $convert.base64Decode(
    'Cg5CaWxsaW5nU3VyZmFjZRInCg9hY3RpdmVfcHJvdmlkZXIYASABKAlSDmFjdGl2ZVByb3ZpZG'
    'VyEhsKCXBsYW5fdGllchgCIAEoCVIIcGxhblRpZXISFgoGc3RhdHVzGAMgASgJUgZzdGF0dXMS'
    'IQoMY2FuX3B1cmNoYXNlGAQgASgIUgtjYW5QdXJjaGFzZRIhCgxibG9ja19yZWFzb24YBSABKA'
    'lSC2Jsb2NrUmVhc29uEj8KDWJsb2NrZWRfdW50aWwYBiABKAsyGi5nb29nbGUucHJvdG9idWYu'
    'VGltZXN0YW1wUgxibG9ja2VkVW50aWwSNAoIcHJvZHVjdHMYByADKAsyGC5iaWxsaW5nLnYxLl'
    'N0b3JlUHJvZHVjdFIIcHJvZHVjdHMSIgoNd2ViX2xpbmtfbW9kZRgIIAEoCVILd2ViTGlua01v'
    'ZGUSIQoMc2hvd19yZXN0b3JlGAkgASgIUgtzaG93UmVzdG9yZRIdCgptYW5hZ2VfdXJsGAogAS'
    'gJUgltYW5hZ2VVcmw=');

@$core.Deprecated('Use beginStorePurchaseRequestDescriptor instead')
const BeginStorePurchaseRequest$json = {
  '1': 'BeginStorePurchaseRequest',
  '2': [
    {'1': 'platform', '3': 1, '4': 1, '5': 9, '10': 'platform'},
    {'1': 'product_id', '3': 2, '4': 1, '5': 9, '10': 'productId'},
  ],
};

/// Descriptor for `BeginStorePurchaseRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List beginStorePurchaseRequestDescriptor =
    $convert.base64Decode(
        'ChlCZWdpblN0b3JlUHVyY2hhc2VSZXF1ZXN0EhoKCHBsYXRmb3JtGAEgASgJUghwbGF0Zm9ybR'
        'IdCgpwcm9kdWN0X2lkGAIgASgJUglwcm9kdWN0SWQ=');

@$core.Deprecated('Use beginStorePurchaseResponseDescriptor instead')
const BeginStorePurchaseResponse$json = {
  '1': 'BeginStorePurchaseResponse',
  '2': [
    {'1': 'allowed', '3': 1, '4': 1, '5': 8, '10': 'allowed'},
    {'1': 'block_reason', '3': 2, '4': 1, '5': 9, '10': 'blockReason'},
    {
      '1': 'blocked_until',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'blockedUntil'
    },
    {'1': 'app_account_token', '3': 4, '4': 1, '5': 9, '10': 'appAccountToken'},
  ],
};

/// Descriptor for `BeginStorePurchaseResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List beginStorePurchaseResponseDescriptor = $convert.base64Decode(
    'ChpCZWdpblN0b3JlUHVyY2hhc2VSZXNwb25zZRIYCgdhbGxvd2VkGAEgASgIUgdhbGxvd2VkEi'
    'EKDGJsb2NrX3JlYXNvbhgCIAEoCVILYmxvY2tSZWFzb24SPwoNYmxvY2tlZF91bnRpbBgDIAEo'
    'CzIaLmdvb2dsZS5wcm90b2J1Zi5UaW1lc3RhbXBSDGJsb2NrZWRVbnRpbBIqChFhcHBfYWNjb3'
    'VudF90b2tlbhgEIAEoCVIPYXBwQWNjb3VudFRva2Vu');

@$core.Deprecated('Use verifyStorePurchaseRequestDescriptor instead')
const VerifyStorePurchaseRequest$json = {
  '1': 'VerifyStorePurchaseRequest',
  '2': [
    {'1': 'platform', '3': 1, '4': 1, '5': 9, '10': 'platform'},
    {'1': 'jws_transaction', '3': 2, '4': 1, '5': 9, '10': 'jwsTransaction'},
    {'1': 'purchase_token', '3': 3, '4': 1, '5': 9, '10': 'purchaseToken'},
    {'1': 'product_id', '3': 4, '4': 1, '5': 9, '10': 'productId'},
  ],
};

/// Descriptor for `VerifyStorePurchaseRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List verifyStorePurchaseRequestDescriptor = $convert.base64Decode(
    'ChpWZXJpZnlTdG9yZVB1cmNoYXNlUmVxdWVzdBIaCghwbGF0Zm9ybRgBIAEoCVIIcGxhdGZvcm'
    '0SJwoPandzX3RyYW5zYWN0aW9uGAIgASgJUg5qd3NUcmFuc2FjdGlvbhIlCg5wdXJjaGFzZV90'
    'b2tlbhgDIAEoCVINcHVyY2hhc2VUb2tlbhIdCgpwcm9kdWN0X2lkGAQgASgJUglwcm9kdWN0SW'
    'Q=');

@$core.Deprecated('Use restoreStorePurchasesRequestDescriptor instead')
const RestoreStorePurchasesRequest$json = {
  '1': 'RestoreStorePurchasesRequest',
  '2': [
    {'1': 'platform', '3': 1, '4': 1, '5': 9, '10': 'platform'},
    {'1': 'jws_transactions', '3': 2, '4': 3, '5': 9, '10': 'jwsTransactions'},
    {'1': 'purchase_tokens', '3': 3, '4': 3, '5': 9, '10': 'purchaseTokens'},
    {'1': 'product_id', '3': 4, '4': 1, '5': 9, '10': 'productId'},
  ],
};

/// Descriptor for `RestoreStorePurchasesRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List restoreStorePurchasesRequestDescriptor = $convert.base64Decode(
    'ChxSZXN0b3JlU3RvcmVQdXJjaGFzZXNSZXF1ZXN0EhoKCHBsYXRmb3JtGAEgASgJUghwbGF0Zm'
    '9ybRIpChBqd3NfdHJhbnNhY3Rpb25zGAIgAygJUg9qd3NUcmFuc2FjdGlvbnMSJwoPcHVyY2hh'
    'c2VfdG9rZW5zGAMgAygJUg5wdXJjaGFzZVRva2VucxIdCgpwcm9kdWN0X2lkGAQgASgJUglwcm'
    '9kdWN0SWQ=');

@$core.Deprecated('Use adminListStoreTransactionsRequestDescriptor instead')
const AdminListStoreTransactionsRequest$json = {
  '1': 'AdminListStoreTransactionsRequest',
  '2': [
    {'1': 'organization_id', '3': 1, '4': 1, '5': 9, '10': 'organizationId'},
    {'1': 'limit', '3': 2, '4': 1, '5': 5, '10': 'limit'},
  ],
};

/// Descriptor for `AdminListStoreTransactionsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List adminListStoreTransactionsRequestDescriptor =
    $convert.base64Decode(
        'CiFBZG1pbkxpc3RTdG9yZVRyYW5zYWN0aW9uc1JlcXVlc3QSJwoPb3JnYW5pemF0aW9uX2lkGA'
        'EgASgJUg5vcmdhbml6YXRpb25JZBIUCgVsaW1pdBgCIAEoBVIFbGltaXQ=');

@$core.Deprecated('Use storeTransactionInfoDescriptor instead')
const StoreTransactionInfo$json = {
  '1': 'StoreTransactionInfo',
  '2': [
    {'1': 'provider', '3': 1, '4': 1, '5': 9, '10': 'provider'},
    {'1': 'transaction_id', '3': 2, '4': 1, '5': 9, '10': 'transactionId'},
    {
      '1': 'original_transaction_id',
      '3': 3,
      '4': 1,
      '5': 9,
      '10': 'originalTransactionId'
    },
    {'1': 'product_id', '3': 4, '4': 1, '5': 9, '10': 'productId'},
    {'1': 'environment', '3': 5, '4': 1, '5': 9, '10': 'environment'},
    {
      '1': 'purchase_date',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'purchaseDate'
    },
    {
      '1': 'expires_date',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'expiresDate'
    },
    {
      '1': 'revocation_date',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'revocationDate'
    },
    {'1': 'offer_identifier', '3': 9, '4': 1, '5': 9, '10': 'offerIdentifier'},
  ],
};

/// Descriptor for `StoreTransactionInfo`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List storeTransactionInfoDescriptor = $convert.base64Decode(
    'ChRTdG9yZVRyYW5zYWN0aW9uSW5mbxIaCghwcm92aWRlchgBIAEoCVIIcHJvdmlkZXISJQoOdH'
    'JhbnNhY3Rpb25faWQYAiABKAlSDXRyYW5zYWN0aW9uSWQSNgoXb3JpZ2luYWxfdHJhbnNhY3Rp'
    'b25faWQYAyABKAlSFW9yaWdpbmFsVHJhbnNhY3Rpb25JZBIdCgpwcm9kdWN0X2lkGAQgASgJUg'
    'lwcm9kdWN0SWQSIAoLZW52aXJvbm1lbnQYBSABKAlSC2Vudmlyb25tZW50Ej8KDXB1cmNoYXNl'
    'X2RhdGUYBiABKAsyGi5nb29nbGUucHJvdG9idWYuVGltZXN0YW1wUgxwdXJjaGFzZURhdGUSPQ'
    'oMZXhwaXJlc19kYXRlGAcgASgLMhouZ29vZ2xlLnByb3RvYnVmLlRpbWVzdGFtcFILZXhwaXJl'
    'c0RhdGUSQwoPcmV2b2NhdGlvbl9kYXRlGAggASgLMhouZ29vZ2xlLnByb3RvYnVmLlRpbWVzdG'
    'FtcFIOcmV2b2NhdGlvbkRhdGUSKQoQb2ZmZXJfaWRlbnRpZmllchgJIAEoCVIPb2ZmZXJJZGVu'
    'dGlmaWVy');

@$core.Deprecated('Use adminListStoreTransactionsResponseDescriptor instead')
const AdminListStoreTransactionsResponse$json = {
  '1': 'AdminListStoreTransactionsResponse',
  '2': [
    {
      '1': 'transactions',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.billing.v1.StoreTransactionInfo',
      '10': 'transactions'
    },
  ],
};

/// Descriptor for `AdminListStoreTransactionsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List adminListStoreTransactionsResponseDescriptor =
    $convert.base64Decode(
        'CiJBZG1pbkxpc3RTdG9yZVRyYW5zYWN0aW9uc1Jlc3BvbnNlEkQKDHRyYW5zYWN0aW9ucxgBIA'
        'MoCzIgLmJpbGxpbmcudjEuU3RvcmVUcmFuc2FjdGlvbkluZm9SDHRyYW5zYWN0aW9ucw==');
