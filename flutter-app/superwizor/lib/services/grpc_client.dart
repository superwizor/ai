import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:grpc/grpc.dart';
import 'package:grpc/grpc_or_grpcweb.dart';
import '../generated/identity/v1/identity.pbgrpc.dart';
import '../generated/clinical/v1/clinical.pbgrpc.dart';
import '../generated/ingestion/v1/ingestion.pbgrpc.dart';
import '../generated/notification/v1/notification.pbgrpc.dart';
import '../generated/billing/v1/billing.pbgrpc.dart';

class GrpcClients {
  late final GrpcOrGrpcWebClientChannel identityChannel;
  late final GrpcOrGrpcWebClientChannel clinicalChannel;
  late final GrpcOrGrpcWebClientChannel ingestionChannel;
  late final GrpcOrGrpcWebClientChannel notificationChannel;
  late final GrpcOrGrpcWebClientChannel? billingChannel;

  late final IdentityServiceClient identity;
  late final ClinicalServiceClient clinical;
  late final IngestionServiceClient ingestion;
  late final NotificationServiceClient notification;
  late final BillingServiceClient? billing;

  GrpcClients({
    required String identityUrl,
    required int identityPort,
    required String clinicalUrl,
    required int clinicalPort,
    required String ingestionUrl,
    required int ingestionPort,
    required String notificationUrl,
    required int notificationPort,
    String? billingUrl,
    int billingPort = 443,
  }) {
    identityChannel = GrpcOrGrpcWebClientChannel.toSingleEndpoint(
      host: identityUrl,
      port: identityPort,
      transportSecure: identityPort == 443,
    );
    clinicalChannel = GrpcOrGrpcWebClientChannel.toSingleEndpoint(
      host: clinicalUrl,
      port: clinicalPort,
      transportSecure: clinicalPort == 443,
    );
    ingestionChannel = GrpcOrGrpcWebClientChannel.toSingleEndpoint(
      host: ingestionUrl,
      port: ingestionPort,
      transportSecure: ingestionPort == 443,
    );
    notificationChannel = GrpcOrGrpcWebClientChannel.toSingleEndpoint(
      host: notificationUrl,
      port: notificationPort,
      transportSecure: notificationPort == 443,
    );

    final interceptors = [AuthInterceptor()];
    identity = IdentityServiceClient(identityChannel, interceptors: interceptors);
    clinical = ClinicalServiceClient(clinicalChannel, interceptors: interceptors);
    ingestion = IngestionServiceClient(ingestionChannel, interceptors: interceptors);
    notification = NotificationServiceClient(notificationChannel, interceptors: interceptors);

    // billing-svc jest internal (no allUsers). W obecnej fazie 3 Flutter NIE
    // wywołuje go bezpośrednio — clinical-svc/ingestion-svc proxy'ują quota
    // checks. Klient jest opcjonalny i wpinany tylko jeśli backend wystawi
    // public proxy lub mamy custom auth proxy. Zostawiamy szkielet ready.
    if (billingUrl != null && billingUrl.isNotEmpty) {
      billingChannel = GrpcOrGrpcWebClientChannel.toSingleEndpoint(
        host: billingUrl,
        port: billingPort,
        transportSecure: billingPort == 443,
      );
      billing = BillingServiceClient(billingChannel!, interceptors: interceptors);
    } else {
      billingChannel = null;
      billing = null;
    }
  }

  void dispose() {
    identityChannel.shutdown();
    clinicalChannel.shutdown();
    ingestionChannel.shutdown();
    notificationChannel.shutdown();
    billingChannel?.shutdown();
  }
}

class AuthInterceptor extends ClientInterceptor {
  @override
  ResponseFuture<R> interceptUnary<Q, R>(
      ClientMethod<Q, R> method, Q request, CallOptions options, ClientUnaryInvoker<Q, R> invoker) {
    return invoker(
      method,
      request,
      options.mergedWith(CallOptions(
        providers: [_authProvider],
        timeout: const Duration(seconds: 30),
      )),
    );
  }

  @override
  ResponseStream<R> interceptStreaming<Q, R>(
      ClientMethod<Q, R> method, Stream<Q> requests, CallOptions options, ClientStreamingInvoker<Q, R> invoker) {
    return invoker(
      method,
      requests,
      options.mergedWith(CallOptions(
        providers: [_authProvider],
        timeout: const Duration(seconds: 30),
      )),
    );
  }

  Future<void> _authProvider(Map<String, String> metadata, String uri) async {
    final user = fb_auth.FirebaseAuth.instance.currentUser;
    if (user != null) {
      final token = await user.getIdToken();
      if (token != null) {
        metadata['authorization'] = 'Bearer $token';
      }
    }
  }
}
