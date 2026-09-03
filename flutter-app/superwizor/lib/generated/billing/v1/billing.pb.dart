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
    $core.String? therapistId,
  }) {
    final result = create();
    if (organizationId != null) result.organizationId = organizationId;
    if (therapistId != null) result.therapistId = therapistId;
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
    ..aOS(2, _omitFieldNames ? '' : 'therapistId')
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

  /// Whose quota to report. Optional and additive: omit it (every
  /// existing server-to-server caller does) and the response carries the
  /// organization-wide numbers exactly as before.
  ///
  /// Set by clinical-svc on GetMyBillingState. Under the docs/38 seat
  /// model a therapist in an org spends against a PER-THERAPIST counter,
  /// but the app was reading the org-level one — so the phone showed the
  /// org's limit (40/0) while the org panel showed the therapist's real
  /// seat (30/1). Same period, two different counter rows.
  @$pb.TagNumber(2)
  $core.String get therapistId => $_getSZ(1);
  @$pb.TagNumber(2)
  set therapistId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTherapistId() => $_has(1);
  @$pb.TagNumber(2)
  void clearTherapistId() => $_clearField(2);
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
    $core.String? billingProvider,
    $2.Timestamp? graceUntil,
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
    if (billingProvider != null) result.billingProvider = billingProvider;
    if (graceUntil != null) result.graceUntil = graceUntil;
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
    ..aOS(15, _omitFieldNames ? '' : 'billingProvider')
    ..aOM<$2.Timestamp>(16, _omitFieldNames ? '' : 'graceUntil',
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

  /// docs/70: kto sprzedał tę subskrypcję — STRIPE | APPLE_IAP |
  /// GOOGLE_IAP | MANUAL | P24. Decyduje, co pokazać na ekranie
  /// Subskrypcja: link do portalu Stripe, deep link do sklepu, czy
  /// komunikat "planem zarządza Twoja organizacja". Puste dla starych
  /// klientów, którzy nie znają tego pola.
  @$pb.TagNumber(15)
  $core.String get billingProvider => $_getSZ(14);
  @$pb.TagNumber(15)
  set billingProvider($core.String value) => $_setString(14, value);
  @$pb.TagNumber(15)
  $core.bool hasBillingProvider() => $_has(14);
  @$pb.TagNumber(15)
  void clearBillingProvider() => $_clearField(15);

  /// Koniec billing grace period ze sklepu (nieudane obciążenie, dostęp
  /// trwa). Puste poza tym stanem.
  @$pb.TagNumber(16)
  $2.Timestamp get graceUntil => $_getN(15);
  @$pb.TagNumber(16)
  set graceUntil($2.Timestamp value) => $_setField(16, value);
  @$pb.TagNumber(16)
  $core.bool hasGraceUntil() => $_has(15);
  @$pb.TagNumber(16)
  void clearGraceUntil() => $_clearField(16);
  @$pb.TagNumber(16)
  $2.Timestamp ensureGraceUntil() => $_ensure(15);
}

class AdminResetTokensRequest extends $pb.GeneratedMessage {
  factory AdminResetTokensRequest({
    $core.String? organizationId,
    $core.int? tokensUsed,
    $core.int? tokensLimit,
    $core.String? reason,
    $core.String? idempotencyKey,
    $core.String? therapistId,
  }) {
    final result = create();
    if (organizationId != null) result.organizationId = organizationId;
    if (tokensUsed != null) result.tokensUsed = tokensUsed;
    if (tokensLimit != null) result.tokensLimit = tokensLimit;
    if (reason != null) result.reason = reason;
    if (idempotencyKey != null) result.idempotencyKey = idempotencyKey;
    if (therapistId != null) result.therapistId = therapistId;
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
    ..aOS(6, _omitFieldNames ? '' : 'therapistId')
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

  /// Optional scope narrowing. Empty (default) keeps the historical
  /// behaviour: tokens_used lands on EVERY active per-therapist counter
  /// of the organization plus the org-level one.
  ///
  /// When set, the reset touches ONLY that therapist's counter. The
  /// admin panel's user card sends it — without this field the card
  /// reset the whole organization while its audit reason named a single
  /// person, so the trail claimed less than the operation did.
  ///
  /// tokens_limit is rejected in this mode: per-seat limits come from
  /// the seat's plan (org_seat_allocations), not from an operator
  /// override. Allowing one here would recreate the 2026-08-01 "40 on a
  /// 90 plan" incident at seat level.
  @$pb.TagNumber(6)
  $core.String get therapistId => $_getSZ(5);
  @$pb.TagNumber(6)
  set therapistId($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasTherapistId() => $_has(5);
  @$pb.TagNumber(6)
  void clearTherapistId() => $_clearField(6);
}

class PlanInfo extends $pb.GeneratedMessage {
  factory PlanInfo({
    $core.String? planId,
    $core.String? tier,
    $core.String? cycle,
    $core.String? displayName,
    $core.String? priceGross,
    $core.String? currencyCode,
    $core.int? tokensPerPeriod,
  }) {
    final result = create();
    if (planId != null) result.planId = planId;
    if (tier != null) result.tier = tier;
    if (cycle != null) result.cycle = cycle;
    if (displayName != null) result.displayName = displayName;
    if (priceGross != null) result.priceGross = priceGross;
    if (currencyCode != null) result.currencyCode = currencyCode;
    if (tokensPerPeriod != null) result.tokensPerPeriod = tokensPerPeriod;
    return result;
  }

  PlanInfo._();

  factory PlanInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PlanInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PlanInfo',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'billing.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'planId')
    ..aOS(2, _omitFieldNames ? '' : 'tier')
    ..aOS(3, _omitFieldNames ? '' : 'cycle')
    ..aOS(4, _omitFieldNames ? '' : 'displayName')
    ..aOS(5, _omitFieldNames ? '' : 'priceGross')
    ..aOS(6, _omitFieldNames ? '' : 'currencyCode')
    ..aI(7, _omitFieldNames ? '' : 'tokensPerPeriod')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PlanInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PlanInfo copyWith(void Function(PlanInfo) updates) =>
      super.copyWith((message) => updates(message as PlanInfo)) as PlanInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PlanInfo create() => PlanInfo._();
  @$core.override
  PlanInfo createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PlanInfo getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<PlanInfo>(create);
  static PlanInfo? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get planId => $_getSZ(0);
  @$pb.TagNumber(1)
  set planId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPlanId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPlanId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get tier => $_getSZ(1);
  @$pb.TagNumber(2)
  set tier($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTier() => $_has(1);
  @$pb.TagNumber(2)
  void clearTier() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get cycle => $_getSZ(2);
  @$pb.TagNumber(3)
  set cycle($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCycle() => $_has(2);
  @$pb.TagNumber(3)
  void clearCycle() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get displayName => $_getSZ(3);
  @$pb.TagNumber(4)
  set displayName($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasDisplayName() => $_has(3);
  @$pb.TagNumber(4)
  void clearDisplayName() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get priceGross => $_getSZ(4);
  @$pb.TagNumber(5)
  set priceGross($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasPriceGross() => $_has(4);
  @$pb.TagNumber(5)
  void clearPriceGross() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get currencyCode => $_getSZ(5);
  @$pb.TagNumber(6)
  set currencyCode($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasCurrencyCode() => $_has(5);
  @$pb.TagNumber(6)
  void clearCurrencyCode() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get tokensPerPeriod => $_getIZ(6);
  @$pb.TagNumber(7)
  set tokensPerPeriod($core.int value) => $_setSignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasTokensPerPeriod() => $_has(6);
  @$pb.TagNumber(7)
  void clearTokensPerPeriod() => $_clearField(7);
}

class AdminListPlansResponse extends $pb.GeneratedMessage {
  factory AdminListPlansResponse({
    $core.Iterable<PlanInfo>? plans,
  }) {
    final result = create();
    if (plans != null) result.plans.addAll(plans);
    return result;
  }

  AdminListPlansResponse._();

  factory AdminListPlansResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AdminListPlansResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AdminListPlansResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'billing.v1'),
      createEmptyInstance: create)
    ..pPM<PlanInfo>(1, _omitFieldNames ? '' : 'plans',
        subBuilder: PlanInfo.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminListPlansResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminListPlansResponse copyWith(
          void Function(AdminListPlansResponse) updates) =>
      super.copyWith((message) => updates(message as AdminListPlansResponse))
          as AdminListPlansResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AdminListPlansResponse create() => AdminListPlansResponse._();
  @$core.override
  AdminListPlansResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AdminListPlansResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AdminListPlansResponse>(create);
  static AdminListPlansResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<PlanInfo> get plans => $_getList(0);
}

class AdminGetOrgSeatUsageRequest extends $pb.GeneratedMessage {
  factory AdminGetOrgSeatUsageRequest({
    $core.String? organizationId,
  }) {
    final result = create();
    if (organizationId != null) result.organizationId = organizationId;
    return result;
  }

  AdminGetOrgSeatUsageRequest._();

  factory AdminGetOrgSeatUsageRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AdminGetOrgSeatUsageRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AdminGetOrgSeatUsageRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'billing.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'organizationId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminGetOrgSeatUsageRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminGetOrgSeatUsageRequest copyWith(
          void Function(AdminGetOrgSeatUsageRequest) updates) =>
      super.copyWith(
              (message) => updates(message as AdminGetOrgSeatUsageRequest))
          as AdminGetOrgSeatUsageRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AdminGetOrgSeatUsageRequest create() =>
      AdminGetOrgSeatUsageRequest._();
  @$core.override
  AdminGetOrgSeatUsageRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AdminGetOrgSeatUsageRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AdminGetOrgSeatUsageRequest>(create);
  static AdminGetOrgSeatUsageRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get organizationId => $_getSZ(0);
  @$pb.TagNumber(1)
  set organizationId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasOrganizationId() => $_has(0);
  @$pb.TagNumber(1)
  void clearOrganizationId() => $_clearField(1);
}

class SeatAllocationSpec extends $pb.GeneratedMessage {
  factory SeatAllocationSpec({
    $core.String? planId,
    $core.int? seats,
    $core.String? priceGrossPerSeat,
  }) {
    final result = create();
    if (planId != null) result.planId = planId;
    if (seats != null) result.seats = seats;
    if (priceGrossPerSeat != null) result.priceGrossPerSeat = priceGrossPerSeat;
    return result;
  }

  SeatAllocationSpec._();

  factory SeatAllocationSpec.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SeatAllocationSpec.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SeatAllocationSpec',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'billing.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'planId')
    ..aI(2, _omitFieldNames ? '' : 'seats')
    ..aOS(3, _omitFieldNames ? '' : 'priceGrossPerSeat')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SeatAllocationSpec clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SeatAllocationSpec copyWith(void Function(SeatAllocationSpec) updates) =>
      super.copyWith((message) => updates(message as SeatAllocationSpec))
          as SeatAllocationSpec;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SeatAllocationSpec create() => SeatAllocationSpec._();
  @$core.override
  SeatAllocationSpec createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SeatAllocationSpec getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SeatAllocationSpec>(create);
  static SeatAllocationSpec? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get planId => $_getSZ(0);
  @$pb.TagNumber(1)
  set planId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPlanId() => $_has(0);
  @$pb.TagNumber(1)
  void clearPlanId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get seats => $_getIZ(1);
  @$pb.TagNumber(2)
  set seats($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSeats() => $_has(1);
  @$pb.TagNumber(2)
  void clearSeats() => $_clearField(2);

  /// Negotiated gross price per seat as a decimal string ("79.99").
  /// Empty = catalog plan.price_gross.
  @$pb.TagNumber(3)
  $core.String get priceGrossPerSeat => $_getSZ(2);
  @$pb.TagNumber(3)
  set priceGrossPerSeat($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPriceGrossPerSeat() => $_has(2);
  @$pb.TagNumber(3)
  void clearPriceGrossPerSeat() => $_clearField(3);
}

class AdminSetSeatAllocationsRequest extends $pb.GeneratedMessage {
  factory AdminSetSeatAllocationsRequest({
    $core.String? organizationId,
    $core.Iterable<SeatAllocationSpec>? allocations,
    $2.Timestamp? subscriptionStart,
    $core.String? reason,
    $core.String? idempotencyKey,
  }) {
    final result = create();
    if (organizationId != null) result.organizationId = organizationId;
    if (allocations != null) result.allocations.addAll(allocations);
    if (subscriptionStart != null) result.subscriptionStart = subscriptionStart;
    if (reason != null) result.reason = reason;
    if (idempotencyKey != null) result.idempotencyKey = idempotencyKey;
    return result;
  }

  AdminSetSeatAllocationsRequest._();

  factory AdminSetSeatAllocationsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AdminSetSeatAllocationsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AdminSetSeatAllocationsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'billing.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'organizationId')
    ..pPM<SeatAllocationSpec>(2, _omitFieldNames ? '' : 'allocations',
        subBuilder: SeatAllocationSpec.create)
    ..aOM<$2.Timestamp>(3, _omitFieldNames ? '' : 'subscriptionStart',
        subBuilder: $2.Timestamp.create)
    ..aOS(15, _omitFieldNames ? '' : 'reason')
    ..aOS(16, _omitFieldNames ? '' : 'idempotencyKey')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminSetSeatAllocationsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminSetSeatAllocationsRequest copyWith(
          void Function(AdminSetSeatAllocationsRequest) updates) =>
      super.copyWith(
              (message) => updates(message as AdminSetSeatAllocationsRequest))
          as AdminSetSeatAllocationsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AdminSetSeatAllocationsRequest create() =>
      AdminSetSeatAllocationsRequest._();
  @$core.override
  AdminSetSeatAllocationsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AdminSetSeatAllocationsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AdminSetSeatAllocationsRequest>(create);
  static AdminSetSeatAllocationsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get organizationId => $_getSZ(0);
  @$pb.TagNumber(1)
  set organizationId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasOrganizationId() => $_has(0);
  @$pb.TagNumber(1)
  void clearOrganizationId() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<SeatAllocationSpec> get allocations => $_getList(1);

  /// Start of the (first) subscription period. Ignored when the org
  /// already has an active subscription — the running period wins.
  @$pb.TagNumber(3)
  $2.Timestamp get subscriptionStart => $_getN(2);
  @$pb.TagNumber(3)
  set subscriptionStart($2.Timestamp value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasSubscriptionStart() => $_has(2);
  @$pb.TagNumber(3)
  void clearSubscriptionStart() => $_clearField(3);
  @$pb.TagNumber(3)
  $2.Timestamp ensureSubscriptionStart() => $_ensure(2);

  @$pb.TagNumber(15)
  $core.String get reason => $_getSZ(3);
  @$pb.TagNumber(15)
  set reason($core.String value) => $_setString(3, value);
  @$pb.TagNumber(15)
  $core.bool hasReason() => $_has(3);
  @$pb.TagNumber(15)
  void clearReason() => $_clearField(15);

  @$pb.TagNumber(16)
  $core.String get idempotencyKey => $_getSZ(4);
  @$pb.TagNumber(16)
  set idempotencyKey($core.String value) => $_setString(4, value);
  @$pb.TagNumber(16)
  $core.bool hasIdempotencyKey() => $_has(4);
  @$pb.TagNumber(16)
  void clearIdempotencyKey() => $_clearField(16);
}

class SeatAllocationInfo extends $pb.GeneratedMessage {
  factory SeatAllocationInfo({
    $core.String? allocationId,
    $core.String? planId,
    $core.String? planTier,
    $core.String? planCycle,
    $core.int? seats,
    $core.int? seatsAssigned,
    $core.int? seatsPending,
    $core.String? priceGrossPerSeat,
    $core.String? currencyCode,
    $core.int? tokensPerSeat,
  }) {
    final result = create();
    if (allocationId != null) result.allocationId = allocationId;
    if (planId != null) result.planId = planId;
    if (planTier != null) result.planTier = planTier;
    if (planCycle != null) result.planCycle = planCycle;
    if (seats != null) result.seats = seats;
    if (seatsAssigned != null) result.seatsAssigned = seatsAssigned;
    if (seatsPending != null) result.seatsPending = seatsPending;
    if (priceGrossPerSeat != null) result.priceGrossPerSeat = priceGrossPerSeat;
    if (currencyCode != null) result.currencyCode = currencyCode;
    if (tokensPerSeat != null) result.tokensPerSeat = tokensPerSeat;
    return result;
  }

  SeatAllocationInfo._();

  factory SeatAllocationInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SeatAllocationInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SeatAllocationInfo',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'billing.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'allocationId')
    ..aOS(2, _omitFieldNames ? '' : 'planId')
    ..aOS(3, _omitFieldNames ? '' : 'planTier')
    ..aOS(4, _omitFieldNames ? '' : 'planCycle')
    ..aI(5, _omitFieldNames ? '' : 'seats')
    ..aI(6, _omitFieldNames ? '' : 'seatsAssigned')
    ..aI(7, _omitFieldNames ? '' : 'seatsPending')
    ..aOS(8, _omitFieldNames ? '' : 'priceGrossPerSeat')
    ..aOS(9, _omitFieldNames ? '' : 'currencyCode')
    ..aI(10, _omitFieldNames ? '' : 'tokensPerSeat')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SeatAllocationInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SeatAllocationInfo copyWith(void Function(SeatAllocationInfo) updates) =>
      super.copyWith((message) => updates(message as SeatAllocationInfo))
          as SeatAllocationInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SeatAllocationInfo create() => SeatAllocationInfo._();
  @$core.override
  SeatAllocationInfo createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SeatAllocationInfo getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SeatAllocationInfo>(create);
  static SeatAllocationInfo? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get allocationId => $_getSZ(0);
  @$pb.TagNumber(1)
  set allocationId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAllocationId() => $_has(0);
  @$pb.TagNumber(1)
  void clearAllocationId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get planId => $_getSZ(1);
  @$pb.TagNumber(2)
  set planId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPlanId() => $_has(1);
  @$pb.TagNumber(2)
  void clearPlanId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get planTier => $_getSZ(2);
  @$pb.TagNumber(3)
  set planTier($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPlanTier() => $_has(2);
  @$pb.TagNumber(3)
  void clearPlanTier() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get planCycle => $_getSZ(3);
  @$pb.TagNumber(4)
  set planCycle($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasPlanCycle() => $_has(3);
  @$pb.TagNumber(4)
  void clearPlanCycle() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get seats => $_getIZ(4);
  @$pb.TagNumber(5)
  set seats($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasSeats() => $_has(4);
  @$pb.TagNumber(5)
  void clearSeats() => $_clearField(5);

  /// Occupancy halves (docs/38 §3): active assignments + pending
  /// unexpired invitations.
  @$pb.TagNumber(6)
  $core.int get seatsAssigned => $_getIZ(5);
  @$pb.TagNumber(6)
  set seatsAssigned($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasSeatsAssigned() => $_has(5);
  @$pb.TagNumber(6)
  void clearSeatsAssigned() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get seatsPending => $_getIZ(6);
  @$pb.TagNumber(7)
  set seatsPending($core.int value) => $_setSignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasSeatsPending() => $_has(6);
  @$pb.TagNumber(7)
  void clearSeatsPending() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get priceGrossPerSeat => $_getSZ(7);
  @$pb.TagNumber(8)
  set priceGrossPerSeat($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasPriceGrossPerSeat() => $_has(7);
  @$pb.TagNumber(8)
  void clearPriceGrossPerSeat() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.String get currencyCode => $_getSZ(8);
  @$pb.TagNumber(9)
  set currencyCode($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasCurrencyCode() => $_has(8);
  @$pb.TagNumber(9)
  void clearCurrencyCode() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.int get tokensPerSeat => $_getIZ(9);
  @$pb.TagNumber(10)
  set tokensPerSeat($core.int value) => $_setSignedInt32(9, value);
  @$pb.TagNumber(10)
  $core.bool hasTokensPerSeat() => $_has(9);
  @$pb.TagNumber(10)
  void clearTokensPerSeat() => $_clearField(10);
}

class TherapistSeatUsage extends $pb.GeneratedMessage {
  factory TherapistSeatUsage({
    $core.String? therapistId,
    $core.String? firstName,
    $core.String? lastName,
    $core.String? planTier,
    $core.int? tokensUsed,
    $core.int? tokensReserved,
    $core.int? tokensLimit,
    $core.bool? isActive,
  }) {
    final result = create();
    if (therapistId != null) result.therapistId = therapistId;
    if (firstName != null) result.firstName = firstName;
    if (lastName != null) result.lastName = lastName;
    if (planTier != null) result.planTier = planTier;
    if (tokensUsed != null) result.tokensUsed = tokensUsed;
    if (tokensReserved != null) result.tokensReserved = tokensReserved;
    if (tokensLimit != null) result.tokensLimit = tokensLimit;
    if (isActive != null) result.isActive = isActive;
    return result;
  }

  TherapistSeatUsage._();

  factory TherapistSeatUsage.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory TherapistSeatUsage.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TherapistSeatUsage',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'billing.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'therapistId')
    ..aOS(2, _omitFieldNames ? '' : 'firstName')
    ..aOS(3, _omitFieldNames ? '' : 'lastName')
    ..aOS(4, _omitFieldNames ? '' : 'planTier')
    ..aI(5, _omitFieldNames ? '' : 'tokensUsed')
    ..aI(6, _omitFieldNames ? '' : 'tokensReserved')
    ..aI(7, _omitFieldNames ? '' : 'tokensLimit')
    ..aOB(8, _omitFieldNames ? '' : 'isActive')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TherapistSeatUsage clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TherapistSeatUsage copyWith(void Function(TherapistSeatUsage) updates) =>
      super.copyWith((message) => updates(message as TherapistSeatUsage))
          as TherapistSeatUsage;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TherapistSeatUsage create() => TherapistSeatUsage._();
  @$core.override
  TherapistSeatUsage createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static TherapistSeatUsage getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TherapistSeatUsage>(create);
  static TherapistSeatUsage? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get therapistId => $_getSZ(0);
  @$pb.TagNumber(1)
  set therapistId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTherapistId() => $_has(0);
  @$pb.TagNumber(1)
  void clearTherapistId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get firstName => $_getSZ(1);
  @$pb.TagNumber(2)
  set firstName($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasFirstName() => $_has(1);
  @$pb.TagNumber(2)
  void clearFirstName() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get lastName => $_getSZ(2);
  @$pb.TagNumber(3)
  set lastName($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasLastName() => $_has(2);
  @$pb.TagNumber(3)
  void clearLastName() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get planTier => $_getSZ(3);
  @$pb.TagNumber(4)
  set planTier($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasPlanTier() => $_has(3);
  @$pb.TagNumber(4)
  void clearPlanTier() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get tokensUsed => $_getIZ(4);
  @$pb.TagNumber(5)
  set tokensUsed($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasTokensUsed() => $_has(4);
  @$pb.TagNumber(5)
  void clearTokensUsed() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get tokensReserved => $_getIZ(5);
  @$pb.TagNumber(6)
  set tokensReserved($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasTokensReserved() => $_has(5);
  @$pb.TagNumber(6)
  void clearTokensReserved() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get tokensLimit => $_getIZ(6);
  @$pb.TagNumber(7)
  set tokensLimit($core.int value) => $_setSignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasTokensLimit() => $_has(6);
  @$pb.TagNumber(7)
  void clearTokensLimit() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.bool get isActive => $_getBF(7);
  @$pb.TagNumber(8)
  set isActive($core.bool value) => $_setBool(7, value);
  @$pb.TagNumber(8)
  $core.bool hasIsActive() => $_has(7);
  @$pb.TagNumber(8)
  void clearIsActive() => $_clearField(8);
}

class OrgSeatSummary extends $pb.GeneratedMessage {
  factory OrgSeatSummary({
    $core.String? organizationId,
    $core.Iterable<SeatAllocationInfo>? allocations,
    $core.Iterable<TherapistSeatUsage>? therapistUsage,
    $2.Timestamp? periodStart,
    $2.Timestamp? periodEnd,
    $core.String? subscriptionStatus,
  }) {
    final result = create();
    if (organizationId != null) result.organizationId = organizationId;
    if (allocations != null) result.allocations.addAll(allocations);
    if (therapistUsage != null) result.therapistUsage.addAll(therapistUsage);
    if (periodStart != null) result.periodStart = periodStart;
    if (periodEnd != null) result.periodEnd = periodEnd;
    if (subscriptionStatus != null)
      result.subscriptionStatus = subscriptionStatus;
    return result;
  }

  OrgSeatSummary._();

  factory OrgSeatSummary.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory OrgSeatSummary.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'OrgSeatSummary',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'billing.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'organizationId')
    ..pPM<SeatAllocationInfo>(2, _omitFieldNames ? '' : 'allocations',
        subBuilder: SeatAllocationInfo.create)
    ..pPM<TherapistSeatUsage>(3, _omitFieldNames ? '' : 'therapistUsage',
        subBuilder: TherapistSeatUsage.create)
    ..aOM<$2.Timestamp>(4, _omitFieldNames ? '' : 'periodStart',
        subBuilder: $2.Timestamp.create)
    ..aOM<$2.Timestamp>(5, _omitFieldNames ? '' : 'periodEnd',
        subBuilder: $2.Timestamp.create)
    ..aOS(6, _omitFieldNames ? '' : 'subscriptionStatus')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OrgSeatSummary clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  OrgSeatSummary copyWith(void Function(OrgSeatSummary) updates) =>
      super.copyWith((message) => updates(message as OrgSeatSummary))
          as OrgSeatSummary;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static OrgSeatSummary create() => OrgSeatSummary._();
  @$core.override
  OrgSeatSummary createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static OrgSeatSummary getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<OrgSeatSummary>(create);
  static OrgSeatSummary? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get organizationId => $_getSZ(0);
  @$pb.TagNumber(1)
  set organizationId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasOrganizationId() => $_has(0);
  @$pb.TagNumber(1)
  void clearOrganizationId() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<SeatAllocationInfo> get allocations => $_getList(1);

  /// Per-therapist counters for the current period (docs/38 billing
  /// model: enforcement per seat). Empty for orgs without allocations.
  @$pb.TagNumber(3)
  $pb.PbList<TherapistSeatUsage> get therapistUsage => $_getList(2);

  @$pb.TagNumber(4)
  $2.Timestamp get periodStart => $_getN(3);
  @$pb.TagNumber(4)
  set periodStart($2.Timestamp value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasPeriodStart() => $_has(3);
  @$pb.TagNumber(4)
  void clearPeriodStart() => $_clearField(4);
  @$pb.TagNumber(4)
  $2.Timestamp ensurePeriodStart() => $_ensure(3);

  @$pb.TagNumber(5)
  $2.Timestamp get periodEnd => $_getN(4);
  @$pb.TagNumber(5)
  set periodEnd($2.Timestamp value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasPeriodEnd() => $_has(4);
  @$pb.TagNumber(5)
  void clearPeriodEnd() => $_clearField(5);
  @$pb.TagNumber(5)
  $2.Timestamp ensurePeriodEnd() => $_ensure(4);

  @$pb.TagNumber(6)
  $core.String get subscriptionStatus => $_getSZ(5);
  @$pb.TagNumber(6)
  set subscriptionStatus($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasSubscriptionStatus() => $_has(5);
  @$pb.TagNumber(6)
  void clearSubscriptionStatus() => $_clearField(6);
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

class DiscountCode extends $pb.GeneratedMessage {
  factory DiscountCode({
    $core.String? id,
    $core.String? code,
    $core.String? name,
    $core.String? percentOff,
    $core.String? duration,
    $core.int? durationPeriods,
    $2.Timestamp? validFrom,
    $2.Timestamp? validUntil,
    $core.int? maxRedemptions,
    $core.int? redemptionsCount,
    $core.Iterable<$core.String>? appliesToTiers,
    $core.Iterable<$core.String>? appliesToCycles,
    $core.bool? newCustomersOnly,
    $core.Iterable<$core.String>? channels,
    $core.bool? isActive,
    $core.String? stripePromotionCodeId,
    $2.Timestamp? createdAt,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (code != null) result.code = code;
    if (name != null) result.name = name;
    if (percentOff != null) result.percentOff = percentOff;
    if (duration != null) result.duration = duration;
    if (durationPeriods != null) result.durationPeriods = durationPeriods;
    if (validFrom != null) result.validFrom = validFrom;
    if (validUntil != null) result.validUntil = validUntil;
    if (maxRedemptions != null) result.maxRedemptions = maxRedemptions;
    if (redemptionsCount != null) result.redemptionsCount = redemptionsCount;
    if (appliesToTiers != null) result.appliesToTiers.addAll(appliesToTiers);
    if (appliesToCycles != null) result.appliesToCycles.addAll(appliesToCycles);
    if (newCustomersOnly != null) result.newCustomersOnly = newCustomersOnly;
    if (channels != null) result.channels.addAll(channels);
    if (isActive != null) result.isActive = isActive;
    if (stripePromotionCodeId != null)
      result.stripePromotionCodeId = stripePromotionCodeId;
    if (createdAt != null) result.createdAt = createdAt;
    return result;
  }

  DiscountCode._();

  factory DiscountCode.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DiscountCode.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DiscountCode',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'billing.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'code')
    ..aOS(3, _omitFieldNames ? '' : 'name')
    ..aOS(4, _omitFieldNames ? '' : 'percentOff')
    ..aOS(5, _omitFieldNames ? '' : 'duration')
    ..aI(6, _omitFieldNames ? '' : 'durationPeriods')
    ..aOM<$2.Timestamp>(7, _omitFieldNames ? '' : 'validFrom',
        subBuilder: $2.Timestamp.create)
    ..aOM<$2.Timestamp>(8, _omitFieldNames ? '' : 'validUntil',
        subBuilder: $2.Timestamp.create)
    ..aI(9, _omitFieldNames ? '' : 'maxRedemptions')
    ..aI(10, _omitFieldNames ? '' : 'redemptionsCount')
    ..pPS(11, _omitFieldNames ? '' : 'appliesToTiers')
    ..pPS(12, _omitFieldNames ? '' : 'appliesToCycles')
    ..aOB(13, _omitFieldNames ? '' : 'newCustomersOnly')
    ..pPS(14, _omitFieldNames ? '' : 'channels')
    ..aOB(15, _omitFieldNames ? '' : 'isActive')
    ..aOS(16, _omitFieldNames ? '' : 'stripePromotionCodeId')
    ..aOM<$2.Timestamp>(17, _omitFieldNames ? '' : 'createdAt',
        subBuilder: $2.Timestamp.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DiscountCode clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DiscountCode copyWith(void Function(DiscountCode) updates) =>
      super.copyWith((message) => updates(message as DiscountCode))
          as DiscountCode;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DiscountCode create() => DiscountCode._();
  @$core.override
  DiscountCode createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DiscountCode getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DiscountCode>(create);
  static DiscountCode? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get code => $_getSZ(1);
  @$pb.TagNumber(2)
  set code($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCode() => $_has(1);
  @$pb.TagNumber(2)
  void clearCode() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get name => $_getSZ(2);
  @$pb.TagNumber(3)
  set name($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasName() => $_has(2);
  @$pb.TagNumber(3)
  void clearName() => $_clearField(3);

  /// Procent zniżki jako string dziesiętny ("33.00") — ta sama
  /// konwencja co PlanInfo.price_gross, bez utraty precyzji na double.
  @$pb.TagNumber(4)
  $core.String get percentOff => $_getSZ(3);
  @$pb.TagNumber(4)
  set percentOff($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasPercentOff() => $_has(3);
  @$pb.TagNumber(4)
  void clearPercentOff() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get duration => $_getSZ(4);
  @$pb.TagNumber(5)
  set duration($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasDuration() => $_has(4);
  @$pb.TagNumber(5)
  void clearDuration() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get durationPeriods => $_getIZ(5);
  @$pb.TagNumber(6)
  set durationPeriods($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasDurationPeriods() => $_has(5);
  @$pb.TagNumber(6)
  void clearDurationPeriods() => $_clearField(6);

  @$pb.TagNumber(7)
  $2.Timestamp get validFrom => $_getN(6);
  @$pb.TagNumber(7)
  set validFrom($2.Timestamp value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasValidFrom() => $_has(6);
  @$pb.TagNumber(7)
  void clearValidFrom() => $_clearField(7);
  @$pb.TagNumber(7)
  $2.Timestamp ensureValidFrom() => $_ensure(6);

  @$pb.TagNumber(8)
  $2.Timestamp get validUntil => $_getN(7);
  @$pb.TagNumber(8)
  set validUntil($2.Timestamp value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasValidUntil() => $_has(7);
  @$pb.TagNumber(8)
  void clearValidUntil() => $_clearField(8);
  @$pb.TagNumber(8)
  $2.Timestamp ensureValidUntil() => $_ensure(7);

  @$pb.TagNumber(9)
  $core.int get maxRedemptions => $_getIZ(8);
  @$pb.TagNumber(9)
  set maxRedemptions($core.int value) => $_setSignedInt32(8, value);
  @$pb.TagNumber(9)
  $core.bool hasMaxRedemptions() => $_has(8);
  @$pb.TagNumber(9)
  void clearMaxRedemptions() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.int get redemptionsCount => $_getIZ(9);
  @$pb.TagNumber(10)
  set redemptionsCount($core.int value) => $_setSignedInt32(9, value);
  @$pb.TagNumber(10)
  $core.bool hasRedemptionsCount() => $_has(9);
  @$pb.TagNumber(10)
  void clearRedemptionsCount() => $_clearField(10);

  @$pb.TagNumber(11)
  $pb.PbList<$core.String> get appliesToTiers => $_getList(10);

  @$pb.TagNumber(12)
  $pb.PbList<$core.String> get appliesToCycles => $_getList(11);

  @$pb.TagNumber(13)
  $core.bool get newCustomersOnly => $_getBF(12);
  @$pb.TagNumber(13)
  set newCustomersOnly($core.bool value) => $_setBool(12, value);
  @$pb.TagNumber(13)
  $core.bool hasNewCustomersOnly() => $_has(12);
  @$pb.TagNumber(13)
  void clearNewCustomersOnly() => $_clearField(13);

  @$pb.TagNumber(14)
  $pb.PbList<$core.String> get channels => $_getList(13);

  @$pb.TagNumber(15)
  $core.bool get isActive => $_getBF(14);
  @$pb.TagNumber(15)
  set isActive($core.bool value) => $_setBool(14, value);
  @$pb.TagNumber(15)
  $core.bool hasIsActive() => $_has(14);
  @$pb.TagNumber(15)
  void clearIsActive() => $_clearField(15);

  @$pb.TagNumber(16)
  $core.String get stripePromotionCodeId => $_getSZ(15);
  @$pb.TagNumber(16)
  set stripePromotionCodeId($core.String value) => $_setString(15, value);
  @$pb.TagNumber(16)
  $core.bool hasStripePromotionCodeId() => $_has(15);
  @$pb.TagNumber(16)
  void clearStripePromotionCodeId() => $_clearField(16);

  @$pb.TagNumber(17)
  $2.Timestamp get createdAt => $_getN(16);
  @$pb.TagNumber(17)
  set createdAt($2.Timestamp value) => $_setField(17, value);
  @$pb.TagNumber(17)
  $core.bool hasCreatedAt() => $_has(16);
  @$pb.TagNumber(17)
  void clearCreatedAt() => $_clearField(17);
  @$pb.TagNumber(17)
  $2.Timestamp ensureCreatedAt() => $_ensure(16);
}

class AdminCreateDiscountCodeRequest extends $pb.GeneratedMessage {
  factory AdminCreateDiscountCodeRequest({
    $core.String? code,
    $core.String? name,
    $core.String? percentOff,
    $core.String? duration,
    $core.int? durationPeriods,
    $2.Timestamp? validUntil,
    $core.int? maxRedemptions,
    $core.Iterable<$core.String>? appliesToTiers,
    $core.Iterable<$core.String>? appliesToCycles,
    $core.bool? newCustomersOnly,
    $core.Iterable<$core.String>? channels,
    $core.String? reason,
    $core.String? idempotencyKey,
  }) {
    final result = create();
    if (code != null) result.code = code;
    if (name != null) result.name = name;
    if (percentOff != null) result.percentOff = percentOff;
    if (duration != null) result.duration = duration;
    if (durationPeriods != null) result.durationPeriods = durationPeriods;
    if (validUntil != null) result.validUntil = validUntil;
    if (maxRedemptions != null) result.maxRedemptions = maxRedemptions;
    if (appliesToTiers != null) result.appliesToTiers.addAll(appliesToTiers);
    if (appliesToCycles != null) result.appliesToCycles.addAll(appliesToCycles);
    if (newCustomersOnly != null) result.newCustomersOnly = newCustomersOnly;
    if (channels != null) result.channels.addAll(channels);
    if (reason != null) result.reason = reason;
    if (idempotencyKey != null) result.idempotencyKey = idempotencyKey;
    return result;
  }

  AdminCreateDiscountCodeRequest._();

  factory AdminCreateDiscountCodeRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AdminCreateDiscountCodeRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AdminCreateDiscountCodeRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'billing.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'code')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aOS(3, _omitFieldNames ? '' : 'percentOff')
    ..aOS(4, _omitFieldNames ? '' : 'duration')
    ..aI(5, _omitFieldNames ? '' : 'durationPeriods')
    ..aOM<$2.Timestamp>(6, _omitFieldNames ? '' : 'validUntil',
        subBuilder: $2.Timestamp.create)
    ..aI(7, _omitFieldNames ? '' : 'maxRedemptions')
    ..pPS(8, _omitFieldNames ? '' : 'appliesToTiers')
    ..pPS(9, _omitFieldNames ? '' : 'appliesToCycles')
    ..aOB(10, _omitFieldNames ? '' : 'newCustomersOnly')
    ..pPS(11, _omitFieldNames ? '' : 'channels')
    ..aOS(15, _omitFieldNames ? '' : 'reason')
    ..aOS(16, _omitFieldNames ? '' : 'idempotencyKey')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminCreateDiscountCodeRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminCreateDiscountCodeRequest copyWith(
          void Function(AdminCreateDiscountCodeRequest) updates) =>
      super.copyWith(
              (message) => updates(message as AdminCreateDiscountCodeRequest))
          as AdminCreateDiscountCodeRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AdminCreateDiscountCodeRequest create() =>
      AdminCreateDiscountCodeRequest._();
  @$core.override
  AdminCreateDiscountCodeRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AdminCreateDiscountCodeRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AdminCreateDiscountCodeRequest>(create);
  static AdminCreateDiscountCodeRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get code => $_getSZ(0);
  @$pb.TagNumber(1)
  set code($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCode() => $_has(0);
  @$pb.TagNumber(1)
  void clearCode() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get percentOff => $_getSZ(2);
  @$pb.TagNumber(3)
  set percentOff($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPercentOff() => $_has(2);
  @$pb.TagNumber(3)
  void clearPercentOff() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get duration => $_getSZ(3);
  @$pb.TagNumber(4)
  set duration($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasDuration() => $_has(3);
  @$pb.TagNumber(4)
  void clearDuration() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get durationPeriods => $_getIZ(4);
  @$pb.TagNumber(5)
  set durationPeriods($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasDurationPeriods() => $_has(4);
  @$pb.TagNumber(5)
  void clearDurationPeriods() => $_clearField(5);

  @$pb.TagNumber(6)
  $2.Timestamp get validUntil => $_getN(5);
  @$pb.TagNumber(6)
  set validUntil($2.Timestamp value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasValidUntil() => $_has(5);
  @$pb.TagNumber(6)
  void clearValidUntil() => $_clearField(6);
  @$pb.TagNumber(6)
  $2.Timestamp ensureValidUntil() => $_ensure(5);

  @$pb.TagNumber(7)
  $core.int get maxRedemptions => $_getIZ(6);
  @$pb.TagNumber(7)
  set maxRedemptions($core.int value) => $_setSignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasMaxRedemptions() => $_has(6);
  @$pb.TagNumber(7)
  void clearMaxRedemptions() => $_clearField(7);

  @$pb.TagNumber(8)
  $pb.PbList<$core.String> get appliesToTiers => $_getList(7);

  @$pb.TagNumber(9)
  $pb.PbList<$core.String> get appliesToCycles => $_getList(8);

  @$pb.TagNumber(10)
  $core.bool get newCustomersOnly => $_getBF(9);
  @$pb.TagNumber(10)
  set newCustomersOnly($core.bool value) => $_setBool(9, value);
  @$pb.TagNumber(10)
  $core.bool hasNewCustomersOnly() => $_has(9);
  @$pb.TagNumber(10)
  void clearNewCustomersOnly() => $_clearField(10);

  @$pb.TagNumber(11)
  $pb.PbList<$core.String> get channels => $_getList(10);

  @$pb.TagNumber(15)
  $core.String get reason => $_getSZ(11);
  @$pb.TagNumber(15)
  set reason($core.String value) => $_setString(11, value);
  @$pb.TagNumber(15)
  $core.bool hasReason() => $_has(11);
  @$pb.TagNumber(15)
  void clearReason() => $_clearField(15);

  @$pb.TagNumber(16)
  $core.String get idempotencyKey => $_getSZ(12);
  @$pb.TagNumber(16)
  set idempotencyKey($core.String value) => $_setString(12, value);
  @$pb.TagNumber(16)
  $core.bool hasIdempotencyKey() => $_has(12);
  @$pb.TagNumber(16)
  void clearIdempotencyKey() => $_clearField(16);
}

class AdminUpdateDiscountCodeRequest extends $pb.GeneratedMessage {
  factory AdminUpdateDiscountCodeRequest({
    $core.String? id,
    $core.String? name,
    $2.Timestamp? validUntil,
    $core.int? maxRedemptions,
    $core.int? setActive,
    $core.String? reason,
    $core.String? idempotencyKey,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (name != null) result.name = name;
    if (validUntil != null) result.validUntil = validUntil;
    if (maxRedemptions != null) result.maxRedemptions = maxRedemptions;
    if (setActive != null) result.setActive = setActive;
    if (reason != null) result.reason = reason;
    if (idempotencyKey != null) result.idempotencyKey = idempotencyKey;
    return result;
  }

  AdminUpdateDiscountCodeRequest._();

  factory AdminUpdateDiscountCodeRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AdminUpdateDiscountCodeRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AdminUpdateDiscountCodeRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'billing.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aOM<$2.Timestamp>(3, _omitFieldNames ? '' : 'validUntil',
        subBuilder: $2.Timestamp.create)
    ..aI(4, _omitFieldNames ? '' : 'maxRedemptions')
    ..aI(5, _omitFieldNames ? '' : 'setActive')
    ..aOS(15, _omitFieldNames ? '' : 'reason')
    ..aOS(16, _omitFieldNames ? '' : 'idempotencyKey')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminUpdateDiscountCodeRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminUpdateDiscountCodeRequest copyWith(
          void Function(AdminUpdateDiscountCodeRequest) updates) =>
      super.copyWith(
              (message) => updates(message as AdminUpdateDiscountCodeRequest))
          as AdminUpdateDiscountCodeRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AdminUpdateDiscountCodeRequest create() =>
      AdminUpdateDiscountCodeRequest._();
  @$core.override
  AdminUpdateDiscountCodeRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AdminUpdateDiscountCodeRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AdminUpdateDiscountCodeRequest>(create);
  static AdminUpdateDiscountCodeRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);

  @$pb.TagNumber(3)
  $2.Timestamp get validUntil => $_getN(2);
  @$pb.TagNumber(3)
  set validUntil($2.Timestamp value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasValidUntil() => $_has(2);
  @$pb.TagNumber(3)
  void clearValidUntil() => $_clearField(3);
  @$pb.TagNumber(3)
  $2.Timestamp ensureValidUntil() => $_ensure(2);

  @$pb.TagNumber(4)
  $core.int get maxRedemptions => $_getIZ(3);
  @$pb.TagNumber(4)
  set maxRedemptions($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasMaxRedemptions() => $_has(3);
  @$pb.TagNumber(4)
  void clearMaxRedemptions() => $_clearField(4);

  /// -1 = bez zmian, 0 = dezaktywuj, 1 = aktywuj. Osobne pole zamiast
  /// bool, bo proto3 nie odróżnia false od "nie ustawione".
  @$pb.TagNumber(5)
  $core.int get setActive => $_getIZ(4);
  @$pb.TagNumber(5)
  set setActive($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasSetActive() => $_has(4);
  @$pb.TagNumber(5)
  void clearSetActive() => $_clearField(5);

  @$pb.TagNumber(15)
  $core.String get reason => $_getSZ(5);
  @$pb.TagNumber(15)
  set reason($core.String value) => $_setString(5, value);
  @$pb.TagNumber(15)
  $core.bool hasReason() => $_has(5);
  @$pb.TagNumber(15)
  void clearReason() => $_clearField(15);

  @$pb.TagNumber(16)
  $core.String get idempotencyKey => $_getSZ(6);
  @$pb.TagNumber(16)
  set idempotencyKey($core.String value) => $_setString(6, value);
  @$pb.TagNumber(16)
  $core.bool hasIdempotencyKey() => $_has(6);
  @$pb.TagNumber(16)
  void clearIdempotencyKey() => $_clearField(16);
}

class AdminListDiscountCodesRequest extends $pb.GeneratedMessage {
  factory AdminListDiscountCodesRequest({
    $core.bool? includeInactive,
  }) {
    final result = create();
    if (includeInactive != null) result.includeInactive = includeInactive;
    return result;
  }

  AdminListDiscountCodesRequest._();

  factory AdminListDiscountCodesRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AdminListDiscountCodesRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AdminListDiscountCodesRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'billing.v1'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'includeInactive')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminListDiscountCodesRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminListDiscountCodesRequest copyWith(
          void Function(AdminListDiscountCodesRequest) updates) =>
      super.copyWith(
              (message) => updates(message as AdminListDiscountCodesRequest))
          as AdminListDiscountCodesRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AdminListDiscountCodesRequest create() =>
      AdminListDiscountCodesRequest._();
  @$core.override
  AdminListDiscountCodesRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AdminListDiscountCodesRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AdminListDiscountCodesRequest>(create);
  static AdminListDiscountCodesRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get includeInactive => $_getBF(0);
  @$pb.TagNumber(1)
  set includeInactive($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasIncludeInactive() => $_has(0);
  @$pb.TagNumber(1)
  void clearIncludeInactive() => $_clearField(1);
}

class AdminListDiscountCodesResponse extends $pb.GeneratedMessage {
  factory AdminListDiscountCodesResponse({
    $core.Iterable<DiscountCode>? codes,
  }) {
    final result = create();
    if (codes != null) result.codes.addAll(codes);
    return result;
  }

  AdminListDiscountCodesResponse._();

  factory AdminListDiscountCodesResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AdminListDiscountCodesResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AdminListDiscountCodesResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'billing.v1'),
      createEmptyInstance: create)
    ..pPM<DiscountCode>(1, _omitFieldNames ? '' : 'codes',
        subBuilder: DiscountCode.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminListDiscountCodesResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminListDiscountCodesResponse copyWith(
          void Function(AdminListDiscountCodesResponse) updates) =>
      super.copyWith(
              (message) => updates(message as AdminListDiscountCodesResponse))
          as AdminListDiscountCodesResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AdminListDiscountCodesResponse create() =>
      AdminListDiscountCodesResponse._();
  @$core.override
  AdminListDiscountCodesResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AdminListDiscountCodesResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AdminListDiscountCodesResponse>(create);
  static AdminListDiscountCodesResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<DiscountCode> get codes => $_getList(0);
}

class AdminGetDiscountCodeRequest extends $pb.GeneratedMessage {
  factory AdminGetDiscountCodeRequest({
    $core.String? id,
  }) {
    final result = create();
    if (id != null) result.id = id;
    return result;
  }

  AdminGetDiscountCodeRequest._();

  factory AdminGetDiscountCodeRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AdminGetDiscountCodeRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AdminGetDiscountCodeRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'billing.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminGetDiscountCodeRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminGetDiscountCodeRequest copyWith(
          void Function(AdminGetDiscountCodeRequest) updates) =>
      super.copyWith(
              (message) => updates(message as AdminGetDiscountCodeRequest))
          as AdminGetDiscountCodeRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AdminGetDiscountCodeRequest create() =>
      AdminGetDiscountCodeRequest._();
  @$core.override
  AdminGetDiscountCodeRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AdminGetDiscountCodeRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AdminGetDiscountCodeRequest>(create);
  static AdminGetDiscountCodeRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);
}

class DiscountCodeRedemption extends $pb.GeneratedMessage {
  factory DiscountCodeRedemption({
    $core.String? organizationId,
    $core.String? organizationName,
    $core.String? channel,
    $core.String? status,
    $2.Timestamp? reservedAt,
    $2.Timestamp? committedAt,
  }) {
    final result = create();
    if (organizationId != null) result.organizationId = organizationId;
    if (organizationName != null) result.organizationName = organizationName;
    if (channel != null) result.channel = channel;
    if (status != null) result.status = status;
    if (reservedAt != null) result.reservedAt = reservedAt;
    if (committedAt != null) result.committedAt = committedAt;
    return result;
  }

  DiscountCodeRedemption._();

  factory DiscountCodeRedemption.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DiscountCodeRedemption.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DiscountCodeRedemption',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'billing.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'organizationId')
    ..aOS(2, _omitFieldNames ? '' : 'organizationName')
    ..aOS(3, _omitFieldNames ? '' : 'channel')
    ..aOS(4, _omitFieldNames ? '' : 'status')
    ..aOM<$2.Timestamp>(5, _omitFieldNames ? '' : 'reservedAt',
        subBuilder: $2.Timestamp.create)
    ..aOM<$2.Timestamp>(6, _omitFieldNames ? '' : 'committedAt',
        subBuilder: $2.Timestamp.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DiscountCodeRedemption clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DiscountCodeRedemption copyWith(
          void Function(DiscountCodeRedemption) updates) =>
      super.copyWith((message) => updates(message as DiscountCodeRedemption))
          as DiscountCodeRedemption;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DiscountCodeRedemption create() => DiscountCodeRedemption._();
  @$core.override
  DiscountCodeRedemption createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DiscountCodeRedemption getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DiscountCodeRedemption>(create);
  static DiscountCodeRedemption? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get organizationId => $_getSZ(0);
  @$pb.TagNumber(1)
  set organizationId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasOrganizationId() => $_has(0);
  @$pb.TagNumber(1)
  void clearOrganizationId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get organizationName => $_getSZ(1);
  @$pb.TagNumber(2)
  set organizationName($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasOrganizationName() => $_has(1);
  @$pb.TagNumber(2)
  void clearOrganizationName() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get channel => $_getSZ(2);
  @$pb.TagNumber(3)
  set channel($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasChannel() => $_has(2);
  @$pb.TagNumber(3)
  void clearChannel() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get status => $_getSZ(3);
  @$pb.TagNumber(4)
  set status($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasStatus() => $_has(3);
  @$pb.TagNumber(4)
  void clearStatus() => $_clearField(4);

  @$pb.TagNumber(5)
  $2.Timestamp get reservedAt => $_getN(4);
  @$pb.TagNumber(5)
  set reservedAt($2.Timestamp value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasReservedAt() => $_has(4);
  @$pb.TagNumber(5)
  void clearReservedAt() => $_clearField(5);
  @$pb.TagNumber(5)
  $2.Timestamp ensureReservedAt() => $_ensure(4);

  @$pb.TagNumber(6)
  $2.Timestamp get committedAt => $_getN(5);
  @$pb.TagNumber(6)
  set committedAt($2.Timestamp value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasCommittedAt() => $_has(5);
  @$pb.TagNumber(6)
  void clearCommittedAt() => $_clearField(6);
  @$pb.TagNumber(6)
  $2.Timestamp ensureCommittedAt() => $_ensure(5);
}

class DiscountCodeDetails extends $pb.GeneratedMessage {
  factory DiscountCodeDetails({
    DiscountCode? code,
    $core.Iterable<DiscountCodeRedemption>? redemptions,
  }) {
    final result = create();
    if (code != null) result.code = code;
    if (redemptions != null) result.redemptions.addAll(redemptions);
    return result;
  }

  DiscountCodeDetails._();

  factory DiscountCodeDetails.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DiscountCodeDetails.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DiscountCodeDetails',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'billing.v1'),
      createEmptyInstance: create)
    ..aOM<DiscountCode>(1, _omitFieldNames ? '' : 'code',
        subBuilder: DiscountCode.create)
    ..pPM<DiscountCodeRedemption>(2, _omitFieldNames ? '' : 'redemptions',
        subBuilder: DiscountCodeRedemption.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DiscountCodeDetails clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DiscountCodeDetails copyWith(void Function(DiscountCodeDetails) updates) =>
      super.copyWith((message) => updates(message as DiscountCodeDetails))
          as DiscountCodeDetails;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DiscountCodeDetails create() => DiscountCodeDetails._();
  @$core.override
  DiscountCodeDetails createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DiscountCodeDetails getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DiscountCodeDetails>(create);
  static DiscountCodeDetails? _defaultInstance;

  @$pb.TagNumber(1)
  DiscountCode get code => $_getN(0);
  @$pb.TagNumber(1)
  set code(DiscountCode value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasCode() => $_has(0);
  @$pb.TagNumber(1)
  void clearCode() => $_clearField(1);
  @$pb.TagNumber(1)
  DiscountCode ensureCode() => $_ensure(0);

  @$pb.TagNumber(2)
  $pb.PbList<DiscountCodeRedemption> get redemptions => $_getList(1);
}

class ValidateDiscountCodeRequest extends $pb.GeneratedMessage {
  factory ValidateDiscountCodeRequest({
    $core.String? code,
    $core.String? planTier,
    $core.String? planCycle,
    $core.String? channel,
  }) {
    final result = create();
    if (code != null) result.code = code;
    if (planTier != null) result.planTier = planTier;
    if (planCycle != null) result.planCycle = planCycle;
    if (channel != null) result.channel = channel;
    return result;
  }

  ValidateDiscountCodeRequest._();

  factory ValidateDiscountCodeRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ValidateDiscountCodeRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ValidateDiscountCodeRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'billing.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'code')
    ..aOS(2, _omitFieldNames ? '' : 'planTier')
    ..aOS(3, _omitFieldNames ? '' : 'planCycle')
    ..aOS(4, _omitFieldNames ? '' : 'channel')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ValidateDiscountCodeRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ValidateDiscountCodeRequest copyWith(
          void Function(ValidateDiscountCodeRequest) updates) =>
      super.copyWith(
              (message) => updates(message as ValidateDiscountCodeRequest))
          as ValidateDiscountCodeRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ValidateDiscountCodeRequest create() =>
      ValidateDiscountCodeRequest._();
  @$core.override
  ValidateDiscountCodeRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ValidateDiscountCodeRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ValidateDiscountCodeRequest>(create);
  static ValidateDiscountCodeRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get code => $_getSZ(0);
  @$pb.TagNumber(1)
  set code($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCode() => $_has(0);
  @$pb.TagNumber(1)
  void clearCode() => $_clearField(1);

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

  /// Kanał zakupu. Puste = WEB.
  @$pb.TagNumber(4)
  $core.String get channel => $_getSZ(3);
  @$pb.TagNumber(4)
  set channel($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasChannel() => $_has(3);
  @$pb.TagNumber(4)
  void clearChannel() => $_clearField(4);
}

class DiscountCodeQuote extends $pb.GeneratedMessage {
  factory DiscountCodeQuote({
    $core.bool? valid,
    $core.String? reason,
    $core.String? code,
    $core.String? name,
    $core.String? percentOff,
    $core.String? priceBefore,
    $core.String? priceAfter,
    $core.String? currencyCode,
    $core.String? duration,
    $core.int? durationPeriods,
    $core.int? redemptionsLeft,
  }) {
    final result = create();
    if (valid != null) result.valid = valid;
    if (reason != null) result.reason = reason;
    if (code != null) result.code = code;
    if (name != null) result.name = name;
    if (percentOff != null) result.percentOff = percentOff;
    if (priceBefore != null) result.priceBefore = priceBefore;
    if (priceAfter != null) result.priceAfter = priceAfter;
    if (currencyCode != null) result.currencyCode = currencyCode;
    if (duration != null) result.duration = duration;
    if (durationPeriods != null) result.durationPeriods = durationPeriods;
    if (redemptionsLeft != null) result.redemptionsLeft = redemptionsLeft;
    return result;
  }

  DiscountCodeQuote._();

  factory DiscountCodeQuote.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DiscountCodeQuote.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DiscountCodeQuote',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'billing.v1'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'valid')
    ..aOS(2, _omitFieldNames ? '' : 'reason')
    ..aOS(3, _omitFieldNames ? '' : 'code')
    ..aOS(4, _omitFieldNames ? '' : 'name')
    ..aOS(5, _omitFieldNames ? '' : 'percentOff')
    ..aOS(6, _omitFieldNames ? '' : 'priceBefore')
    ..aOS(7, _omitFieldNames ? '' : 'priceAfter')
    ..aOS(8, _omitFieldNames ? '' : 'currencyCode')
    ..aOS(9, _omitFieldNames ? '' : 'duration')
    ..aI(10, _omitFieldNames ? '' : 'durationPeriods')
    ..aI(11, _omitFieldNames ? '' : 'redemptionsLeft')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DiscountCodeQuote clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DiscountCodeQuote copyWith(void Function(DiscountCodeQuote) updates) =>
      super.copyWith((message) => updates(message as DiscountCodeQuote))
          as DiscountCodeQuote;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DiscountCodeQuote create() => DiscountCodeQuote._();
  @$core.override
  DiscountCodeQuote createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DiscountCodeQuote getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DiscountCodeQuote>(create);
  static DiscountCodeQuote? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get valid => $_getBF(0);
  @$pb.TagNumber(1)
  set valid($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasValid() => $_has(0);
  @$pb.TagNumber(1)
  void clearValid() => $_clearField(1);

  /// Kod odmowy dla interfejsu: NOT_FOUND | EXPIRED | NOT_STARTED |
  /// EXHAUSTED | ALREADY_USED | PLAN_NOT_ELIGIBLE | CHANNEL_NOT_ELIGIBLE |
  /// NEW_CUSTOMERS_ONLY | INACTIVE.
  @$pb.TagNumber(2)
  $core.String get reason => $_getSZ(1);
  @$pb.TagNumber(2)
  set reason($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasReason() => $_has(1);
  @$pb.TagNumber(2)
  void clearReason() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get code => $_getSZ(2);
  @$pb.TagNumber(3)
  set code($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCode() => $_has(2);
  @$pb.TagNumber(3)
  void clearCode() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get name => $_getSZ(3);
  @$pb.TagNumber(4)
  set name($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasName() => $_has(3);
  @$pb.TagNumber(4)
  void clearName() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get percentOff => $_getSZ(4);
  @$pb.TagNumber(5)
  set percentOff($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasPercentOff() => $_has(4);
  @$pb.TagNumber(5)
  void clearPercentOff() => $_clearField(5);

  /// Kwoty brutto jako stringi dziesiętne w walucie planu.
  @$pb.TagNumber(6)
  $core.String get priceBefore => $_getSZ(5);
  @$pb.TagNumber(6)
  set priceBefore($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasPriceBefore() => $_has(5);
  @$pb.TagNumber(6)
  void clearPriceBefore() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get priceAfter => $_getSZ(6);
  @$pb.TagNumber(7)
  set priceAfter($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasPriceAfter() => $_has(6);
  @$pb.TagNumber(7)
  void clearPriceAfter() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get currencyCode => $_getSZ(7);
  @$pb.TagNumber(8)
  set currencyCode($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasCurrencyCode() => $_has(7);
  @$pb.TagNumber(8)
  void clearCurrencyCode() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.String get duration => $_getSZ(8);
  @$pb.TagNumber(9)
  set duration($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasDuration() => $_has(8);
  @$pb.TagNumber(9)
  void clearDuration() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.int get durationPeriods => $_getIZ(9);
  @$pb.TagNumber(10)
  set durationPeriods($core.int value) => $_setSignedInt32(9, value);
  @$pb.TagNumber(10)
  $core.bool hasDurationPeriods() => $_has(9);
  @$pb.TagNumber(10)
  void clearDurationPeriods() => $_clearField(10);

  /// Ile użyć zostało (przybliżenie — rozstrzyga Stripe przy checkoucie).
  @$pb.TagNumber(11)
  $core.int get redemptionsLeft => $_getIZ(10);
  @$pb.TagNumber(11)
  set redemptionsLeft($core.int value) => $_setSignedInt32(10, value);
  @$pb.TagNumber(11)
  $core.bool hasRedemptionsLeft() => $_has(10);
  @$pb.TagNumber(11)
  void clearRedemptionsLeft() => $_clearField(11);
}

class StoreProduct extends $pb.GeneratedMessage {
  factory StoreProduct({
    $core.String? productId,
    $core.String? planTier,
    $core.String? planCycle,
    $core.int? tokensPerPeriod,
    $core.String? referencePriceGross,
    $core.String? currencyCode,
  }) {
    final result = create();
    if (productId != null) result.productId = productId;
    if (planTier != null) result.planTier = planTier;
    if (planCycle != null) result.planCycle = planCycle;
    if (tokensPerPeriod != null) result.tokensPerPeriod = tokensPerPeriod;
    if (referencePriceGross != null)
      result.referencePriceGross = referencePriceGross;
    if (currencyCode != null) result.currencyCode = currencyCode;
    return result;
  }

  StoreProduct._();

  factory StoreProduct.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory StoreProduct.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StoreProduct',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'billing.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'productId')
    ..aOS(2, _omitFieldNames ? '' : 'planTier')
    ..aOS(3, _omitFieldNames ? '' : 'planCycle')
    ..aI(4, _omitFieldNames ? '' : 'tokensPerPeriod')
    ..aOS(5, _omitFieldNames ? '' : 'referencePriceGross')
    ..aOS(6, _omitFieldNames ? '' : 'currencyCode')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StoreProduct clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StoreProduct copyWith(void Function(StoreProduct) updates) =>
      super.copyWith((message) => updates(message as StoreProduct))
          as StoreProduct;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static StoreProduct create() => StoreProduct._();
  @$core.override
  StoreProduct createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static StoreProduct getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<StoreProduct>(create);
  static StoreProduct? _defaultInstance;

  /// Identyfikator produktu w sklepie, po którym aplikacja odpytuje
  /// StoreKit / Play o CENĘ. Ceny nie bierzemy z backendu — musi
  /// pochodzić ze sklepu, w walucie storefrontu użytkownika.
  @$pb.TagNumber(1)
  $core.String get productId => $_getSZ(0);
  @$pb.TagNumber(1)
  set productId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasProductId() => $_has(0);
  @$pb.TagNumber(1)
  void clearProductId() => $_clearField(1);

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

  @$pb.TagNumber(4)
  $core.int get tokensPerPeriod => $_getIZ(3);
  @$pb.TagNumber(4)
  set tokensPerPeriod($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasTokensPerPeriod() => $_has(3);
  @$pb.TagNumber(4)
  void clearTokensPerPeriod() => $_clearField(4);

  /// Cena referencyjna brutto (PLN) — wyłącznie do porównań i telemetrii.
  @$pb.TagNumber(5)
  $core.String get referencePriceGross => $_getSZ(4);
  @$pb.TagNumber(5)
  set referencePriceGross($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasReferencePriceGross() => $_has(4);
  @$pb.TagNumber(5)
  void clearReferencePriceGross() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get currencyCode => $_getSZ(5);
  @$pb.TagNumber(6)
  set currencyCode($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasCurrencyCode() => $_has(5);
  @$pb.TagNumber(6)
  void clearCurrencyCode() => $_clearField(6);
}

class BillingSurface extends $pb.GeneratedMessage {
  factory BillingSurface({
    $core.String? activeProvider,
    $core.String? planTier,
    $core.String? status,
    $core.bool? canPurchase,
    $core.String? blockReason,
    $2.Timestamp? blockedUntil,
    $core.Iterable<StoreProduct>? products,
    $core.String? webLinkMode,
    $core.bool? showRestore,
    $core.String? manageUrl,
  }) {
    final result = create();
    if (activeProvider != null) result.activeProvider = activeProvider;
    if (planTier != null) result.planTier = planTier;
    if (status != null) result.status = status;
    if (canPurchase != null) result.canPurchase = canPurchase;
    if (blockReason != null) result.blockReason = blockReason;
    if (blockedUntil != null) result.blockedUntil = blockedUntil;
    if (products != null) result.products.addAll(products);
    if (webLinkMode != null) result.webLinkMode = webLinkMode;
    if (showRestore != null) result.showRestore = showRestore;
    if (manageUrl != null) result.manageUrl = manageUrl;
    return result;
  }

  BillingSurface._();

  factory BillingSurface.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory BillingSurface.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BillingSurface',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'billing.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'activeProvider')
    ..aOS(2, _omitFieldNames ? '' : 'planTier')
    ..aOS(3, _omitFieldNames ? '' : 'status')
    ..aOB(4, _omitFieldNames ? '' : 'canPurchase')
    ..aOS(5, _omitFieldNames ? '' : 'blockReason')
    ..aOM<$2.Timestamp>(6, _omitFieldNames ? '' : 'blockedUntil',
        subBuilder: $2.Timestamp.create)
    ..pPM<StoreProduct>(7, _omitFieldNames ? '' : 'products',
        subBuilder: StoreProduct.create)
    ..aOS(8, _omitFieldNames ? '' : 'webLinkMode')
    ..aOB(9, _omitFieldNames ? '' : 'showRestore')
    ..aOS(10, _omitFieldNames ? '' : 'manageUrl')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BillingSurface clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BillingSurface copyWith(void Function(BillingSurface) updates) =>
      super.copyWith((message) => updates(message as BillingSurface))
          as BillingSurface;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BillingSurface create() => BillingSurface._();
  @$core.override
  BillingSurface createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static BillingSurface getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<BillingSurface>(create);
  static BillingSurface? _defaultInstance;

  /// Kto sprzedał obecną subskrypcję: STRIPE | APPLE_IAP | GOOGLE_IAP |
  /// MANUAL | P24. Puste = brak aktywnej subskrypcji.
  @$pb.TagNumber(1)
  $core.String get activeProvider => $_getSZ(0);
  @$pb.TagNumber(1)
  set activeProvider($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasActiveProvider() => $_has(0);
  @$pb.TagNumber(1)
  void clearActiveProvider() => $_clearField(1);

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

  /// Czy paywall ma w ogóle sprzedawać na TEJ platformie.
  @$pb.TagNumber(4)
  $core.bool get canPurchase => $_getBF(3);
  @$pb.TagNumber(4)
  set canPurchase($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasCanPurchase() => $_has(3);
  @$pb.TagNumber(4)
  void clearCanPurchase() => $_clearField(4);

  /// Gdy can_purchase = false: OTHER_PROVIDER_ACTIVE | ORG_MANAGED |
  /// IAP_DISABLED | PENDING_CHECKOUT | ACCOUNT_INACTIVE.
  @$pb.TagNumber(5)
  $core.String get blockReason => $_getSZ(4);
  @$pb.TagNumber(5)
  set blockReason($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasBlockReason() => $_has(4);
  @$pb.TagNumber(5)
  void clearBlockReason() => $_clearField(5);

  /// Do kiedy blokada obowiązuje (koniec okresu u innego dostawcy).
  @$pb.TagNumber(6)
  $2.Timestamp get blockedUntil => $_getN(5);
  @$pb.TagNumber(6)
  set blockedUntil($2.Timestamp value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasBlockedUntil() => $_has(5);
  @$pb.TagNumber(6)
  void clearBlockedUntil() => $_clearField(6);
  @$pb.TagNumber(6)
  $2.Timestamp ensureBlockedUntil() => $_ensure(5);

  /// Produkty do pokazania na paywallu tej platformy. Puste, gdy
  /// can_purchase = false.
  @$pb.TagNumber(7)
  $pb.PbList<StoreProduct> get products => $_getList(6);

  /// NONE | TEXT | LINK — czy aplikacja może wspomnieć o zakupie na
  /// superwizor.ai. NONE jest domyślne i jedyne bezpieczne bez analizy
  /// warunków DMA (docs/70 R6).
  @$pb.TagNumber(8)
  $core.String get webLinkMode => $_getSZ(7);
  @$pb.TagNumber(8)
  set webLinkMode($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasWebLinkMode() => $_has(7);
  @$pb.TagNumber(8)
  void clearWebLinkMode() => $_clearField(8);

  /// Czy pokazać „Przywróć zakupy" (wymóg Apple 3.1.2 na platformach
  /// ze sprzedażą IAP).
  @$pb.TagNumber(9)
  $core.bool get showRestore => $_getBF(8);
  @$pb.TagNumber(9)
  set showRestore($core.bool value) => $_setBool(8, value);
  @$pb.TagNumber(9)
  $core.bool hasShowRestore() => $_has(8);
  @$pb.TagNumber(9)
  void clearShowRestore() => $_clearField(9);

  /// Głęboki link do zarządzania subskrypcją: portal Stripe (web),
  /// ustawienia subskrypcji w sklepie (iOS/Android). Puste dla MANUAL.
  @$pb.TagNumber(10)
  $core.String get manageUrl => $_getSZ(9);
  @$pb.TagNumber(10)
  set manageUrl($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasManageUrl() => $_has(9);
  @$pb.TagNumber(10)
  void clearManageUrl() => $_clearField(10);
}

class BeginStorePurchaseRequest extends $pb.GeneratedMessage {
  factory BeginStorePurchaseRequest({
    $core.String? platform,
    $core.String? productId,
  }) {
    final result = create();
    if (platform != null) result.platform = platform;
    if (productId != null) result.productId = productId;
    return result;
  }

  BeginStorePurchaseRequest._();

  factory BeginStorePurchaseRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory BeginStorePurchaseRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BeginStorePurchaseRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'billing.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'platform')
    ..aOS(2, _omitFieldNames ? '' : 'productId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BeginStorePurchaseRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BeginStorePurchaseRequest copyWith(
          void Function(BeginStorePurchaseRequest) updates) =>
      super.copyWith((message) => updates(message as BeginStorePurchaseRequest))
          as BeginStorePurchaseRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BeginStorePurchaseRequest create() => BeginStorePurchaseRequest._();
  @$core.override
  BeginStorePurchaseRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static BeginStorePurchaseRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<BeginStorePurchaseRequest>(create);
  static BeginStorePurchaseRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get platform => $_getSZ(0);
  @$pb.TagNumber(1)
  set platform($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPlatform() => $_has(0);
  @$pb.TagNumber(1)
  void clearPlatform() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get productId => $_getSZ(1);
  @$pb.TagNumber(2)
  set productId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasProductId() => $_has(1);
  @$pb.TagNumber(2)
  void clearProductId() => $_clearField(2);
}

class BeginStorePurchaseResponse extends $pb.GeneratedMessage {
  factory BeginStorePurchaseResponse({
    $core.bool? allowed,
    $core.String? blockReason,
    $2.Timestamp? blockedUntil,
    $core.String? appAccountToken,
  }) {
    final result = create();
    if (allowed != null) result.allowed = allowed;
    if (blockReason != null) result.blockReason = blockReason;
    if (blockedUntil != null) result.blockedUntil = blockedUntil;
    if (appAccountToken != null) result.appAccountToken = appAccountToken;
    return result;
  }

  BeginStorePurchaseResponse._();

  factory BeginStorePurchaseResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory BeginStorePurchaseResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BeginStorePurchaseResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'billing.v1'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'allowed')
    ..aOS(2, _omitFieldNames ? '' : 'blockReason')
    ..aOM<$2.Timestamp>(3, _omitFieldNames ? '' : 'blockedUntil',
        subBuilder: $2.Timestamp.create)
    ..aOS(4, _omitFieldNames ? '' : 'appAccountToken')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BeginStorePurchaseResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BeginStorePurchaseResponse copyWith(
          void Function(BeginStorePurchaseResponse) updates) =>
      super.copyWith(
              (message) => updates(message as BeginStorePurchaseResponse))
          as BeginStorePurchaseResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BeginStorePurchaseResponse create() => BeginStorePurchaseResponse._();
  @$core.override
  BeginStorePurchaseResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static BeginStorePurchaseResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<BeginStorePurchaseResponse>(create);
  static BeginStorePurchaseResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get allowed => $_getBF(0);
  @$pb.TagNumber(1)
  set allowed($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAllowed() => $_has(0);
  @$pb.TagNumber(1)
  void clearAllowed() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get blockReason => $_getSZ(1);
  @$pb.TagNumber(2)
  set blockReason($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasBlockReason() => $_has(1);
  @$pb.TagNumber(2)
  void clearBlockReason() => $_clearField(2);

  @$pb.TagNumber(3)
  $2.Timestamp get blockedUntil => $_getN(2);
  @$pb.TagNumber(3)
  set blockedUntil($2.Timestamp value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasBlockedUntil() => $_has(2);
  @$pb.TagNumber(3)
  void clearBlockedUntil() => $_clearField(3);
  @$pb.TagNumber(3)
  $2.Timestamp ensureBlockedUntil() => $_ensure(2);

  /// UUID organizacji przekazywany do sklepu jako appAccountToken
  /// (Apple) / obfuscatedExternalAccountId (Google). Jedyne wiązanie
  /// transakcji z kontem.
  @$pb.TagNumber(4)
  $core.String get appAccountToken => $_getSZ(3);
  @$pb.TagNumber(4)
  set appAccountToken($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasAppAccountToken() => $_has(3);
  @$pb.TagNumber(4)
  void clearAppAccountToken() => $_clearField(4);
}

class VerifyStorePurchaseRequest extends $pb.GeneratedMessage {
  factory VerifyStorePurchaseRequest({
    $core.String? platform,
    $core.String? jwsTransaction,
    $core.String? purchaseToken,
    $core.String? productId,
  }) {
    final result = create();
    if (platform != null) result.platform = platform;
    if (jwsTransaction != null) result.jwsTransaction = jwsTransaction;
    if (purchaseToken != null) result.purchaseToken = purchaseToken;
    if (productId != null) result.productId = productId;
    return result;
  }

  VerifyStorePurchaseRequest._();

  factory VerifyStorePurchaseRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory VerifyStorePurchaseRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'VerifyStorePurchaseRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'billing.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'platform')
    ..aOS(2, _omitFieldNames ? '' : 'jwsTransaction')
    ..aOS(3, _omitFieldNames ? '' : 'purchaseToken')
    ..aOS(4, _omitFieldNames ? '' : 'productId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  VerifyStorePurchaseRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  VerifyStorePurchaseRequest copyWith(
          void Function(VerifyStorePurchaseRequest) updates) =>
      super.copyWith(
              (message) => updates(message as VerifyStorePurchaseRequest))
          as VerifyStorePurchaseRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static VerifyStorePurchaseRequest create() => VerifyStorePurchaseRequest._();
  @$core.override
  VerifyStorePurchaseRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static VerifyStorePurchaseRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<VerifyStorePurchaseRequest>(create);
  static VerifyStorePurchaseRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get platform => $_getSZ(0);
  @$pb.TagNumber(1)
  set platform($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPlatform() => $_has(0);
  @$pb.TagNumber(1)
  void clearPlatform() => $_clearField(1);

  /// iOS: podpisany JWS transakcji ze StoreKit 2.
  @$pb.TagNumber(2)
  $core.String get jwsTransaction => $_getSZ(1);
  @$pb.TagNumber(2)
  set jwsTransaction($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasJwsTransaction() => $_has(1);
  @$pb.TagNumber(2)
  void clearJwsTransaction() => $_clearField(2);

  /// Android: purchaseToken + product_id z Play Billing.
  @$pb.TagNumber(3)
  $core.String get purchaseToken => $_getSZ(2);
  @$pb.TagNumber(3)
  set purchaseToken($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPurchaseToken() => $_has(2);
  @$pb.TagNumber(3)
  void clearPurchaseToken() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get productId => $_getSZ(3);
  @$pb.TagNumber(4)
  set productId($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasProductId() => $_has(3);
  @$pb.TagNumber(4)
  void clearProductId() => $_clearField(4);
}

class RestoreStorePurchasesRequest extends $pb.GeneratedMessage {
  factory RestoreStorePurchasesRequest({
    $core.String? platform,
    $core.Iterable<$core.String>? jwsTransactions,
    $core.Iterable<$core.String>? purchaseTokens,
    $core.String? productId,
  }) {
    final result = create();
    if (platform != null) result.platform = platform;
    if (jwsTransactions != null) result.jwsTransactions.addAll(jwsTransactions);
    if (purchaseTokens != null) result.purchaseTokens.addAll(purchaseTokens);
    if (productId != null) result.productId = productId;
    return result;
  }

  RestoreStorePurchasesRequest._();

  factory RestoreStorePurchasesRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RestoreStorePurchasesRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RestoreStorePurchasesRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'billing.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'platform')
    ..pPS(2, _omitFieldNames ? '' : 'jwsTransactions')
    ..pPS(3, _omitFieldNames ? '' : 'purchaseTokens')
    ..aOS(4, _omitFieldNames ? '' : 'productId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RestoreStorePurchasesRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RestoreStorePurchasesRequest copyWith(
          void Function(RestoreStorePurchasesRequest) updates) =>
      super.copyWith(
              (message) => updates(message as RestoreStorePurchasesRequest))
          as RestoreStorePurchasesRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RestoreStorePurchasesRequest create() =>
      RestoreStorePurchasesRequest._();
  @$core.override
  RestoreStorePurchasesRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RestoreStorePurchasesRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RestoreStorePurchasesRequest>(create);
  static RestoreStorePurchasesRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get platform => $_getSZ(0);
  @$pb.TagNumber(1)
  set platform($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPlatform() => $_has(0);
  @$pb.TagNumber(1)
  void clearPlatform() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<$core.String> get jwsTransactions => $_getList(1);

  @$pb.TagNumber(3)
  $pb.PbList<$core.String> get purchaseTokens => $_getList(2);

  @$pb.TagNumber(4)
  $core.String get productId => $_getSZ(3);
  @$pb.TagNumber(4)
  set productId($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasProductId() => $_has(3);
  @$pb.TagNumber(4)
  void clearProductId() => $_clearField(4);
}

class AdminListStoreTransactionsRequest extends $pb.GeneratedMessage {
  factory AdminListStoreTransactionsRequest({
    $core.String? organizationId,
    $core.int? limit,
  }) {
    final result = create();
    if (organizationId != null) result.organizationId = organizationId;
    if (limit != null) result.limit = limit;
    return result;
  }

  AdminListStoreTransactionsRequest._();

  factory AdminListStoreTransactionsRequest.fromBuffer(
          $core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AdminListStoreTransactionsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AdminListStoreTransactionsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'billing.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'organizationId')
    ..aI(2, _omitFieldNames ? '' : 'limit')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminListStoreTransactionsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminListStoreTransactionsRequest copyWith(
          void Function(AdminListStoreTransactionsRequest) updates) =>
      super.copyWith((message) =>
              updates(message as AdminListStoreTransactionsRequest))
          as AdminListStoreTransactionsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AdminListStoreTransactionsRequest create() =>
      AdminListStoreTransactionsRequest._();
  @$core.override
  AdminListStoreTransactionsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AdminListStoreTransactionsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AdminListStoreTransactionsRequest>(
          create);
  static AdminListStoreTransactionsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get organizationId => $_getSZ(0);
  @$pb.TagNumber(1)
  set organizationId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasOrganizationId() => $_has(0);
  @$pb.TagNumber(1)
  void clearOrganizationId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get limit => $_getIZ(1);
  @$pb.TagNumber(2)
  set limit($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasLimit() => $_has(1);
  @$pb.TagNumber(2)
  void clearLimit() => $_clearField(2);
}

class StoreTransactionInfo extends $pb.GeneratedMessage {
  factory StoreTransactionInfo({
    $core.String? provider,
    $core.String? transactionId,
    $core.String? originalTransactionId,
    $core.String? productId,
    $core.String? environment,
    $2.Timestamp? purchaseDate,
    $2.Timestamp? expiresDate,
    $2.Timestamp? revocationDate,
    $core.String? offerIdentifier,
  }) {
    final result = create();
    if (provider != null) result.provider = provider;
    if (transactionId != null) result.transactionId = transactionId;
    if (originalTransactionId != null)
      result.originalTransactionId = originalTransactionId;
    if (productId != null) result.productId = productId;
    if (environment != null) result.environment = environment;
    if (purchaseDate != null) result.purchaseDate = purchaseDate;
    if (expiresDate != null) result.expiresDate = expiresDate;
    if (revocationDate != null) result.revocationDate = revocationDate;
    if (offerIdentifier != null) result.offerIdentifier = offerIdentifier;
    return result;
  }

  StoreTransactionInfo._();

  factory StoreTransactionInfo.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory StoreTransactionInfo.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'StoreTransactionInfo',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'billing.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'provider')
    ..aOS(2, _omitFieldNames ? '' : 'transactionId')
    ..aOS(3, _omitFieldNames ? '' : 'originalTransactionId')
    ..aOS(4, _omitFieldNames ? '' : 'productId')
    ..aOS(5, _omitFieldNames ? '' : 'environment')
    ..aOM<$2.Timestamp>(6, _omitFieldNames ? '' : 'purchaseDate',
        subBuilder: $2.Timestamp.create)
    ..aOM<$2.Timestamp>(7, _omitFieldNames ? '' : 'expiresDate',
        subBuilder: $2.Timestamp.create)
    ..aOM<$2.Timestamp>(8, _omitFieldNames ? '' : 'revocationDate',
        subBuilder: $2.Timestamp.create)
    ..aOS(9, _omitFieldNames ? '' : 'offerIdentifier')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StoreTransactionInfo clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  StoreTransactionInfo copyWith(void Function(StoreTransactionInfo) updates) =>
      super.copyWith((message) => updates(message as StoreTransactionInfo))
          as StoreTransactionInfo;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static StoreTransactionInfo create() => StoreTransactionInfo._();
  @$core.override
  StoreTransactionInfo createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static StoreTransactionInfo getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<StoreTransactionInfo>(create);
  static StoreTransactionInfo? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get provider => $_getSZ(0);
  @$pb.TagNumber(1)
  set provider($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasProvider() => $_has(0);
  @$pb.TagNumber(1)
  void clearProvider() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get transactionId => $_getSZ(1);
  @$pb.TagNumber(2)
  set transactionId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTransactionId() => $_has(1);
  @$pb.TagNumber(2)
  void clearTransactionId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get originalTransactionId => $_getSZ(2);
  @$pb.TagNumber(3)
  set originalTransactionId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasOriginalTransactionId() => $_has(2);
  @$pb.TagNumber(3)
  void clearOriginalTransactionId() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get productId => $_getSZ(3);
  @$pb.TagNumber(4)
  set productId($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasProductId() => $_has(3);
  @$pb.TagNumber(4)
  void clearProductId() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get environment => $_getSZ(4);
  @$pb.TagNumber(5)
  set environment($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasEnvironment() => $_has(4);
  @$pb.TagNumber(5)
  void clearEnvironment() => $_clearField(5);

  @$pb.TagNumber(6)
  $2.Timestamp get purchaseDate => $_getN(5);
  @$pb.TagNumber(6)
  set purchaseDate($2.Timestamp value) => $_setField(6, value);
  @$pb.TagNumber(6)
  $core.bool hasPurchaseDate() => $_has(5);
  @$pb.TagNumber(6)
  void clearPurchaseDate() => $_clearField(6);
  @$pb.TagNumber(6)
  $2.Timestamp ensurePurchaseDate() => $_ensure(5);

  @$pb.TagNumber(7)
  $2.Timestamp get expiresDate => $_getN(6);
  @$pb.TagNumber(7)
  set expiresDate($2.Timestamp value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasExpiresDate() => $_has(6);
  @$pb.TagNumber(7)
  void clearExpiresDate() => $_clearField(7);
  @$pb.TagNumber(7)
  $2.Timestamp ensureExpiresDate() => $_ensure(6);

  @$pb.TagNumber(8)
  $2.Timestamp get revocationDate => $_getN(7);
  @$pb.TagNumber(8)
  set revocationDate($2.Timestamp value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasRevocationDate() => $_has(7);
  @$pb.TagNumber(8)
  void clearRevocationDate() => $_clearField(8);
  @$pb.TagNumber(8)
  $2.Timestamp ensureRevocationDate() => $_ensure(7);

  @$pb.TagNumber(9)
  $core.String get offerIdentifier => $_getSZ(8);
  @$pb.TagNumber(9)
  set offerIdentifier($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasOfferIdentifier() => $_has(8);
  @$pb.TagNumber(9)
  void clearOfferIdentifier() => $_clearField(9);
}

class AdminListStoreTransactionsResponse extends $pb.GeneratedMessage {
  factory AdminListStoreTransactionsResponse({
    $core.Iterable<StoreTransactionInfo>? transactions,
  }) {
    final result = create();
    if (transactions != null) result.transactions.addAll(transactions);
    return result;
  }

  AdminListStoreTransactionsResponse._();

  factory AdminListStoreTransactionsResponse.fromBuffer(
          $core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AdminListStoreTransactionsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AdminListStoreTransactionsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'billing.v1'),
      createEmptyInstance: create)
    ..pPM<StoreTransactionInfo>(1, _omitFieldNames ? '' : 'transactions',
        subBuilder: StoreTransactionInfo.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminListStoreTransactionsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AdminListStoreTransactionsResponse copyWith(
          void Function(AdminListStoreTransactionsResponse) updates) =>
      super.copyWith((message) =>
              updates(message as AdminListStoreTransactionsResponse))
          as AdminListStoreTransactionsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AdminListStoreTransactionsResponse create() =>
      AdminListStoreTransactionsResponse._();
  @$core.override
  AdminListStoreTransactionsResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AdminListStoreTransactionsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AdminListStoreTransactionsResponse>(
          create);
  static AdminListStoreTransactionsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<StoreTransactionInfo> get transactions => $_getList(0);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
