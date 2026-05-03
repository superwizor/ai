import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../generated/clinical/v1/clinical.pbgrpc.dart';
import 'grpc_provider.dart';

final sessionDetailsProvider = FutureProvider.family<GetSessionDetailsResponse, String>((ref, sessionId) async {
  final clients = ref.watch(grpcClientsProvider);
  
  final request = GetSessionDetailsRequest(sessionId: sessionId);
  final response = await clients.clinical.getSessionDetails(request);
  
  return response;
});
