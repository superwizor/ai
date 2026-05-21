// Central DI bindings for service-layer singletons (Riverpod 3.x).
// Wire any service that has implicit external state (Firestore,
// Hive, Firebase Auth) here so swapping implementations later (e.g.
// LocalConsentService → BackendConsentService per D9) is one edit.

import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/consent_service.dart';
import '../services/fcm_token_service.dart';
import '../services/recording_service.dart';
import '../services/secure_audio_storage_service.dart';
import '../services/session_state_listener.dart';
import '../services/transcript_pdf_exporter.dart';
import '../services/upload_service.dart';
import 'grpc_provider.dart';

final firebaseAuthProvider = Provider<fb_auth.FirebaseAuth>(
  (ref) => fb_auth.FirebaseAuth.instance,
);

final consentServiceProvider = Provider<ConsentService>((ref) {
  // D9 — MVP local-only stub. Post-MVP: BackendConsentService.
  return LocalConsentService(ref.watch(firebaseAuthProvider));
});

final fcmTokenServiceProvider = Provider<FcmTokenService>((ref) {
  return FcmTokenService(ref.watch(grpcClientsProvider).notification);
});

final sessionStateListenerProvider = Provider<SessionStateListener>(
  (ref) => SessionStateListener(),
);

final secureAudioStorageProvider = Provider<SecureAudioStorageService>(
  (ref) => SecureAudioStorageService(),
);

final recordingServiceProvider = Provider<RecordingService>((ref) {
  final svc = RecordingService();
  ref.onDispose(svc.dispose);
  return svc;
});

final uploadServiceProvider = Provider<UploadService>((ref) {
  return UploadService(ref.watch(secureAudioStorageProvider));
});

// transcriptCacheProvider retired 2026-05 — transcript caching is now
// part of SessionDetailsRepository (see lib/repositories/).

final transcriptPdfExporterProvider = Provider<TranscriptPdfExporter>(
  (ref) => TranscriptPdfExporter(),
);
