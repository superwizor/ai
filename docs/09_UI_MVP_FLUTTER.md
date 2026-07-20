---
type: System Documentation
title: "Faza UI — Superwizor AI Flutter MVP"
description: "---"
resource: file:///Users/maciekckoklormam91/Desktop/Inne/APP%20-%20Superwizor%20AI/docs/09_UI_MVP_FLUTTER.md
tags: [ai, analytics, crm, database, frontend, identity, ingestion, notifications, security, testing]
timestamp: 2026-05-10T23:14:54+02:00
---

# 📱 Faza UI — Superwizor AI Flutter MVP

> **Cel:** Doprowadzić aplikację Flutter do stanu MVP zdolnego przeprowadzić terapeutę przez pełny flow: login → setup → nagranie sesji → upload → live status → transkrypcja + raport. Backend (Fazy 0-3) jest gotowy i wystawia gRPC + Firestore mirror.
>
> Bazuje na: [`02_ARCHITEKTURA_TECHNICZNA.md`](./02_ARCHITEKTURA_TECHNICZNA.md), [`03_DATA_MODEL.md`](./03_DATA_MODEL.md), [`08_FAZA_3_NOTIFICATIONS.md`](./08_FAZA_3_NOTIFICATIONS.md), `B_05_ui_ux_design_system.md`, `B_09_trauma_informed_writing.md`.

---

## 📝 Changelog

- **v1.4** (2026-05-09): Zmiana formatu audio z M4A na **OGG-OPUS @ 64 kbps mono**. Chirp 3 nie wspiera natywnie M4A/AAC (`stt-worker/main.go:358`). Opus: natywny hardware encoder na iOS (AudioToolbox 11+) i Android (MediaCodec API 21+), 130 min = ~62 MB (vs ~585 MB FLAC). Usunięto `ffmpeg_kit_flutter`, dodano `record: ^5.1.0`. Backend: `ingestion-svc` wymaga drobnej zmiany (hardcoded `.m4a` → dynamiczne rozszerzenie). Plan B: FLAC przez ten sam `record` package (zero ffmpeg).
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
- [ ] Stan `FAILED` ma własny komunikat (bez Kaskady Sukcesu), z przyciskiem "Skontaktuj się z pomocą". **Uwaga:** FAILED nie jest mirrorowany do Firestore (ADR-IMPL-012) — wykrywany wyłącznie przez fallback poll do `clinical-svc.GetSessionDetails` (60s).
- [ ] Transkrypcja działa: chronologiczna oś czasu, filtr per mówca, search, time-synced playback z audio, kopiowanie do schowka.
- [ ] Raport pokazuje 7 sekcji w akordionie (mobile) / tabach (tablet).
- [ ] Wylogowanie kasuje FCM token przez `notification-svc.RemoveFCMToken`; kolejne pushe nie idą na to urządzenie.

### Niefunkcjonalne

- [ ] **P1 (Zero Data Loss)**: Audio jest szyfrowane (AES-256, klucz per-user) PRZED zapisem na dysk. Crash/kill apki nie traci sesji — encrypted chunks + stan `PENDING_UPLOAD` w Hive odzyskują się przy ponownym otwarciu.
- [ ] **P3 (EU residency)**: Firestore region `europe-central2`, audio bucket `europe-central2`. Klient nie pisze niczego do regionów spoza UE.
- [ ] **P4 (Flutter read-only on AI reports)**: Raport jest tylko do odczytu; brak inline edit, brak local-only diff vs backend.
- [ ] **PHI on screen**: ekrany transkryptu, raportu i danych pacjenta mają `FLAG_SECURE` (Android) + iOS screenshot detection. Privacy overlay przy backgrounding apki.
- [ ] UX writing zgodny z `B_09_trauma_informed_writing.md`: kropki na końcu nagłówków, zero toxic positivity, zero wykrzykników wymuszających entuzjazm.
- [ ] **i18n (D7)**: zero hardcoded stringów w widgetach UI; wszystkie teksty z `app_pl.arb`; `grep -rn "Text('[A-Za-zżźćń]" lib/` zwraca pusty wynik (poza testami).
- [ ] **Zgoda RODO/DPA (D8 + D9)**: `add_patient_modal` ma checkbox; przycisk zapisu disabled bez zgody. W MVP to czysty UI mockup — checkbox blokuje przycisk zapisu, ale żadna logika zapisu nie jest aktywna. Pełna implementacja (`ConsentService` + Hive + backend migration) opisana w sekcji LATER/POST-MVP.

### Operacyjne

- [ ] Wszystkie teksty komunikatów odpowiadają DOKŁADNIE definicjom z sekcji [UX Writing](#ux-writing).
- [ ] CI Flutter passing: lint + widget tests + unit tests.
- [ ] Pliki Markdown (Regulamin, Polityka Prywatności, DPA) ładują się z `assets/legal/` (offline) przez `flutter_markdown`.
- [ ] Hard Delete ("USUWAM") wymaga literalnie tego słowa, case-sensitive.

---

<a id="decyzje"></a>

## Decyzje produktowe + architektoniczne

Decyzje podjęte w trakcie review (2026-05-08):

| # | Decyzja | Uzasadnienie |
|---|---|---|
| D1 | **Klucz szyfrujący audio: per-user** | Prostsza rotacja (zmiana hasła = nowy klucz dla nowych nagrań; stare chunki dekryptowalne starym kluczem trzymanym w `flutter_secure_storage` keychain z metadanymi `key_version`) |
| D2 | **Kopiowanie transkryptu do schowka: MVP** | Terapeuci potrzebują łatwego dostępu do tekstu. Przycisk "Kopiuj do schowka" zamiast PDF — prostsze, bezpieczniejsze, zero dodatkowych paczek |
| D3 | **Sekcji raportu: 7 (nie 9)** | Zmieszczone w protokole `clinical.v1.Report.content` jako structured JSON; mapping w sekcji [Etap 5b](#etap-5b) |
| D4 | **Fallback poll do clinical-svc po 60s ciszy w listenerze** | Zgodne z `08_FAZA_3_NOTIFICATIONS.md` ADR-IMPL-009 (Firestore best-effort); 60s daje cushion na cold start funkcji notification-worker |
| D5 | **Hard cap nagrania: 130 min** | iOS technicznie nie limituje (UIBackgroundModes: audio jest skonfigurowane), ale 130 min daje 20 min marginesu na realne sesje 90-min + interruption recovery (rozmowa, kalendarzowy alert). Backend przyjmie do 300 MB pliku — to nie limit |
| D6 | **Brak dark mode w MVP** | Dodanie post-MVP po feedback od pierwszych beta-testerów |
| D7 | **i18n od dnia 1 (zakaz hardcoded stringów)** | Apka start-uje jako PL-only, ale architektura tekstów (ARB + `flutter_localizations`/`intl`) jest wdrożona od początku. Dodanie EN/innego języka post-MVP będzie zmianą plików, nie kodu UI |
| D8 | **Obowiązkowy checkbox zgody pacjenta (RODO/DPA) przed nagraniem** | Wymóg prawny — bez wyraźnej, udokumentowanej zgody pacjenta nie wolno przetwarzać nagrań. Walidacja blokuje przejście do nagrywania. Tekst zgody odsyła do `assets/legal/DPA Superwizor AI.md` |
| D9 | **MVP bez modyfikacji backendu — UI-only mockup zgody** | W MVP checkbox blokuje przycisk zapisu pacjenta, ale żadna logika zapisu/audytu nie jest aktywna. Pełna implementacja (migracja `consent_given_at` + proto extension + `ConsentService` + Hive + backend walidacja) opisana w sekcji LATER/POST-MVP. Interfejs jest gotowy na podmianę implementacji jednym DI swap-em |
| D10 | **Format audio: OGG-OPUS @ 64 kbps mono** | Chirp 3 nie wspiera natywnie M4A/AAC (`stt-worker/main.go:358`). Opus: codec stworzony dla voice (Xiph + Skype), hardware encoder na iOS/Android, 130 min = ~62 MB. Plan B: FLAC przez ten sam `record` package (bez `ffmpeg_kit_flutter` w obu scenariuszach) |

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
  flutter_markdown: ^0.7.4
  record: ^5.1.0             # OGG-OPUS recording (hardware-accelerated)
  hive: ^2.2.3
  hive_flutter: ^1.1.0
  shimmer: ^3.0.0
```

> [!IMPORTANT]
> **`ffmpeg_kit_flutter` USUNIĘTE.** `record` package nagrywa bezpośrednio w OGG-OPUS — brak post-processingu. Oszczędność ~50 MB w paczce.

#### Konfiguracja nagrywania (D10 — OGG-OPUS)

```dart
import 'package:record/record.dart';

final config = RecordConfig(
  encoder: AudioEncoder.opus,    // kontener OGG z kodekiem Opus
  bitRate: 64000,                // 64 kbps mono — clinical-grade voice
  sampleRate: 48000,             // natywny sample rate Opus
  numChannels: 1,                // mono — wszystkie sesje
);

await audioRecorder.start(config, path: '$dir/session_$sessionId.ogg');
```

**Dlaczego OGG-OPUS, nie M4A/AAC ani FLAC:**

| Codec | Chirp 3 | 60 min mono | Hardware encoder |
|---|---|---|---|
| OGG-OPUS 64kbps | ✅ natywny | ~28 MB | ✅ iOS 11+ / Android API 21+ |
| FLAC | ✅ natywny | ~270 MB | ❌ software-only |
| M4A/AAC | ⚠️ **niestabilne** | ~23 MB | ✅ natywny |

> Komentarz w `stt-worker/main.go:358`: `"Codec not supported by Chirp 3 (e.g. M4A/AAC; use FLAC, WAV-LINEAR16, OGG-OPUS)"`

**Plan B** (jeśli E2E test wykaże regresję WER > 5% vs FLAC):
1. Bump Opus na 96 kbps (60 min = ~43 MB)
2. Wróć do FLAC przez ten sam `record` package (`AudioEncoder.flac`) — **nadal BEZ `ffmpeg_kit_flutter`**

### Task 1.2 — `SecureAudioStorageService` (per-user key)

**Plik:** `lib/services/secure_audio_storage_service.dart`

**Strategia klucza** (D1):
- Klucz AES-256 generowany jednorazowo przy pierwszym loginie tego usera na tym device → zapisywany w `flutter_secure_storage` (iOS Keychain, Android Keystore-backed).
- `key_version` (int) zapisany razem z kluczem; każdy plik chunka ma `key_version` w metadanych pliku.
- **Rotacja przy zmianie hasła**: nowy klucz `key_version + 1`, zapisz oba; nowe nagrania używają nowego, stare chunki dekryptowalne starym dopóki nie zostaną wgrane.
- Po pomyślnym wgraniu wszystkich chunków danej sesji → wyczyść klucze starszych wersji.

```dart
class SecureAudioStorageService {
  final FlutterSecureStorage _storage;

  Future<EncryptedChunk> writeChunk(int seq, List<int> rawAudio) async {
    final key = await _currentKey();
    final iv = IV.fromSecureRandom(16);
    final encrypter = Encrypter(AES(key, mode: AESMode.gcm));
    final encrypted = encrypter.encryptBytes(rawAudio, iv: iv);

    final dir = await getApplicationDocumentsDirectory();
    final f = File('${dir.path}/sessions/$sessionId/chunk_${seq.toString().padLeft(5, '0')}.enc');
    await f.parent.create(recursive: true);
    await f.writeAsBytes([
      ..._headerBytes(keyVersion, iv.bytes), // 1B version + 16B iv
      ...encrypted.bytes,
    ]);
    return EncryptedChunk(seq: seq, path: f.path, sizeBytes: await f.length());
  }
}
```

### Task 1.3 — Workmanager dla background uploadu

**Plik:** `lib/services/upload_worker.dart`

- Po `CompleteAudioUpload` (Etap 3) → enqueue `Workmanager.registerOneOffTask("upload-${sessionId}", ...)` z constraint `NetworkType.connected`.
- Worker dekryptuje chunki, łączy do jednego pliku OGG (chunki z `record` to segmenty tego samego OGG), wysyła PUT na signed URL z `ingestion-svc` z `Content-Type: audio/ogg`.
- Brak konwersji formatów — `record` nagrywa w finalnym formacie (OGG-OPUS). Zero post-processingu.
- Po sukcesie wszystkich chunków → wywołanie `ingestionService.completeAudioUpload()` → kasujemy enkryptowane chunki z dysku → stan w Hive: `UPLOADED`.

### Task 1.4 — Testy

```dart
test('encrypt then decrypt yields original bytes', () async { ... });
test('chunk file has 17-byte header (1B version + 16B IV)', () async { ... });
test('crashed before encrypt() finishes → file does not exist', () async { ... });
test('rotated key_version: old chunks decryptable until purged', () async { ... });
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
                  builder: (_) => LegalMarkdownScreen(assetPath: 'assets/legal/DPA Superwizor AI.md'),
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

Po prawej linkowanym tekstem: "Zobacz dokument DPA." → otwiera `assets/legal/DPA Superwizor AI.md` w `LegalMarkdownScreen` (Task 5c.1).

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

  // [MVP Mockup] — Zgoda na razie wisi tylko w UI.
  // Bez włączonego checkboxa przycisk był disabled, więc w tym miejscu
  // mamy pewność, że zgoda została odkliknięta. W wersji MVP celowo 
  // nie zapisujemy tego jeszcze na urządzeniu (sekcja LATER/POST-MVP).

  Navigator.pop(context, patient);
}
```

**`_NoConsentBottomSheet`** (UX writing w sekcji [UX Writing](#ux-writing)) — wywoływany gdy user próbuje przejść dalej bez zaznaczenia checkboxa (defensywnie — przycisk powinien być disabled, ale jeśli ktoś kliknie skróconą ścieżką "Zacznij sesję" z dashboardu na pacjenta bez zgody, ten sam BottomSheet się pokazuje).

#### ⚠️ LATER / POST-MVP: `ConsentService` — Zapis zgody i Backend
> **UWAGA:** Kod poniżej został w 100% wyjęty z planu dla MVP. Wersja MVP to czysty UI mockup z zaznaczaniem checkboxa, bez logiki zapisu. Poniższa sekcja celowo zostaje w dokumencie wyłącznie jako gotowy plan na za kilka dni, kiedy będziemy dopinać zapisy do backendu.

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

### Task 3.5 — iOS background recording

`UIBackgroundModes: audio` jest już skonfigurowane w `Info.plist` ✓. Ale:
- **AVAudioSession config**: ustaw category `playAndRecord` z opcją `mixWithOthers: false` (sesja terapii nie powinna mieszać się z YouTube/Spotify).
- **Interruptions**: nasłuchuj `AVAudioSessionInterruption` (rozmowa telefoniczna, alarm) → automatyczna pauza, po `interruption ended` → user musi ręcznie wznowić (nie auto-resume — terapeuta może chcieć przerwać).
- **Audio focus loss na Androidzie**: `AudioFocusRequest` z `gain: AUDIOFOCUS_GAIN`; przy `AUDIOFOCUS_LOSS` → pauzuj i zachowaj stan.

> 🔬 **TODO przed beta**: test 130-min nagrania na fizycznym iPhone w tle (apka zminimalizowana). Jeśli iOS ubije proces przed końcem — ograniczamy do 90 min i dodajemy alert. Ale realnie: z `audio` background mode aktywnym, iOS NIE ubija audio recording session. Główne ryzyko: out-of-memory przy długim chunkingu (kontroluj alokację — flush chunka co 30-60s do dysku, nie trzymaj pełnego bufora w RAM).
>
> 🔬 **Weryfikacja hardware Opus**: test na minimum-supported iPhone (iPhone 8, A11 chip) — AudioToolbox Opus encoder musi działać bez fallbacku software.

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
| 3. Analiza | `analyzing` | „Sztuczna Inteligencja przygotowuje wnioski." |
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
  await audioPlayer.play(AssetSource('sounds/SFX_succes.mp3'));
  await _showEuphireSuccessAnimation(); // natywna ScaleTransition, bez Lottie
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
  final AudioPlayer _player;

  AsyncValue<TranscriptData> data = AsyncValue.loading();
  String selectedSpeaker = 'all';
  String searchQuery = '';
  Duration currentPosition = Duration.zero;
}

class TranscriptData {
  final List<TranscriptSegment> segments;
  final Map<String, String> speakerLabels;
  final String audioUrl; // signed download URL z clinical-svc
}
```

### Task 5a.1 — Direct Load z gRPC

**Strategy**:
1. Otwórz ekran → pokaż `ShimmerLoader`.
2. Pobierz `clinical.getSessionDetails()` bezpośrednio z backendu.
3. Gdy dane wrócą, odśwież UI. Brak skomplikowanego cache lokalnego w celach zapewnienia zawsze aktualnych danych (Single Source of Truth).

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
  // - Kopiuj całą transkrypcję do schowka (otwiera Task 5a.8)
)
```

### Task 5a.8 — Kopiowanie do schowka

**Zamiast generowania skomplikowanych plików PDF (co rodzi ryzyko łatwego przekazywania danych wrażliwych poza bezpieczny obieg), aplikacja pozwala na skopiowanie sformatowanego tekstu do systemowego schowka, aby terapeuta mógł go wkleić do własnych, bezpiecznych notatek.**

```dart
import 'package:flutter/services.dart';

Future<void> _onCopyToClipboardPressed() async {
  // Formatujemy: "Osoba 1 (00:04): Tekst..."
  final textLines = data.segments.map((s) => 
    '${s.speakerLabel} (${_formatTimeRange(s)}): ${s.text}'
  );
  final text = textLines.join('\n\n');
  
  await Clipboard.setData(ClipboardData(text: text));
  
  // UX: Subtelne powiadomienie po udanym skopiowaniu
  EuphireToast.show(context, 'Skopiowano transkrypcję do schowka');
}
```

### Task 5a.9 — Empty/loading/error states

| Stan | UI |
|---|---|
| Loading | `ShimmerLoader` z 5 placeholder segmentami podczas pobierania przez gRPC |
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
testWidgets('copy to clipboard formats all segments with speaker and timestamp', ...);
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
│ 📄 Regulamin         │  ← assets/legal/Regulamin Świadczenia Usług Superwizor AI.md
│ 🔒 Polityka prywat.  │  ← assets/legal/Polityka Prywatności Superwizor AI.md
│ ℹ️  O aplikacji      │
├──────────────────────┤
│ 🚪 Wyloguj           │
│ ⚠ Usuń konto         │  ← Hard Delete
└──────────────────────┘
```

### Task 5c.1 — Legal Markdown screens

```dart
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter/services.dart' show rootBundle;

class LegalMarkdownScreen extends StatelessWidget {
  final String assetPath; // 'assets/legal/Regulamin Świadczenia Usług Superwizor AI.md'

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titleFor(assetPath))),
      body: FutureBuilder<String>(
        future: rootBundle.loadString(assetPath),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
          return Markdown(
            data: snapshot.data!,
            selectable: true,
            styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)),
          );
        },
      ),
    );
  }
}
```

**Pliki w `assets/legal/`** (Markdown, nie PDF):
- `DPA Superwizor AI.md`
- `Polityka Prywatności Superwizor AI.md`
- `Regulamin Świadczenia Usług Superwizor AI.md`

**Test acceptance**: polskie znaki diakrytyczne (ą, ż, ć, ł, ó, ę, ś, ń) renderują się poprawnie. Markdown rendering jest natywny — bez problemów z kompresją UTF-8 znanych z PDF.

### Task 5c.2 — Wylogowanie

```dart
Future<void> _logout() async {
  await _fcmTokenService.unregister(); // notification-svc.RemoveFCMToken
  await FirebaseAuth.instance.signOut();
  // Wyczyść dane tymczasowe sesji, ale zachowaj consent audit
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

Offline-tolerable: przeglądanie wcześniej załadowanych danych (jeśli ekran jest w pamięci).
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
│   ├── clipboard_exporter.dart
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
3. „Sztuczna Inteligencja przygotowuje wnioski."
4. „Proces zakończony. Przygotowaliśmy Twój raport."

### Stan FAILED

- Nagłówek (w stepperze): **Nie udało się przygotować raportu.**
- Opis: Coś poszło nie tak po stronie analizy. Spróbujemy ponownie automatycznie. Jeśli problem się utrzymuje, skontaktuj się z pomocą techniczną.
- Przycisk: **Skontaktuj się z pomocą.**

### Kopiowanie do schowka — Toast

- Toast po kliknięciu "Kopiuj do schowka": **Skopiowano transkrypcję do schowka.**

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
- [ ] Kopiowanie do schowka działa z prawidłowym formatowaniem (speaker label + timestamp + tekst).
- [ ] Hard delete kasuje WSZYSTKO (PG przez backend, Firebase Auth, lokalny cache, klucze).

### Performance

- [ ] Transkrypt 1500-segment renderuje płynnie (`ListView.builder`).
- [ ] Ekran transkryptu ładuje się < 2s przy 1500 segmentach (gRPC direct load).
- [ ] Audio playback time-sync nie jankuje przy long-press / scroll.

### Quality

- [ ] Wszystkie polskie znaki diakrytyczne renderują się w Markdown legal screens.
- [ ] Dynamic type / text scaling honored.
- [ ] Lint + tests passing on CI.
- [ ] Screen reader (TalkBack / VoiceOver) działa na każdym kluczowym ekranie.
- [ ] **i18n audit**: każdy widoczny tekst pochodzi z ARB. Add patient consent label, BottomSheet "Brak zgody", oba zaktualizowane teksty ekranu nagrywania (bez "kliniczne") wszystkie są w `app_pl.arb`.

### Backend change requests (post-MVP — NIE w tym wydaniu)

> Per D9: MVP NIE modyfikuje backendu. Lista poniżej to przyszłe ticket-y do założenia po skończeniu MVP, kiedy product chce centralny audit trail zgód:

- [ ] Migracja 000010: `patient_files.consent_given_at` + `consent_document_version`.
- [ ] Proto: `clinical.v1.CreatePatientFileRequest` rozszerzone o pola consent (lub osobne `RecordConsent` RPC).
- [ ] Walidacja serwer-side: zwracaj `INVALID_ARGUMENT` jeśli zgoda nie została zapisana.
- [ ] `BackendConsentService` w aplikacji + DI swap z `LocalConsentService`.
- [ ] Jednorazowa migracja Hive → backend dla zalegających rekordów na device-ach.

### Backend change: ingestion-svc (WYMAGANE przed MVP — drobna zmiana)

> **To jedyna zmiana backendowa wymagana w MVP.** Bez niej signed URL odrzuci upload z `Content-Type: audio/ogg`.

- [ ] **`ingestion-svc/internal/adapters/grpc/server.go:84`**: zmień hardcoded `.m4a` na dynamiczne rozszerzenie z `content_type`:
  ```go
  // PRZED:
  objectPath := fmt.Sprintf("%s/%s/%d.m4a", ...)
  
  // PO:
  ext := extFromContentType(req.ContentType) // "audio/ogg" → ".ogg", "audio/m4a" → ".m4a"
  objectPath := fmt.Sprintf("%s/%s/%d%s", therapistID, patientFileID, time.Now().Unix(), ext)
  ```
- [ ] **`proto/ingestion/v1/ingestion.proto:23`**: zmień komentarz `'audio/m4a'` → `'audio/ogg' (or audio/m4a, audio/flac)`
- [ ] **Brak zmian w stt-worker** — `AutoDetectDecodingConfig` obsługuje OGG-OPUS natywnie.

### Walidacja OPUS E2E (kryteria akceptacji przed merge)

```bash
# 1. Stwórz fixturę OPUS z istniejącej FLAC-owej:
ffmpeg -i tests/e2e/testdata/sample.flac \
  -c:a libopus -b:a 64k -ac 1 -ar 48000 \
  tests/e2e/testdata/sample.ogg

# 2. Uruchom E2E test z nową fixturą:
AUDIO_FILE=tests/e2e/testdata/sample.ogg \
  go test -tags=e2e -timeout=15m ./e2e/... -run TestFullSession_HappyPath

# 3. Kryteria pass/fail:
#    - transcript_segments count: ±2 vs FLAC baseline = OK
#    - average confidence: > 0.85 = OK
#    - speaker_count: 2 (dokładnie)
#    - any chunk z text="": FAIL
#    - WER vs FLAC baseline: < 5% regresji = OK
```

### Tagging

- [ ] `git tag -a v0.1.0-flutter-mvp -F <message>` po passingu wszystkich powyższych.

---

## Pytania otwarte (do rozstrzygnięcia z product / design team)

1. **Audio key rotation**: czy przy zmianie hasła rotujemy klucz immediate vs lazy (przy następnym uploadzie)?
2. **Tablet layout**: 2-kolumnowy grid czy tab bar dla raportu na iPad?
3. **Loading time per status**: jak długo trzymamy stepper widoczny po `done` zanim auto-routing? Plan mówi 2s — wystarczy?
4. **Long-press na segment transkryptu**: pokazujemy timestamp absolute (`14:23:01`) czy relative (`00:23:01` od początku sesji)?
5. **Eksport raportu**: w MVP kopiowanie do schowka (jak transkrypt) czy osobny format? Terapeuci pewnie będą pytać.
6. **Sentry / Crashlytics**: wybór i scrubbing rules przed beta.
