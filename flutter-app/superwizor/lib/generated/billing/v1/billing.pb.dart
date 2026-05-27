// This is a generated file - do not edit.
//
// Generated from billing/v1/billing.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;
import 'package:protobuf/well_known_types/google/protobuf/timestamp.pb.dart'
    as $2;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

class CheckQuotaRequest extends $pb.GeneratedMessage {
  factory CheckQuotaRequest({
    $core.String? organizationId,
    $core.String? therapistId,
    $core.String? usageType,
    $core.int? amount,
  }) {
    final result = create();
    if (organizationId != null) result.organizationId = organizationId;
    if (therapistId != null) result.therapistId = therapistId;
    if (usageType != null) result.usageType = usageType;
    if (amount != null) result.amount = amount;
    return result;
  }

  CheckQuotaRequest._();

  factory CheckQuotaRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CheckQuotaRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CheckQuotaRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'billing.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'organizationId')
    ..aOS(2, _omitFieldNames ? '' : 'therapistId')
    ..aOS(3, _omitFieldNames ? '' : 'usageType')
    ..aI(4, _omitFieldNames ? '' : 'amount')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CheckQuotaRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CheckQuotaRequest copyWith(void Function(CheckQuotaRequest) updates) =>
      super.copyWith((message) => updates(message as CheckQuotaRequest))
          as CheckQuotaRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CheckQuotaRequest create() => CheckQuotaRequest._();
  @$core.override
  CheckQuotaRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CheckQuotaRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CheckQuotaRequest>(create);
  static CheckQuotaRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get organizationId => $_getSZ(0);
  @$pb.TagNumber(1)
  set organizationId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasOrganizationId() => $_has(0);
  @$pb.TagNumber(1)
  void clearOrganizationId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get therapistId => $_getSZ(1);
  @$pb.TagNumber(2)
  set therapistId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTherapistId() => $_has(1);
  @$pb.TagNumber(2)
  void clearTherapistId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get usageType => $_getSZ(2);
  @$pb.TagNumber(3)
  set usageType($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasUsageType() => $_has(2);
  @$pb.TagNumber(3)
  void clearUsageType() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get amount => $_getIZ(3);
  @$pb.TagNumber(4)
  set amount($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasAmount() => $_has(3);
  @$pb.TagNumber(4)
  void clearAmount() => $_clearField(4);
}

class QuotaDecision extends $pb.GeneratedMessage {
  factory QuotaDecision({
    $core.bool? allowed,
    $core.String? reason,
    $core.int? remaining,
    $core.int? limit,
    $core.int? remainingTokens,
    $core.int? limitTokens,
    $2.Timestamp? periodEnd,
  }) {
    final result = create();
    if (allowed != null) result.allowed = allowed;
    if (reason != null) result.reason = reason;
    if (remaining != null) result.remaining = remaining;
    if (limit != null) result.limit = limit;
    if (remainingTokens != null) result.remainingTokens = remainingTokens;
    if (limitTokens != null) result.limitTokens = limitTokens;
    if (periodEnd != null) result.periodEnd = periodEnd;
    return result;
  }

  QuotaDecision._();

  factory QuotaDecision.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory QuotaDecision.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'QuotaDecision',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'billing.v1'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'allowed')
    ..aOS(2, _omitFieldNames ? '' : 'reason')
    ..aI(3, _omitFieldNames ? '' : 'remaining')
    ..aI(4, _omitFieldNames ? '' : 'limit')
    ..aI(5, _omitFieldNames ? '' : 'remainingTokens')
    ..aI(6, _omitFieldNames ? '' : 'limitTokens')
    ..aOM<$2.Timestamp>(7, _omitFieldNames ? '' : 'periodEnd',
        subBuilder: $2.Timestamp.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  QuotaDecision clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  QuotaDecision copyWith(void Function(QuotaDecision) updates) =>
      super.copyWith((message) => updates(message as QuotaDecision))
          as QuotaDecision;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static QuotaDecision create() => QuotaDecision._();
  @$core.override
  QuotaDecision createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static QuotaDecision getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<QuotaDecision>(create);
  static QuotaDecision? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get allowed => $_getBF(0);
  @$pb.TagNumber(1)
  set allowed($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAllowed() => $_has(0);
  @$pb.TagNumber(1)
  void clearAllowed() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get reason => $_getSZ(1);
  @$pb.TagNumber(2)
  set reason($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasReason() => $_has(1);
  @$pb.TagNumber(2)
  void clearReason() => $_clearField(2);

  /// remaining/limit zostają (legacy) — od Phase 3 znaczą TOKENY, nie sesje.
  @$pb.TagNumber(3)
  $core.int get remaining => $_getIZ(2);
  @$pb.TagNumber(3)
  set remaining($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasRemaining() => $_has(2);
  @$pb.TagNumber(3)
  void clearRemaining() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get limit => $_getIZ(3);
  @$pb.TagNumber(4)
  set limit($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasLimit() => $_has(3);
  @$pb.TagNumber(4)
  void clearLimit() => $_clearField(4);

  /// Explicit aliasy dla nowych callerów (= remaining/limit).
  @$pb.TagNumber(5)
  $core.int get remainingTokens => $_getIZ(4);
  @$pb.TagNumber(5)
  set remainingTokens($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasRemainingTokens() => $_has(4);
  @$pb.TagNumber(5)
  void clearRemainingTokens() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get limitTokens => $_getIZ(5);
  @$pb.TagNumber(6)
  set limitTokens($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasLimitTokens() => $_has(5);
  @$pb.TagNumber(6)
  void clearLimitTokens() => $_clearField(6);

  @$pb.TagNumber(7)
  $2.Timestamp get periodEnd => $_getN(6);
  @$pb.TagNumber(7)
  set periodEnd($2.Timestamp value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasPeriodEnd() => $_has(6);
  @$pb.TagNumber(7)
  void clearPeriodEnd() => $_clearField(7);
  @$pb.TagNumber(7)
  $2.Timestamp ensurePeriodEnd() => $_ensure(6);
}

class ReserveCreditRequest extends $pb.GeneratedMessage {
  factory ReserveCreditRequest({
    $core.String? sessionId,
    $core.String? organizationId,
    $core.String? therapistId,
    $core.int? estimatedTokens,
    $core.String? idempotencyKey,
  }) {
    final result = create();
    if (sessionId != null) result.sessionId = sessionId;
    if (organizationId != null) result.organizationId = organizationId;
    if (therapistId != null) result.therapistId = therapistId;
    if (estimatedTokens != null) result.estimatedTokens = estimatedTokens;
    if (idempotencyKey != null) result.idempotencyKey = idempotencyKey;
    return result;
  }

  ReserveCreditRequest._();

  factory ReserveCreditRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ReserveCreditRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ReserveCreditRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'billing.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'sessionId')
    ..aOS(2, _omitFieldNames ? '' : 'organizationId')
    ..aOS(3, _omitFieldNames ? '' : 'therapistId')
    ..aI(4, _omitFieldNames ? '' : 'estimatedTokens')
    ..aOS(5, _omitFieldNames ? '' : 'idempotencyKey')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReserveCreditRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReserveCreditRequest copyWith(void Function(ReserveCreditRequest) updates) =>
      super.copyWith((message) => updates(message as ReserveCreditRequest))
          as ReserveCreditRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ReserveCreditRequest create() => ReserveCreditRequest._();
  @$core.override
  ReserveCreditRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ReserveCreditRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ReserveCreditRequest>(create);
  static ReserveCreditRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get sessionId => $_getSZ(0);
  @$pb.TagNumber(1)
  set sessionId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSessionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSessionId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get organizationId => $_getSZ(1);
  @$pb.TagNumber(2)
  set organizationId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasOrganizationId() => $_has(1);
  @$pb.TagNumber(2)
  void clearOrganizationId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get therapistId => $_getSZ(2);
  @$pb.TagNumber(3)
  set therapistId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTherapistId() => $_has(2);
  @$pb.TagNumber(3)
  void clearTherapistId() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get estimatedTokens => $_getIZ(3);
  @$pb.TagNumber(4)
  set estimatedTokens($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasEstimatedTokens() => $_has(3);
  @$pb.TagNumber(4)
  void clearEstimatedTokens() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get idempotencyKey => $_getSZ(4);
  @$pb.TagNumber(5)
  set idempotencyKey($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasIdempotencyKey() => $_has(4);
  @$pb.TagNumber(5)
  void clearIdempotencyKey() => $_clearField(5);
}

class Reservation extends $pb.GeneratedMessage {
  factory Reservation({
    $core.String? reservationId,
    $core.String? sessionId,
    $core.int? tokensReserved,
    $2.Timestamp? expiresAt,
  }) {
    final result = create();
    if (reservationId != null) result.reservationId = reservationId;
    if (sessionId != null) result.sessionId = sessionId;
    if (tokensReserved != null) result.tokensReserved = tokensReserved;
    if (expiresAt != null) result.expiresAt = expiresAt;
    return result;
  }

  Reservation._();

  factory Reservation.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Reservation.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Reservation',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'billing.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'reservationId')
    ..aOS(2, _omitFieldNames ? '' : 'sessionId')
    ..aI(3, _omitFieldNames ? '' : 'tokensReserved')
    ..aOM<$2.Timestamp>(4, _omitFieldNames ? '' : 'expiresAt',
        subBuilder: $2.Timestamp.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Reservation clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Reservation copyWith(void Function(Reservation) updates) =>
      super.copyWith((message) => updates(message as Reservation))
          as Reservation;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Reservation create() => Reservation._();
  @$core.override
  Reservation createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Reservation getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Reservation>(create);
  static Reservation? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get reservationId => $_getSZ(0);
  @$pb.TagNumber(1)
  set reservationId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasReservationId() => $_has(0);
  @$pb.TagNumber(1)
  void clearReservationId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get sessionId => $_getSZ(1);
  @$pb.TagNumber(2)
  set sessionId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSessionId() => $_has(1);
  @$pb.TagNumber(2)
  void clearSessionId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get tokensReserved => $_getIZ(2);
  @$pb.TagNumber(3)
  set tokensReserved($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTokensReserved() => $_has(2);
  @$pb.TagNumber(3)
  void clearTokensReserved() => $_clearField(3);

  @$pb.TagNumber(4)
  $2.Timestamp get expiresAt => $_getN(3);
  @$pb.TagNumber(4)
  set expiresAt($2.Timestamp value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasExpiresAt() => $_has(3);
  @$pb.TagNumber(4)
  void clearExpiresAt() => $_clearField(4);
  @$pb.TagNumber(4)
  $2.Timestamp ensureExpiresAt() => $_ensure(3);
}

class CommitUsageRequest extends $pb.GeneratedMessage {
  factory CommitUsageRequest({
    $core.String? sessionId,
    $core.String? organizationId,
    $core.String? therapistId,
    $core.int? durationSeconds,
    $core.String? usageType,
    $core.String? idempotencyKey,
  }) {
    final result = create();
    if (sessionId != null) result.sessionId = sessionId;
    if (organizationId != null) result.organizationId = organizationId;
    if (therapistId != null) result.therapistId = therapistId;
    if (durationSeconds != null) result.durationSeconds = durationSeconds;
    if (usageType != null) result.usageType = usageType;
    if (idempotencyKey != null) result.idempotencyKey = idempotencyKey;
    return result;
  }

  CommitUsageRequest._();

  factory CommitUsageRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CommitUsageRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CommitUsageRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'billing.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'sessionId')
    ..aOS(2, _omitFieldNames ? '' : 'organizationId')
    ..aOS(3, _omitFieldNames ? '' : 'therapistId')
    ..aI(4, _omitFieldNames ? '' : 'durationSeconds')
    ..aOS(5, _omitFieldNames ? '' : 'usageType')
    ..aOS(6, _omitFieldNames ? '' : 'idempotencyKey')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CommitUsageRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CommitUsageRequest copyWith(void Function(CommitUsageRequest) updates) =>
      super.copyWith((message) => updates(message as CommitUsageRequest))
          as CommitUsageRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CommitUsageRequest create() => CommitUsageRequest._();
  @$core.override
  CommitUsageRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CommitUsageRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CommitUsageRequest>(create);
  static CommitUsageRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get sessionId => $_getSZ(0);
  @$pb.TagNumber(1)
  set sessionId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSessionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSessionId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get organizationId => $_getSZ(1);
  @$pb.TagNumber(2)
  set organizationId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasOrganizationId() => $_has(1);
  @$pb.TagNumber(2)
  void clearOrganizationId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get therapistId => $_getSZ(2);
  @$pb.TagNumber(3)
  set therapistId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTherapistId() => $_has(2);
  @$pb.TagNumber(3)
  void clearTherapistId() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get durationSeconds => $_getIZ(3);
  @$pb.TagNumber(4)
  set durationSeconds($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasDurationSeconds() => $_has(3);
  @$pb.TagNumber(4)
  void clearDurationSeconds() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get usageType => $_getSZ(4);
  @$pb.TagNumber(5)
  set usageType($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasUsageType() => $_has(4);
  @$pb.TagNumber(5)
  void clearUsageType() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get idempotencyKey => $_getSZ(5);
  @$pb.TagNumber(6)
  set idempotencyKey($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasIdempotencyKey() => $_has(5);
  @$pb.TagNumber(6)
  void clearIdempotencyKey() => $_clearField(6);
}

class UsageCommit extends $pb.GeneratedMessage {
  factory UsageCommit({
    $core.int? tokensConsumed,
    $core.int? remainingTokens,
    $core.int? limitTokens,
  }) {
    final result = create();
    if (tokensConsumed != null) result.tokensConsumed = tokensConsumed;
    if (remainingTokens != null) result.remainingTokens = remainingTokens;
    if (limitTokens != null) result.limitTokens = limitTokens;
    return result;
  }

  UsageCommit._();

  factory UsageCommit.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UsageCommit.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UsageCommit',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'billing.v1'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'tokensConsumed')
    ..aI(2, _omitFieldNames ? '' : 'remainingTokens')
    ..aI(3, _omitFieldNames ? '' : 'limitTokens')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UsageCommit clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UsageCommit copyWith(void Function(UsageCommit) updates) =>
      super.copyWith((message) => updates(message as UsageCommit))
          as UsageCommit;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UsageCommit create() => UsageCommit._();
  @$core.override
  UsageCommit createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UsageCommit getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UsageCommit>(create);
  static UsageCommit? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get tokensConsumed => $_getIZ(0);
  @$pb.TagNumber(1)
  set tokensConsumed($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTokensConsumed() => $_has(0);
  @$pb.TagNumber(1)
  void clearTokensConsumed() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get remainingTokens => $_getIZ(1);
  @$pb.TagNumber(2)
  set remainingTokens($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRemainingTokens() => $_has(1);
  @$pb.TagNumber(2)
  void clearRemainingTokens() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get limitTokens => $_getIZ(2);
  @$pb.TagNumber(3)
  set limitTokens($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasLimitTokens() => $_has(2);
  @$pb.TagNumber(3)
  void clearLimitTokens() => $_clearField(3);
}

class ReleaseCreditRequest extends $pb.GeneratedMessage {
  factory ReleaseCreditRequest({
    $core.String? sessionId,
    $core.String? organizationId,
    $core.String? reason,
  }) {
    final result = create();
    if (sessionId != null) result.sessionId = sessionId;
    if (organizationId != null) result.organizationId = organizationId;
    if (reason != null) result.reason = reason;
    return result;
  }

  ReleaseCreditRequest._();

  factory ReleaseCreditRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ReleaseCreditRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ReleaseCreditRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'billing.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'sessionId')
    ..aOS(2, _omitFieldNames ? '' : 'organizationId')
    ..aOS(3, _omitFieldNames ? '' : 'reason')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReleaseCreditRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ReleaseCreditRequest copyWith(void Function(ReleaseCreditRequest) updates) =>
      super.copyWith((message) => updates(message as ReleaseCreditRequest))
          as ReleaseCreditRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ReleaseCreditRequest create() => ReleaseCreditRequest._();
  @$core.override
  ReleaseCreditRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ReleaseCreditRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ReleaseCreditRequest>(create);
  static ReleaseCreditRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get sessionId => $_getSZ(0);
  @$pb.TagNumber(1)
  set sessionId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSessionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSessionId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get organizationId => $_getSZ(1);
  @$pb.TagNumber(2)
  set organizationId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasOrganizationId() => $_has(1);
  @$pb.TagNumber(2)
  void clearOrganizationId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get reason => $_getSZ(2);
  @$pb.TagNumber(3)
  set reason($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasReason() => $_has(2);
  @$pb.TagNumber(3)
  void clearReason() => $_clearField(3);
}

@$core.Deprecated('This message is deprecated')
class IncrementUsageRequest extends $pb.GeneratedMessage {
  factory IncrementUsageRequest({
    $core.String? organizationId,
    $core.String? therapistId,
    $core.String? usageType,
    $core.int? amount,
    $core.String? sessionId,
    $core.String? idempotencyKey,
  }) {
    final result = create();
    if (organizationId != null) result.organizationId = organizationId;
    if (therapistId != null) result.therapistId = therapistId;
    if (usageType != null) result.usageType = usageType;
    if (amount != null) result.amount = amount;
    if (sessionId != null) result.sessionId = sessionId;
    if (idempotencyKey != null) result.idempotencyKey = idempotencyKey;
    return result;
  }

  IncrementUsageRequest._();

  factory IncrementUsageRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory IncrementUsageRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'IncrementUsageRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'billing.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'organizationId')
    ..aOS(2, _omitFieldNames ? '' : 'therapistId')
    ..aOS(3, _omitFieldNames ? '' : 'usageType')
    ..aI(4, _omitFieldNames ? '' : 'amount')
    ..aOS(5, _omitFieldNames ? '' : 'sessionId')
    ..aOS(6, _omitFieldNames ? '' : 'idempotencyKey')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  IncrementUsageRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  IncrementUsageRequest copyWith(
          void Function(IncrementUsageRequest) updates) =>
      super.copyWith((message) => updates(message as IncrementUsageRequest))
          as IncrementUsageRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static IncrementUsageRequest create() => IncrementUsageRequest._();
  @$core.override
  IncrementUsageRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static IncrementUsageRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<IncrementUsageRequest>(create);
  static IncrementUsageRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get organizationId => $_getSZ(0);
  @$pb.TagNumber(1)
  set organizationId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasOrganizationId() => $_has(0);
  @$pb.TagNumber(1)
  void clearOrganizationId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get therapistId => $_getSZ(1);
  @$pb.TagNumber(2)
  set therapistId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTherapistId() => $_has(1);
  @$pb.TagNumber(2)
  void clearTherapistId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get usageType => $_getSZ(2);
  @$pb.TagNumber(3)
  set usageType($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasUsageType() => $_has(2);
  @$pb.TagNumber(3)
  void clearUsageType() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get amount => $_getIZ(3);
  @$pb.TagNumber(4)
  set amount($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasAmount() => $_has(3);
  @$pb.TagNumber(4)
  void clearAmount() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get sessionId => $_getSZ(4);
  @$pb.TagNumber(5)
  set sessionId($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasSessionId() => $_has(4);
  @$pb.TagNumber(5)
  void clearSessionId() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get idempotencyKey => $_getSZ(5);
  @$pb.TagNumber(6)
  set idempotencyKey($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasIdempotencyKey() => $_has(5);
  @$pb.TagNumber(6)
  void clearIdempotencyKey() => $_clearField(6);
}

class GetSubscriptionRequest extends $pb.GeneratedMessage {
  factory GetSubscriptionRequest({
    $core.String? organizationId,
  }) {
    final result = create();
    if (organizationId != null) result.organizationId = organizationId;
    return result;
  }

  GetSubscriptionRequest._();

  factory GetSubscriptionRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetSubscriptionRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetSubscriptionRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'billing.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'organizationId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetSubscriptionRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetSubscriptionRequest copyWith(
          void Function(GetSubscriptionRequest) updates) =>
      super.copyWith((message) => updates(message as GetSubscriptionRequest))
          as GetSubscriptionRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetSubscriptionRequest create() => GetSubscriptionRequest._();
  @$core.override
  GetSubscriptionRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetSubscriptionRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetSubscriptionRequest>(create);
  static GetSubscriptionRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get organizationId => $_getSZ(0);
  @$pb.TagNumber(1)
  set organizationId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasOrganizationId() => $_has(0);
  @$pb.TagNumber(1)
  void clearOrganizationId() => $_clearField(1);
}

class Subscription extends $pb.GeneratedMessage {
  factory Subscription({
    $core.String? id,
    $core.String? planTier,
    $core.String? status,
    $core.int? sessionsPerMonthLimit,
    $core.int? sessionsUsedThisPeriod,
    $core.int? tokensPerPeriod,
    $core.int? tokensUsedThisPeriod,
    $core.int? tokensReservedThisPeriod,
    $2.Timestamp? currentPeriodStart,
    $2.Timestamp? currentPeriodEnd,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (planTier != null) result.planTier = planTier;
    if (status != null) result.status = status;
    if (sessionsPerMonthLimit != null)
      result.sessionsPerMonthLimit = sessionsPerMonthLimit;
    if (sessionsUsedThisPeriod != null)
      result.sessionsUsedThisPeriod = sessionsUsedThisPeriod;
    if (tokensPerPeriod != null) result.tokensPerPeriod = tokensPerPeriod;
    if (tokensUsedThisPeriod != null)
      result.tokensUsedThisPeriod = tokensUsedThisPeriod;
    if (tokensReservedThisPeriod != null)
      result.tokensReservedThisPeriod = tokensReservedThisPeriod;
    if (currentPeriodStart != null)
      result.currentPeriodStart = currentPeriodStart;
    if (currentPeriodEnd != null) result.currentPeriodEnd = currentPeriodEnd;
    return result;
  }

  Subscription._();

  factory Subscription.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Subscription.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Subscription',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'billing.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'planTier')
    ..aOS(3, _omitFieldNames ? '' : 'status')
    ..aI(4, _omitFieldNames ? '' : 'sessionsPerMonthLimit')
    ..aI(5, _omitFieldNames ? '' : 'sessionsUsedThisPeriod')
    ..aI(6, _omitFieldNames ? '' : 'tokensPerPeriod')
    ..aI(7, _omitFieldNames ? '' : 'tokensUsedThisPeriod')
    ..aI(8, _omitFieldNames ? '' : 'tokensReservedThisPeriod')
    ..aOM<$2.Timestamp>(9, _omitFieldNames ? '' : 'currentPeriodStart',
        subBuilder: $2.Timestamp.create)
    ..aOM<$2.Timestamp>(10, _omitFieldNames ? '' : 'currentPeriodEnd',
        subBuilder: $2.Timestamp.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Subscription clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Subscription copyWith(void Function(Subscription) updates) =>
      super.copyWith((message) => updates(message as Subscription))
          as Subscription;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Subscription create() => Subscription._();
  @$core.override
  Subscription createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Subscription getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Subscription>(create);
  static Subscription? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get planTier => $_getSZ(1);
  @$pb.TagNumber(2)
  set planTier($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPlanTier() => $_has(1);
  @$pb.TagNumber(2)
  void clearPlanTier() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get status => $_getSZ(2);
  @$pb.TagNumber(3)
  set status($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasStatus() => $_has(2);
  @$pb.TagNumber(3)
  void clearStatus() => $_clearField(3);

  /// Legacy fields — populated z tokens_* dla wstecznej kompatybilności
  /// (sesje ≈ tokens przy mapowaniu 1:1).
  @$pb.TagNumber(4)
  $core.int get sessionsPerMonthLimit => $_getIZ(3);
  @$pb.TagNumber(4)
  set sessionsPerMonthLimit($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSessionsPerMonthLimit() => $_has(3);
  @$pb.TagNumber(4)
  void clearSessionsPerMonthLimit() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get sessionsUsedThisPeriod => $_getIZ(4);
  @$pb.TagNumber(5)
  set sessionsUsedThisPeriod($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasSessionsUsedThisPeriod() => $_has(4);
  @$pb.TagNumber(5)
  void clearSessionsUsedThisPeriod() => $_clearField(5);

  /// Phase 3 canonical fields:
  @$pb.TagNumber(6)
  $core.int get tokensPerPeriod => $_getIZ(5);
  @$pb.TagNumber(6)
  set tokensPerPeriod($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasTokensPerPeriod() => $_has(5);
  @$pb.TagNumber(6)
  void clearTokensPerPeriod() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get tokensUsedThisPeriod => $_getIZ(6);
  @$pb.TagNumber(7)
  set tokensUsedThisPeriod($core.int value) => $_setSignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasTokensUsedThisPeriod() => $_has(6);
  @$pb.TagNumber(7)
  void clearTokensUsedThisPeriod() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.int get tokensReservedThisPeriod => $_getIZ(7);
  @$pb.TagNumber(8)
  set tokensReservedThisPeriod($core.int value) => $_setSignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasTokensReservedThisPeriod() => $_has(7);
  @$pb.TagNumber(8)
  void clearTokensReservedThisPeriod() => $_clearField(8);

  @$pb.TagNumber(9)
  $2.Timestamp get currentPeriodStart => $_getN(8);
  @$pb.TagNumber(9)
  set currentPeriodStart($2.Timestamp value) => $_setField(9, value);
  @$pb.TagNumber(9)
  $core.bool hasCurrentPeriodStart() => $_has(8);
  @$pb.TagNumber(9)
  void clearCurrentPeriodStart() => $_clearField(9);
  @$pb.TagNumber(9)
  $2.Timestamp ensureCurrentPeriodStart() => $_ensure(8);

  @$pb.TagNumber(10)
  $2.Timestamp get currentPeriodEnd => $_getN(9);
  @$pb.TagNumber(10)
  set currentPeriodEnd($2.Timestamp value) => $_setField(10, value);
  @$pb.TagNumber(10)
  $core.bool hasCurrentPeriodEnd() => $_has(9);
  @$pb.TagNumber(10)
  void clearCurrentPeriodEnd() => $_clearField(10);
  @$pb.TagNumber(10)
  $2.Timestamp ensureCurrentPeriodEnd() => $_ensure(9);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
