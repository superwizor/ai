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

  /// Pobiera historię faktur dla organizacji.
  $grpc.ResponseFuture<$0.ListInvoicesResponse> listInvoices(
    $0.ListInvoicesRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$listInvoices, request, options: options);
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

  /// SUPERWIZOR_ADMIN. Sets/updates the org's seat allocations
  /// (plan × seats × negotiated price) and ensures a MANUAL
  /// subscription exists starting at subscription_start. Creates
  /// per-therapist usage counters for already-seated therapists;
  /// later joiners get theirs lazily on first ReserveCredit.
  /// reason >= 10 chars → audit_events.
  $grpc.ResponseFuture<$0.OrgSeatSummary> adminSetSeatAllocations(
    $0.AdminSetSeatAllocationsRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$adminSetSeatAllocations, request,
        options: options);
  }

  /// ORG_ADMIN. Seat occupancy + per-therapist token usage for the
  /// /org panel. Org resolved from the caller's auth context.
  $grpc.ResponseFuture<$0.OrgSeatSummary> getMyOrgSeatUsage(
    $1.Empty request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getMyOrgSeatUsage, request, options: options);
  }

  /// SUPERWIZOR_ADMIN. Active plan catalog — feeds the /admin/orgs/new
  /// seat-allocation table (plan_id × seats × price).
  $grpc.ResponseFuture<$0.AdminListPlansResponse> adminListPlans(
    $1.Empty request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$adminListPlans, request, options: options);
  }

  /// SUPERWIZOR_ADMIN. Seat occupancy + per-therapist usage for ANY
  /// organization — the /admin/orgs/[id] edit surface. Same payload as
  /// GetMyOrgSeatUsage but org comes from the request, gated on the
  /// platform-admin role.
  $grpc.ResponseFuture<$0.OrgSeatSummary> adminGetOrgSeatUsage(
    $0.AdminGetOrgSeatUsageRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$adminGetOrgSeatUsage, request, options: options);
  }

  /// SUPERWIZOR_ADMIN. Zakłada kod rabatowy: nasz wiersz w
  /// discount_codes + coupon i promotion code po stronie Stripe'a
  /// (to Stripe atomowo pilnuje max_redemptions przy checkoucie).
  /// reason >= 10 znaków → audit_events.
  $grpc.ResponseFuture<$0.DiscountCode> adminCreateDiscountCode(
    $0.AdminCreateDiscountCodeRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$adminCreateDiscountCode, request,
        options: options);
  }

  /// SUPERWIZOR_ADMIN. Zmienia nazwę / termin / limit / aktywność.
  /// Stripe nie pozwala zmienić expires_at ani max_redemptions na
  /// istniejącym promotion code, więc zmiana któregokolwiek z nich
  /// zakłada NOWY promotion code pod tym samym kuponem i wygasza stary
  /// (docs/70 §6.4 D10).
  $grpc.ResponseFuture<$0.DiscountCode> adminUpdateDiscountCode(
    $0.AdminUpdateDiscountCodeRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$adminUpdateDiscountCode, request,
        options: options);
  }

  /// SUPERWIZOR_ADMIN. Lista kodów do tabeli w panelu.
  $grpc.ResponseFuture<$0.AdminListDiscountCodesResponse>
      adminListDiscountCodes(
    $0.AdminListDiscountCodesRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$adminListDiscountCodes, request,
        options: options);
  }

  /// SUPERWIZOR_ADMIN. Kod + historia użyć (organizacja, data, kanał).
  $grpc.ResponseFuture<$0.DiscountCodeDetails> adminGetDiscountCode(
    $0.AdminGetDiscountCodeRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$adminGetDiscountCode, request, options: options);
  }

  /// Zalogowany użytkownik. Walidacja kodu PRZED checkoutem: czy ważny,
  /// czy obejmuje wybrany plan, ile wyniesie cena. Nie rezerwuje użycia —
  /// rezerwacja powstaje przy tworzeniu sesji Checkout.
  $grpc.ResponseFuture<$0.DiscountCodeQuote> validateDiscountCode(
    $0.ValidateDiscountCodeRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$validateDiscountCode, request, options: options);
  }

  /// Zalogowany użytkownik. Co wolno pokazać na paywallu: aktywny
  /// dostawca, czy zakup jest w ogóle dozwolony (i dlaczego nie),
  /// katalog produktów sklepowych, tryb wzmianki o WWW. Aplikacja NIE
  /// decyduje o tym sama — flagi i blokady krzyżowe żyją na serwerze.
  $grpc.ResponseFuture<$0.BillingSurface> getBillingSurface(
    $1.Empty request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getBillingSurface, request, options: options);
  }

  /// Zalogowany użytkownik. Bramka przed otwarciem arkusza zakupu:
  /// sprawdza blokady (inny dostawca, organizacja na miejscach, flaga
  /// wyłączona, równoległy checkout) i zwraca app_account_token, którym
  /// aplikacja podpisuje transakcję w sklepie.
  $grpc.ResponseFuture<$0.BeginStorePurchaseResponse> beginStorePurchase(
    $0.BeginStorePurchaseRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$beginStorePurchase, request, options: options);
  }

  /// Zalogowany użytkownik. Weryfikuje zakup u Apple/Google i nadaje
  /// uprawnienie. Aplikacja NIGDY nie przyznaje go sobie sama; transakcji
  /// nie wolno finishować/acknowledge'ować przed sukcesem tego RPC.
  $grpc.ResponseFuture<$0.Subscription> verifyStorePurchase(
    $0.VerifyStorePurchaseRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$verifyStorePurchase, request, options: options);
  }

  /// Zalogowany użytkownik. „Przywróć zakupy" (wymóg Apple 3.1.2).
  /// Odrzuca transakcje z app_account_token innej organizacji.
  $grpc.ResponseFuture<$0.Subscription> restoreStorePurchases(
    $0.RestoreStorePurchasesRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$restoreStorePurchases, request, options: options);
  }

  /// SUPERWIZOR_ADMIN. Dziennik transakcji sklepowych organizacji.
  $grpc.ResponseFuture<$0.AdminListStoreTransactionsResponse>
      adminListStoreTransactions(
    $0.AdminListStoreTransactionsRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$adminListStoreTransactions, request,
        options: options);
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
  static final _$listInvoices =
      $grpc.ClientMethod<$0.ListInvoicesRequest, $0.ListInvoicesResponse>(
          '/billing.v1.BillingService/ListInvoices',
          ($0.ListInvoicesRequest value) => value.writeToBuffer(),
          $0.ListInvoicesResponse.fromBuffer);
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
  static final _$adminSetSeatAllocations =
      $grpc.ClientMethod<$0.AdminSetSeatAllocationsRequest, $0.OrgSeatSummary>(
          '/billing.v1.BillingService/AdminSetSeatAllocations',
          ($0.AdminSetSeatAllocationsRequest value) => value.writeToBuffer(),
          $0.OrgSeatSummary.fromBuffer);
  static final _$getMyOrgSeatUsage =
      $grpc.ClientMethod<$1.Empty, $0.OrgSeatSummary>(
          '/billing.v1.BillingService/GetMyOrgSeatUsage',
          ($1.Empty value) => value.writeToBuffer(),
          $0.OrgSeatSummary.fromBuffer);
  static final _$adminListPlans =
      $grpc.ClientMethod<$1.Empty, $0.AdminListPlansResponse>(
          '/billing.v1.BillingService/AdminListPlans',
          ($1.Empty value) => value.writeToBuffer(),
          $0.AdminListPlansResponse.fromBuffer);
  static final _$adminGetOrgSeatUsage =
      $grpc.ClientMethod<$0.AdminGetOrgSeatUsageRequest, $0.OrgSeatSummary>(
          '/billing.v1.BillingService/AdminGetOrgSeatUsage',
          ($0.AdminGetOrgSeatUsageRequest value) => value.writeToBuffer(),
          $0.OrgSeatSummary.fromBuffer);
  static final _$adminCreateDiscountCode =
      $grpc.ClientMethod<$0.AdminCreateDiscountCodeRequest, $0.DiscountCode>(
          '/billing.v1.BillingService/AdminCreateDiscountCode',
          ($0.AdminCreateDiscountCodeRequest value) => value.writeToBuffer(),
          $0.DiscountCode.fromBuffer);
  static final _$adminUpdateDiscountCode =
      $grpc.ClientMethod<$0.AdminUpdateDiscountCodeRequest, $0.DiscountCode>(
          '/billing.v1.BillingService/AdminUpdateDiscountCode',
          ($0.AdminUpdateDiscountCodeRequest value) => value.writeToBuffer(),
          $0.DiscountCode.fromBuffer);
  static final _$adminListDiscountCodes = $grpc.ClientMethod<
          $0.AdminListDiscountCodesRequest, $0.AdminListDiscountCodesResponse>(
      '/billing.v1.BillingService/AdminListDiscountCodes',
      ($0.AdminListDiscountCodesRequest value) => value.writeToBuffer(),
      $0.AdminListDiscountCodesResponse.fromBuffer);
  static final _$adminGetDiscountCode = $grpc.ClientMethod<
          $0.AdminGetDiscountCodeRequest, $0.DiscountCodeDetails>(
      '/billing.v1.BillingService/AdminGetDiscountCode',
      ($0.AdminGetDiscountCodeRequest value) => value.writeToBuffer(),
      $0.DiscountCodeDetails.fromBuffer);
  static final _$validateDiscountCode =
      $grpc.ClientMethod<$0.ValidateDiscountCodeRequest, $0.DiscountCodeQuote>(
          '/billing.v1.BillingService/ValidateDiscountCode',
          ($0.ValidateDiscountCodeRequest value) => value.writeToBuffer(),
          $0.DiscountCodeQuote.fromBuffer);
  static final _$getBillingSurface =
      $grpc.ClientMethod<$1.Empty, $0.BillingSurface>(
          '/billing.v1.BillingService/GetBillingSurface',
          ($1.Empty value) => value.writeToBuffer(),
          $0.BillingSurface.fromBuffer);
  static final _$beginStorePurchase = $grpc.ClientMethod<
          $0.BeginStorePurchaseRequest, $0.BeginStorePurchaseResponse>(
      '/billing.v1.BillingService/BeginStorePurchase',
      ($0.BeginStorePurchaseRequest value) => value.writeToBuffer(),
      $0.BeginStorePurchaseResponse.fromBuffer);
  static final _$verifyStorePurchase =
      $grpc.ClientMethod<$0.VerifyStorePurchaseRequest, $0.Subscription>(
          '/billing.v1.BillingService/VerifyStorePurchase',
          ($0.VerifyStorePurchaseRequest value) => value.writeToBuffer(),
          $0.Subscription.fromBuffer);
  static final _$restoreStorePurchases =
      $grpc.ClientMethod<$0.RestoreStorePurchasesRequest, $0.Subscription>(
          '/billing.v1.BillingService/RestoreStorePurchases',
          ($0.RestoreStorePurchasesRequest value) => value.writeToBuffer(),
          $0.Subscription.fromBuffer);
  static final _$adminListStoreTransactions = $grpc.ClientMethod<
          $0.AdminListStoreTransactionsRequest,
          $0.AdminListStoreTransactionsResponse>(
      '/billing.v1.BillingService/AdminListStoreTransactions',
      ($0.AdminListStoreTransactionsRequest value) => value.writeToBuffer(),
      $0.AdminListStoreTransactionsResponse.fromBuffer);
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
    $addMethod(
        $grpc.ServiceMethod<$0.ListInvoicesRequest, $0.ListInvoicesResponse>(
            'ListInvoices',
            listInvoices_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.ListInvoicesRequest.fromBuffer(value),
            ($0.ListInvoicesResponse value) => value.writeToBuffer()));
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
    $addMethod($grpc.ServiceMethod<$0.AdminSetSeatAllocationsRequest,
            $0.OrgSeatSummary>(
        'AdminSetSeatAllocations',
        adminSetSeatAllocations_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.AdminSetSeatAllocationsRequest.fromBuffer(value),
        ($0.OrgSeatSummary value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$1.Empty, $0.OrgSeatSummary>(
        'GetMyOrgSeatUsage',
        getMyOrgSeatUsage_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $1.Empty.fromBuffer(value),
        ($0.OrgSeatSummary value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$1.Empty, $0.AdminListPlansResponse>(
        'AdminListPlans',
        adminListPlans_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $1.Empty.fromBuffer(value),
        ($0.AdminListPlansResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.AdminGetOrgSeatUsageRequest, $0.OrgSeatSummary>(
            'AdminGetOrgSeatUsage',
            adminGetOrgSeatUsage_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.AdminGetOrgSeatUsageRequest.fromBuffer(value),
            ($0.OrgSeatSummary value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.AdminCreateDiscountCodeRequest, $0.DiscountCode>(
            'AdminCreateDiscountCode',
            adminCreateDiscountCode_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.AdminCreateDiscountCodeRequest.fromBuffer(value),
            ($0.DiscountCode value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.AdminUpdateDiscountCodeRequest, $0.DiscountCode>(
            'AdminUpdateDiscountCode',
            adminUpdateDiscountCode_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.AdminUpdateDiscountCodeRequest.fromBuffer(value),
            ($0.DiscountCode value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.AdminListDiscountCodesRequest,
            $0.AdminListDiscountCodesResponse>(
        'AdminListDiscountCodes',
        adminListDiscountCodes_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.AdminListDiscountCodesRequest.fromBuffer(value),
        ($0.AdminListDiscountCodesResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.AdminGetDiscountCodeRequest,
            $0.DiscountCodeDetails>(
        'AdminGetDiscountCode',
        adminGetDiscountCode_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.AdminGetDiscountCodeRequest.fromBuffer(value),
        ($0.DiscountCodeDetails value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ValidateDiscountCodeRequest,
            $0.DiscountCodeQuote>(
        'ValidateDiscountCode',
        validateDiscountCode_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.ValidateDiscountCodeRequest.fromBuffer(value),
        ($0.DiscountCodeQuote value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$1.Empty, $0.BillingSurface>(
        'GetBillingSurface',
        getBillingSurface_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $1.Empty.fromBuffer(value),
        ($0.BillingSurface value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.BeginStorePurchaseRequest,
            $0.BeginStorePurchaseResponse>(
        'BeginStorePurchase',
        beginStorePurchase_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.BeginStorePurchaseRequest.fromBuffer(value),
        ($0.BeginStorePurchaseResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.VerifyStorePurchaseRequest, $0.Subscription>(
            'VerifyStorePurchase',
            verifyStorePurchase_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.VerifyStorePurchaseRequest.fromBuffer(value),
            ($0.Subscription value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.RestoreStorePurchasesRequest, $0.Subscription>(
            'RestoreStorePurchases',
            restoreStorePurchases_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.RestoreStorePurchasesRequest.fromBuffer(value),
            ($0.Subscription value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.AdminListStoreTransactionsRequest,
            $0.AdminListStoreTransactionsResponse>(
        'AdminListStoreTransactions',
        adminListStoreTransactions_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.AdminListStoreTransactionsRequest.fromBuffer(value),
        ($0.AdminListStoreTransactionsResponse value) =>
            value.writeToBuffer()));
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

  $async.Future<$0.ListInvoicesResponse> listInvoices_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.ListInvoicesRequest> $request) async {
    return listInvoices($call, await $request);
  }

  $async.Future<$0.ListInvoicesResponse> listInvoices(
      $grpc.ServiceCall call, $0.ListInvoicesRequest request);

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

  $async.Future<$0.OrgSeatSummary> adminSetSeatAllocations_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.AdminSetSeatAllocationsRequest> $request) async {
    return adminSetSeatAllocations($call, await $request);
  }

  $async.Future<$0.OrgSeatSummary> adminSetSeatAllocations(
      $grpc.ServiceCall call, $0.AdminSetSeatAllocationsRequest request);

  $async.Future<$0.OrgSeatSummary> getMyOrgSeatUsage_Pre(
      $grpc.ServiceCall $call, $async.Future<$1.Empty> $request) async {
    return getMyOrgSeatUsage($call, await $request);
  }

  $async.Future<$0.OrgSeatSummary> getMyOrgSeatUsage(
      $grpc.ServiceCall call, $1.Empty request);

  $async.Future<$0.AdminListPlansResponse> adminListPlans_Pre(
      $grpc.ServiceCall $call, $async.Future<$1.Empty> $request) async {
    return adminListPlans($call, await $request);
  }

  $async.Future<$0.AdminListPlansResponse> adminListPlans(
      $grpc.ServiceCall call, $1.Empty request);

  $async.Future<$0.OrgSeatSummary> adminGetOrgSeatUsage_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.AdminGetOrgSeatUsageRequest> $request) async {
    return adminGetOrgSeatUsage($call, await $request);
  }

  $async.Future<$0.OrgSeatSummary> adminGetOrgSeatUsage(
      $grpc.ServiceCall call, $0.AdminGetOrgSeatUsageRequest request);

  $async.Future<$0.DiscountCode> adminCreateDiscountCode_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.AdminCreateDiscountCodeRequest> $request) async {
    return adminCreateDiscountCode($call, await $request);
  }

  $async.Future<$0.DiscountCode> adminCreateDiscountCode(
      $grpc.ServiceCall call, $0.AdminCreateDiscountCodeRequest request);

  $async.Future<$0.DiscountCode> adminUpdateDiscountCode_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.AdminUpdateDiscountCodeRequest> $request) async {
    return adminUpdateDiscountCode($call, await $request);
  }

  $async.Future<$0.DiscountCode> adminUpdateDiscountCode(
      $grpc.ServiceCall call, $0.AdminUpdateDiscountCodeRequest request);

  $async.Future<$0.AdminListDiscountCodesResponse> adminListDiscountCodes_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.AdminListDiscountCodesRequest> $request) async {
    return adminListDiscountCodes($call, await $request);
  }

  $async.Future<$0.AdminListDiscountCodesResponse> adminListDiscountCodes(
      $grpc.ServiceCall call, $0.AdminListDiscountCodesRequest request);

  $async.Future<$0.DiscountCodeDetails> adminGetDiscountCode_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.AdminGetDiscountCodeRequest> $request) async {
    return adminGetDiscountCode($call, await $request);
  }

  $async.Future<$0.DiscountCodeDetails> adminGetDiscountCode(
      $grpc.ServiceCall call, $0.AdminGetDiscountCodeRequest request);

  $async.Future<$0.DiscountCodeQuote> validateDiscountCode_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.ValidateDiscountCodeRequest> $request) async {
    return validateDiscountCode($call, await $request);
  }

  $async.Future<$0.DiscountCodeQuote> validateDiscountCode(
      $grpc.ServiceCall call, $0.ValidateDiscountCodeRequest request);

  $async.Future<$0.BillingSurface> getBillingSurface_Pre(
      $grpc.ServiceCall $call, $async.Future<$1.Empty> $request) async {
    return getBillingSurface($call, await $request);
  }

  $async.Future<$0.BillingSurface> getBillingSurface(
      $grpc.ServiceCall call, $1.Empty request);

  $async.Future<$0.BeginStorePurchaseResponse> beginStorePurchase_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.BeginStorePurchaseRequest> $request) async {
    return beginStorePurchase($call, await $request);
  }

  $async.Future<$0.BeginStorePurchaseResponse> beginStorePurchase(
      $grpc.ServiceCall call, $0.BeginStorePurchaseRequest request);

  $async.Future<$0.Subscription> verifyStorePurchase_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.VerifyStorePurchaseRequest> $request) async {
    return verifyStorePurchase($call, await $request);
  }

  $async.Future<$0.Subscription> verifyStorePurchase(
      $grpc.ServiceCall call, $0.VerifyStorePurchaseRequest request);

  $async.Future<$0.Subscription> restoreStorePurchases_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.RestoreStorePurchasesRequest> $request) async {
    return restoreStorePurchases($call, await $request);
  }

  $async.Future<$0.Subscription> restoreStorePurchases(
      $grpc.ServiceCall call, $0.RestoreStorePurchasesRequest request);

  $async.Future<$0.AdminListStoreTransactionsResponse>
      adminListStoreTransactions_Pre($grpc.ServiceCall $call,
          $async.Future<$0.AdminListStoreTransactionsRequest> $request) async {
    return adminListStoreTransactions($call, await $request);
  }

  $async.Future<$0.AdminListStoreTransactionsResponse>
      adminListStoreTransactions(
          $grpc.ServiceCall call, $0.AdminListStoreTransactionsRequest request);
}
