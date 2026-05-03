import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/grpc_client.dart';

final grpcClientsProvider = Provider<GrpcClients>((ref) {
  // TODO: Use environment variables or configuration for these URLs in production.
  // Using localhost or local network IPs for development.
  // Note: For Android Emulator, localhost is usually 10.0.2.2.
  final clients = GrpcClients(
    identityUrl: '127.0.0.1',
    identityPort: 8080, // Zastąpić docelowym portem (lub Cloud Run url)
    clinicalUrl: '127.0.0.1',
    clinicalPort: 8081, // Zastąpić docelowym portem (lub Cloud Run url)
    ingestionUrl: '127.0.0.1',
    ingestionPort: 8082, // Zastąpić docelowym portem (lub Cloud Run url)
  );

  ref.onDispose(() {
    clients.dispose();
  });

  return clients;
});
