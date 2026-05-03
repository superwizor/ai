import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/grpc_client.dart';

final grpcClientsProvider = Provider<GrpcClients>((ref) {
  // TODO: Use environment variables or configuration for these URLs in production.
  // Using localhost or local network IPs for development.
  // Note: For Android Emulator, localhost is usually 10.0.2.2.
  final clients = GrpcClients(
    identityUrl: 'identity-svc-344724821207.europe-central2.run.app',
    identityPort: 443,
    clinicalUrl: 'clinical-svc-344724821207.europe-central2.run.app',
    clinicalPort: 443,
    ingestionUrl: 'ingestion-svc-344724821207.europe-central2.run.app', // dedicated ingestion-svc
    ingestionPort: 443,
  );

  ref.onDispose(() {
    clients.dispose();
  });

  return clients;
});
