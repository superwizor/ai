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
        );

  ref.onDispose(clients.dispose);
  return clients;
});

