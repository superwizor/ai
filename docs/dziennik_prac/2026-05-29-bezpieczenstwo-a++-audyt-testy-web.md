# Sesja: Bezpieczeństwo A++ — Zewnętrzny Audyt, Testy i Web Compatibility

**Data:** 2026-05-29
**Cel sesji:** Przeprowadzenie zewnętrznego audytu bezpieczeństwa ($40k-grade) warstwy nagrywania i szyfrowania, implementacja pełnego pokrycia testami (A++), wdrożenie poprawek audytu, i przygotowanie kodu pod kompilację Web (Flutter Web).

## 🛠 Zmiany w kodzie i plikach

### Testy (A++ pokrycie — 165 testów, 4 pliki)

- `test/security/secure_audio_storage_test.dart` — **73 testy** pokrywające HKDF-SHA256 (Unicode, avalanche, kolizje, puste ID, 100 unikalnych kluczy), AES-256-GCM (round-trip, zły klucz/IV/tag, puste dane, 64KB bloki), detekcja obcych plików (ukryte pliki, wielokrotne iniekcje), SecureRandomService (singleton, dystrybucja bajtów), certificate pinner (multi-instance).

- `test/security/encrypt_decrypt_pipeline_test.dart` — **30 testów integracyjnych** pełny cykl encrypt→manifest→verify→decrypt, detekcja tamperingu (SHA-256 mismatch, HMAC fałszywy, zmieniona liczba chunków), izolacja kluczy między sesjami, wsteczna kompatybilność (pre-HKDF sesje), ścieżki błędów (zbyt krótki chunk, zły key_version).

- `test/security/upload_error_security_test.dart` — **30 testów** klasyfikacji błędów: wszystkie kody gRPC (terminal vs retryable), HTTP signed-URL (403/401/410/400+ExpiredToken), TLS errors, IntegrityViolation, F-13 signedUrl wykluczenie z JSON.

- `test/security/pending_upload_test.dart` — **32 testy modelu** PendingUpload: JSON round-trip, F-13 signedUrl bezpieczeństwo, fazy terminalne, initial factory, copyWith immutability, time-based ops, wsteczna kompatybilność JSON (brakujące pola, nieznane enumy).

### Poprawki z audytu (5 quick fixes)

- `lib/services/secure_audio_storage_service.dart` — **EXT-05:** HKDF domain separation label (`superwizor-audio-v1:$sessionId`) zapobiega kolizji kluczy jeśli HKDF zostanie użyty do innego celu. **EXT-09:** timestamp `createdAt` w manifeście do analizy forensic i wykrywania replay.

- `android/app/src/main/kotlin/.../MainActivity.kt` — **EXT-07:** `SecureRandom` singleton zamiast tworzenia nowej instancji przy każdym wywołaniu.

- `lib/services/secure_random_service.dart` — **EXT-08:** 2-sekundowy timeout na MethodChannel (zapobieganie hang gdy Secure Enclave zajęty). **EXT-02:** `kIsWeb` early exit — na Web skipuje MethodChannel, używa Random.secure() (Web Crypto API).

- `lib/uploads/upload_io_grpc.dart` — **EXT-12:** assertion na niepuste sessionId (zapobiega współdzieleniu klucza przez "puste" sesje).

### Web Compatibility (conditional imports)

- `lib/uploads/certificate_pinner.dart` → **conditional export hub**
  - `certificate_pinner_io.dart` — IOClient + badCertificateCallback (mobile)
  - `certificate_pinner_web.dart` — plain http.Client (browser TLS)

- `lib/uploads/upload_error.dart` → **conditional export hub**
  - `upload_error_io.dart` — pełny klasyfikator z SocketException, HandshakeException
  - `upload_error_web.dart` — klasyfikator bez typów dart:io

- `lib/services/secure_audio_types.dart` — **[NEW]** platformowo-niezależne typy (EncryptedChunk, IntegrityViolation) wyekstrahowane z dart:io-zależnego secure_audio_storage_service.dart

## 🏗 Architektura i Decyzje (Flutter/Firebase)

### Bezpieczeństwo / Kryptografia

- **HKDF Domain Separation (RFC 5869 §3.2):** Dodano prefix `superwizor-audio-v1:` do parametru `info` w HKDF-Expand. Dzięki temu, nawet jeśli w przyszłości dodamy HKDF do innego celu (np. key wrapping), ten sam sessionId nie wygeneruje tego samego klucza. Jest to best practice w kryptografii.

- **Manifest Forensics:** Dodano pole `createdAt` (ISO 8601 UTC) do manifestu integralności. Umożliwia detekcję replay attacks (stare manifesty użyte z nowymi chunkami) i post-mortem forensics w przypadku incydentów.

- **Web Crypto API:** Na platformie Web, `Random.secure()` deleguje do `crypto.getRandomValues()` — natywnego API przeglądarki backed by hardware RNG. Bezpieczeństwo kryptograficzne jest zachowane.

### Conditional Imports Pattern

Użyto standardowego Flutter pattern'u `export ... if (dart.library.io)` do rozdzielenia kodu platformowo-specyficznego:
- Plik "hub" (`certificate_pinner.dart`) eksportuje `_web.dart` domyślnie, `_io.dart` gdy dart:io jest dostępne
- Pozwala to na kompilację Web bez importowania dart:io
- Żadnych zmian behawioralnych na iOS/Android

### Zero Data Loss (P1)

- ✅ Wszystkie zmiany zachowują idempotentność pipeline'u nagrywania
- ✅ F-13: signedUrl nadal nie jest persystowany do Hive
- ✅ IntegrityViolation nadal jest klasyfikowany jako terminal (non-retryable)
- ✅ Wsteczna kompatybilność z pre-HKDF sesjami potwierdzona testami

## 🚨 Znane problemy i Dług Technologiczny

- [ ] `test/uploads/upload_state_transitions_test.dart` — 13 pre-existing failures (nie spowodowane naszymi zmianami, potwierdzone git stash). Wymagają osobnego investigation.
- [ ] `test/uploads/upload_queue_runner_test.dart` — 21 pre-existing failures (ten sam root cause co powyżej).
- [ ] `upload_io_grpc.dart` i `secure_audio_storage_service.dart` nadal importują `dart:io` — te pliki są z natury mobile-only (File I/O, path_provider). Na Web, nagrywanie sesji nie będzie obsługiwane (brak dostępu do mikrofonu + local file system w wymaganym formacie FLAC). Web będzie obsługiwał tylko przeglądanie raportów.
- [ ] Pełna kompilacja `flutter build web` wymaga jeszcze dodatkowego conditional import na `upload_io_grpc.dart` (importowany przez `upload_queue_provider.dart`) — do zrobienia gdy faktycznie będziemy budować Web.

## 🎯 Następne kroki (Next Actions)

1. **Naprawić pre-existing test failures** w `upload_state_transitions_test.dart` i `upload_queue_runner_test.dart`
2. **Merge `bezpieczne-nagrywanie` → `main`** po review (branch jest pushed i gotowy do PR)
3. **Web MVP:** Conditional import na `upload_queue_provider.dart` + stub `UploadIo` dla Web (no-op, bo Web nie nagrania)
4. **CI Integration:** Dodać `flutter test test/security/` do GitHub Actions workflow
