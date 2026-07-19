// Central DI bindings for service-layer singletons (Riverpod 3.x).
// Wire any service that has implicit external state (Firestore,
// Hive, Firebase Auth) here so swapping implementations later (e.g.
// LocalConsentService → BackendConsentService per D9) is one edit.

import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/consent_service.dart';
import '../services/fcm_token_service.dart';
import '../services/live_activity_service.dart';
import '../services/recording_manifest_store.dart';
import '../services/recording_service.dart';
import '../services/secure_audio_storage_service.dart';
import '../services/session_state_listener.dart';
import '../services/transcript_pdf_exporter.dart';
import '../services/upload_service.dart';
import 'grpc_provider.dart';
import 'settings_provider.dart';

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
  
  // Listen to setting changes dynamically (mid-session rescheduling)
  ref.listen<AppSettings>(
    appSettingsProvider,
    (previous, next) {
      svc.updateSettings(
        next.reminderIntervalMinutes,
        next.soundEnabled,
        next.hapticsEnabled,
      );
    },
    fireImmediately: true,
  );

  ref.onDispose(svc.dispose);
  return svc;
});

/// Reactive stream of recording state changes — watch this in any widget
/// that needs to rebuild when a recording starts, stops, or is cancelled.
/// Replaces the anti-pattern of reading `recSvc.state` inside build()
/// which never triggers rebuilds because `Provider<RecordingService>`
/// holds a stable singleton.
final recordingStateStreamProvider = StreamProvider<RecordingState>((ref) {
  final svc = ref.watch(recordingServiceProvider);
  return svc.stateStream;
});

final recordingManifestStoreProvider = Provider<RecordingManifestStore>(
  (ref) => RecordingManifestStore(),
);

final uploadServiceProvider = Provider<UploadService>((ref) {
  return UploadService(ref.watch(secureAudioStorageProvider));
});

// transcriptCacheProvider retired 2026-05 — transcript caching is now
// part of SessionDetailsRepository (see lib/repositories/).

final transcriptPdfExporterProvider = Provider<TranscriptPdfExporter>(
  (ref) => TranscriptPdfExporter(),
);

final liveActivityServiceProvider = Provider<LiveActivityService>(
  (ref) => LiveActivityService(),
);
