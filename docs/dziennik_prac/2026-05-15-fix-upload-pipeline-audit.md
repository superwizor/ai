---
type: Developer Worklog
title: "Sesja: Fix Upload Pipeline + Audyt Architektoniczny + Lokalizacja UX"
description: "Data: 2026-05-15 Cel sesji: Naprawa krytycznego buga PathNotFoundException przy wysyłce nagrań do analizy AI + głęboki audyt architektoniczny pipeline'u nagr..."
resource: file:///Users/maciekckoklormam91/Desktop/Inne/APP%20-%20Superwizor%20AI/docs/dziennik_prac/2026-05-15-fix-upload-pipeline-audit.md
tags: [dziennik-prac, upload, pipeline]
timestamp: 2026-05-15T22:46:26+02:00
---

# Sesja: Fix Upload Pipeline + Audyt Architektoniczny + Lokalizacja UX

**Data:** 2026-05-15
**Cel sesji:** Naprawa krytycznego buga `PathNotFoundException` przy wysyłce nagrań do analizy AI + głęboki audyt architektoniczny pipeline'u nagrywanie→szyfrowanie→upload + pełna lokalizacja delete-account i modality UX.

---

## 🛠 Zmiany w kodzie i plikach

### Pipeline nagrywanie→upload (critical fix)

- `lib/services/secure_audio_storage_service.dart` — **Nowa metoda `estimateDecryptedSize(chunks)`** — oblicza dokładny rozmiar plaintext z metadanych chunków (chunk.sizeBytes - 29 bajtów overhead na chunk) bez żadnego I/O. **Atomic guard** w `encryptRecording()` — czyści stare `.enc` chunki przed nową próbą, chroni przed korupcją po crashu. **Temp dir guard** — `getTemporaryDirectory()` na macOS sandbox nie gwarantuje istnienia katalogu. Stale comments OGG→FLAC.
- `lib/screens/recording_screen.dart` — **Wyeliminowany double-decrypt anti-pattern** — stary kod odszyfrowywał cały plik audio DWA RAZY (raz dla `.length()`, kasował, i znów w UploadService). Teraz rozmiar obliczany arytmetycznie. **Fix `clientPlatform`** — `Platform.isIOS ? 'ios' : 'android'` na macOS wysyłał `'android'`. Teraz: `ios`/`macos`/`android`/`desktop`. Stale comments OPUS→FLAC.
- `lib/screens/new_session_screen.dart` — Ten sam fix `clientPlatform` w ścieżce uploadu pliku z dysku.
- `lib/services/recording_service.dart` — Stale docstrings OGG/OPUS → FLAC.
- `lib/services/audio_converter_service.dart` — Temp dir guard.
- `lib/services/transcript_pdf_exporter.dart` — Temp dir guard.

### Lokalizacja i UX

- `lib/screens/delete_account_screen.dart` — Pełna migracja na `AppLocalizations`, usunięte hardcoded polskie stringi, ujednolicona typografia, poprawka casing (USUWAM → usuwam per UX writing standards)
- `lib/screens/home_screen.dart` — Rozbudowa patient management, modality sheet integration
- `lib/widgets/modality_sheet.dart` — Rozbudowany widżet wyboru modalności terapeutycznej
- `lib/constants/modalities.dart` — Aktualizacja definicji modalności
- `lib/l10n/app_pl.arb` + `app_en.arb` — ~19 nowych kluczy lokalizacyjnych
- `lib/screens/menu_screen.dart` — Brakujący import `foundation.dart` (fix build error z `LicenseEntry`/`LicenseRegistry`)

---

## 🏗 Architektura i Decyzje

### Double-Decrypt Anti-Pattern (P1 — wyeliminowany)

Stary flow:
```
record → encrypt (secure delete raw) → DECRYPT #1 (just for .length()) → delete →
→ get signed URL → DECRYPT #2 (upload) → delete → complete
```

Nowy flow:
```
record → encrypt (secure delete raw) → size = Σ(chunk.sizeBytes - 29) →
→ get signed URL → DECRYPT (single, upload) → delete → complete
```

Każdy plik `.enc` ma dokładnie 29 bajtów overhead: 1 byte `key_version` + 12 bytes `IV` + 16 bytes `GCM tag`. Rozmiar plaintext = `chunk.sizeBytes - 29`. Eliminuje pełny cykl AES-GCM + zapis/odczyt z dysku.

### Atomiczność szyfrowania (P1 — Zero Data Loss)

`encryptRecording()` teraz na wejściu czyści stare chunki `.enc` z katalogu sesji — jeśli poprzednia próba szyfrowania padła w połowie (crash, brak miejsca), następna nie dostaje mix starych+nowych chunków.

### clientPlatform telemetria

Backend dostaje prawdziwy identyfikator platformy zamiast `'android'` gdy app działa na macOS. Istotne dla diagnostyki i analytics.

---

## 🚨 Znane problemy i Dług Technologiczny

- [ ] Pipeline nie ma retry-after-failure dla uploadu zaszyfrowanego audio — chunki .enc zostają na dysku ale brak UI/logiki do wznowienia
- [ ] `_finishAndUpload` nie ma timeout protection — jeśli upload zawiesza się, user czeka w nieskończoność
- [ ] `encryptRecording` kasuje raw.flac po sukcesie ale nie robi cleanup chunków przy failure
- [ ] `kMinSessionDuration` ustawione na 30s (test) zamiast 5min (produkcja) — TODO(pre-prod) w kodzie

---

## 🎯 Następne kroki

- [ ] Przetestować pełny cykl nagranie→upload→raport na macOS i iPhone
- [ ] Upload retry queue z persistencją (Hive/drift) — P1 Zero Data Loss
- [ ] Timeout protection w `_finishAndUpload` (30s na signed URL, 5min na upload)
- [ ] Przywrócić `kMinSessionDuration = 5min` przed TestFlight
