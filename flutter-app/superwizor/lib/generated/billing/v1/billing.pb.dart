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
    Subscription? stateAfter,
  }) {
    final result = create();
    if (reservationId != null) result.reservationId = reservationId;
    if (sessionId != null) result.sessionId = sessionId;
    if (tokensReserved != null) result.tokensReserved = tokensReserved;
    if (expiresAt != null) result.expiresAt = expiresAt;
    if (stateAfter != null) result.stateAfter = stateAfter;
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
    ..aOM<Subscription>(5, _omitFieldNames ? '' : 'stateAfter',
        subBuilder: Subscription.create)
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

  /// Full counter snapshot AFTER this reservation was applied. Lets the
  /// client refresh its cached billing state from a single round trip
  /// instead of subscribing to a separate Firestore mirror. The field is
  /// populated for newly-created reservations AND for the idempotent
  /// "already exists" path — clients should always overwrite their
  /// local cache with this value.
  @$pb.TagNumber(5)
  Subscription get stateAfter => $_getN(4);
  @$pb.TagNumber(5)
  set stateAfter(Subscription value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasStateAfter() => $_has(4);
  @$pb.TagNumber(5)
  void clearStateAfter() => $_clearField(5);
  @$pb.TagNumber(5)
  Subscription ensureStateAfter() => $_ensure(4);
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
    Subscription? stateAfter,
  }) {
    final result = create();
    if (tokensConsumed != null) result.tokensConsumed = tokensConsumed;
    if (remainingTokens != null) result.remainingTokens = remainingTokens;
    if (limitTokens != null) result.limitTokens = limitTokens;
    if (stateAfter != null) result.stateAfter = stateAfter;
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
    ..aOM<Subscription>(4, _omitFieldNames ? '' : 'stateAfter',
        subBuilder: Subscription.create)
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

  /// Full counter snapshot AFTER this commit. Same role as on
  /// Reservation — primary mechanism for clients to keep their local
  /// billing cache in sync without a separate mirror.
  @$pb.TagNumber(4)
  Subscription get stateAfter => $_getN(3);
  @$pb.TagNumber(4)
  set stateAfter(Subscription value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasStateAfter() => $_has(3);
  @$pb.TagNumber(4)
  void clearStateAfter() => $_clearField(4);
  @$pb.TagNumber(4)
  Subscription ensureStateAfter() => $_ensure(3);
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
    $core.String? planCycle,
    $core.int? tokensRemaining,
    $core.bool? cancelAtPeriodEnd,
    $2.Timestamp? canceledAt,
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
    if (planCycle != null) result.planCycle = planCycle;
    if (tokensRemaining != null) result.tokensRemaining = tokensRemaining;
    if (cancelAtPeriodEnd != null) result.cancelAtPeriodEnd = cancelAtPeriodEnd;
    if (canceledAt != null) result.canceledAt = canceledAt;
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
    ..aOS(11, _omitFieldNames ? '' : 'planCycle')
    ..aI(12, _omitFieldNames ? '' : 'tokensRemaining')
    ..aOB(13, _omitFieldNames ? '' : 'cancelAtPeriodEnd')
    ..aOM<$2.Timestamp>(14, _omitFieldNames ? '' : 'canceledAt',
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

  /// Phase 3b (client-cache refactor): make Subscription a self-contained
  /// snapshot suitable for direct caching on the client. Adds plan_cycle
  /// (so SubscriptionPlanScreen can label MONTHLY vs ANNUAL without a
  /// second lookup) and the server-computed tokens_remaining so callers
  /// never have to reimplement the formula (max(0, limit - used - reserved)).
  @$pb.TagNumber(11)
  $core.String get planCycle => $_getSZ(10);
  @$pb.TagNumber(11)
  set planCycle($core.String value) => $_setString(10, value);
  @$pb.TagNumber(11)
  $core.bool hasPlanCycle() => $_has(10);
  @$pb.TagNumber(11)
  void clearPlanCycle() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.int get tokensRemaining => $_getIZ(11);
  @$pb.TagNumber(12)
  set tokensRemaining($core.int value) => $_setSignedInt32(11, value);
  @$pb.TagNumber(12)
  $core.bool hasTokensRemaining() => $_has(11);
  @$pb.TagNumber(12)
  void clearTokensRemaining() => $_clearField(12);

  @$pb.TagNumber(13)
  $core.bool get cancelAtPeriodEnd => $_getBF(12);
  @$pb.TagNumber(13)
  set cancelAtPeriodEnd($core.bool value) => $_setBool(12, value);
  @$pb.TagNumber(13)
  $core.bool hasCancelAtPeriodEnd() => $_has(12);
  @$pb.TagNumber(13)
  void clearCancelAtPeriodEnd() => $_clearField(13);

  @$pb.TagNumber(14)
  $2.Timestamp get canceledAt => $_getN(13);
  @$pb.TagNumber(14)
  set canceledAt($2.Timestamp value) => $_setField(14, value);
  @$pb.TagNumber(14)
  $core.bool hasCanceledAt() => $_has(13);
  @$pb.TagNumber(14)
  void clearCanceledAt() => $_clearField(14);
  @$pb.TagNumber(14)
  $2.Timestamp ensureCanceledAt() => $_ensure(13);
}

class AdminResetTokensRequest extends $pb.GeneratedMessage {
  factory AdminResetTokensRequest({
    $core.String? organizationId,
    $core.int? tokensUsed,
    $core.int? tokensLimit,
    $core.String? reason,
    $core.String? idempotencyKey,
  }) {
    final result = create();
    if (organizationId != null) result.organizationId = organizationId;
    if (tokensUsed != null) result.tokensUsed = tokensUsed;
    if (tokensLimit != null) result.tokensLimit = tokensLimit;
    if (reason != null) result.reason = reason;
    if (idempotencyKey != null) result.idempotencyKey = idempotencyKey;
    return result;
  }

  AdminResetTokensRequest._();

  factory AdminResetTokensRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AdminResetTokensRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AdminResetTokensRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'billing.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'organizationId')
    ..aI(2, _omitFieldNames ? '' : 'tokensUsed')
    ..aI(3, _omitFieldNames ? '' : 'tokensLimit')
    ..aOS(4, _omitFieldNames ? '' : 'reason')
    ..aOS(5, _omitFieldNames ? '' : 'idempotencyKey')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminResetTokensRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminResetTokensRequest copyWith(
          void Function(AdminResetTokensRequest) updates) =>
      super.copyWith((message) => updates(message as AdminResetTokensRequest))
          as AdminResetTokensRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AdminResetTokensRequest create() => AdminResetTokensRequest._();
  @$core.override
  AdminResetTokensRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AdminResetTokensRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AdminResetTokensRequest>(create);
  static AdminResetTokensRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get organizationId => $_getSZ(0);
  @$pb.TagNumber(1)
  set organizationId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasOrganizationId() => $_has(0);
  @$pb.TagNumber(1)
  void clearOrganizationId() => $_clearField(1);

  /// New value for usage_counters.tokens_used. Must be >= 0.
  /// Pass -1 to leave tokens_used unchanged (limit-only updates).
  @$pb.TagNumber(2)
  $core.int get tokensUsed => $_getIZ(1);
  @$pb.TagNumber(2)
  set tokensUsed($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTokensUsed() => $_has(1);
  @$pb.TagNumber(2)
  void clearTokensUsed() => $_clearField(2);

  /// Optional override on tokens_limit. Pass -1 to leave it untouched
  /// (only adjust tokens_used). When set, must be > 0.
  @$pb.TagNumber(3)
  $core.int get tokensLimit => $_getIZ(2);
  @$pb.TagNumber(3)
  set tokensLimit($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTokensLimit() => $_has(2);
  @$pb.TagNumber(3)
  void clearTokensLimit() => $_clearField(3);

  /// Required, >= 10 chars. Stored on audit_events.reason.
  @$pb.TagNumber(4)
  $core.String get reason => $_getSZ(3);
  @$pb.TagNumber(4)
  set reason($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasReason() => $_has(3);
  @$pb.TagNumber(4)
  void clearReason() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get idempotencyKey => $_getSZ(4);
  @$pb.TagNumber(5)
  set idempotencyKey($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasIdempotencyKey() => $_has(4);
  @$pb.TagNumber(5)
  void clearIdempotencyKey() => $_clearField(5);
}

class AdminChangePlanRequest extends $pb.GeneratedMessage {
  factory AdminChangePlanRequest({
    $core.String? organizationId,
    $core.String? planTier,
    $core.String? planCycle,
    $core.String? reason,
    $core.String? idempotencyKey,
  }) {
    final result = create();
    if (organizationId != null) result.organizationId = organizationId;
    if (planTier != null) result.planTier = planTier;
    if (planCycle != null) result.planCycle = planCycle;
    if (reason != null) result.reason = reason;
    if (idempotencyKey != null) result.idempotencyKey = idempotencyKey;
    return result;
  }

  AdminChangePlanRequest._();

  factory AdminChangePlanRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AdminChangePlanRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AdminChangePlanRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'billing.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'organizationId')
    ..aOS(2, _omitFieldNames ? '' : 'planTier')
    ..aOS(3, _omitFieldNames ? '' : 'planCycle')
    ..aOS(4, _omitFieldNames ? '' : 'reason')
    ..aOS(5, _omitFieldNames ? '' : 'idempotencyKey')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminChangePlanRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminChangePlanRequest copyWith(
          void Function(AdminChangePlanRequest) updates) =>
      super.copyWith((message) => updates(message as AdminChangePlanRequest))
          as AdminChangePlanRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AdminChangePlanRequest create() => AdminChangePlanRequest._();
  @$core.override
  AdminChangePlanRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AdminChangePlanRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AdminChangePlanRequest>(create);
  static AdminChangePlanRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get organizationId => $_getSZ(0);
  @$pb.TagNumber(1)
  set organizationId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasOrganizationId() => $_has(0);
  @$pb.TagNumber(1)
  void clearOrganizationId() => $_clearField(1);

  /// Target plan_tier (SOLO | PRO | CLINIC | TRIAL) and cycle
  /// (MONTHLY | ANNUAL). Resolves to a subscription_plans row at
  /// handler time.
  @$pb.TagNumber(2)
  $core.String get planTier => $_getSZ(1);
  @$pb.TagNumber(2)
  set planTier($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPlanTier() => $_has(1);
  @$pb.TagNumber(2)
  void clearPlanTier() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get planCycle => $_getSZ(2);
  @$pb.TagNumber(3)
  set planCycle($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPlanCycle() => $_has(2);
  @$pb.TagNumber(3)
  void clearPlanCycle() => $_clearField(3);

  /// Required, >= 10 chars.
  @$pb.TagNumber(4)
  $core.String get reason => $_getSZ(3);
  @$pb.TagNumber(4)
  set reason($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasReason() => $_has(3);
  @$pb.TagNumber(4)
  void clearReason() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get idempotencyKey => $_getSZ(4);
  @$pb.TagNumber(5)
  set idempotencyKey($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasIdempotencyKey() => $_has(4);
  @$pb.TagNumber(5)
  void clearIdempotencyKey() => $_clearField(5);
}

class ListInvoicesRequest extends $pb.GeneratedMessage {
  factory ListInvoicesRequest({
    $core.String? organizationId,
  }) {
    final result = create();
    if (organizationId != null) result.organizationId = organizationId;
    return result;
  }

  ListInvoicesRequest._();

  factory ListInvoicesRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ListInvoicesRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListInvoicesRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'billing.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'organizationId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListInvoicesRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListInvoicesRequest copyWith(void Function(ListInvoicesRequest) updates) =>
      super.copyWith((message) => updates(message as ListInvoicesRequest))
          as ListInvoicesRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListInvoicesRequest create() => ListInvoicesRequest._();
  @$core.override
  ListInvoicesRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ListInvoicesRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListInvoicesRequest>(create);
  static ListInvoicesRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get organizationId => $_getSZ(0);
  @$pb.TagNumber(1)
  set organizationId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasOrganizationId() => $_has(0);
  @$pb.TagNumber(1)
  void clearOrganizationId() => $_clearField(1);
}

class ListInvoicesResponse extends $pb.GeneratedMessage {
  factory ListInvoicesResponse({
    $core.Iterable<Invoice>? invoices,
  }) {
    final result = create();
    if (invoices != null) result.invoices.addAll(invoices);
    return result;
  }

  ListInvoicesResponse._();

  factory ListInvoicesResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ListInvoicesResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListInvoicesResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'billing.v1'),
      createEmptyInstance: create)
    ..pPM<Invoice>(1, _omitFieldNames ? '' : 'invoices',
        subBuilder: Invoice.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListInvoicesResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListInvoicesResponse copyWith(void Function(ListInvoicesResponse) updates) =>
      super.copyWith((message) => updates(message as ListInvoicesResponse))
          as ListInvoicesResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListInvoicesResponse create() => ListInvoicesResponse._();
  @$core.override
  ListInvoicesResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ListInvoicesResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListInvoicesResponse>(create);
  static ListInvoicesResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<Invoice> get invoices => $_getList(0);
}

class Invoice extends $pb.GeneratedMessage {
  factory Invoice({
    $core.String? id,
    $core.String? stripeInvoiceId,
    $core.double? amountPaid,
    $core.String? currency,
    $core.String? invoicePdf,
    $core.String? hostedInvoiceUrl,
    $2.Timestamp? periodStart,
    $2.Timestamp? periodEnd,
    $2.Timestamp? createdAt,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (stripeInvoiceId != null) result.stripeInvoiceId = stripeInvoiceId;
    if (amountPaid != null) result.amountPaid = amountPaid;
    if (currency != null) result.currency = currency;
    if (invoicePdf != null) result.invoicePdf = invoicePdf;
    if (hostedInvoiceUrl != null) result.hostedInvoiceUrl = hostedInvoiceUrl;
    if (periodStart != null) result.periodStart = periodStart;
    if (periodEnd != null) result.periodEnd = periodEnd;
    if (createdAt != null) result.createdAt = createdAt;
    return result;
  }

  Invoice._();

  factory Invoice.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Invoice.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Invoice',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'billing.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'stripeInvoiceId')
    ..aD(3, _omitFieldNames ? '' : 'amountPaid')
    ..aOS(4, _omitFieldNames ? '' : 'currency')
    ..aOS(5, _omitFieldNames ? '' : 'invoicePdf')
    ..aOS(6, _omitFieldNames ? '' : 'hostedInvoiceUrl')
    ..aOM<$2.Timestamp>(7, _omitFieldNames ? '' : 'periodStart',
        subBuilder: $2.Timestamp.create)
    ..aOM<$2.Timestamp>(8, _omitFieldNames ? '' : 'periodEnd',
        subBuilder: $2.Timestamp.create)
    ..aOM<$2.Timestamp>(9, _omitFieldNames ? '' : 'createdAt',
        subBuilder: $2.Timestamp.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Invoice clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Invoice copyWith(void Function(Invoice) updates) =>
      super.copyWith((message) => updates(message as Invoice)) as Invoice;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Invoice create() => Invoice._();
  @$core.override
  Invoice createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Invoice getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Invoice>(create);
  static Invoice? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get stripeInvoiceId => $_getSZ(1);
  @$pb.TagNumber(2)
  set stripeInvoiceId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasStripeInvoiceId() => $_has(1);
  @$pb.TagNumber(2)
  void clearStripeInvoiceId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.double get amountPaid => $_getN(2);
  @$pb.TagNumber(3)
  set amountPaid($core.double value) => $_setDouble(2, value);
  @$pb.TagNumber(3)
  $core.bool hasAmountPaid() => $_has(2);
  @$pb.TagNumber(3)
  void clearAmountPaid() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get currency => $_getSZ(3);
  @$pb.TagNumber(4)
  set currency($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasCurrency() => $_has(3);
  @$pb.TagNumber(4)
  void clearCurrency() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get invoicePdf => $_getSZ(4);
  @$pb.TagNumber(5)
  set invoicePdf($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasInvoicePdf() => $_has(4);
  @$pb.TagNumber(5)
  void clearInvoicePdf() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get hostedInvoiceUrl => $_getSZ(5);
  @$pb.TagNumber(6)
  set hostedInvoiceUrl($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasHostedInvoiceUrl() => $_has(5);
  @$pb.TagNumber(6)
  void clearHostedInvoiceUrl() => $_clearField(6);

  @$pb.TagNumber(7)
  $2.Timestamp get periodStart => $_getN(6);
  @$pb.TagNumber(7)
  set periodStart($2.Timestamp value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasPeriodStart() => $_has(6);
  @$pb.TagNumber(7)
  void clearPeriodStart() => $_clearField(7);
  @$pb.TagNumber(7)
  $2.Timestamp ensurePeriodStart() => $_ensure(6);

  @$pb.TagNumber(8)
  $2.Timestamp get periodEnd => $_getN(7);
  @$pb.TagNumber(8)
  set periodEnd($2.Timestamp value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasPeriodEnd() => $_has(7);
  @$pb.TagNumber(8)
  void clearPeriodEnd() => $_clearField(8);
  @$pb.TagNumber(8)
  $2.Timestamp ensurePeriodEnd() => $_ensure(7);

  @$pb.TagNumber(9)
  $2.Timestamp get createdAt => $_getN(8);
  @$pb.TagNumber(9)
  set createdAt($2.Timestamp value) => $_setField(9, value);
  @$pb.TagNumber(9)
  $core.bool hasCreatedAt() => $_has(8);
  @$pb.TagNumber(9)
  void clearCreatedAt() => $_clearField(9);
  @$pb.TagNumber(9)
  $2.Timestamp ensureCreatedAt() => $_ensure(8);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
