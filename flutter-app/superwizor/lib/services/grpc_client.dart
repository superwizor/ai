import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:grpc/grpc.dart';
import '../generated/identity/v1/identity.pbgrpc.dart';
import '../generated/clinical/v1/clinical.pbgrpc.dart';
import '../generated/ingestion/v1/ingestion.pbgrpc.dart';

class GrpcClients {
  late final ClientChannel identityChannel;
  late final ClientChannel clinicalChannel;
  late final ClientChannel ingestionChannel;

  late final IdentityServiceClient identity;
  late final ClinicalServiceClient clinical;
  late final IngestionServiceClient ingestion;

  GrpcClients({
    required String identityUrl,
    required int identityPort,
    required String clinicalUrl,
    required int clinicalPort,
    required String ingestionUrl,
    required int ingestionPort,
  }) {
    identityChannel = ClientChannel(
      identityUrl,
      port: identityPort,
      options: const ChannelOptions(
        credentials: ChannelCredentials.insecure(),
        connectionTimeout: Duration(seconds: 5),
      ),
    );
    clinicalChannel = ClientChannel(
      clinicalUrl,
      port: clinicalPort,
      options: const ChannelOptions(
        credentials: ChannelCredentials.insecure(),
        connectionTimeout: Duration(seconds: 5),
      ),
    );
    ingestionChannel = ClientChannel(
      ingestionUrl,
      port: ingestionPort,
      options: const ChannelOptions(
        credentials: ChannelCredentials.insecure(),
        connectionTimeout: Duration(seconds: 5),
      ),
    );

    final interceptors = [AuthInterceptor()];
    identity = IdentityServiceClient(identityChannel, interceptors: interceptors);
    clinical = ClinicalServiceClient(clinicalChannel, interceptors: interceptors);
    ingestion = IngestionServiceClient(ingestionChannel, interceptors: interceptors);
  }

  void dispose() {
    identityChannel.shutdown();
    clinicalChannel.shutdown();
    ingestionChannel.shutdown();
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
        timeout: const Duration(seconds: 10),
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
        timeout: const Duration(seconds: 10),
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
