import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/grpc_client.dart';

/// Cloud Run endpoints. TODO: env-driven config.
final grpcClientsProvider = Provider<GrpcClients>((ref) {
  final clients = GrpcClients(
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
