---
type: Technical Design
title: "39 — Panel Klienta (pacjenta): design & plan implementacji"
description: "Status: DESIGN — decyzje D2/D6/PR9 ZATWIERDZONE (2026-07-03). Buduje na fundamentach docs/38 — mechanizm zaproszeń jest tą samą maszynerią co zaproszenie man..."
resource: file:///Users/maciekckoklormam91/Desktop/Inne/APP%20-%20Superwizor%20AI/docs/39_CLIENT_PANEL_DESIGN.md
tags: [ai, analytics, architecture, billing, crm, database, frontend, identity, infrastructure, ingestion, notifications, security, testing]
timestamp: 2026-07-03T23:30:01+02:00
---

# 39 — Panel Klienta (pacjenta): design & plan implementacji

Status: DESIGN — decyzje D2/D6/PR9 ZATWIERDZONE (2026-07-03). Buduje na fundamentach docs/38 — mechanizm
zaproszeń jest **tą samą maszynerią co zaproszenie managera organizacji**
(magic link + `invitations.invited_role`), a panel to **wariant webowy
aplikacji Flutter** (ta sama binarka, routing po roli). Zakres MVP: tylko web.

## 0. Personas i workflow (wymaganie)

1. **Terapeuta** — z poziomu kartoteki klika **„Zaproś klienta"** →
   podaje/potwierdza e-mail → system wysyła magic link (7 dni, jak dla
   managera). Decyduje też, **co klient widzi**: udostępnia sesje
   (z transkrypcją) i notatki per pozycja.
2. **Klient** — klika link → ustawia hasło (Firebase, jak manager/terapeuta)
   → ląduje w **panelu klienta** (app.superwizor.ai, Flutter web):
   - widzi **swoje sesje** udostępnione przez terapeutę,
   - czyta **transkrypcje** tych sesji,
   - czyta **notatki, które wysłał mu terapeuta** (plany działania i notatki),
   - **tworzy własne notatki** i **wysyła je do terapeuty**.
3. **Terapeuta** widzi notatki klienta w kartotece (badge „nowa notatka
   od klienta").

## 1. Co już jest (reużywamy — to jest delta, nie budowa od zera)

| Element | Gdzie | Użycie |
|---|---|---|
| `users` z rolą **PATIENT**; kartoteka wskazuje pacjenta przez `patient_files.patient_id` (FK SET NULL); pacjenci mają dziś `firebase_uid`/`email` **NULL** (constraint wymusza je tylko dla nie-pacjentów) | 000013 | konto klienta = TEN SAM wiersz `users`, uzupełniony o `firebase_uid`/`email` przy akceptacji |
| **Magic-link invitations z rolą**: `invitations.invited_role` + `AcceptInvitation` honorujące rolę; refresh tokenu przy ponownym zaproszeniu; szablon e-maila wybierany po roli | 000035+000063, docs/38 PR2/PR4 | identyczny mechanizm dla `PATIENT` — dokładnie tak, jak dla `ORG_ADMIN` |
| Strona `/accept-invite` (marketing-site): Firebase signup → `AcceptInvitation` → redirect po roli (ORG_ADMIN→/org) | docs/38 + PR #35 | dodajemy gałąź PATIENT → SSO handoff do app.superwizor.ai |
| Cross-origin SSO marketing → Flutter web (`MintAppLoginToken`, `applySsoFromUrl`) | identity + `lib/auth/sso_handler_web.dart` | klient po akceptacji trafia zalogowany do panelu |
| `patient_notes`: **envelope-encrypted** (KMS DEK) tytuł+treść, `kind` FREE_NOTE\|ACTION_PLAN, `source_session_id`, `sent_to_patient_at` | 000040, docs/22 | baza notatek w obie strony; sharing in-app zamiast tylko e-maila |
| Deaktywacja konta: `users.is_active` + gate `ACCOUNT_DEACTIVATED` w `ValidateToken`/`resolveCaller` | docs/38 PR2 | terapeuta może odciąć dostęp klienta bez kasowania danych |
| RODO: `DeletePatientUser` (kasacja konta pacjenta z kaskadą), `ExportPatientData` (DSAR, decrypt KMS) | docs/RODO | prawa klienta obsłużone istniejącymi ścieżkami |
| Object-level authz w clinical-svc (`requireTherapistDataAccess`) | fix IDOR 2026-07-03 | wzorzec dla nowej, RÓWNOLEGŁEJ gałęzi `requirePatientSelfAccess` |
| Szablony e-mail per rola (`invited_role` w SendInvitationEmail) | docs/38 PR4 | nowy szablon `patient_invite` (pl/en) |

## 2. Kluczowe decyzje projektowe

**D1 — Konto klienta = istniejący wiersz `users(role=PATIENT)`.**
Akceptacja zaproszenia NIE tworzy nowego usera (inaczej niż dla
managera/terapeuty): uzupełnia `firebase_uid` + `email` + `has_accepted_tos`
na pacjencie wskazanym przez `patient_files.patient_id` (backfill 000013
gwarantuje, że każda kartoteka może go mieć). Dzięki temu wszystkie
istniejące FK (sesje, notatki, kaskady RODO) działają bez zmian.

**D2 — Default-deny + jawne udostępnianie (ZATWIERDZONE).**
Klient NIE widzi automatycznie wszystkiego. Terapeuta udostępnia:
- sesję (wraz z transkrypcją) — `sessions.shared_with_client_at`,
- notatkę/plan działania — `patient_notes.shared_with_client_at`
  (ACTION_PLAN wysłany e-mailem w przeszłości ⇒ backfill z
  `sent_to_patient_at`).
Uzasadnienie: kontrola terapeutyczna (surowa transkrypcja bywa
nieodpowiednia bez omówienia) + minimalizacja ryzyka RODO. „Udostępniaj
automatycznie" jako opcja per kartoteka — świadomie PO MVP (zatwierdzone).

**D6 — Panel zastępuje e-mail jako kanał TREŚCI (ZATWIERDZONE).**
Dotychczasowe „wyślij plan działania e-mailem" (treść planu w mailu)
ewoluuje w „udostępnij w panelu klienta": treść żyje wyłącznie w panelu
(szyfrowana w bazie), a e-mail — jeśli w ogóle — jest tylko
POWIADOMIENIEM bez PHI („Masz nową pozycję w panelu" + link). Efekt
uboczny: dane szczególnej kategorii przestają krążyć po skrzynkach
pocztowych klientów — istotne wzmocnienie RODO vs stan obecny.
Dla klientów BEZ aktywowanego panelu stary flow e-mail z treścią
pozostaje jako fallback (do wygaszenia po adopcji).

**D3 — Osobne, read-only RPC dla klienta zamiast rozszerzania istniejących.**
Nowa rodzina `Client*` w clinical-svc z własną bramką
`requirePatientSelfAccess` (rola PATIENT + `patient_files.patient_id ==
caller.userID`). Zero zmian w ścieżkach terapeuty ⇒ zero ryzyka
rozszczelnienia świeżo załatanego IDOR-a. Raporty AI, notatki prywatne
terapeuty, HITOP itd. **nie mają** odpowiednika Client* — twarda granica.

**D4 — Jeden klient, wiele kartotek.**
`users.email`/`firebase_uid` są UNIQUE globalnie. Jeśli zapraszany e-mail
już należy do aktywowanego klienta (np. drugi terapeuta tego samego
klienta), akceptacja **podpina istniejące konto** do nowej kartoteki
(`patient_files.patient_id = existing.id`), zamiast tworzyć duplikat.
Panel klienta grupuje dane per kartoteka/terapeuta.

**D5 — Panel = Flutter web, routing po roli.**
`_AuthGate` (main.dart) dostaje trzecią gałąź: `role == PATIENT` →
`ClientHomeScreen`. Brak nagrywania, kartotek, billingu, onboardingu —
kod terapeuty pozostaje nietknięty; wspólne są theme, l10n, gRPC-Web
klienci, SSO. Build web deployowany jak dziś na app.superwizor.ai.

## 3. Model danych (migracje 000065+)

```sql
-- 0000NN_patient_invitations.up.sql
ALTER TABLE invitations DROP CONSTRAINT chk_invitations_invitable_role;
ALTER TABLE invitations ADD CONSTRAINT chk_invitations_invitable_role
  CHECK (invited_role IN ('THERAPIST', 'ORG_ADMIN', 'PATIENT'));
ALTER TABLE invitations ADD COLUMN patient_file_id UUID
  REFERENCES patient_files(id) ON DELETE CASCADE;
ALTER TABLE invitations ADD CONSTRAINT chk_invitations_patient_binding
  CHECK (invited_role <> 'PATIENT' OR patient_file_id IS NOT NULL);
-- jedna aktywna inwitacja klienta per kartoteka
CREATE UNIQUE INDEX uq_invitations_patient_file_pending
  ON invitations(patient_file_id)
  WHERE accepted_at IS NULL AND invited_role = 'PATIENT';

-- 0000NN_client_sharing.up.sql
ALTER TABLE sessions ADD COLUMN shared_with_client_at TIMESTAMPTZ;
ALTER TABLE patient_notes ADD COLUMN shared_with_client_at TIMESTAMPTZ;
ALTER TABLE patient_notes ADD COLUMN author_role user_role NOT NULL DEFAULT 'THERAPIST';
ALTER TABLE patient_notes DROP CONSTRAINT patient_notes_kind_check;
ALTER TABLE patient_notes ADD CONSTRAINT patient_notes_kind_check
  CHECK (kind IN ('FREE_NOTE', 'ACTION_PLAN', 'CLIENT_NOTE'));
-- CLIENT_NOTE: author_role='PATIENT', widoczna dla terapeuty od utworzenia
ALTER TABLE patient_notes ADD COLUMN read_by_therapist_at TIMESTAMPTZ;
ALTER TABLE patient_notes ADD COLUMN read_by_client_at TIMESTAMPTZ;
-- backfill: plany działania wysłane e-mailem są już "udostępnione"
UPDATE patient_notes SET shared_with_client_at = sent_to_patient_at
  WHERE sent_to_patient_at IS NOT NULL;
```

Uwagi:
- `patient_notes` już szyfruje tytuł/treść kopertowo (KMS) — notatki
  klienta dziedziczą to bez zmian; `therapist_id` zostaje jako „adresat"
  (kolumna NOT NULL), autor rozróżniany przez `author_role`.
- Indeksy: `sessions(patient_file_id) WHERE shared_with_client_at IS NOT
  NULL`, `patient_notes(patient_file_id, kind)`.

## 4. API

### identity-svc
```protobuf
// Terapeuta, z kartoteki. Ten sam mechanizm co AdminInviteOrgManager:
// token 32B → SHA-256 w DB, TTL 7 dni, refresh przy ponownym wywołaniu,
// e-mail z szablonu patient_invite. Wymaga patient_email na kartotece
// (lub podaje go w request — zapisywany jak w UpdatePatientUser).
rpc InviteClient(InviteClientRequest) returns (Invitation);
message InviteClientRequest {
  string patient_file_id = 1;
  string email = 2;            // opcjonalny override patient_email
}

// AcceptInvitation — rozszerzenie istniejącego handlera o gałąź PATIENT:
//  1) invitation.patient_file_id → kartoteka → patient_id (users.PATIENT)
//  2) jeśli users z tym e-mailem/firebase_uid już istnieje jako PATIENT
//     (D4) → patient_files.patient_id := existing.id
//  3) w innym razie: UPDATE users SET firebase_uid, email,
//     has_accepted_tos=TRUE WHERE id = patient_id
//  4) mark accepted; ZERO tworzenia organizacji/subskrypcji/seatów
```
Gating: `InviteClient` przez `requireTherapistDataAccess` (właściciel
kartoteki / ORG_ADMIN — spójnie z resztą clinical-authz; wołane przez
clinical? NIE — invitations żyją w identity, więc identity robi lookup
kartoteki po `patient_file_id` tak samo, jak robi to dla seatów).

### clinical-svc — rodzina Client* (rola PATIENT, self-access)
```protobuf
// Wspólna bramka: caller.role == PATIENT AND
// patient_files.patient_id == caller.user_id → inaczej NotFound.
rpc ClientGetMyOverview(google.protobuf.Empty) returns (ClientOverview);
//   → lista kartotek klienta (D4): terapeuta (imię, org), liczby
//     udostępnionych sesji/notatek, nieprzeczytane.

rpc ClientListSessions(ClientListSessionsRequest) returns (ClientListSessionsResponse);
//   → tylko sesje z shared_with_client_at IS NOT NULL; metadane:
//     data, numer, czas trwania. BEZ statusów pipeline'u, BEZ raportów.

rpc ClientGetTranscript(ClientGetTranscriptRequest) returns (ClientTranscript);
//   → segmenty transkrypcji (decrypt KMS) TYLKO dla udostępnionej sesji;
//     etykiety mówców jak w apce terapeuty (Terapeuta/Klient).

rpc ClientListNotes(ClientListNotesRequest) returns (ClientListNotesResponse);
//   → (a) notatki terapeuty z shared_with_client_at IS NOT NULL
//     (FREE_NOTE/ACTION_PLAN), (b) własne CLIENT_NOTE. Decrypt KMS.

rpc ClientCreateNote(ClientCreateNoteRequest) returns (ClientNote);
//   → kind=CLIENT_NOTE, author_role=PATIENT, szyfrowanie jak dziś;
//     utworzenie == wysłanie do terapeuty (bez draftów w MVP).
rpc ClientMarkNoteRead(...) / read_by_client_at

// Strona terapeuty (istniejące ekrany kartoteki):
rpc ShareSessionWithClient(ShareSessionRequest) returns (google.protobuf.Empty);   // + unshare
rpc ShareNoteWithClient(ShareNoteRequest) returns (google.protobuf.Empty);         // + unshare
//   → ListPatientNotes zwraca też CLIENT_NOTE (badge „od klienta",
//     read_by_therapist_at).
```

### notification-svc
- Szablon `patient_invite` (pl/en) — selektor po `invited_role` już
  istnieje (docs/38 PR4); treść: „Twój terapeuta {inviter_first_name}
  zaprasza Cię do bezpiecznego panelu klienta…".
- (Opcjonalnie, PR7) `client_note_received` dla terapeuty.

## 5. Web — wariant kliencki aplikacji Flutter (tylko web w MVP)

- **Routing po roli** w `_AuthGate`: `PATIENT` → `ClientHomeScreen`;
  gate deaktywacji działa bez zmian (terapeuta może odciąć dostęp).
- **Ekrany** (nowy moduł `lib/client/`):
  1. `ClientHomeScreen` — nagłówek „Twoja terapia", per kartoteka:
     terapeuta + dwie listy-zakładki: *Sesje*, *Notatki*.
  2. `ClientSessionScreen` — metadane sesji + read-only transkrypcja
     (reużycie widgetu transkrypcji z ekranu sesji terapeuty,
     w trybie bez edycji etykiet).
  3. `ClientNotesScreen` — „Od terapeuty" / „Moje notatki";
     edytor (tytuł+treść) → „Wyślij do terapeuty".
- **Bez**: nagrywania, kartotek, billingu, onboardingu, ustawień
  terapeutycznych; menu klienta: konto (hasło/e-mail przez Firebase),
  język, wyloguj, usuń konto (istniejący flow RODO).
- **Accept-invite** (marketing-site): gałąź PATIENT w `AcceptInviteForm` —
  po akceptacji redirect przez istniejący SSO handoff do
  `app.superwizor.ai` (wzorzec managera → `/org` z PR #35).
- **Kartoteka terapeuty** (Flutter): przycisk „Zaproś klienta"
  (stan: zaproszony/aktywny/nieaktywny), przełącznik „Udostępnij
  klientowi" na sesji i na notatce, badge nieprzeczytanych CLIENT_NOTE.

## 6. Prywatność / RODO (twarde granice)

1. Klient widzi WYŁĄCZNIE własne dane (art. 15 RODO) i tylko jawnie
   udostępnione pozycje (D2). Żadnych raportów AI, notatek prywatnych
   terapeuty, danych innych klientów, danych organizacji.
2. Decrypt KMS transkrypcji/notatki wykonywany per żądanie, tylko po
   przejściu `requirePatientSelfAccess` + checku `shared_with_client_at`.
3. Każde wejście klienta w transkrypcję → `analytics_events`
   (metadane, bez treści) — ślad audytowy dostępu do PHI.
4. Akceptacja zaproszenia = zgoda klienta (ToS + polityka prywatności,
   checkbox jak u terapeuty); wzór zgody na sesję (docs/37) do
   aktualizacji o zdanie „materiały udostępnione w panelu klienta" —
   konsultacja prawna.
5. Deaktywacja (odcięcie dostępu, dane zostają) ≠ usunięcie konta
   (`DeletePatientUser`, kaskada RODO) — oba dostępne terapeucie.
6. `users_firebase_uid_required_for_non_patient` bez zmian — pacjent
   przed aktywacją dalej może mieć NULL-e.

## 7. Plan implementacji (PR-y)

| PR | Zakres | Zależy od |
|---|---|---|
| PR1 | Migracje §3 (invitations+PATIENT+patient_file_id, sharing kolumny, CLIENT_NOTE, backfill) — up/down + smoke na pg15 | — |
| PR2 | identity-svc: `InviteClient`, gałąź PATIENT w `AcceptInvitation` (attach-not-create, D1/D4), testy bramek | PR1 |
| PR3 | clinical-svc: `requirePatientSelfAccess` + rodzina `Client*` + `Share*WithClient`; `ListPatientNotes` z CLIENT_NOTE; testy authz (klient A nie widzi kartoteki klienta B → NotFound) | PR1 |
| PR4 | notification-svc: szablon `patient_invite` (pl/en) | PR2 |
| PR5 | marketing-site: gałąź PATIENT w accept-invite (redirect SSO → app) | PR2 |
| PR6 | Flutter (terapeuta): „Zaproś klienta" w kartotece, przełączniki udostępniania, badge CLIENT_NOTE | PR2+PR3 |
| PR7 | Flutter web (klient): `_AuthGate` routing po roli + `lib/client/*` (3 ekrany) | PR3 |
| PR8 | E2E staging: invite → accept (fresh Firebase user) → share sesji → ClientGetTranscript → ClientCreateNote → widoczność u terapeuty → deactivate → ACCOUNT_DEACTIVATED; negatywne: nieudostępniona sesja → NotFound, cudza kartoteka → NotFound | wszystkie |
| PR9 | Powiadomienia (ZATWIERDZONE): e-mail bez PHI „nowa pozycja w panelu" do klienta przy udostępnieniu sesji/notatki + `client_note_received` do terapeuty; aktualizacja wzoru zgody (prawne) | PR3+PR4 |

Szacunek: PR1–PR5 to niemal kalka mechaniki docs/38 (mały/średni rozmiar);
ciężar leży w PR3 (nowa powierzchnia authz — pisać testy najpierw) i PR7
(nowy moduł UI).

## 8. Ryzyka / decyzje otwarte

- (a) **Wspólny e-mail klienta i terapeuty** — users.email UNIQUE: jeśli
  zapraszany e-mail należy do konta THERAPIST/ORG_ADMIN, `InviteClient`
  zwraca FailedPrecondition (komunikat dla terapeuty). Single-role MVP
  utrzymany.
- (b) **iOS/Android klienta** — poza MVP; architektura (wariant po roli
  w tej samej binarce) czyni to naturalnym krokiem.
- (c) **Powiadomienia o nowej pozycji** — ZATWIERDZONE jako PR9
  (e-mail bez PHI, tylko sygnał + link); push mobilny — po MVP razem
  z aplikacjami natywnymi.
- (d) **Automatyczne udostępnianie** (per kartoteka „udostępniaj każdą
  ukończoną sesję") — świadomie po MVP, po feedbacku terapeutów.
- (e) **Współdzielona kartoteka w organizacji** — ORG_ADMIN nie widzi
  treści (docs/38 §7.3); panel klienta tego nie zmienia.
