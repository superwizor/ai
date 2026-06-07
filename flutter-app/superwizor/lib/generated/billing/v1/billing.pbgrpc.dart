// This is a generated file - do not edit.
//
// Generated from billing/v1/billing.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:async' as $async;
import 'dart:core' as $core;

import 'package:grpc/service_api.dart' as $grpc;
import 'package:protobuf/protobuf.dart' as $pb;
import 'package:protobuf/well_known_types/google/protobuf/empty.pb.dart' as $1;

import 'billing.pb.dart' as $0;

export 'billing.pb.dart';

/// BillingService — quota i lifecycle subskrypcji (Phase 3).
///
/// Model tokenów (ADR-DM-017): 1 token = ≤75min audio (twarda granica, bez grace).
/// Pula trzymana per organizacja, debet idzie dwuetapowo:
/// ReserveCredit (przy CreateAudioUpload) → CommitUsage (po STT, znany duration).
///
/// Reference: docs/16_BILLING_SERVICE_PHASE_3.md
@$pb.GrpcServiceName('billing.v1.BillingService')
class BillingServiceClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  BillingServiceClient(super.channel, {super.options, super.interceptors});

  /// Sprawdza dostępną pulę tokenów (read-only, nie blokuje).
  $grpc.ResponseFuture<$0.QuotaDecision> checkQuota(
    $0.CheckQuotaRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$checkQuota, request, options: options);
  }

  /// Rezerwuje token na sesję (ADR-BL-001). TTL 4h.
  /// Idempotent po session_id: powtórne wywołanie zwraca tę samą rezerwację.
  $grpc.ResponseFuture<$0.Reservation> reserveCredit(
    $0.ReserveCreditRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$reserveCredit, request, options: options);
  }

  /// Commituje token po STT, ze znanym duration_seconds.
  /// Idempotent po session_id (usage_events.session_id UNIQUE).
  $grpc.ResponseFuture<$0.UsageCommit> commitUsage(
    $0.CommitUsageRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$commitUsage, request, options: options);
  }

  /// Zwalnia rezerwację (np. upload failed, manual cancel przed STT).
  /// Idempotent: re-call na RELEASED/COMMITTED zwraca OK bez zmian.
  $grpc.ResponseFuture<$1.Empty> releaseCredit(
    $0.ReleaseCreditRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$releaseCredit, request, options: options);
  }

  /// DEPRECATED: użyj CommitUsage. Zachowane dla Phase 2 callers.
  /// Internal mapping: amount → tokens (1:1), duration_seconds = 0,
  /// co oznacza że advisory lock + counter update działają jak commit
  /// ale bez weryfikacji formuły grace period.
  @$core.Deprecated('This method is deprecated')
  $grpc.ResponseFuture<$1.Empty> incrementUsage(
    $0.IncrementUsageRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$incrementUsage, request, options: options);
  }

  /// Stan subskrypcji + bieżące zużycie.
  $grpc.ResponseFuture<$0.Subscription> getSubscription(
    $0.GetSubscriptionRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getSubscription, request, options: options);
  }

  /// Sets usage_counters.tokens_used (and optionally tokens_limit)
  /// on the org's current active counter. Used for support escapes
  /// — refunds, manual top-ups, period rolls. Returns the fresh
  /// Subscription proto so the admin UI updates inline.
  $grpc.ResponseFuture<$0.Subscription> adminResetTokens(
    $0.AdminResetTokensRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$adminResetTokens, request, options: options);
  }

  /// Changes the org's subscription plan_tier + plan_cycle. Creates
  /// a new usage_counters row at the new plan's tokens_limit, marks
  /// the old counter inactive. Returns the fresh Subscription.
  $grpc.ResponseFuture<$0.Subscription> adminChangePlan(
    $0.AdminChangePlanRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$adminChangePlan, request, options: options);
  }

  // method descriptors

  static final _$checkQuota =
      $grpc.ClientMethod<$0.CheckQuotaRequest, $0.QuotaDecision>(
          '/billing.v1.BillingService/CheckQuota',
          ($0.CheckQuotaRequest value) => value.writeToBuffer(),
          $0.QuotaDecision.fromBuffer);
  static final _$reserveCredit =
      $grpc.ClientMethod<$0.ReserveCreditRequest, $0.Reservation>(
          '/billing.v1.BillingService/ReserveCredit',
          ($0.ReserveCreditRequest value) => value.writeToBuffer(),
          $0.Reservation.fromBuffer);
  static final _$commitUsage =
      $grpc.ClientMethod<$0.CommitUsageRequest, $0.UsageCommit>(
          '/billing.v1.BillingService/CommitUsage',
          ($0.CommitUsageRequest value) => value.writeToBuffer(),
          $0.UsageCommit.fromBuffer);
  static final _$releaseCredit =
      $grpc.ClientMethod<$0.ReleaseCreditRequest, $1.Empty>(
          '/billing.v1.BillingService/ReleaseCredit',
          ($0.ReleaseCreditRequest value) => value.writeToBuffer(),
          $1.Empty.fromBuffer);
  static final _$incrementUsage =
      $grpc.ClientMethod<$0.IncrementUsageRequest, $1.Empty>(
          '/billing.v1.BillingService/IncrementUsage',
          ($0.IncrementUsageRequest value) => value.writeToBuffer(),
          $1.Empty.fromBuffer);
  static final _$getSubscription =
      $grpc.ClientMethod<$0.GetSubscriptionRequest, $0.Subscription>(
          '/billing.v1.BillingService/GetSubscription',
          ($0.GetSubscriptionRequest value) => value.writeToBuffer(),
          $0.Subscription.fromBuffer);
  static final _$adminResetTokens =
      $grpc.ClientMethod<$0.AdminResetTokensRequest, $0.Subscription>(
          '/billing.v1.BillingService/AdminResetTokens',
          ($0.AdminResetTokensRequest value) => value.writeToBuffer(),
          $0.Subscription.fromBuffer);
  static final _$adminChangePlan =
      $grpc.ClientMethod<$0.AdminChangePlanRequest, $0.Subscription>(
          '/billing.v1.BillingService/AdminChangePlan',
          ($0.AdminChangePlanRequest value) => value.writeToBuffer(),
          $0.Subscription.fromBuffer);
}

@$pb.GrpcServiceName('billing.v1.BillingService')
abstract class BillingServiceBase extends $grpc.Service {
  $core.String get $name => 'billing.v1.BillingService';

  BillingServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.CheckQuotaRequest, $0.QuotaDecision>(
        'CheckQuota',
        checkQuota_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.CheckQuotaRequest.fromBuffer(value),
        ($0.QuotaDecision value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ReserveCreditRequest, $0.Reservation>(
        'ReserveCredit',
        reserveCredit_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.ReserveCreditRequest.fromBuffer(value),
        ($0.Reservation value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.CommitUsageRequest, $0.UsageCommit>(
        'CommitUsage',
        commitUsage_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.CommitUsageRequest.fromBuffer(value),
        ($0.UsageCommit value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ReleaseCreditRequest, $1.Empty>(
        'ReleaseCredit',
        releaseCredit_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.ReleaseCreditRequest.fromBuffer(value),
        ($1.Empty value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.IncrementUsageRequest, $1.Empty>(
        'IncrementUsage',
        incrementUsage_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.IncrementUsageRequest.fromBuffer(value),
        ($1.Empty value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GetSubscriptionRequest, $0.Subscription>(
        'GetSubscription',
        getSubscription_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.GetSubscriptionRequest.fromBuffer(value),
        ($0.Subscription value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.AdminResetTokensRequest, $0.Subscription>(
        'AdminResetTokens',
        adminResetTokens_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.AdminResetTokensRequest.fromBuffer(value),
        ($0.Subscription value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.AdminChangePlanRequest, $0.Subscription>(
        'AdminChangePlan',
        adminChangePlan_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.AdminChangePlanRequest.fromBuffer(value),
        ($0.Subscription value) => value.writeToBuffer()));
  }

  $async.Future<$0.QuotaDecision> checkQuota_Pre($grpc.ServiceCall $call,
      $async.Future<$0.CheckQuotaRequest> $request) async {
    return checkQuota($call, await $request);
  }

  $async.Future<$0.QuotaDecision> checkQuota(
      $grpc.ServiceCall call, $0.CheckQuotaRequest request);

  $async.Future<$0.Reservation> reserveCredit_Pre($grpc.ServiceCall $call,
      $async.Future<$0.ReserveCreditRequest> $request) async {
    return reserveCredit($call, await $request);
  }

  $async.Future<$0.Reservation> reserveCredit(
      $grpc.ServiceCall call, $0.ReserveCreditRequest request);

  $async.Future<$0.UsageCommit> commitUsage_Pre($grpc.ServiceCall $call,
      $async.Future<$0.CommitUsageRequest> $request) async {
    return commitUsage($call, await $request);
  }

  $async.Future<$0.UsageCommit> commitUsage(
      $grpc.ServiceCall call, $0.CommitUsageRequest request);

  $async.Future<$1.Empty> releaseCredit_Pre($grpc.ServiceCall $call,
      $async.Future<$0.ReleaseCreditRequest> $request) async {
    return releaseCredit($call, await $request);
  }

  $async.Future<$1.Empty> releaseCredit(
      $grpc.ServiceCall call, $0.ReleaseCreditRequest request);

  $async.Future<$1.Empty> incrementUsage_Pre($grpc.ServiceCall $call,
      $async.Future<$0.IncrementUsageRequest> $request) async {
    return incrementUsage($call, await $request);
  }

  $async.Future<$1.Empty> incrementUsage(
      $grpc.ServiceCall call, $0.IncrementUsageRequest request);

  $async.Future<$0.Subscription> getSubscription_Pre($grpc.ServiceCall $call,
      $async.Future<$0.GetSubscriptionRequest> $request) async {
    return getSubscription($call, await $request);
  }

  $async.Future<$0.Subscription> getSubscription(
      $grpc.ServiceCall call, $0.GetSubscriptionRequest request);

  $async.Future<$0.Subscription> adminResetTokens_Pre($grpc.ServiceCall $call,
      $async.Future<$0.AdminResetTokensRequest> $request) async {
    return adminResetTokens($call, await $request);
  }

  $async.Future<$0.Subscription> adminResetTokens(
      $grpc.ServiceCall call, $0.AdminResetTokensRequest request);

  $async.Future<$0.Subscription> adminChangePlan_Pre($grpc.ServiceCall $call,
      $async.Future<$0.AdminChangePlanRequest> $request) async {
    return adminChangePlan($call, await $request);
  }

  $async.Future<$0.Subscription> adminChangePlan(
      $grpc.ServiceCall call, $0.AdminChangePlanRequest request);
}
