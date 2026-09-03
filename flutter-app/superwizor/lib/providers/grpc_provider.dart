import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/grpc_client.dart';

/// Cloud Run endpoints. TODO: env-driven config.
final grpcClientsProvider = Provider<GrpcClients>((ref) {
  // Check if we should connect to the local backend services (ports 8080-8084 on localhost)
  const bool useLocal = bool.fromEnvironment('LOCAL_BACKEND', defaultValue: false);

  final clients = useLocal
      ? GrpcClients(
          identityUrl: '127.0.0.1',
          identityPort: 8080,
          clinicalUrl: '127.0.0.1',
          clinicalPort: 8082,
          ingestionUrl: '127.0.0.1',
          ingestionPort: 8083,
          notificationUrl: '127.0.0.1',
          notificationPort: 8084,
          billingUrl: '127.0.0.1',
          billingPort: 8081,
        )
      : GrpcClients(
          identityUrl: 'identity-svc-344724821207.europe-central2.run.app',
          identityPort: 443,
          clinicalUrl: 'clinical-svc-344724821207.europe-central2.run.app',
          clinicalPort: 443,
          ingestionUrl: 'ingestion-svc-344724821207.europe-central2.run.app',
          ingestionPort: 443,
          notificationUrl: 'notification-svc-344724821207.europe-central2.run.app',
          notificationPort: 443,
          // Wzorzec „browser-direct" z docs/agents/03_billing-svc.md: sklepowe
          // RPC (GetBillingSurface / BeginStorePurchase / VerifyStorePurchase /
          // RestoreStorePurchases) idą PROSTO do billing-svc, bez hopa przez
          // clinical-svc, który przy proxy dawał RST_STREAM. Ten sam host, na
          // który wchodzi dziś przeglądarka (NEXT_PUBLIC_BILLING_URL).
          // Quota (GetMyBillingState) zostaje na clinical-svc — bez zmian.
          billingUrl: 'billing-svc-344724821207.europe-central2.run.app',
          billingPort: 443,
        );

  ref.onDispose(clients.dispose);
  return clients;
});

