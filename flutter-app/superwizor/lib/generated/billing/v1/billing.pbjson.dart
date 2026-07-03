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
    'LnByb3RvYnVmLlRpbWVzdGFtcFIKY2FuY2VsZWRBdA==');

@$core.Deprecated('Use adminResetTokensRequestDescriptor instead')
const AdminResetTokensRequest$json = {
  '1': 'AdminResetTokensRequest',
  '2': [
    {'1': 'organization_id', '3': 1, '4': 1, '5': 9, '10': 'organizationId'},
    {'1': 'tokens_used', '3': 2, '4': 1, '5': 5, '10': 'tokensUsed'},
    {'1': 'tokens_limit', '3': 3, '4': 1, '5': 5, '10': 'tokensLimit'},
    {'1': 'reason', '3': 4, '4': 1, '5': 9, '10': 'reason'},
    {'1': 'idempotency_key', '3': 5, '4': 1, '5': 9, '10': 'idempotencyKey'},
  ],
};

/// Descriptor for `AdminResetTokensRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List adminResetTokensRequestDescriptor = $convert.base64Decode(
    'ChdBZG1pblJlc2V0VG9rZW5zUmVxdWVzdBInCg9vcmdhbml6YXRpb25faWQYASABKAlSDm9yZ2'
    'FuaXphdGlvbklkEh8KC3Rva2Vuc191c2VkGAIgASgFUgp0b2tlbnNVc2VkEiEKDHRva2Vuc19s'
    'aW1pdBgDIAEoBVILdG9rZW5zTGltaXQSFgoGcmVhc29uGAQgASgJUgZyZWFzb24SJwoPaWRlbX'
    'BvdGVuY3lfa2V5GAUgASgJUg5pZGVtcG90ZW5jeUtleQ==');

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
