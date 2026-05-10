# 📱 Faza UI — Superwizor AI Flutter MVP

> **Cel:** Doprowadzić aplikację Flutter do stanu MVP zdolnego przeprowadzić terapeutę przez pełny flow: login → setup → nagranie sesji → upload → live status → transkrypcja + raport. Backend (Fazy 0-3) jest gotowy i wystawia gRPC + Firestore mirror.
>
> Bazuje na: [`02_ARCHITEKTURA_TECHNICZNA.md`](./02_ARCHITEKTURA_TECHNICZNA.md), [`03_DATA_MODEL.md`](./03_DATA_MODEL.md), [`08_FAZA_3_NOTIFICATIONS.md`](./08_FAZA_3_NOTIFICATIONS.md), `B_05_ui_ux_design_system.md`, `B_09_trauma_informed_writing.md`.

---

## 📝 Changelog

- **v1.4** (2026-05-09): Codec audio: `record` package + OGG-OPUS @ 64 kbps mono zamiast `ffmpeg_kit_flutter` + FLAC. Hardware-accelerated na iOS/Android, 5-10x mniejszy upload niż FLAC, zgodny z Chirp 3 (per stt-worker comment). Kryteria walidacji E2E przed merge.
- **v1.3** (2026-05-08): MVP nie modyfikuje backendu. Checkbox zgody waliduje się tylko po stronie aplikacji przez `ConsentService` (stub zwraca OK + audit log lokalny w Hive). Backend change (migracja 000010 + proto extension) odkładamy na post-MVP.
- **v1.2** (2026-05-08): Internacjonalizacja (zakaz hardcoded stringów, ARB), obowiązkowy checkbox zgody RODO/DPA w add_patient_modal, usunięcie słów "kliniczne/klinicznej" z dwóch komunikatów ekranu nagrywania.
- **v1.1** (2026-05-08): Po review architektonicznym — dodano Etap 0 (Auth + FCM + Firestore foundation), rozszerzono ekran transkrypcji (sekcja B), zaadresowano stan FAILED, screenshot blocking, cache offline, fallback poll po 60s, limit nagrania 130 min.
- **v1.0** (2026-05-07): Pierwsza wersja UI MVP plan-u.

---

## 📋 Spis treści

1. [Definition of Done](#definition-of-done)
2. [Decyzje produktowe + architektoniczne](#decyzje)
3. [Etap 0 — Auth + FCM + Firestore foundation](#etap-0)
4. [Etap 1 — Bezpieczeństwo audio + szyfrowanie](#etap-1)
5. [Etap 2 — Ekran konfiguracji początkowej](#etap-2)
6. [Etap 3 — Nagrywanie i logika czasu](#etap-3)
7. [Etap 4 — Stepper postępu + Kaskada Sukcesu](#etap-4)
8. [Etap 5a — Ekran transkrypcji](#etap-5a)
9. [Etap 5b — Ekran raportu (7 sekcji)](#etap-5b)
10. [Etap 5c — Hamburger menu + Legal + Hard Delete](#etap-5c)
11. [Cross-cutting concerns](#cross-cutting)
12. [Architektura, komponenty, state management](#architektura)
13. [UX writing — pełny katalog tekstów](#ux-writing)

---

<a id="definition-of-done"></a>

## Definition of Done

Aplikacja gotowa do beta-testów, gdy **wszystkie** poniższe są prawdziwe:

### Funkcjonalne

- [ ] Terapeuta loguje się przez Firebase Auth, profil zapisuje się przez `identity-svc.RegisterUser`, FCM token rejestruje się przez `notification-svc.RegisterFCMToken`.
- [ ] Po zakończeniu nagrania (do 130 min) audio uploaduje się do GCS, pipeline backend wykonuje STT + LLM, terapeuta dostaje FCM push i widzi raport w aplikacji.
- [ ] Stepper na ekranie sesji aktualizuje się live z Firestore (`session_states/{sessionId}`); przy ciszy listenera > 60s fallback do `clinical-svc.GetSessionDetails`.
- [ ] Stan `FAILED` ma własny komunikat (bez Kaskady Sukcesu), z przyciskiem "Skontaktuj się z pomocą".
- [ ] Transkrypcja działa: chronologiczna oś czasu, filtr per mówca, search, time-synced playback z audio, eksport do PDF.
- [ ] Raport pokazuje 7 sekcji w akordionie (mobile) / tabach (tablet).
- [ ] Wylogowanie kasuje FCM token przez `notification-svc.RemoveFCMToken`; kolejne pushe nie idą na to urządzenie.

### Niefunkcjonalne

- [ ] **P1 (Zero Data Loss)**: Audio jest szyfrowane (AES-256, klucz per-user) PRZED zapisem na dysk. Crash/kill apki nie traci sesji — encrypted chunks + stan `PENDING_UPLOAD` w Hive odzyskują się przy ponownym otwarciu.
- [ ] **P3 (EU residency)**: Firestore region `europe-central2`, audio bucket `europe-central2`. Klient nie pisze niczego do regionów spoza UE.
- [ ] **P4 (Flutter read-only on AI reports)**: Raport jest tylko do odczytu; brak inline edit, brak local-only diff vs backend.
- [ ] **PHI on screen**: ekrany transkryptu, raportu i danych pacjenta mają `FLAG_SECURE` (Android) + iOS screenshot detection. Privacy overlay przy backgrounding apki.
- [ ] UX writing zgodny z `B_09_trauma_informed_writing.md`: kropki na końcu nagłówków, zero toxic positivity, zero wykrzykników wymuszających entuzjazm.
- [ ] **i18n (D7)**: zero hardcoded stringów w widgetach UI; wszystkie teksty z `app_pl.arb`; `grep -rn "Text('[A-Za-zżźćń]" lib/` zwraca pusty wynik (poza testami).
- [ ] **Zgoda RODO/DPA (D8 + D9)**: `add_patient_modal` ma checkbox; przycisk zapisu disabled bez zgody; `LocalConsentService` zapisuje rekord do Hive; nagrywanie zablokowane gdy `consentService.hasConsent()` zwróci `false`. Backend persistence post-MVP — w MVP audit jest na device.
- [ ] **Codec audio (D10)**: `record` package zapisuje OGG-OPUS @ 64 kbps mono natywnie. `ffmpeg_kit_flutter` NIE jest w `pubspec.yaml`. E2E test z fixturą `.ogg` przechodzi z kryteriami: ±2 segmentów vs FLAC, ConfidenceAvg > 0.85, SpeakerCount=2, brak segmentów `text=""`.

### Operacyjne

- [ ] Wszystkie teksty komunikatów odpowiadają DOKŁADNIE definicjom z sekcji [UX Writing](#ux-writing).
- [ ] CI Flutter passing: lint + widget tests + unit tests.
- [ ] Pliki PDF (Regulamin, RODO) ładują się z `assets/legal/` (offline).
- [ ] Hard Delete ("USUWAM") wymaga literalnie tego słowa, case-sensitive.

---

<a id="decyzje"></a>

## Decyzje produktowe + architektoniczne

Decyzje podjęte w trakcie review (2026-05-08):

| # | Decyzja | Uzasadnienie |
|---|---|---|
| D1 | **Klucz szyfrujący audio: per-user** | Prostsza rotacja (zmiana hasła = nowy klucz dla nowych nagrań; stare chunki dekryptowalne starym kluczem trzymanym w `flutter_secure_storage` keychain z metadanymi `key_version`) |
| D2 | **Eksport transkryptu: MVP** | Terapeuci pytali o to w research. PDF z disclaimerem PHI przed exportem |
| D3 | **Sekcji raportu: 7 (nie 9)** | Zmieszczone w protokole `clinical.v1.Report.content` jako structured JSON; mapping w sekcji [Etap 5b](#etap-5b) |
| D4 | **Fallback poll do clinical-svc po 60s ciszy w listenerze** | Zgodne z `08_FAZA_3_NOTIFICATIONS.md` ADR-IMPL-009 (Firestore best-effort); 60s daje cushion na cold start funkcji notification-worker |
| D5 | **Hard cap nagrania: 130 min** | iOS technicznie nie limituje (UIBackgroundModes: audio jest skonfigurowane), ale 130 min daje 20 min marginesu na realne sesje 90-min + interruption recovery (rozmowa, kalendarzowy alert). Backend przyjmie do 300 MB pliku — to nie limit |
| D6 | **Brak dark mode w MVP** | Dodanie post-MVP po feedback od pierwszych beta-testerów |
| D7 | **i18n od dnia 1 (zakaz hardcoded stringów)** | Apka start-uje jako PL-only, ale architektura tekstów (ARB + `flutter_localizations`/`intl`) jest wdrożona od początku. Dodanie EN/innego języka post-MVP będzie zmianą plików, nie kodu UI |
| D8 | **Obowiązkowy checkbox zgody pacjenta (RODO/DPA) przed nagraniem** | Wymóg prawny — bez wyraźnej, udokumentowanej zgody pacjenta nie wolno przetwarzać nagrań. Walidacja blokuje przejście do nagrywania. Tekst zgody odsyła do `assets/legal/DPA Superwizor AI.pdf` |
| D9 | **MVP bez modyfikacji backendu — stub `ConsentService`** | Backend change (migracja `consent_given_at` + proto extension + serwerowa walidacja) odkładamy na post-MVP. W MVP `ConsentService.recordConsent()` zwraca `OK`, zapisuje audit log lokalnie w Hive (`box: 'consent_audit'`), ale nie wysyła do backendu. Interfejs jest gotowy na podmianę implementacji jednym DI swap-em |
| D10 | **Codec audio: OGG-OPUS @ 64 kbps mono przez `record` package** | Chirp 3 oficjalnie wspiera tylko {FLAC, WAV-LINEAR16, OGG-OPUS} — M4A/AAC daje silent failures (`stt-worker/main.go:358`). Opus jest hardware-accelerated na iOS (AudioToolbox 11+) i Android (MediaCodec API 21+), 5-10x mniejszy upload niż FLAC (60 min ≈ 28 MB), trenowany przez Google na masie Opus-encoded data (Meet/WhatsApp/Discord). `ffmpeg_kit_flutter` znika z deps (-15 MB SDK + cała gałąź bugów ffmpeg na różnych OS). Plan B: bumpnij na 96 kbps; plan C: FLAC nadal przez `record` (też wspierany natywnie) |

### Wzorce z dokumentacji backendu (NIE łamać)

- **`speaker_label_mapping` ma klucze STRING** (`"1"`, nie `1`). Caught in E2E test `1778244356`.
- **Etykiety mówców są neutralne** ("Osoba 1/2"), NIE "Terapeuta/Pacjent". LLM zgaduje role w 90-95% przypadków, ale przypisanie błędu klinicznie szkodliwe.
- **Reports.speaker_role_inference NIE jest w proto** — to backend-internal artifact używany do populacji `transcript_segments.speaker_label`. Flutter konsumuje już zlabellowane segmenty.
- **FCM payload nie zawiera PHI** (ADR-IMPL-013) — tylko `session_id` + `notification_type`. Pełny raport pociągany dopiero po kliknięciu w push.

---

<a id="etap-0"></a>

## Etap 0 — Auth + FCM + Firestore foundation

> **Cel:** Postawić fundamenty bez których kolejne etapy nie da się sensownie testować. Login, FCM token lifecycle, Firestore listener — wszystko PRZED ekranami produktowymi.

### Task 0.1 — Firebase Auth login/register

**Plik:** `lib/screens/auth/login_screen.dart` + `register_screen.dart`

- Login: email + password, `FirebaseAuth.instance.signInWithEmailAndPassword()`
- Register: tworzy Firebase user → wywołuje `identityService.registerUser(firebaseUid, displayName, role='THERAPIST')`
- Po sukcesie loginu/registracji → wywołanie `_registerFCMToken()` (Task 0.2)
- Persist auth state przez Firebase Auth (automatyczny refresh tokenów)

**Forgot password**: `FirebaseAuth.instance.sendPasswordResetEmail()`. EuphirePopup z komunikatem: "Wysłaliśmy link do zmiany hasła na Twój e-mail."

### Task 0.2 — FCM token lifecycle

**Plik:** `lib/services/fcm_token_service.dart`

```dart
class FcmTokenService {
  final NotificationServiceClient _notificationClient;

  Future<void> register() async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) return; // user może odmówić push permissions

    await _notificationClient.registerFCMToken(RegisterFCMTokenRequest(
      token: token,
      platform: _detectPlatform(),
      appVersion: (await PackageInfo.fromPlatform()).version,
      deviceModel: await _deviceModel(),
      locale: 'pl-PL',
    ));
  }

  void watchTokenRefresh() {
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      // FCM rotation ~co 30 dni; backend ma idempotent UPSERT
      await _notificationClient.registerFCMToken(...);
    });
  }

  Future<void> unregister() async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      await _notificationClient.removeFCMToken(RemoveFCMTokenRequest(token: token));
    }
    await FirebaseMessaging.instance.deleteToken();
  }
}
```

**Permission request**: `FirebaseMessaging.instance.requestPermission()` PO udanym loginie (lepszy timing niż na splash — user już ufa apce).

### Task 0.3 — Background notification handler

**Plik:** `lib/main.dart` (top-level handler) + `lib/services/notification_handler.dart`

```dart
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage msg) async {
  // Background isolate — minimal work; just log + ensure delivery
}

void main() {
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  FirebaseMessaging.onMessageOpenedApp.listen((msg) {
    if (msg.data['notification_type'] == 'report_ready') {
      final sessionId = msg.data['session_id'];
      _navigatorKey.currentState?.pushNamed('/session/$sessionId');
    }
  });

  // Foreground handler: show in-app toast
  FirebaseMessaging.onMessage.listen((msg) {
    // EuphireToast(msg.notification?.title, msg.notification?.body)
  });

  runApp(MyApp());
}
```

### Task 0.4 — Firestore listener helper

**Plik:** `lib/services/session_state_listener.dart`

```dart
class SessionStateListener {
  Stream<SessionState> watch(String sessionId) {
    return FirebaseFirestore.instance
        .doc('session_states/$sessionId')
        .snapshots()
        .map((doc) => SessionState.fromFirestore(doc));
  }

  Stream<List<InboxNotification>> inboxFor(String firebaseUid) {
    return FirebaseFirestore.instance
        .collection('user_notifications/$firebaseUid/inbox')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs.map(InboxNotification.fromDoc).toList());
  }
}
```

### Task 0.5 — gRPC client setup

**Plik:** `lib/services/grpc_clients.dart`

- Use `grpc` Dart package
- Per-RPC authorization metadata: `'authorization': 'Bearer ${await firebaseUser.getIdToken()}'`
- Cloud Run URLs hardcoded per env (staging: `https://notification-svc-…run.app`)
- Generate Dart proto stubs: `protoc --dart_out=grpc:lib/gen proto/notification/v1/*.proto`

### Etap 0 — Smoke test

```bash
# 1. Zaloguj się w apce; check że FCM token poszedł do PG
gcloud sql connect superwizor-db-bc4c27de --user=superwizor_app --quiet
psql> SELECT user_id, platform, app_version FROM fcm_tokens WHERE invalidated_at IS NULL;

# 2. Wyślij ręczny push
gcloud pubsub topics publish report.generated \
  --message='{"session_id":"<jakiś istniejący>","report_id":"<jakiś istniejący>"}'

# 3. Apka powinna dostać push w foreground i background; tap → ekran sesji
```

---

<a id="etap-1"></a>

## Etap 1 — Bezpieczeństwo audio + szyfrowanie

### Task 1.1 — Pakiety

```yaml
dependencies:
  flutter_secure_storage: ^9.0.0
  encrypt: ^5.0.3
  path_provider: ^2.1.2
  workmanager: ^0.5.2
  audioplayers: ^6.1.0
  lottie: ^3.1.0
  record: ^5.1.0           # NATIVE recording w Opus/FLAC/WAV — zastępuje ffmpeg_kit
  hive: ^2.2.3
  hive_flutter: ^1.1.0
  shimmer: ^3.0.0
```

> **Zmiana v1.4 (D10)**: Usunięto `ffmpeg_kit_flutter` (~15 MB SDK + bugy iOS/Android). `record` package zapisuje natywnie w Opus/FLAC/WAV bez post-processingu. Hardware encoder na iOS (AudioToolbox) i Android (MediaCodec) → praktycznie zero overhead w czasie nagrywania.

### Task 1.1.1 — Konfiguracja codec-a (D10)

**Wybór codec-a — primary**: OGG-OPUS @ 64 kbps mono.

```dart
// lib/services/recording_service.dart
import 'package:record/record.dart';

class RecordingService {
  final _recorder = AudioRecorder();

  Future<void> startSession(String sessionId) async {
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/sessions/$sessionId/raw.ogg';
    await Directory(p.dirname(path)).create(recursive: true);

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.opus,    // OGG container, hardware-accelerated
        bitRate: 64000,                // 64 kbps mono — clinical-grade voice
        sampleRate: 48000,             // matches Chirp 3 native rate
        numChannels: 1,                // mono
        autoGain: true,                // poprawia spokojnych pacjentów
        echoCancel: false,             // OFF — nie chcemy zniekształcać voice content
        noiseSuppress: false,          // OFF — to samo
      ),
      path: path,
    );
  }

  Future<String?> stop() => _recorder.stop();
  Future<void> pause() => _recorder.pause();
  Future<void> resume() => _recorder.resume();
}
```

**Plan B**: jeśli E2E walidacja (Task 1.4) wykaże regres jakości STT > 5% WER vs FLAC → bumpnij `bitRate: 96000`. 60 min @ 96 kbps mono = ~43 MB; nadal 6x mniej niż FLAC.

**Plan C**: jeśli i 96 kbps Opus regresuje → fallback do FLAC z tego samego `record` package: `encoder: AudioEncoder.flac`. Nadal bez `ffmpeg_kit_flutter` w deps.

### Task 1.2 — `SecureAudioStorageService` (per-user key)

**Plik:** `lib/services/secure_audio_storage_service.dart`

**Strategia klucza** (D1):
- Klucz AES-256 generowany jednorazowo przy pierwszym loginie tego usera na tym device → zapisywany w `flutter_secure_storage` (iOS Keychain, Android Keystore-backed).
- `key_version` (int) zapisany razem z kluczem; każdy plik chunka ma `key_version` w metadanych pliku.
- **Rotacja przy zmianie hasła**: nowy klucz `key_version + 1`, zapisz oba; nowe nagrania używają nowego, stare chunki dekryptowalne starym dopóki nie zostaną wgrane.
- Po pomyślnym wgraniu wszystkich chunków danej sesji → wyczyść klucze starszych wersji.

**Strategia chunkingu (zmiana v1.4)**:

`record` package zapisuje natywnie do **jednego pliku OGG** (nie do chunków PCM jak by robiło ffmpeg-pipeline). To znaczy że szyfrowanie odbywa się **post-recording**, nie in-flight per chunk audio frame. Sekwencja:

1. **W trakcie nagrywania**: `record` zapisuje surowy `.ogg` do `getApplicationDocumentsDirectory()/sessions/$sessionId/raw.ogg`. Ten plik jest **chroniony przez iOS Data Protection** (Apple's hardware AES-256 przy zablokowanym device) i Android `EncryptedFile` (jeśli chcemy dodatkową warstwę). To NIE jest naszą warstwą szyfrowania, ale jest pierwszą linią obrony przed thief-with-locked-device.

2. **Po `recorder.stop()`**: `EncryptionPipeline.encryptFile(rawOgg)` — czyta plik OGG strumieniowo w **chunkach 1 MB**, każdy chunk szyfruje AES-256-GCM osobnym IV, zapisuje do `chunk_NNNNN.enc`. Po skończonej operacji **kasuje raw.ogg** (z secure delete — overwrite zerami przed unlink).

3. **Workmanager** (Task 1.3) odczytuje encrypted chunks, dekryptuje strumieniowo, łączy w jeden bufor (lub strumień), wysyła PUT na signed URL.

4. **Po sukcesie uploadu**: kasuje encrypted chunks z dysku.

**Trade-off wyjaśnione**: chwilowo (między `recorder.stop()` a `encryptFile()` complete) raw OGG istnieje na dysku **niezaszyfrowany przez naszą warstwę**, ale nadal pod iOS Data Protection. Window czasowy: ~5-10s dla sesji 60-min. Akceptowalne ryzyko vs alternatywa (custom OGG encoder w Dart-cie który szyfruje frame-by-frame — out of MVP scope).

```dart
class SecureAudioStorageService {
  final FlutterSecureStorage _storage;

  /// Encrypts an existing recording file in 1MB chunks.
  /// Source file is securely deleted (zero-overwritten) after successful encryption.
  Future<List<EncryptedChunk>> encryptRecording(String rawPath, String sessionId) async {
    final key = await _currentKey();
    final keyVersion = await _currentKeyVersion();
    final raw = File(rawPath);
    final chunks = <EncryptedChunk>[];

    final input = raw.openRead();
    int seq = 0;
    final buffer = BytesBuilder();

    await for (final piece in input) {
      buffer.add(piece);
      while (buffer.length >= _chunkSize) {
        final taken = buffer.takeBytes().sublist(0, _chunkSize);
        chunks.add(await _encryptOneChunk(seq++, taken, key, keyVersion, sessionId));
      }
    }
    if (buffer.length > 0) {
      chunks.add(await _encryptOneChunk(seq++, buffer.takeBytes(), key, keyVersion, sessionId));
    }

    await _secureDelete(raw);  // overwrite z zerami + unlink
    return chunks;
  }

  Future<EncryptedChunk> _encryptOneChunk(
    int seq, List<int> bytes, Key key, int keyVersion, String sessionId,
  ) async {
    final iv = IV.fromSecureRandom(12);  // GCM standard 96-bit IV
    final encrypted = Encrypter(AES(key, mode: AESMode.gcm)).encryptBytes(bytes, iv: iv);

    final dir = await getApplicationDocumentsDirectory();
    final f = File('${dir.path}/sessions/$sessionId/chunk_${seq.toString().padLeft(5, "0")}.enc');
    await f.parent.create(recursive: true);
    await f.writeAsBytes([
      ..._headerBytes(keyVersion, iv.bytes),  // 1B version + 12B IV
      ...encrypted.bytes,                      // ciphertext + 16B GCM auth tag
    ]);
    return EncryptedChunk(seq: seq, path: f.path, sizeBytes: await f.length());
  }

  static const _chunkSize = 1024 * 1024;  // 1 MB
}
```

### Task 1.3 — Workmanager dla background uploadu

**Plik:** `lib/services/upload_worker.dart`

- Po `recorder.stop()` + `encryptRecording()` (Task 1.2) → enqueue `Workmanager.registerOneOffTask("upload-${sessionId}", ...)` z constraint `NetworkType.connected`.
- Worker:
  1. Dekryptuje encrypted chunks strumieniowo (1 MB at a time)
  2. Sklada w buforze albo strumień bezpośrednio do PUT body
  3. Wysyła PUT na signed URL z `ingestion-svc`
  4. **Brak ffmpeg-a** — plik OGG jest już w finalnym formacie z `record` package; merge to po prostu konkatenacja zdekryptowanych chunków (które razem składają się na oryginalny ciągły plik OGG)
- iOS: workmanager używa BGAppRefreshTask — limity ~30 sekund. Plik OGG (28-43 MB dla 60 min) zwykle mieści się; jeśli nie → chunked PUT z resume support (signed URL przez ingestion-svc to wspiera).
- Po sukcesie wszystkich chunków → wywołanie `ingestionService.completeAudioUpload()` → kasujemy enkryptowane chunki z dysku → stan w Hive: `UPLOADED`.

### Task 1.4 — Testy + walidacja STT (D10)

#### Unit testy

```dart
test('encrypt then decrypt yields original bytes', () async { ... });
test('chunk file has 13-byte header (1B version + 12B GCM IV)', () async { ... });
test('crashed before encryptRecording() finishes → raw.ogg still exists, no chunks', () async { ... });
test('successful encryption → raw.ogg securely deleted (zero-overwrite + unlink)', () async { ... });
test('rotated key_version: old chunks decryptable until purged', () async { ... });
test('record package emits OGG file with Opus codec', () async {
  // Use ffprobe (host) to verify .ogg file z record package ma codec=opus
});
```

#### E2E walidacja STT — przed merge OPUS do main

Backend test fixture jest dziś w FLAC (`tests/e2e/testdata/sample.flac`). Tworzymy paralelną fixturę OPUS z identyczną treścią, aby porównać jakość STT:

```bash
# 1. Generate OPUS fixture from existing FLAC
ffmpeg -i superwizor-backend/tests/e2e/testdata/sample.flac \
  -c:a libopus -b:a 64k -ac 1 -ar 48000 \
  superwizor-backend/tests/e2e/testdata/sample.ogg

# 2. Run E2E with OPUS — twin run
cd superwizor-backend/tests
AUDIO_FILE=e2e/testdata/sample.ogg \
  go test -tags=e2e -timeout=15m -v ./e2e/... -run TestFullSession_HappyPath \
  > /tmp/e2e_opus.log

# 3. Run E2E with FLAC (baseline)
AUDIO_FILE=e2e/testdata/sample.flac \
  go test -tags=e2e -timeout=15m -v ./e2e/... -run TestFullSession_HappyPath \
  > /tmp/e2e_flac.log

# 4. Compare:
diff <(grep "transcript segments" /tmp/e2e_opus.log) \
     <(grep "transcript segments" /tmp/e2e_flac.log)
```

**Kryteria akceptacji** (wszystkie muszą być spełnione, inaczej fallback Plan B → 96 kbps):

| Kryterium | Próg |
|---|---|
| Liczba transcript_segments | ±2 vs FLAC baseline |
| `ConfidenceAvg` per chunk | > 0.85 |
| `SpeakerCount` | dokładnie 2 (sesja FLAC daje 2) |
| Żaden segment z `text=""` | 0 pustych |
| WER (jeśli mamy known-truth dla sample.flac) | < 5% różnicy vs FLAC |

#### Hardware encoder verification (bonus przed beta)

```dart
test('iOS Opus encoder uses hardware path on minimum supported device', () async {
  // Run on physical iPhone 8 (A11 chip, minimum supported per app config).
  // Measure encoder CPU usage during 5-min recording session.
  // Expectation: < 15% peak CPU (hardware path); > 40% would indicate software fallback.
}, skip: 'Manual benchmark; run in CI on macOS runner with iOS device target');
```

---

<a id="etap-2"></a>

## Etap 2 — Ekran konfiguracji początkowej

### Task 2.1 — `TherapistSetupScreen`

**Plik:** `lib/screens/setup/therapist_setup_screen.dart`

- Ikona EUPHIRE u góry (lub Lottie animation z miękką falą — TBD przez design team)
- Pola formularza:
  - Imię + nazwisko (lub pseudonim)
  - **Główny nurt** (dropdown 8 opcji, lista poniżej)
  - **Język sesji** — domyślnie PL; wybór EN → EuphirePopup (zobacz Task 2.3)
- `EuphireButton` "Kontynuuj" → `identityService.updateUserProfile(...)` → home

### Lista 8 nurtów

```dart
const modalities = [
  ('integrative',     'Uniwersalny / Integracyjny'),
  ('cbt',             'Poznawczo-Behawioralny (CBT)'),
  ('psychodynamic',   'Psychodynamiczny'),
  ('positive',        'Pozytywny (PPT)'),
  ('schema',          'Terapia Schematów (ST)'),
  ('systemic',        'Systemowa (dla par i rodzin)'),
  ('eft',             'Skoncentrowana na Emocjach (EFT)'),
  ('coaching',        'Coaching (ICF/GROW)'),
];
```

### Task 2.2 — Modal "Dodaj pacjenta"

**Plik:** `lib/widgets/add_patient_modal.dart` (jako BottomSheet)

**Pola formularza:**

1. Imię / pseudonim pacjenta (`EuphireTextField`)
2. Nurt — domyślnie **dziedziczony z profilu terapeuty** (dropdown z 8 opcji, pre-selected)
3. Język sesji (PL na razie; EN przełącza przez EuphirePopup z 2.3)
4. **Checkbox zgody RODO/DPA — OBOWIĄZKOWY** (D8)

**Checkbox zgody (kluczowy element):**

```dart
Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
  Checkbox(
    value: _consentGiven,
    onChanged: (v) => setState(() => _consentGiven = v ?? false),
  ),
  Expanded(
    child: GestureDetector(
      onTap: () => setState(() => _consentGiven = !_consentGiven),
      child: RichText(
        text: TextSpan(
          style: theme.textTheme.bodyMedium,
          children: [
            TextSpan(text: AppLocalizations.of(context).addPatientConsentLabel),
            TextSpan(text: ' '),
            TextSpan(
              text: AppLocalizations.of(context).addPatientConsentLinkLabel, // "Zobacz dokument DPA."
              style: TextStyle(decoration: TextDecoration.underline, color: theme.colorScheme.primary),
              recognizer: TapGestureRecognizer()..onTap = () =>
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => LegalPdfScreen(assetPath: 'assets/legal/DPA Superwizor AI.pdf'),
                )),
            ),
          ],
        ),
      ),
    ),
  ),
]),
```

**Tekst checkboxa** (z ARB, nigdy hardcoded):

> Oświadczam, że pacjent wyraził zgodę na nagrywanie i przetwarzanie danych zgodnie z Polityką Prywatności i DPA Superwizor AI.

Po prawej linkowanym tekstem: "Zobacz dokument DPA." → otwiera `assets/legal/DPA Superwizor AI.pdf` w `LegalPdfScreen` (Task 5c.1).

**Walidacja (MVP — D9, bez modyfikacji backendu):**

```dart
EuphireButton(
  label: AppLocalizations.of(context).addPatientSavePrimary, // "Zapisz pacjenta"
  enabled: _formValid && _consentGiven,
  onPressed: _onSavePressed,
)

Future<void> _onSavePressed() async {
  if (!_consentGiven) {
    showEuphireBottomSheet(context, _NoConsentBottomSheet());
    return;
  }

  // Backend (stan obecny) NIE przyjmuje consent_given_at — wołamy bez niego.
  final patient = await clinicalService.createPatientFile(
    name: _name,
    modalityCode: _selectedModality,
    languageCode: 'pl',
  );

  // Lokalny audit log — stub do czasu wdrożenia backend change-u.
  // Zapisany na device w Hive; QA / regulator może zweryfikować że
  // checkbox został zaznaczony przed utworzeniem pacjenta.
  await consentService.recordConsent(
    patientFileId: patient.id,
    documentVersion: 'dpa-v1-2026-04',
  );

  Navigator.pop(context, patient);
}
```

**`_NoConsentBottomSheet`** (UX writing w sekcji [UX Writing](#ux-writing)) — wywoływany gdy user próbuje przejść dalej bez zaznaczenia checkboxa (defensywnie — przycisk powinien być disabled, ale jeśli ktoś kliknie skróconą ścieżką "Zacznij sesję" z dashboardu na pacjenta bez zgody, ten sam BottomSheet się pokazuje).

#### `ConsentService` — stub na MVP, pełny serwis post-MVP

**Plik:** `lib/services/consent_service.dart`

```dart
/// Cienki interfejs zgodnie z D9 — w MVP zwraca OK i loguje do Hive.
/// Po wdrożeniu backend change-u (migracja 000010 + proto extension):
/// 1. Zaimplementuj BackendConsentService który woła
///    clinicalService.createPatientFile(... consent_given_at: ...)
///    albo dedykowane RPC clinicalService.RecordConsent.
/// 2. Podmień binding w DI (Riverpod / get_it / inny container).
/// 3. Optional migration: jednorazowy Hive → backend sync zalegających
///    consent log entries. Plan migracji: osobny ticket post-Etap 2.
abstract class ConsentService {
  /// Zapisuje że zgoda została udzielona w danym momencie.
  /// Throws [ConsentRecordingFailed] gdy nie udało się zapisać —
  /// caller musi zdecydować czy przerwać tworzenie pacjenta
  /// (UI: pokaż EuphireBottomSheet z "Spróbuj ponownie").
  Future<void> recordConsent({
    required String patientFileId,
    required String documentVersion,
  });

  /// Czy mamy dowód zgody dla tego pacjenta? Używane przed startem
  /// nagrywania jako druga linia obrony (poza checkboxem w modal-u).
  Future<bool> hasConsent({required String patientFileId});

  /// Lista wszystkich zarejestrowanych zgód — do panelu admin / debug.
  Future<List<ConsentRecord>> listAll();
}

class ConsentRecord {
  final String patientFileId;
  final String documentVersion;
  final DateTime givenAt;
  final String givenByFirebaseUid; // who clicked the checkbox

  const ConsentRecord({
    required this.patientFileId,
    required this.documentVersion,
    required this.givenAt,
    required this.givenByFirebaseUid,
  });
}

class ConsentRecordingFailed implements Exception {
  final String reason;
  ConsentRecordingFailed(this.reason);
}
```

**MVP implementacja — local-only:**

```dart
/// Stub na MVP: zapisuje audit do Hive box 'consent_audit', zwraca OK.
/// Backend NIE jest wołany. Po wdrożeniu backend change-u — patrz
/// BackendConsentService poniżej (do zaimplementowania, na razie TODO).
class LocalConsentService implements ConsentService {
  static const _boxName = 'consent_audit';
  final FirebaseAuth _auth;

  LocalConsentService(this._auth);

  @override
  Future<void> recordConsent({
    required String patientFileId,
    required String documentVersion,
  }) async {
    final box = await Hive.openBox<Map>(_boxName);
    final user = _auth.currentUser;
    if (user == null) {
      throw ConsentRecordingFailed('user not authenticated');
    }
    await box.put(patientFileId, {
      'patient_file_id': patientFileId,
      'document_version': documentVersion,
      'given_at': DateTime.now().toUtc().toIso8601String(),
      'given_by_firebase_uid': user.uid,
    });
  }

  @override
  Future<bool> hasConsent({required String patientFileId}) async {
    final box = await Hive.openBox<Map>(_boxName);
    return box.containsKey(patientFileId);
  }

  @override
  Future<List<ConsentRecord>> listAll() async {
    final box = await Hive.openBox<Map>(_boxName);
    return box.values.map((m) => ConsentRecord(
      patientFileId: m['patient_file_id'] as String,
      documentVersion: m['document_version'] as String,
      givenAt: DateTime.parse(m['given_at'] as String),
      givenByFirebaseUid: m['given_by_firebase_uid'] as String,
    )).toList();
  }
}
```

**DI binding (Riverpod):**

```dart
final consentServiceProvider = Provider<ConsentService>((ref) {
  return LocalConsentService(FirebaseAuth.instance);
  // Post-MVP: return BackendConsentService(ref.watch(clinicalClientProvider));
});
```

**Bramka również w innych miejscach (działa offline-first):**

- Przed startem nagrywania na pacjencie: `await consentService.hasConsent(patientFileId: ...)` → jeśli `false`, pokaż BottomSheet "Brak zgody". To jest second-line-of-defense — pacjenci utworzeni przez MVP zawsze mają wpis w Hive (bo `_onSavePressed` zapisuje), ale legacy / zaimportowani / zsynchronizowani z innego device będą wymagać uzupełnienia zgody w przyszłości.

- **Multi-device gotcha (do zanotowania, NIE blocker MVP)**: Hive jest lokalne. Jeśli terapeuta zaloguje się na drugim device, audit log nie jest zsynchronizowany. Konsekwencja: na drugim device `hasConsent()` zwróci `false` mimo że pacjent ma zgodę → user będzie musiał ponownie zaznaczyć checkbox. To jest do zaadresowania backend-side (centralny `consent_given_at` w PG); na razie godzimy się z tym ograniczeniem MVP. Komunikat dla support: "Jeśli pacjent jest na innym Twoim urządzeniu — zaznacz zgodę ponownie."

#### Plan migracji do backend persistence (post-MVP, do osobnego ticketu)

Gdy backend wystawi `consent_given_at`:

1. Dodaj `BackendConsentService` woła `clinicalService.createPatientFile(... consentGivenAt:)` lub dedykowane `clinicalService.RecordConsent` RPC.
2. Jednorazowy migration job w aplikacji przy starcie: `LocalConsentService.listAll()` → dla każdego rekordu wywołaj backend RPC; po sukcesie usuń z Hive.
3. Po skończonej migracji wszystkich klientów (telemetria potwierdza Hive box pusty na większości device-ów) — usunąć `LocalConsentService`, zostawić tylko `BackendConsentService`.

### Task 2.3 — EuphirePopup dla EN→PL

UX writing zdefiniowany w sekcji [UX Writing](#ux-writing).

### Task 2.4 — Rejestracja FCM tokena (z Etap 0)

Przy zapisie profilu po raz pierwszy: `await fcmTokenService.register()`. Idempotent po stronie backendu — wielokrotne rejestracje tego samego tokena to no-op.

### Etap 2 — Testy

- Widget test: 8 elementów w dropdownie nurtów.
- Widget test: wybór EN pokazuje EuphirePopup; po Confirm język wraca na PL.

---

<a id="etap-3"></a>

## Etap 3 — Nagrywanie i logika czasu

### Task 3.1 — UI ekranu nagrywania

**Plik:** `lib/screens/recording/recording_screen.dart`

Layout (góra → dół):
1. Header: nazwa pacjenta + numer sesji
2. Waveform (live audio meter) — komponent `EuphireWaveform`
3. Licznik czasu (mm:ss, lub HH:mm:ss > 60min)
4. Przyciski sterujące: Start/Pauza/Stop
5. **Stały blok "Jak najlepiej nagrywać?"** (zobacz UX Writing)
6. Tekst stanu: "Nagrywanie w toku." / "Nagrywanie wstrzymane."

### Task 3.2 — Logika < 5 minut (blokada)

```dart
void onStopPressed() {
  if (_recordingDuration < Duration(minutes: 5)) {
    // NIE pauzuj — nagrywanie leci dalej
    showEuphireBottomSheet(context, _tooShortBottomSheet);
  } else {
    _audioRecorder.pause();
    showEuphireBottomSheet(context, _confirmEndBottomSheet);
  }
}
```

UX writing — sekcja [UX Writing](#ux-writing).

### Task 3.3 — Logika > 5 minut (wysyłka)

Pauzuj → BottomSheet z 3 opcjami: Rozpocznij analizę / Wróć do nagrywania / Usuń bezpowrotnie.

### Task 3.4 — Limit 130 min (nie 150 — D5)

```dart
const maxDuration = Duration(minutes: 130);

if (_recordingDuration >= maxDuration) {
  _audioRecorder.pause();
  _persistPendingUploadState(); // do Hive
  showEuphireBottomSheet(context, _maxDurationBottomSheet);
}
```

**Persistence** (kluczowe — apka może być zminimalizowana albo ubita):

```dart
class PendingUploadState {
  final String sessionId;
  final String patientFileId;
  final List<EncryptedChunkRef> chunks;
  final DateTime recordedAt;
  final Duration duration;
}

// Hive box: 'pending_uploads', expiry per record = 7 dni
// Po reopenie apki: jeśli istnieje pending state → pokaż ekran "Niedokończone nagranie"
```

### Task 3.5 — iOS background recording + hardware Opus

`UIBackgroundModes: audio` jest już skonfigurowane w `Info.plist` ✓. Ale:
- **AVAudioSession config**: ustaw category `playAndRecord` z opcją `mixWithOthers: false` (sesja terapii nie powinna mieszać się z YouTube/Spotify).
- **Interruptions**: nasłuchuj `AVAudioSessionInterruption` (rozmowa telefoniczna, alarm) → automatyczna pauza, po `interruption ended` → user musi ręcznie wznowić (nie auto-resume — terapeuta może chcieć przerwać).
- **Audio focus loss na Androidzie**: `AudioFocusRequest` z `gain: AUDIOFOCUS_GAIN`; przy `AUDIOFOCUS_LOSS` → pauzuj i zachowaj stan.

#### Hardware Opus encoder verification (D10)

`record` package na iOS używa AVAudioRecorder/AudioToolbox dla Opus. Hardware path jest dostępny od iOS 11+ na chipach A11 (iPhone 8) i nowszych. Sprawdź na minimum supported device:

```bash
# Po build na iPhone 8/SE2:
# 1. Uruchom 5-min nagranie sesji
# 2. Otwórz Xcode → Window → Devices and Simulators → Open Console
# 3. Filter: process="superwizor" + signal="encoder"
# 4. Sprawdź czy log zawiera "AudioToolbox: Using hardware encoder for kAudioFormatOpus"
#
# Jeśli widzisz "software encoder fallback" — sprawdź:
#   - Sample rate (musi być ≥ 8000 Hz, ≤ 48000 Hz)
#   - Channels (mono — stereo Opus na iOS bywa software)
#   - iOS version (≥ 11.0)
```

> 🔬 **TODO przed beta — full battery profile**: test 130-min nagrania na fizycznym iPhone (8/SE2/13) w tle (apka zminimalizowana). Mierzyć:
> - Czy iOS NIE ubija audio session przez 130 min (powinno przejść — `audio` BG mode jest dokładnie do tego).
> - Drain baterii w % po 130-min recording (target: < 15% na pełnej sesji = nie więcej niż video call).
> - CPU usage encoder-a — hardware path daje stale ~5% CPU, software fallback skoczyłby na 30-40%.
>
> Jeśli iOS ubija session przed 130 min albo CPU mówi software fallback → eskalacja do osobnego ticketu, ewentualne obniżenie limitu do 90 min. Realnie: z `audio` BG mode aktywnym, iOS NIE ubija sesji audio. Głównym ryzykiem out-of-memory NIE JEST już problem (record package flush-uje encoded OGG do pliku w czasie rzeczywistym; brak wielkiego buffer-a PCM w RAM).

### Etap 3 — Testy

- Mock timera, sprawdź że BottomSheet "Nagranie zbyt krótkie" pokazuje się PRZY UTRZYMANYM nagrywaniu.
- Mock timera do 130:00, sprawdź auto-pauzę i zapis do Hive.
- Test: po crash + restart apki, ekran "Niedokończone nagranie" się pokazuje.

---

<a id="etap-4"></a>

## Etap 4 — Stepper postępu + Kaskada Sukcesu

### Task 4.1 — `EuphireSessionStatusStepper`

**Plik:** `lib/widgets/euphire_session_status_stepper.dart`

Mapowanie statusów Firestore → kroki UI (zgodne z ADR-IMPL-012, Faza 3):

| Step | Aktywny gdy `session_states.status` = | Tekst |
|---|---|---|
| 1. Audio | `uploaded` lub późniejszy | „Audio bezpieczne na naszych serwerach.” |
| 2. Transkrypcja | `analyzing` lub `done` (backend SKIPS `transcribing` w Fazie 3) | „Tworzymy transkrypcję." |
| 3. Analiza | `analyzing` | „Sztuczna Inteligencja przygotowuje wnioski kliniczne." |
| 4. Gotowe | `done` | „Proces zakończony. Przygotowaliśmy Twój raport." |

**Krytyczne**: backend NIE publikuje statusu `transcribing`. Stepper automatycznie zalicza krok 2 jako ukończony gdy widzi `analyzing`.

### Task 4.2 — Listener gating

```dart
class SessionStatusViewModel {
  Timer? _fallbackTimer;

  void watchSession(String sessionId) {
    _sessionStateListener.watch(sessionId).listen((state) {
      _currentState = state;
      _resetFallbackTimer();
    });
  }

  void _resetFallbackTimer() {
    _fallbackTimer?.cancel();
    _fallbackTimer = Timer(Duration(seconds: 60), _pollClinicalSvc); // D4
  }

  Future<void> _pollClinicalSvc() async {
    // Firestore listener stalled. Może doc nie powstał (cold start) albo write failed.
    final details = await _clinicalClient.getSessionDetails(...);
    if (details.session.status == 'COMPLETED') {
      // Backend mówi done, Firestore się gubi → kontynuuj jakby było done
      _onCompleted();
    } else if (details.session.status == 'FAILED') {
      _onFailed();
    }
  }
}
```

### Task 4.3 — Stan FAILED

UX writing — sekcja [UX Writing](#ux-writing).
- Stepper: ostatni krok kolor destructive (czerwonkowy z design system), ikona "X" zamiast checka.
- BRAK Kaskady Sukcesu, BRAK auto-routing.
- CTA: "Skontaktuj się z pomocą" (mailto: `support@superwizor.ai` lub deep link do support).

### Task 4.4 — Kaskada Sukcesu (po `status=done`)

```dart
Future<void> _runSuccessCascade() async {
  await HapticFeedback.heavyImpact();
  await audioPlayer.play(AssetSource('sounds/SFX_succes.wav'));
  await _showLottie('assets/animations/success_check.json');
  await Future.delayed(Duration(seconds: 2));
  if (mounted) {
    Navigator.of(context).pushReplacementNamed('/session/$sessionId/report');
  }
}
```

### Etap 4 — Testy

- Mockuj StreamController dla Firestore: emit `uploaded → analyzing → done` → assert wszystkie 4 kroki zmieniają stan.
- Mockuj timer 60s bez nowego statusu → assert wywołanie `clinicalClient.getSessionDetails`.
- Mock `status = 'FAILED'` → assert: BottomSheet z "Nie udało się przygotować raportu" się pojawia, BRAK haptic feedback / dźwięku / nawigacji.

---

<a id="etap-5a"></a>

## Etap 5a — Ekran transkrypcji

### Architektura

**Źródło danych**: `clinical-svc.GetSessionDetails(session_id)` → `transcript.segments[]`.

**NIE używamy**: `reports.speaker_role_inference` (nie jest w gRPC, jest backend-internal).

```dart
class TranscriptScreenViewModel extends ChangeNotifier {
  final ClinicalServiceClient _clinical;
  final TranscriptCacheStore _cache;
  final AudioPlayer _player;

  AsyncValue<TranscriptData> data = AsyncValue.loading();
  String selectedSpeaker = 'all';
  String searchQuery = '';
  Duration currentPosition = Duration.zero;
  String? exportingState; // 'idle' | 'generating' | 'sharing'
}

class TranscriptData {
  final List<TranscriptSegment> segments;
  final Map<String, String> speakerLabels;
  final String audioUrl; // signed download URL z clinical-svc
  final DateTime cachedAt;
}
```

### Task 5a.1 — Cache + load

**Plik:** `lib/services/transcript_cache_store.dart`

```dart
class TranscriptCacheStore {
  final Box _hive; // box: 'transcripts'

  Future<void> save(String sessionId, TranscriptData data) async { ... }
  Future<TranscriptData?> load(String sessionId) async { ... }
  Future<void> invalidate(String sessionId) async { ... }
}
```

**Strategy**:
1. Otwórz ekran → `cache.load()` synchronicznie. Jeśli istnieje, pokaż natychmiast.
2. W tle: `clinical.getSessionDetails()`. Jeśli różni się od cache → update + `notifyListeners()`.
3. Jeśli `cache.cachedAt < now() - 1h` → odśwież z backendu (już z loaderem) zanim pokażesz.
4. Po `DeletePatientFile` lub Hard Delete → `invalidate()` wszystkich sesji z tego patient_file.

### Task 5a.2 — Layout

```
┌───────────────────────────────────────────────────┐
│ ← Sesja z 5 maja                          [⋮]    │  AppBar
│                                                   │
│ ┌─ 🎵 Audio player (sticky) ─────────────────┐   │
│ │  ▶ 00:42 ━━━━━●━━━━━━━━━━━━━━━ 40:13       │   │
│ └────────────────────────────────────────────┘   │
│                                                   │
│ [Wszyscy] [Osoba 1] [Osoba 2]                    │  Filter chips
│ 🔍 Szukaj w transkrypcji…                        │  Search
│                                                   │
│ ┌─ Segment ─────────────────────────────────┐    │
│ │ Osoba 1                  00:01 — 00:04   │    │
│ │ Cześć, jak się czujesz dzisiaj?          │    │  ← Currently playing
│ └───────────────────────────────────────────┘    │     (subtle accent border)
│                                                   │
│ ┌─ Segment ─────────────────────────────────┐    │
│ │ Osoba 2                  00:04 — 00:08   │    │
│ │ Trochę zmęczona, ale ogólnie dobrze.     │    │
│ └───────────────────────────────────────────┘    │
│ …                                                │
└───────────────────────────────────────────────────┘
```

### Task 5a.3 — Filter chips

```dart
SegmentedButton<String>(
  segments: [
    ButtonSegment(value: 'all', label: Text('Wszyscy')),
    ...data.speakerLabels.entries.map((e) =>
      ButtonSegment(value: e.key, label: Text(e.value)),
    ),
  ],
  selected: {viewModel.selectedSpeaker},
  onSelectionChanged: viewModel.setSpeaker,
);
```

**Krytyczne**: klucze są STRING (`"1"`), nie int. `data.speakerLabels[1]` zwróci `null`.

### Task 5a.4 — Search z highlight

```dart
List<TranscriptSegment> get visibleSegments {
  var result = data.segments;
  if (selectedSpeaker != 'all') {
    result = result.where((s) => s.speakerTag.toString() == selectedSpeaker).toList();
  }
  if (searchQuery.isNotEmpty) {
    final q = searchQuery.toLowerCase();
    result = result.where((s) => s.text.toLowerCase().contains(q)).toList();
  }
  return result;
}
```

Dla render-u highlightu w segmencie używaj `RichText` z `TextSpan`:

```dart
List<TextSpan> _highlightedText(String text, String query) {
  if (query.isEmpty) return [TextSpan(text: text)];
  final regex = RegExp(RegExp.escape(query), caseSensitive: false);
  final spans = <TextSpan>[];
  int lastEnd = 0;
  for (final match in regex.allMatches(text)) {
    if (match.start > lastEnd) spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
    spans.add(TextSpan(
      text: match.group(0),
      style: TextStyle(backgroundColor: theme.highlightColor, fontWeight: FontWeight.w600),
    ));
    lastEnd = match.end;
  }
  if (lastEnd < text.length) spans.add(TextSpan(text: text.substring(lastEnd)));
  return spans;
}
```

### Task 5a.5 — Time-synced playback

```dart
class _TranscriptScreenState extends State<TranscriptScreen> {
  StreamSubscription<Duration>? _posSub;

  @override
  void initState() {
    super.initState();
    _posSub = viewModel.audioPlayer.onPositionChanged.listen((pos) {
      viewModel.currentPosition = pos;
      _scrollToCurrentIfNeeded(pos);
    });
  }

  TranscriptSegment? _currentlyPlaying() {
    final ms = viewModel.currentPosition.inMilliseconds;
    return viewModel.data.segments.firstWhereOrNull(
      (s) => ms >= s.startOffsetMs && ms < s.endOffsetMs,
    );
  }

  void _onSegmentTap(TranscriptSegment segment) {
    viewModel.audioPlayer.seek(Duration(milliseconds: segment.startOffsetMs));
    viewModel.audioPlayer.resume();
  }
}
```

**Auto-scroll**: jeśli aktualnie odtwarzany segment jest poza viewport → scroll z animacją 200ms ease-out. NIE zawsze scrolluj — user może czytać dalej niż gdzie audio gra. Detect: jeśli scroll position user-driven w ostatnich 3s → nie auto-scrolluj.

### Task 5a.6 — Confidence indicator

```dart
Widget _segmentCard(TranscriptSegment s, bool isPlaying) {
  final lowConfidence = s.confidence < 0.7;
  return Card(
    decoration: BoxDecoration(
      border: isPlaying ? Border(left: BorderSide(color: accent, width: 3)) : null,
    ),
    child: Padding(
      padding: EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(s.speakerLabel.isNotEmpty ? s.speakerLabel : '—',
            style: TextStyle(fontWeight: FontWeight.w600, color: speakerColor(s.speakerTag))),
          Spacer(),
          Text(_formatTimeRange(s), style: theme.textTheme.bodySmall),
          if (lowConfidence) ...[
            SizedBox(width: 6),
            Tooltip(
              message: 'Niska pewność transkrypcji w tym fragmencie. Możesz odsłuchać aby zweryfikować.',
              child: Icon(Icons.help_outline, size: 14, color: theme.hintColor),
            ),
          ],
        ]),
        SizedBox(height: 6),
        SelectableText.rich(TextSpan(
          children: _highlightedText(s.text, viewModel.searchQuery),
          style: lowConfidence
            ? TextStyle(fontStyle: FontStyle.italic, color: theme.colorScheme.onSurface.withOpacity(0.85))
            : null,
        )),
      ]),
    ),
  );
}
```

### Task 5a.7 — Long-press context menu

```dart
GestureDetector(
  onLongPress: () => showModalBottomSheet(...),
  // Menu:
  // - Kopiuj cytat
  // - Kopiuj cytat z timestampem
  // - Odtwórz od tego miejsca
  // - Eksportuj transkrypcję (otwiera Task 5a.8)
)
```

### Task 5a.8 — Eksport do PDF (D2 — w MVP)

**Plik:** `lib/services/transcript_pdf_exporter.dart`

```dart
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

Future<File> exportToPdf(TranscriptData data, SessionMeta meta) async {
  final pdf = pw.Document();
  pdf.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    build: (ctx) => [
      pw.Header(level: 0, child: pw.Text('Transkrypcja sesji')),
      pw.Paragraph(text: 'Pacjent: ${meta.patientName}'),
      pw.Paragraph(text: 'Data sesji: ${formatDate(meta.sessionDate)}'),
      pw.Paragraph(text: 'Czas trwania: ${formatDuration(meta.duration)}'),
      pw.Divider(),
      ...data.segments.map((s) => pw.Container(
        margin: pw.EdgeInsets.only(bottom: 12),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text('${s.speakerLabel}  ·  ${formatTimeRange(s)}',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
          pw.SizedBox(height: 4),
          pw.Text(s.text, style: pw.TextStyle(fontSize: 11)),
        ]),
      )),
      pw.Footer(title: pw.Text(
        'Wygenerowane przez Superwizor AI · Dokument zawiera dane wrażliwe pacjenta',
        style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
      )),
    ],
  ));

  final dir = await getTemporaryDirectory();
  final f = File('${dir.path}/transkrypcja_${meta.sessionId}.pdf');
  await f.writeAsBytes(await pdf.save());
  return f;
}
```

**Przed udostępnieniem** — EuphireBottomSheet ostrzegawczy (UX writing w sekcji [UX Writing](#ux-writing)).

```dart
Future<void> _onExportPressed() async {
  final confirmed = await showEuphireBottomSheet(context, _phiWarningBottomSheet);
  if (!confirmed) return;
  final file = await exporter.exportToPdf(data, meta);
  await Share.shareXFiles([XFile(file.path)]);
}
```

### Task 5a.9 — Empty/loading/error states

| Stan | UI |
|---|---|
| Loading (cache miss + fetch in flight) | `ShimmerLoader` z 5 placeholder segmentami |
| Cache hit + tło refresh | Pokaż dane z cache, brak loadera, refresh subtle (np. `ProgressIndicator` 2px na górze) |
| Backend error 5xx | EuphireBottomSheet: "Nie udało się pobrać transkrypcji." z przyciskiem "Spróbuj ponownie" |
| `session.status != COMPLETED` | Stepper widoczny z postępem, transkrypcji jeszcze nie ma. Komunikat: "Transkrypcja przygotowuje się. Możesz wrócić tutaj za chwilę." |
| `session.status == 'FAILED'` | Komunikat z Etap 4.3 |

### Task 5a.10 — Accessibility + security

- `Semantics(label: '${speakerLabel}, godzina ${formatTime(start)}: ${text}')` na każdym segmencie.
- `MediaQuery.textScalerOf(context)` honored — dynamic type działa.
- `FlutterWindowManager.addFlags(FLAG_SECURE)` przy mount, `removeFlags` przy dispose.
- Obserwator iOS `UIScreenCapturedDidChange` → log audit event jeśli ktoś zaczął recordować ekran.

### Etap 5a — Testy

```dart
testWidgets('shows speaker filter chips from speakerLabelMapping', ...);
testWidgets('search filters segments and highlights matched text', ...);
testWidgets('tapping segment seeks audio player to start_offset_ms', ...);
testWidgets('current playback position highlights correct segment', ...);
testWidgets('low confidence segment shows tooltip and italic style', ...);
testWidgets('export bottom sheet must be confirmed before share opens', ...);
test('cache returns immediately, fetch updates in background', ...);
test('cache invalidated after delete patient file', ...);
```

---

<a id="etap-5b"></a>

## Etap 5b — Ekran raportu (7 sekcji)

### 7 sekcji raportu (D3)

Mapping z `clinical.v1.Report.content` (JSON-encoded `ReportPayload` z LLM):

| # | Sekcja | Pole z `ReportPayload` |
|---|---|---|
| 1 | Podsumowanie sesji | `summary_short` + `title` |
| 2 | Główne wątki sesji | `main_themes[]` (theme + salience + evidence_quotes) |
| 3 | Sojusz terapeutyczny | `therapeutic_alliance_observations` |
| 4 | Zaobserwowane interwencje | `interventions_observed[]` (type + description + patient_response) |
| 5 | Wymiary HiTOP | `hitop_dimensions[]` (code + score + confidence + evidence) |
| 6 | Ocena ryzyka | `risk_assessment` (level + concerns + recommended_actions) |
| 7 | Rekomendacje na kolejną sesję | `recommendations_for_next_session[]` |

> **Pomijamy w UI**: `speaker_role_inference` (backend-internal), `rag_summary_chunk` (PHI internal), `sentiment` (włączamy jako badge w sekcji 1, nie osobna sekcja).

### Layout

**Mobile (default)** — pionowy akordion z `EuphireCard`:

```
┌─────────────────────────────────────────┐
│ ▼  1. Podsumowanie sesji              ↑ │  ← rozwinięte
│    "Sesja koncentrowała się na…"       │
│    [Sentyment: neutral]                │
├─────────────────────────────────────────┤
│ ▶  2. Główne wątki sesji              ↓ │  ← zwinięte
├─────────────────────────────────────────┤
│ ▶  3. Sojusz terapeutyczny            ↓ │
├─────────────────────────────────────────┤
│ ▶  4. Zaobserwowane interwencje       ↓ │
├─────────────────────────────────────────┤
│ ▶  5. Wymiary HiTOP                   ↓ │
├─────────────────────────────────────────┤
│ ▶  6. Ocena ryzyka          ⚠ wysokie  │  ← badge gdy risk_level != 'low'
├─────────────────────────────────────────┤
│ ▶  7. Rekomendacje                    ↓ │
└─────────────────────────────────────────┘
```

**Tablet (>600dp)** — 2-kolumnowy grid lub tab bar (TBD design).

### Risk badge

Sekcja 6 ma specjalny treatment:

```dart
Widget _riskBadge(RiskLevel level) {
  switch (level) {
    case RiskLevel.high:
      return Badge(label: Text('⚠ Wysokie ryzyko'), backgroundColor: errorColor);
    case RiskLevel.moderate:
      return Badge(label: Text('Umiarkowane ryzyko'), backgroundColor: warningColor);
    case RiskLevel.low:
    case RiskLevel.none:
      return SizedBox.shrink(); // brak badge
  }
}
```

Akordion sekcji 6 powinien być **rozwinięty domyślnie** jeśli `risk_level == 'high'` lub `'moderate'`.

### Top bar — toggle Transcript / Report

```
┌─────────────────────────────────────────┐
│ ← Sesja z 5 maja              [⋮]     │
│                                         │
│  [ Transkrypcja ]  [ Raport ]          │  ← toggle
│                                         │
│  …                                      │
```

### Etap 5b — Testy

- Widget test: każda z 7 sekcji renderuje się poprawnie z mock danymi.
- Widget test: `risk_level == 'high'` → sekcja 6 rozwinięta + badge widoczny.
- Widget test: pusta `main_themes[]` (np. krótka sesja) → sekcja 2 pokazuje "Brak głównych wątków" zamiast pustej listy.

---

<a id="etap-5c"></a>

## Etap 5c — Hamburger menu + Legal + Hard Delete

### Drawer struktura

```
┌──────────────────────┐
│ Avatar               │
│ Imię terapeuty       │
│ email@…              │
├──────────────────────┤
│ 👤 Mój profil        │
│ 🌐 Język aplikacji   │
│ 📋 Nurty terapii     │
├──────────────────────┤
│ 📄 Regulamin         │  ← assets/legal/regulamin.pdf
│ 🔒 RODO              │  ← assets/legal/rodo.pdf
│ ℹ️  O aplikacji      │
├──────────────────────┤
│ 🚪 Wyloguj           │
│ ⚠ Usuń konto         │  ← Hard Delete
└──────────────────────┘
```

### Task 5c.1 — Legal PDFs

```dart
import 'package:pdfx/pdfx.dart';

class LegalPdfScreen extends StatelessWidget {
  final String assetPath; // 'assets/legal/regulamin.pdf'

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titleFor(assetPath))),
      body: PdfView(controller: PdfController(
        document: PdfDocument.openAsset(assetPath),
      )),
    );
  }
}
```

**Test acceptance**: polskie znaki diakrytyczne (ą, ż, ć, ł, ó, ę, ś, ń) renderują się poprawnie. ICEpdf z compresją UTF-8 czasem zjada — sprawdź na realnym device, nie tylko symulatorze.

### Task 5c.2 — Wylogowanie

```dart
Future<void> _logout() async {
  await _fcmTokenService.unregister(); // notification-svc.RemoveFCMToken
  await FirebaseAuth.instance.signOut();
  // NIE czyść Hive transcript cache — user może wrócić
  // ALE wyczyść klucze szyfrujące jeśli inny user się zaloguje
  Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
}
```

### Task 5c.3 — Hard Delete

UX writing — sekcja [UX Writing](#ux-writing).

```dart
class _HardDeleteSheetState extends State<_HardDeleteSheet> {
  final _controller = TextEditingController();
  bool _enabled = false;

  @override
  Widget build(...) {
    return EuphireBottomSheet(
      title: 'Usunięcie konta jest bezpowrotne.',
      body: Column(children: [
        Text(_explainerText),
        SizedBox(height: 24),
        Text('Aby potwierdzić, wpisz: USUWAM',
          style: TextStyle(fontWeight: FontWeight.bold)),
        EuphireTextField(
          controller: _controller,
          onChanged: (v) => setState(() => _enabled = v == 'USUWAM'), // case-sensitive
        ),
      ]),
      primaryAction: EuphireButton(
        label: 'Usuń konto bezpowrotnie',
        destructive: true,
        enabled: _enabled,
        onPressed: _executeHardDelete,
      ),
      secondaryAction: EuphireButton(
        label: 'Wróć',
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  Future<void> _executeHardDelete() async {
    // 1. Backend: soft delete user + cascade soft delete patient_files + sessions
    await _identityClient.hardDeleteUser(...);
    // 2. FCM unregister
    await _fcmTokenService.unregister();
    // 3. Local: kasuj wszystkie cache, klucze, Hive boxes
    await _localDataPurger.purgeEverything();
    // 4. Firebase Auth: delete user account
    await FirebaseAuth.instance.currentUser?.delete();
    // 5. Routing: na login screen
  }
}
```

---

<a id="cross-cutting"></a>

## Cross-cutting concerns

### Internacjonalizacja (i18n) — D7

**Reguła twarda**: ZAKAZ wpisywania jakichkolwiek widocznych dla użytkownika tekstów "na twardo" w kodzie UI. Każdy string przycisku, nagłówka, alertu, tooltipu, semantycznej etykiety musi pochodzić z pliku ARB.

**Dlaczego od dnia 1**: dodanie i18n po fakcie to refaktor każdego widgetu. Robimy to teraz, gdy apka ma kilka ekranów. Nawet jeśli MVP launchuje się PL-only, dodanie EN/UK/innych języków post-launch będzie pull requestem z plikami ARB, nie zmianą Dart-u.

**Stack:**

```yaml
dependencies:
  flutter_localizations:
    sdk: flutter
  intl: ^0.20.0

flutter:
  generate: true   # auto-genuje lib/gen/l10n/app_localizations.dart z ARB
```

**Plik:** `l10n.yaml` w roocie projektu Flutter:

```yaml
arb-dir: lib/l10n
template-arb-file: app_pl.arb
output-localization-file: app_localizations.dart
output-class: AppLocalizations
nullable-getter: false
```

**Plik:** `lib/l10n/app_pl.arb` — JEDYNE źródło prawdy dla tekstów PL:

```json
{
  "@@locale": "pl",
  "@@last_modified": "2026-05-08",

  "appTitle": "Superwizor AI",
  "@appTitle": { "description": "App display name" },

  "recordingInstructionsTitle": "Jak najlepiej nagrywać?",
  "recordingInstructionPoint1": "Nie blokuj ekranu podczas nagrywania.",

  "recordingTooShortHeader": "Nagranie jest zbyt krótkie.",
  "recordingTooShortBody": "Sesja nie może być krótsza niż 5 minut, aby sztuczna inteligencja mogła wyciągnąć wiarygodne wnioski. Nagrywanie trwa nadal.",
  "recordingTooShortPrimary": "Kontynuuj nagrywanie.",
  "recordingTooShortDestructive": "Zakończ bez zapisu.",

  "addPatientConsentLabel": "Oświadczam, że pacjent wyraził zgodę na nagrywanie i przetwarzanie danych zgodnie z Polityką Prywatności i DPA Superwizor AI.",
  "addPatientNoConsentHeader": "Brak zgody na nagrywanie.",
  "addPatientNoConsentBody": "Nie możemy rozpocząć sesji bez wyraźnej zgody pacjenta. Wymagają tego przepisy o ochronie danych.",
  "addPatientNoConsentPrimary": "Rozumiem.",

  "speakerTooltipLowConfidence": "Niska pewność transkrypcji w tym fragmencie. Możesz odsłuchać aby zweryfikować.",

  "@@x_metadata_examples": "Wszystkie pełne teksty z sekcji UX Writing trafiają tutaj. Powyższe to ilustracja klucza nazewnictwa: <screen><Element><Variant>"
}
```

**Konwencja kluczy:**

- camelCase, prefix od ekranu/feature: `recording*`, `addPatient*`, `report*`, `transcript*`, `legal*`
- Sufiks `Header` / `Body` / `Primary` / `Secondary` / `Destructive` dla części BottomSheet
- Sufiks `Title` / `Hint` / `Tooltip` dla widgetów inline
- ICU placeholders dla parametrów: `"recordingTimeRemaining": "Pozostało {minutes} minut", "@recordingTimeRemaining": { "placeholders": { "minutes": { "type": "int" } } }`

**Użycie w Dart:**

```dart
// PRZED (zakazane):
Text('Kontynuuj nagrywanie.')

// PO (wymagane):
Text(AppLocalizations.of(context).recordingTooShortPrimary)

// Z parametrami:
Text(AppLocalizations.of(context).recordingTimeRemaining(minutesLeft))
```

**Co jest dozwolone "na twardo":**

- Stałe techniczne: `'audio.uploaded'`, `'PLATFORM_IOS'`, klucze do Hive, ścieżki assetów
- Logi i komunikaty błędów wewnętrznych (nie dla użytkownika)
- Wartości enum (`'integrative'`, `'cbt'` itd. — same kody; ich display name idą do ARB)

**Locale fallback:**

- Domyślny locale aplikacji: `pl-PL`
- Jeśli system użytkownika to inny język niż wspierany — pokaż PL (zgodnie z EuphirePopup z Etap 2.3)
- `MaterialApp` config:

```dart
MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: const [Locale('pl')],
  locale: const Locale('pl'),
)
```

**Locale dla backendu**: niezależne od locale UI.

- `notification-svc.RegisterFCMToken.locale = 'pl-PL'` (BCP-47 — używane przez worker do lokalizacji push body)
- `users.ui_language = 'pl'` (krótka forma w PG)

**Linter rule**: dodaj custom analyzer rule lub `pedantic_mono`/`flutter_lints` z regułą `prefer_const_constructors_in_immutables` + custom check że `Text('...')` z literal stringiem zaznacza warning. Można też ręczna code-review checklist.

**Test acceptance**:

```bash
# Search dla literalnych stringów w widgetach (powinno być puste poza testami):
grep -rn "Text('[A-Za-zżźćń]" lib/ --include="*.dart" | grep -v "_test.dart"
```

### Screenshot blocking

```dart
// lib/main.dart, w MaterialApp.builder lub w każdym ekranie z PHI:
WidgetsBinding.instance.addObserver(
  AppLifecycleObserver(
    onInactive: () => FlutterWindowManager.addFlags(FLAG_SECURE),
    onResumed: () { /* keep FLAG_SECURE */ },
  ),
);
```

Włącz `FLAG_SECURE` na ekranach: nagrywanie, transkrypt, raport, lista pacjentów. Wyłącz na ekranach: login, setup, Drawer (z wyjątkiem profilu).

### Error logging

Sentry / Firebase Crashlytics — TBD przed beta. **Filter**: nigdy NIE loguj `text` z `TranscriptSegment`, body raportu ani imienia pacjenta. Tylko ID.

### Connectivity awareness

```dart
import 'package:connectivity_plus/connectivity_plus.dart';

// Banner u góry gdy offline:
StreamBuilder<List<ConnectivityResult>>(
  stream: Connectivity().onConnectivityChanged,
  builder: (ctx, snap) {
    final offline = snap.data?.contains(ConnectivityResult.none) ?? false;
    if (!offline) return SizedBox.shrink();
    return EuphireBanner(
      message: 'Brak połączenia. Niektóre funkcje są ograniczone.',
      severity: BannerSeverity.warning,
    );
  },
);
```

Offline-tolerable: czytanie cache (transkrypt, raport, dane pacjenta).
Offline-NIEtolerable: nagrywanie nowej sesji (zapisuje encrypted lokalnie, upload czeka na wifi).

### iOS interruption handling

```swift
// W AppDelegate.swift dodaj observer:
NotificationCenter.default.addObserver(
  self,
  selector: #selector(handleInterruption),
  name: AVAudioSession.interruptionNotification,
  object: AVAudioSession.sharedInstance()
)
```

W Dart: callback przez `MethodChannel` informuje recording controller że ma się spauzować. Po `interruptionEnded` user musi ręcznie wznowić.

---

<a id="architektura"></a>

## Architektura, komponenty, state management

### Komponenty

`lib/widgets/` (już istnieje per oryginał planu):
- `EuphireButton`
- `EuphireTextField`
- `EuphireBottomSheet`
- `EuphirePopup`
- `EuphireCard`
- `EuphireWaveform`
- `EuphireSessionStatusStepper`
- `EuphireSuccessAnimation`
- `EuphireBanner` (nowy — connectivity)
- `EuphireToast` (nowy — foreground push notifications)

### State management — propozycja

**Riverpod 2.x** dla globalnego state (auth, FCM, current user) + `ChangeNotifier` przez Riverpod dla per-screen view models. Alternatywa: BLoC, jeśli zespół już go używa.

```dart
// Provider hierarchy:
final firebaseAuthProvider = StreamProvider<User?>(...);
final fcmTokenServiceProvider = Provider((ref) => FcmTokenService(...));
final clinicalServiceProvider = Provider((ref) => ClinicalServiceClient(...));
final transcriptViewModelProvider = ChangeNotifierProvider.family<...>((ref, sessionId) => ...);
```

### Architektura warstw

```
lib/
├── main.dart
├── screens/                    # widoki (prezentacja)
│   ├── auth/
│   ├── setup/
│   ├── recording/
│   ├── session/                # transcript + report
│   └── settings/
├── widgets/                    # reusable Euphire* components
├── services/                   # cienkie wrappery wokół clientów
│   ├── fcm_token_service.dart
│   ├── secure_audio_storage_service.dart
│   ├── session_state_listener.dart
│   ├── transcript_cache_store.dart
│   ├── transcript_pdf_exporter.dart
│   ├── upload_worker.dart
│   └── grpc_clients.dart
├── view_models/                # ChangeNotifier per ekran
└── gen/                        # generated proto stubs
    └── notification/v1/...
```

---

<a id="ux-writing"></a>

## UX Writing — pełny katalog tekstów

> Reguły z `B_09_trauma_informed_writing.md`: kropki na końcu nagłówków, brak wykrzykników, brak toxic positivity, transparentne komunikaty.

### Ekran nagrywania

**Stały blok "Jak najlepiej nagrywać?"**:

> Jak najlepiej nagrywać?
> • Nie blokuj ekranu podczas nagrywania.
> • Połóż telefon na stole, między rozmówcami (50–100 cm odległości).
> • Mikrofon skieruj w stronę rozmowy, niczym go nie zasłaniaj.
> • Ciche otoczenie – zamknij okna/drzwi, wyłącz źródła hałasu.
> • Do wideokonferencji (np. Google Meet, Zoom) używaj zawsze dodatkowego urządzenia do nagrywania.

**Stan przycisków**: "Nagrywanie w toku." / "Nagrywanie wstrzymane."

### BottomSheet: < 5 minut (blokada)

- Nagłówek: **Nagranie jest zbyt krótkie.**
- Opis: Sesja nie może być krótsza niż 5 minut, aby sztuczna inteligencja mogła wyciągnąć wiarygodne wnioski. Nagrywanie trwa nadal.
- Przycisk Główny: **Kontynuuj nagrywanie.**
- Przycisk Destrukcyjny: **Zakończ bez zapisu.** (wymaga drugiego potwierdzenia)

> Zmiana v1.2: usunięto słowo "kliniczne" z opisu — komunikat skierowany do terapeuty w trakcie nagrywania ma być przyjazny, nie klinicznie dystansujący.

### BottomSheet: > 5 minut (wysyłka)

- Nagłówek: **Zakończenie i analiza sesji.**
- Opis: Plik audio jest zabezpieczony. Czy chcesz teraz zamknąć nagranie i przekazać je do bezpiecznej analizy?
- Przycisk Główny: **Rozpocznij analizę sesji.**
- Przycisk Secondary: **Wróć do nagrywania.**
- Przycisk Destrukcyjny: **Usuń to nagranie bezpowrotnie.**

> Zmiana v1.2: usunięto słowo "klinicznej" z opisu — z tych samych powodów co wyżej.

### BottomSheet: 130 minut (limit)

- Nagłówek: **Osiągnięto limit czasu nagrywania.**
- Opis: Sesja osiągnęła maksymalny dozwolony czas 130 minut i została bezpiecznie zatrzymana. Przekaż ją teraz do analizy lub usuń, jeśli było to nagrywanie testowe.
- Przycisk Główny: **Rozpocznij analizę sesji.**
- Przycisk Destrukcyjny: **Usuń to nagranie bezpowrotnie.**

### BottomSheet: niedokończone nagranie (po restart apki)

- Nagłówek: **Mamy Twoje niedokończone nagranie.**
- Opis: Sesja z dnia {data} dobiła do limitu 130 minut. Nagranie jest bezpieczne na Twoim urządzeniu i czeka na przekazanie do analizy.
- Przycisk Główny: **Przekaż do analizy.**
- Przycisk Destrukcyjny: **Usuń to nagranie bezpowrotnie.**

### EuphirePopup: zmiana języka EN→PL

- Tytuł: **Język aplikacji.**
- Treść: Obecnie wspieramy w pełni język polski. Przełączyliśmy Twój język docelowy na polski.
- Przycisk: **Rozumiem.**

### Add Patient Modal — checkbox zgody (D8)

- Etykieta checkboxa: **Oświadczam, że pacjent wyraził zgodę na nagrywanie i przetwarzanie danych zgodnie z Polityką Prywatności i DPA Superwizor AI.**
- Link obok: **Zobacz dokument DPA.** → otwiera `assets/legal/DPA Superwizor AI.pdf`
- Przycisk zapisu pacjenta jest *disabled* dopóki checkbox nie jest zaznaczony.

### BottomSheet: brak zgody na nagrywanie

Pokazuje się gdy user próbuje przejść do nagrywania na pacjencie bez `consent_given_at`, lub jeśli ominął walidację checkboxa.

- Nagłówek: **Brak zgody na nagrywanie.**
- Opis: Nie możemy rozpocząć sesji bez wyraźnej zgody pacjenta. Wymagają tego przepisy o ochronie danych.
- Przycisk Główny: **Rozumiem.**

(Brak przycisku secondary/destructive — to nie jest decyzja "kontynuuj mimo wszystko". Bramka jest twarda.)

### Stepper — teksty kroków

1. „Audio bezpieczne na naszych serwerach."
2. „Tworzymy transkrypcję."
3. „Sztuczna Inteligencja przygotowuje wnioski kliniczne."
4. „Proces zakończony. Przygotowaliśmy Twój raport."

### Stan FAILED

- Nagłówek (w stepperze): **Nie udało się przygotować raportu.**
- Opis: Coś poszło nie tak po stronie analizy. Spróbujemy ponownie automatycznie. Jeśli problem się utrzymuje, skontaktuj się z pomocą techniczną.
- Przycisk: **Skontaktuj się z pomocą.**

### Eksport transkryptu — PHI warning

- Nagłówek: **Eksportujesz dane wrażliwe.**
- Opis: Dokument zawiera transkrypcję sesji terapeutycznej. Nie udostępniaj go niezaszyfrowaną pocztą ani komunikatorami bez warstwy E2E.
- Przycisk Główny: **Rozumiem, eksportuj.**
- Przycisk Secondary: **Anuluj.**

### Hard Delete

- Nagłówek: **Usunięcie konta jest bezpowrotne.**
- Opis: Skasujemy Twój profil terapeuty, wszystkie sesje, transkrypcje i raporty. Tej akcji nie można cofnąć. Jeśli jesteś pewna/pewien — wpisz słowo USUWAM.
- Pole: TextField wymagający dokładnie "USUWAM" (case-sensitive)
- Przycisk Główny (destructive, disabled gdy pole nie pasuje): **Usuń konto bezpowrotnie.**
- Przycisk Secondary: **Wróć.**

### Connectivity banner

- Treść: **Brak połączenia. Niektóre funkcje są ograniczone.**

### Foreground push toast

Format: `{title}` + `{body}` z FCM payload (lokalizowane przez backend, np. "Raport gotowy" / "Sesja z dnia 5 maja jest gotowa do wglądu.").

---

## Pre-beta checklist

### Backend integration

- [ ] Wszystkie 4 statusy Firestore mapowane poprawnie (uploaded, analyzing — backend skipuje transcribing — done).
- [ ] FAILED state ma własny UI (sekcja Etap 4.3).
- [ ] FCM token rejestruje się przy loginie i przy `onTokenRefresh`.
- [ ] FCM token kasuje się przy logout i hard delete.
- [ ] Background notification handler kieruje na ekran sesji po kliknięciu.
- [ ] 60s fallback poll do `clinical-svc.GetSessionDetails` działa.

### Bezpieczeństwo

- [ ] AES-256 per-user key, klucz w secure storage z `key_version`.
- [ ] FLAG_SECURE na ekranach z PHI.
- [ ] iOS screen recording detection logged.
- [ ] Eksport PDF wymaga PHI confirmation.
- [ ] Hard delete kasuje WSZYSTKO (PG przez backend, Firebase Auth, lokalny cache, klucze).

### Performance

- [ ] Transkrypt 1500-segment renderuje płynnie (`ListView.builder`).
- [ ] Cache otwiera ekran transkryptu < 200ms (offline first).
- [ ] Audio playback time-sync nie jankuje przy long-press / scroll.

### Quality

- [ ] Wszystkie polskie znaki diakrytyczne renderują się w PDF (eksport + legal).
- [ ] Dynamic type / text scaling honored.
- [ ] Lint + tests passing on CI.
- [ ] Screen reader (TalkBack / VoiceOver) działa na każdym kluczowym ekranie.
- [ ] **i18n audit**: każdy widoczny tekst pochodzi z ARB. Add patient consent label, BottomSheet "Brak zgody", oba zaktualizowane teksty ekranu nagrywania (bez "kliniczne") wszystkie są w `app_pl.arb`.
- [ ] **Codec validation (D10)**: E2E z fixturą OPUS przechodzi (kryteria w Task 1.4). Hardware encoder verification na iPhone 8/SE2 wykonana — Console log potwierdza `AudioToolbox: Using hardware encoder for kAudioFormatOpus`. 5-min recording CPU < 15%.

### Backend change requests (post-MVP — NIE w tym wydaniu)

> Per D9: MVP NIE modyfikuje backendu. Lista poniżej to przyszłe ticket-y do założenia po skończeniu MVP, kiedy product chce centralny audit trail zgód:

- [ ] Migracja 000010: `patient_files.consent_given_at` + `consent_document_version`.
- [ ] Proto: `clinical.v1.CreatePatientFileRequest` rozszerzone o pola consent (lub osobne `RecordConsent` RPC).
- [ ] Walidacja serwer-side: zwracaj `INVALID_ARGUMENT` jeśli zgoda nie została zapisana.
- [ ] `BackendConsentService` w aplikacji + DI swap z `LocalConsentService`.
- [ ] Jednorazowa migracja Hive → backend dla zalegających rekordów na device-ach.

### Tagging

- [ ] `git tag -a v0.1.0-flutter-mvp -F <message>` po passingu wszystkich powyższych.

---

## Pytania otwarte (do rozstrzygnięcia z product / design team)

1. **Audio key rotation**: czy przy zmianie hasła rotujemy klucz immediate vs lazy (przy następnym uploadzie)?
2. **Tablet layout**: 2-kolumnowy grid czy tab bar dla raportu na iPad?
3. **Loading time per status**: jak długo trzymamy stepper widoczny po `done` zanim auto-routing? Plan mówi 2s — wystarczy?
4. **Long-press na segment transkryptu**: pokazujemy timestamp absolute (`14:23:01`) czy relative (`00:23:01` od początku sesji)?
5. **PDF eksport raportu**: w MVP czy Faza 2? Plan teraz NIE zawiera — ale terapeuci pewnie będą pytać o to wraz z transkryptem.
6. **Sentry / Crashlytics**: wybór i scrubbing rules przed beta.
