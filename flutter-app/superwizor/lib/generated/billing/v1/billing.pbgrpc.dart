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

@$pb.GrpcServiceName('billing.v1.BillingService')
class BillingServiceClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  BillingServiceClient(super.channel, {super.options, super.interceptors});

  /// Sprawdza czy organizacja ma quotę na nową sesję
  $grpc.ResponseFuture<$0.QuotaDecision> checkQuota(
    $0.CheckQuotaRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$checkQuota, request, options: options);
  }

  /// Inkrementuje usage po zakończonej analizie
  $grpc.ResponseFuture<$1.Empty> incrementUsage(
    $0.IncrementUsageRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$incrementUsage, request, options: options);
  }

  /// Stan subskrypcji
  $grpc.ResponseFuture<$0.Subscription> getSubscription(
    $0.GetSubscriptionRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getSubscription, request, options: options);
  }

  // method descriptors

  static final _$checkQuota =
      $grpc.ClientMethod<$0.CheckQuotaRequest, $0.QuotaDecision>(
          '/billing.v1.BillingService/CheckQuota',
          ($0.CheckQuotaRequest value) => value.writeToBuffer(),
          $0.QuotaDecision.fromBuffer);
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
  }

  $async.Future<$0.QuotaDecision> checkQuota_Pre($grpc.ServiceCall $call,
      $async.Future<$0.CheckQuotaRequest> $request) async {
    return checkQuota($call, await $request);
  }

  $async.Future<$0.QuotaDecision> checkQuota(
      $grpc.ServiceCall call, $0.CheckQuotaRequest request);

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
}
