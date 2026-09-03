import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/foundation.dart' show kIsWeb;
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
    identity = IdentityServiceClient(
      identityChannel,
      interceptors: interceptors,
    );
    clinical = ClinicalServiceClient(
      clinicalChannel,
      interceptors: interceptors,
    );
    ingestion = IngestionServiceClient(
      ingestionChannel,
      interceptors: interceptors,
    );
    notification = NotificationServiceClient(
      notificationChannel,
      interceptors: interceptors,
    );

    // Sklepowa część billingu (docs/70 §7.2) woła billing-svc BEZPOŚREDNIO —
    // tak jak robi to dziś przeglądarka. Quota (GetMyBillingState) dalej idzie
    // przez clinical-svc, więc brak `billingUrl` nie psuje niczego, co działa:
    // klient zostaje nullem, a warstwa commerce po prostu się nie włącza.
    if (billingUrl != null && billingUrl.isNotEmpty) {
      billingChannel = GrpcOrGrpcWebClientChannel.toSingleEndpoint(
        host: billingUrl,
        port: billingPort,
        transportSecure: billingPort == 443,
      );
      billing = BillingServiceClient(
        billingChannel!,
        interceptors: interceptors,
      );
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
    ClientMethod<Q, R> method,
    Q request,
    CallOptions options,
    ClientUnaryInvoker<Q, R> invoker,
  ) {
    return invoker(
      method,
      request,
      options.mergedWith(
        CallOptions(
          providers: [_authProvider],
          // Domyslne 30 s, ale TYLKO gdy wywolujacy nie podal wlasnego.
          // mergedWith daje pierwszenstwo argumentowi, wiec bezwarunkowe
          // `timeout: 30s` deptalo kazda wartosc ustawiona przy wywolaniu —
          // i czyni loby serwerowy limit ozdoba. Czat potrzebuje wiecej:
          // tura A8 zmierzona na produkcji 20.08.2026 trwala 25,5 s, czyli
          // ocierala sie o te trzydziestke.
          timeout: options.timeout ?? const Duration(seconds: 30),
        ),
      ),
    );
  }

  @override
  ResponseStream<R> interceptStreaming<Q, R>(
    ClientMethod<Q, R> method,
    Stream<Q> requests,
    CallOptions options,
    ClientStreamingInvoker<Q, R> invoker,
  ) {
    return invoker(
      method,
      requests,
      options.mergedWith(
        CallOptions(
          providers: [_authProvider],
          timeout: options.timeout ?? const Duration(seconds: 30),
        ),
      ),
    );
  }

  Future<void> _authProvider(Map<String, String> metadata, String uri) async {
    // NIE na webie. Transport gRPC-Web robi
    // `metadata.forEach(request.setRequestHeader)`, więc KAŻDY klucz
    // metadanych staje się nagłówkiem HTTP objętym walidacją CORS
    // preflight. `X-Client-Platform` nie było na allowliście serwera
    // (pkg/cors/cors.go), więc przeglądarka odrzucała preflight i nie
    // wysyłała POST-a — każdy RPC z superwizor-app.web.app padał na
    // "code 2 UNKNOWN: HTTP request completed without a status
    // (potential CORS issue)" (incydent 2026-07-24 → 2026-07-29).
    // Nagłówek dopisano do defaultAllowedHeaders w tym samym PR; bramkę
    // można zdjąć, gdy identity-svc i clinical-svc będą wdrożone z nową
    // allowlistą — TYLKO te dwa mają w ogóle middleware CORS
    // (`cors.New` w cmd/server/main.go). ingestion-svc i
    // notification-svc serwują goły gRPC po HTTP/2, bez CORS i bez
    // gRPC-Web, więc wywołania do nich z przeglądarki padają niezależnie
    // od tego nagłówka — patrz docs/agents/12_web_file_upload_deferred.md.
    //
    // Konsekwencja bramki: identity-svc stempluje users.first_app_login_at
    // tylko gdy widzi ten nagłówek (profile.go), więc web nigdy go nie
    // zapali. Dziś to bez różnicy — stempel siedzi w GetMyProfile, którego
    // aplikacja Flutter w ogóle nie woła (używa GetUserByFirebaseUID), więc
    // odznaka „pierwsze logowanie w apce" w CRM i tak się nie zapala.
    if (!kIsWeb) {
      metadata['x-client-platform'] = 'flutter-app';
    }
    final user = fb_auth.FirebaseAuth.instance.currentUser;
    if (user != null) {
      final token = await user.getIdToken();
      if (token != null) {
        metadata['authorization'] = 'Bearer $token';
      }
    }
  }
}
