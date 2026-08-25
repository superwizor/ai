# Web-app progress

Project: Superwizor AI — Polish therapist co-pilot. Web-app build using the
long-running-agents harness. See `.claude/CLAUDE.md` for orientation.

**Goal (multi-slice):** Implement Slices 2, 3, 4, 5, and 6 per
`docs/19_WEB_APP_DESIGN.md` and this file. Use the `evaluator` agent after
each feature to gate progress (PASS / NEEDS_WORK). Each slice merges into
`feat/web-app` only after evaluator passes every feature.

## Done

### Slice 1 — backend foundation (branch `feat/web-app`, 18 commits + harness)
- Migrations 000035-000037 (invitations, audit_events.reason, user_role
  ORG_ADMIN + SUPERWIZOR_ADMIN). sqlc regenerated.
- `pkg/cors` shared middleware on identity/clinical/billing.
- `buf.gen.yaml` with connectrpc/go + connectrpc/es + bufbuild/es plugins;
  `gen/ts/` carved out of root `.gitignore`.
- Dedicated SAs for identity-svc + clinical-svc; GCS CORS configured.
- Proto additions: org registration, invitations, profile updates, admin
  RPCs (AdminResetTokens / AdminChangePlan).
- Identity-svc handlers: org registration, invitation create/accept, profile
  updates, SUPERWIZOR_ADMIN operations.
- Billing-svc handlers: AdminResetTokens, AdminChangePlan.
- Connect-RPC adapters across all three services (h2c mixed handler
  dispatches gRPC vs Connect by Content-Type) — commits 5484987, 403035b,
  74abdfa.
- Notification-svc: Resend transactional email integration (secret + IAM
  binding live in staging).
- E2E test: `identity-svc/.../connect_adapter_test.go` proves the Connect
  wire works via httptest.
- Harness: `.claude/` primitives, PROGRESS.md, test-results.json,
  Playwright MCP (commit a40dc23).

### Slice 2 — marketing-site foundation (DONE, merged to `feat/web-app` at aa09972)
8 features, all PASS evaluator, 8+ commits + 1 merge commit:
- nextjs-scaffold       — Euphire brand tokens (Tailwind 4 @theme)
- next-intl-pl-en       — PL/EN with as-needed routing + hreflang
- connect-rpc-client    — typed clients + bearer interceptor
- firebase-auth-init    — Web SDK + emulator + token bridge
- landing-page          — full PL+EN composition (7 sections)
- pricing-page          — Trial + Solo + Pro + Clinic
- legal-static-pages    — Terms/Privacy/DPA markdown PL+EN
- firebase-hosting-deploy — superwizor-www site + GitHub Actions CI

### Slice 3 — registration flows (DONE, merged to `feat/web-app` at 7b10f48)
8 features, all PASS evaluator, 8 commits + 1 merge:
- register-therapist-email     — /register/therapist email form per §13.2
- register-therapist-google    — Continue with Google + finish-profile page
- register-organization-email  — clinic founder signup with HQ address
- register-organization-google — Google OAuth org path
- email-verification-gate      — polling + auto-redirect on verified
- accept-invite-page           — /accept-invite + AcceptInvitation RPC
- login-redirect               — /login 307 → app.superwizor.ai/login
- registration-e2e-playwright  — Playwright happy-path, 2/2 green

### Slice 4 — admin console (PARTIAL, merged to `feat/web-app` at ded7f3d)
2/8 features landed; 6 deferred. The chrome + guard are in place so
features 3-8 can land in any order:
- ✅ admin-auth-guard   — /admin layout with role=SUPERWIZOR_ADMIN gate
- ✅ admin-shell-nav    — sidebar + header chrome
- ⏸ admin-orgs-list
- ⏸ admin-org-detail
- ⏸ admin-org-actions
- ⏸ admin-org-edit
- ⏸ admin-user-crud
- ⏸ admin-audit-log

### Cron-endpoint OIDC auth (branch `fix/scheduler-oidc-auth`, 2026-06-10)

Second half of the 119afdf CRM exposure fix: the 5 Cloud Scheduler cron
endpoints (`/admin/reservation-expiry`, `/admin/manual-period-renewal`,
`/admin/safety-check`, `/admin/email-drip`, `/admin/renewal-reminders`)
were publicly callable — billing-svc has allUsers invoker, so Cloud Run
IAM never validated the scheduler's OIDC token. New
`SchedulerAuthMiddleware` (billing-svc `scheduler_auth.go`) validates the
Google ID token in-process via `idtoken.Validate` (audience = billing-svc
URL) + asserts email == cloud-scheduler-billing SA. Fail-closed (503)
when `SCHEDULER_OIDC_AUDIENCE` / `SCHEDULER_SA_EMAIL` are unset. 8 unit
tests with a fake validator (evidence/fix-scheduler-oidc-auth/).
Gotchas:
- Deploy script + cloudbuild yaml switched the gcloud env-var delimiter
  from `^@^` to `^|^` — the SA email's own `@` would split the value.
- Live scheduler jobs verified (gcloud): all 3 existing jobs already
  mint exactly this SA + audience. No jobs exist yet for email-drip /
  renewal-reminders — when created, they must use the same SA/audience.
- **Not deployed yet** — needs a billing-svc deploy via
  `scripts/deploy-webapp-backend.sh` (sets the two new env vars).

## In progress

### iOS 1.0.8 (build 57) WYSLANE DO RECENZJI APPLE — 2026-08-25

Naprawa potwierdzona przez testera, wiec build 57 poszedl na produkcje.
Wersja 1.0.8 istniala jako szkic od 19.08 (na sprzedazy 1.0.7); podpiety
build 57, zgloszenie 99dde0d0 w stanie WAITING_FOR_REVIEW.
releaseType=AFTER_APPROVAL — po zatwierdzeniu wyda sie SAMO.
Notatki „Co nowego" zostaly te z 19.08 (ogolne: poprawki wizualne,
stabilnosc) — do zmiany przez wlasciciela, jesli maja opisywac
konkretne naprawy kolejki wgran.
UWAGA operacyjna: PATCH submitted=true zwrocil 500 przy pierwszej
probie, a stan mimo to zostal READY_FOR_REVIEW (nie wyslany) — ponowienie
przeszlo (HTTP 200). Przy nastepnym wydaniu: po 500 SPRAWDZAC stan,
nie zakladac ani sukcesu, ani porazki.

### Flutter: build 57 — stan serwera rozstrzyga o wierszu (2026-08-25)

Zgloszenie testera na buildzie 56: nagranie 132 min lezalo na serwerze
jako ukonczona sesja z raportem (21 sie, 131 min), a aplikacja czwarty
dzien pokazywala „Sesja nie mogla zostac wgrana". Trzy ekrany dawaly trzy
rozne odpowiedzi (baner: porazka, status: „czeka w kolejce", po sekundzie:
„Gotowe!" + raport). Przyczyna: stan serwera obserwowalismy WYLACZNIE dla
wierszy `completed`, wiec wiersz zawieszony/failed nie mial jak dowiedziec
sie, ze jego sesja jest gotowa. Fix: kazdy wiersz z sessionId jest
rozstrzygany stanem serwera (done -> wiersz znika bez alarmu; w toku albo
brak sessionId -> porazka zostaje). Drugi blad tej samej klasy:
SessionStatusScreen czytal kolejke tylko przez ref.listen (reaguje na
ZMIANY), wiec wiersz terminalny zostawal na poczatkowym „Audio czeka
w kolejce" — pierwszy odczyt idzie teraz z reki. Build 57 w TestFlight.

### Flutter: kolejka wgrań + widocznosc raportow eksperymentalnych (main, 2026-08-24)

Buildy 55 i 56 w TestFlight (upload potwierdzony). 55: PathNotFound
terminalny z uczciwym komunikatem (source_file_missing), ODZYSK zrodla
(sonda katalogu sesji: chunk_*.enc / upload.flac -> przepiecie wiersza;
root cause: encryptRecording kasuje raw.flac przed utrwaleniem fazy —
kill w oknie = wiersz wskazuje nieistniejacy plik, dane zostaja),
FIFO per kartoteka, rozrozniane numery na kartach kolejki, siatka
nawigacyjna (leading-fallback, isCurrent guard, FCM snackbar zamiast
auto-nawigacji), dedupe kart w kartotece po sesjach RENDEROWANYCH.
56: inbox listener obsluguje experimental_report_ready/skipped ->
invalidate cache sesji + zywy refresh otwartego ekranu (TTL 1 h
ukrywal drugi raport do godziny). Studio promptow: konflikt wersji
(wspolny licznik system+chat) = dedykowany komunikat + samonaprawa.
2026-08-25: jezyk raportu = jezyk kartoteki (s4/1.5.0, chrome pl/en,
label_en/title_en w metaschemacie, szkic CBT przetlumaczony roboczo);
cytaty zamiast "Dane za: sNN" (limit 3/hipoteze, kontrdowod z
"— przeczy:"); fix bramki ekstraktywnej (V5 na wzmiance nie kasuje juz
calej prozy — rozstrzyga ponowna weryfikacja przycietego raportu,
2264fe10). Kanarki na rev 00129: EN komplet (naglowki angielskie,
36 cytatow, zero DaneZa), PL komplet 8 sekcji z proza (18 hipotez,
60 cytatow, V5+V2 przyciete zamiast trybu ekstraktywnego).
F7 (docs/65): F7a-1 i F7a-2 ZROBIONE (8d8a4244) — migracje 000097
(report_spans.topics) i 000098 (report_run_context + _stats), loader S0
w llm-workerze (okno W=3, budzety K=60/S=120, adresy 's0821:s07',
granice T22 i klasy potoku w zapytaniach), bariera N4 (sesja w toku
pomijana i liczona, bez czekania). Kontekst jest LADOWANY i ZAPISYWANY,
jeszcze NIE konsumowany przez prompty — tresc raportow bez zmian.
F7a-3 ZROBIONE (82a6e23b): S2 dostaje blok ustalen TEGO konstruktu +
oddzielone fragmenty historyczne (adres sMMDD:sNN); jedna mapa spanow
uruchamia R2 (sesje!), R5 (about_past) i V1 bez zmiany ich kodu;
min_evidence.sessions przestal byc martwym zapisem; NOWA regula
R2_no_current_span (twierdzenie musi miec dowod z biezacej sesji);
renderer datuje cytat historyczny (21.08 / Aug 21). s2/1.2.0.
F7b-1 i F7b-2 ZROBIONE (25.08): indeks semantyczny na pgvector 0.8.1
(byl juz zainstalowany) z modelem text-embedding-005 (ten sam, co
legacy-RAG — ta sama przestrzen wektorowa, koszt znany). Migracje
000099 (report_inference_index) i 000100 (similarity + liczniki
semantyczne). Retrieval DOKLADA do okna, nigdy go nie zastepuje;
kwerenda ze streszczenia i tematow call-1 (juz spseudonimizowanych).
Semantyka DOMYSLNIE wlaczona na powierzchni eksperymentalnej (org
z REPORT_EXPERIMENTAL_ENABLED dostaje ja bez osobnego wpisu), raport
produkcyjny wymaga jawnej flagi — uzasadnienie w docs/65 §7a.
Flaga wlaczona jawnie dla 3da34bab.
Kanarek F7b-1 zlapal, ze source_claim_id bylo puste we wszystkich
wierszach (zapytanie F7b-2 tego wymaga — wyszukiwanie nie znalazloby
NIGDY niczego, wygladajac na brak historii); naprawione: Persist
zwraca ClaimIDs.
docs/65 przepisane z planu na stan faktyczny (§9: sciezka danych,
piec wad znalezionych kanarkami, tabela wersji).
Kanarek F7b-2 (raport f336af8a, kartoteka Janek Johny CBT): semantyka
DZIALA — 8 twierdzen z sesji SPOZA okna, podobienstwo 0.587-0.655,
1 odrzucone progiem, kanal i podobienstwo w rejestrze, trafienia
dokladnie w konstrukty w grze. ALE zero cytatow historycznych
w twierdzeniach: S2 zobaczyl historie i jej nie uzyl, bo nic go nie
zmuszalo. Wniosek projektowy (docs/65 §9.4): kontekst ma strukturalny
ciag tylko tam, gdzie ontologia deklaruje min_evidence.sessions —
dzis wylacznie Gestalt unfinished_business. DECYZJA EKSPERCKA: dopisac
prog `sessions` konstruktom miedzysesyjnym (np. core_belief w CBT) albo
oprzec sie na kanale ciaglosci F7b-3.
ZOSTAJE: F7b-3 (kanal ciaglosci hipotez + V8), F7b-4 (benchmark
powtarzalnosci — BRAMKA przed semantyka w raportach produkcyjnych).

F7a-5 ZROBIONE (kanarek 25.08, rev 00132, raport 5b703f65): kontekst
zaladowany (okno=3, 2 sesje, 37 twierdzen + 43 spany, zero przyciec),
report_run_context ma wpisy z OBU sesji zrodlowych, w tresci raportu
DWA datowane cytaty historyczne „(20.08)", proza o ciaglosci sie
obronila, V7 spadl z 8 naruszen do 1, brak trybu ekstraktywnego.
Kanarek znalazl po drodze TRZY wady, kazda naprawiona:
 - 6ed7aaf4: Persist nie umial dowiazac cytatu z wczesniejszej sesji
   (Pub/Sub ponawial caly przebieg co 6 min, 6 duplikatow raportu —
   usuniete; wiadomosc-trucizne zdjeto seekiem),
 - 8138ce1c: enum S4 nie zawieral adresow historycznych, wiec regula V7
   byla NIE DO SPELNIENIA (8 naruszen na przebieg),
 - identyfikatory spanow wyciekaly do prozy (33 na raport z kontekstem,
   0 bez) — regula 12 + scrubber w rendererze, s4/1.7.0.
CALY F7a ZAMKNIETY. Nastepne: F7b (indeks semantyczny, docs/65 §5) —
regula F7b to V8, V7 zajety.

F7a-4 ZROBIONE (7fed7581): S4 dostaje USTALENIA Z POPRZEDNICH SPOTKAN
(konstrukty w grze) + oznaczenie „· SPOTKANIE 21.08" przy cytatach
historycznych; NOWA regula V7_ciaglosc_bez_zakotwiczenia (zdanie
o powrocie watku bez cytatu z tamtego spotkania = naruszenie, przyciecie
per hipoteza); regula spi w potoku jednosesyjnym. s4/1.6.0, regula 11
w prompcie. UWAGA: V7 zajety — regula F7b dostaje V8 (docs/65 §5.4).
NASTEPNE: F7a-5 — kanarek konca do konca. Wymaga materialu: kartoteka
z >=2 sesjami majacymi raporty TEJ SAMEJ klasy potoku (eksperymentalne
widza tylko eksperymentalne), najlepiej Gestalt z progiem
unfinished_business sessions:2. UWAGA przy kanarku: kontekst historyczny wymaga, by
poprzednie sesje mialy raporty TEJ SAMEJ klasy potoku (eksperymentalne
widza tylko eksperymentalne).
OTWARTE poza F7: bramka "modalnosc bez ontologii" w
maybeDualRun wychodzi bez zapisu pominiecia (ciche skip_reason);
brak bramki jezykowej w dual-run (decyzja produktowa).


### Ontologia F2/M5+ — uklad nazwanych sekcji (main, db67ff91, 2026-08-24)

Raporty eksperymentalne lustrzane wobec soczewek legacy: `report_profile.layout`
(uporzadkowane sekcje, XOR z wagami) w metaschemacie + walidacja; S4 generuje
suggestions/interventions wylacznie na zamowienie ukladu (basis_construct jako
enum); renderer ze sciezka layout i ogonem never-hide; seedy PPT+CBT po 8 sekcji
(Gestalt celowo przy wagach — lustro procesu, dok. 15). Studio: panel kompozycji
przy ukladzie pokazuje liste zamiast wag (inaczej dokument niewalidowalny),
diff pokrywa uklad. Drafty w DB zaktualizowane (dbw, "wersji z layout: 2").
STAN: DOMKNIETE 2026-08-24. Deploy (uzytkownik uruchamial terragrunt — klasyfikator
trybu auto blokuje apply w tej sesji; rewizje 00126, potem 00127). Kanarki rundy 1
wykryly regresje: pruneViolating budowal Report od zera i przenosil same
Constructs — suggestions/interventions ginely z kazdego raportu z naruszeniem V
(fix a67b0bd0, test lamany celowo). Runda 2 na 00127: PPT komplet 8 sekcji w
kolejnosci soczewki; CBT komplet poza znanymi lukami (cbt_episode bez S2
composite; „Czego mozna bylo nie zauwazyc" znika gdy brak kontrdowodow — by
design). Puste sekcje znikaja z zalozenia, wiec sklad naglowkow moze sie roznic
miedzy przebiegami. Luki nazwane w komentarzach
seedow: TWARDE USTALENIA (ekstrakcja ustalen w S1 — osobny ticket), komentarz
superwizyjny o technice terapeuty (decyzja produktowa przy R10), sekwencja
cbt_episode (S2 composite).


### Pacjent→Klient w produkcie (branch `feat/rename-patient-client-labels`, 2026-06-12)

Dokończenie de-medykalizacji: backend `pkg/i18n/rolelabels` — `therapy|patient`
generuje teraz „Klient"/"Client" (wszystkie 14 języków, identycznie jak
coaching); testy zaktualizowane, zielone. Flutter: `app_pl.arb` (14 stringów)
+ regeneracja l10n + 2 hardkodowane 'Usuń pacjenta' w home_screen*.dart.
Dokumenty prawne: 6 przykładów etykiet zaktualizowanych na „Klient" (zero
Pacjent/Patient w 12 dokumentach). Prompty LLM w llm-worker celowo NIE
ruszone (wewnętrzne, wpływ na jakość diaryzacji). Istniejące sesje zachowują
zapisane etykiety „Pacjent" (dane historyczne w speaker_label_mapping).
NIEZMERGOWANE — czeka na decyzję; deploy etykiet = terraform cloud-functions
(llm-worker). UWAGA dysk: przejściowe ENOSPC przy ciężkich komendach —
czyść flutter build/ + Xcode DerivedData.

### Legal docs v2 (branch `docs/legal-docs-v2`, 2026-06-12) — MERGED to main (0d446c9)

Audited `flutter-app/superwizor/assets/legal/*` against the live architecture
and rewrote all 6 docs (PL+EN: privacy policy, DPA, terms). Key fixes: speaker
labels are role-aware since 2026-05-25 (was "Osoba 1/2 only"); org-policy
claims (`gcp.resourceLocations`, `sql.restrictPublicIp`,
`iam.disableServiceAccountKeyCreation`) are NOT live → softened to IaC-based
claims; Cloud SQL has an authorized public network (contradicted "no public
IP"); added missing sub-processor Resend (US, SCC) + corrected Stripe entities
(DPF); scoped "all data in EEA" to patient session data (Firebase Auth/FCM are
global); RAG described as pseudonymized summary+themes (not "anonymized");
DPA sub-processor list now patient-data-scoped (Stripe/Resend removed); terms
gained: MDR not-a-medical-device, AI Act transparency, UŚUDE unlawful-content
ban, art. 473 §2 KC liability carve-out, przedsiębiorca-na-prawach-konsumenta
section (§12, renumbered §13-15), venue carve-out. DPA cross-refs updated.
Engineering gaps flagged (purger not scheduled; drip emails ignore marketing
consent + no unsubscribe; org policies not applied). Do NOT merge without
explicit user sign-off — legal content.

Website (superwizor.ai) legal docs added on the same branch: replaced the
placeholder drafts in marketing-site/src/content/legal/{pl,en}/ (which named
the wrong company, "Superwizor sp. z o.o.") with the corrected app docs;
privacy.md gained a website-specific Part III (contact form, registration,
Stripe Checkout, Tally lead magnet, server logs, cookies — site has NO
analytics). lastUpdated bumped in legal/[slug]/page.tsx. Verified: dev render
+ full pnpm build, SSG HTML contains new content in both locales. Gotcha:
`pnpm` from PATH resolves to corepack pnpm 11 which crashes on Node 20
(node:sqlite) — use /usr/local/bin/pnpm. Site build was also broken by a stale
node_modules copy of @superwizor/proto-ts (file: dep) — `pnpm install`
refreshed it; lockfile committed. The LegalDraftBanner ("wersja robocza")
stays up pending lawyer sign-off.

### Corrupt-FLAC on pause/resume (branch `fix/corrupt-flac-pause-resume`, 2026-06-12)

Incident: session `028b7dcc-…` (patient "Maciek", 2026-06-12 16:04 CEST) stuck
in TRANSCRIBING → would auto-FAIL. Root cause: client recorded with an
interruption (phone call → pause/resume); the produced FLAC has a corrupt
STREAMINFO (header claims 14 s) + non-monotonic frame DTS, but the real audio
is ~32 min. ingestion-svc's `ProbeDuration` trusted the 14 s header ⇒ skipped
chunking ⇒ whole >20-min file sent to Chirp ⇒ rejected "too long" ⇒ no output
JSON ⇒ stt-finalize never fired. (The chunker's `ffmpegExtractSlice` was already
hardened for non-monotonic DTS via `+genpts` for session e55b7c1e — but the
*probe* that gates chunking was not.)

Two-layer fix (both layers, per user):
- **Server (ingestion-svc):** `ProbeDuration` now cross-checks the header
  duration against file size; if implausible (>1 MB/s ⇒ corrupt container) it
  re-derives the true duration by full PCM decode-count, and returns a
  `suspect` flag. Subscriber normalizes suspect FLACs through the existing
  ffmpeg re-encode (clean STREAMINFO + monotonic timeline) before chunking.
  Universal P1 safety net for ANY malformed audio on the plainFile path.
- **Client (Flutter):** `RecordingService` latches a sticky `hadInterruption`
  flag (set whenever an OS interruption occurs, reset on `start()`).
  `recording_screen.dart` uploads interrupted recordings as `audio/x-flac` +
  `needsServerSideConversion` (same established pattern as orphan recovery), so
  the server re-encodes a clean header. NOTE: scoped to the online plainFile
  path; offline encrypted-chunk path relies on the server probe net. Needs
  on-device QA (reproduce phone-call interruption).

- **Slice 5** — Flutter Web consoles at `app.superwizor.ai`. Branch:
  `feat/web-app-slice-5` (branched off post-Slice-4-partial merge).
- ✅ flutter-web-target — web platform live, build green, recording
  screen kIsWeb-guarded. Login renders cleanly on web.

### Upload stall on large files (branch `fix/upload-stall-resilience`, 2026-06-10)

Off `main` (2c771b3). **Not yet merged** — awaiting device verification on
Marcin's iPhone (the 127 MB session from the field report is the test case).
Full writeup: docs/26 §R2.

- **Bug (field, Marcin):** 127 MB upload frozen at 57 %, "próba 3", minutes
  of no movement. Resumable transport (docs/26) worked — failure handling
  around it didn't.
- **Fix (all client-side, `lib/uploads/`):** (1) timeouts on every HTTP
  call (30 s probe; `30s + size/40KiB·s⁻¹` body PUTs) — a stalled socket
  used to hang `putBytes` forever and freeze the runner's tick loop via
  `_tickInFlight`; (2) transient chunk errors retry **in-attempt** against
  the re-probed GCS offset (2→32 s, escalate only after 5 zero-progress
  rounds); `UploadProgressMadeError` tells the worker to reset
  `attemptCount` when bytes moved; `created`-phase backoff capped at 90 s
  (`putRetryCap`); (3) connectivity-restore pulls `nextAttemptAt` to now
  (was: tick fired but `dueNow()` skipped the backed-off row); (4) probe
  offsets report to the progress bar immediately + intra-chunk 64 KiB
  streamed progress (`_ProgressedBytesRequest`, honest via dart:io socket
  backpressure).
- **Gotchas:** worker `attemptCount` legitimately resets to 0 on every
  successful phase transition (`_doCreate` etc.) — don't assert it
  survives to `completed`. `http.MockClient` materializes streamed
  request bodies, so `onSent` slice callbacks fire in tests. The
  exponential ladder is *correct* for RPC phases (server protection) —
  only the PUT phase is capped.
- **Tests:** new `test/uploads/upload_io_resumable_test.dart` (fake GCS
  resumable session: blips, partial acks, dead session 410, stuck
  escalation, single-PUT fallback) + 4 worker + 1 runner test.
  `test/uploads/` 100/100, full suite 195 green, analyze clean.

### Flutter audio-conversion data-loss fix (branch `fix/app-audio-conversion`, 2026-06-04)

Commit `85c6cc3`, off `main`. **Not yet merged** — awaiting device smoke
test on Marcin's iPhone build.

- **Bug:** file-upload → "Konwertuję" screen → tapping back lost the
  whole session (also app-kill / OS cache purge mid-convert). Root
  cause: client-side conversion (M4A→FLAC, WAV normalize) ran as an
  inline `await` inside `NewSessionScreen` *before* any durable
  `PendingUpload` existed — an interruption returned early past the
  enqueue, and the `finally` even deleted the converted output.
- **Fix:** conversion is now a durable queue phase
  (`UploadPhase.converting`). The row is persisted to Hive the instant
  the file is staged; `UploadIo.convertSource` runs the transcode in
  the worker (writing the FLAC into `queued_uploads/<localId>/`,
  durable + swept by `cleanupSource`); iOS decode-failure / non-iOS
  fall back to the original + `needsServerSideConversion=true` (server
  ffmpeg, no data loss). New `UploadQueueRunner.enqueue()` persists
  without ticking so the screen navigates immediately instead of
  blocking on the first (minute-long) transcode tick. Cancel now works
  during conversion. Gotcha for next time: `copyWith` had to gain
  `sourcePath/contentType/sizeBytes/actualDurationSeconds` params (were
  immutable post-construction) so the worker can repoint the source at
  the transcoded file.
- **Tests:** 4 new converting-phase worker tests; `upload_worker_test`
  +25 / `upload_queue_test` +10 / `pending_upload_test` +7 all green;
  `flutter analyze` 0 new issues. NOTE: `upload_state_transitions_test`
  (+2 −13) and `upload_queue_runner_test` (+3 −7) have **pre-existing**
  flaky failures — verified identical on the clean baseline via
  `git stash` (real-timer/Hive runner-lifecycle tests:
  retryFailed/dismiss/connectivity). Worth a separate cleanup task.
  Evidence: `evidence/fix-app-audio-conversion/`.

### Recording lost on phone call (branch `fix/recording-call-interruption`, 2026-06-09)

Off `main` (83b6e41…). **Not yet merged** — code complete
(WS1–**WS5** of `docs/31_RECORDING_INTERRUPTION_RESILIENCE.md`), awaiting the
on-device manual matrix (docs/28 §8.3 M1–M10) on physical iPhone **+ Android**;
phone-call interruptions can't be simulated.

- **Bug:** incoming phone call during a session recording → recorder
  natively auto-pauses (record_ios `AudioInterruptionMode.pause` default)
  and never resumes; app never subscribed to `onStateChanged` so UI kept
  saying "recording"; if the backgrounded app was killed during the call,
  the partial `raw.flac` was orphaned with no recovery path → session
  totally lost.
- **Fix:** (1) durable `manifest.json` written next to `raw.flac` at
  recording start + once-per-launch orphan-recovery scan with send/later/
  delete sheet on HomeScreenV2 (`RecordingRecoveryGuard`); (2) native
  state sync with intent timestamps → new `RecordingState.interrupted` +
  banner, frozen duration clock; (3) verified resume: iOS
  `superwizor/audio_session` MethodChannel reactivates the AVAudioSession
  (plugin's resume never does), then a **file-growth probe** confirms
  capture (plugin's `isRecording()`/state stream flip optimistically even
  when `AVAudioRecorder.record()` fails — verified in plugin source, do
  NOT trust them); (4) `actualDurationSeconds` excludes interruption gaps.
- **Gotchas for next time:** `RecordingService` now takes injectable
  recorder/documentsDir/wakelock for tests; plugin `isPaused()` is the
  meaningful reconcile probe (`isRecording()` = `state != stop`, so
  paused counts as recording!); new Swift file had to be hand-added to
  `project.pbxproj` (4 entries, mirror AudioConverter.swift).
- **WS5 — Android foreground service (NOW IMPLEMENTED):** `record` plugin
  has no FGS, so a backgrounded Android recording dies on a long call.
  Added `RecordingForegroundService.kt` (microphone FGS +
  `START_NOT_STICKY` + ongoing notification), `superwizor/recording_fgs`
  channel in `MainActivity.kt`, `<service microphone>` +
  `POST_NOTIFICATIONS` in the manifest, and
  `recording_foreground_service.dart` (best-effort, Android-only, never
  aborts recording). Notification strings flow from the l10n pipeline
  (`recording_fgs_notification_*`); Kotlin has PL fallbacks. Started in
  `RecordingService.start`, stopped on stop/cancel/unexpected-stop.
- **R1 RESOLVED — recovered FLAC forced through server ffmpeg:** instead
  of betting Chirp accepts an unfinalized FLAC header, `recover()` uploads
  with content-type **`audio/x-flac`** (a real FLAC MIME that's NOT in the
  server's `IsChirpSupported` list) → ingestion-svc runs its lossless
  ffmpeg re-encode → clean header. Server's ext-map defaults unknown types
  to `.flac` so ffmpeg demuxes correctly; a `audio/mp4` mislabel would
  break the demuxer (`.m4a` path), hence x-flac. **Backend gotcha:** the
  coupling lives in `converter.go:IsChirpSupported` — locked by a new case
  in `converter_test.go` (`audio/x-flac` → false). The local
  `needsServerSideConversion` bool is NOT sent on the RPC; content-type is
  the only server trigger.
- **Tests:** 26 recording unit tests green + backend `TestIsChirpSupported`
  green + `go build ./services/ingestion-svc/...` clean; full Flutter suite
  181 green, analyze at 20-issue baseline.

### Out-of-slice fixes / improvements landed 2026-05-29

All on `feat/web-app`. Independent of any specific slice; ship-ready as
hotfixes to the in-flight web build.

- **Therapist `/account/` page first-class on the marketing origin.**
  Profil + Organizacja + Subskrypcja sections, all PL+EN, with i18n
  ARB-equivalent keys under the `account.*` namespace. Profil + Org are
  collapsible (default-closed) and use a +20% bigger input variant per
  user feedback. Header (email + Otwórz kartoteki + sign-out) also +20%.
  Commits: `5725d12`, `ffbf113`, `2f474aa`, `6e1b3d9`.
- **Subskrypcja card calls billing-svc directly** (`aff0e8e`+
  `2b29922`). The earlier `clinical.GetMyBillingState` proxy was
  intermittently RST_STREAM-ing inside Cloud Run; bypassing it matches
  the proven /admin/orgs `ZMIEŃ PLAN` pattern. **Pre-req on the
  backend:** `billing-svc.GetSubscription` now enforces caller-org
  scope (commit `7e4f2d9`, deployed as `billing-svc-00086-vwt`) — the
  Connect interceptor populates `x-superwizor-organization-id` from
  the validated Firebase token, and any browser caller whose org
  doesn't match the requested `organization_id` gets
  `PermissionDenied`. Server-to-server callers (native gRPC, no
  metadata) bypass; `SUPERWIZOR_ADMIN` bypasses for cross-org reads.
- **Post-email-verification redirect → same origin `/account/`.**
  `ResendVerificationButton.tsx` polls `currentUser.reload()` and on
  `emailVerified=true` now navigates to `/${locale}/account/` instead
  of `https://superwizor-app.web.app/`. Avoids the cross-origin
  re-login that killed the just-completed signup (Firebase Auth
  IndexedDB is origin-scoped). i18n key renamed
  `verifiedGoToApp` → `verifiedGoToAccount`. Commit `18d7030`.
- **Cross-origin SSO from marketing-site → Flutter app.** Otwórz
  kartoteki on `/account/` now mints a short-lived Firebase custom
  token via `identity-svc.MintAppLoginToken` (new RPC), opens
  `https://superwizor-app.web.app/#auth_token=<jwt>` in a new tab, and
  the Flutter web bundle redeems via `signInWithCustomToken` before
  `runApp` (conditional import on `dart.library.html` keeps iOS/Android
  untouched). Token is in the URL fragment, not the query string —
  hashes don't reach Firebase Hosting logs and aren't included in
  Referer headers on outbound clicks. On any failure (mint RPC down,
  popup blocked, token expired) the flow gracefully degrades to the
  pre-SSO `?email=` prefill so the user can still log in by hand.
  Backend commit `fbc3b67`, marketing-site `aff0e8e`, Flutter web
  `3d55ae7`. One-time IAM: granted
  `roles/iam.serviceAccountTokenCreator` to the compute SA on itself
  so the Admin SDK can sign custom tokens via the IAM Credentials API
  without an SA private-key JSON. Switched identity-svc Firebase init
  from `option.WithoutAuthentication()` → plain `firebase.NewApp` so
  it can resolve ADC for the signing call.
- **billing-svc `ConnectErrorInterceptor`** (commit `2b7919f`,
  deployed `billing-svc-00087-ddr`). Connect-Go does not auto-translate
  `status.Errorf(codes.X, ...)` errors — it sees a plain `error` and
  wraps them as `connect.CodeUnknown`, so every admin browser RPC
  surfaced as "Wystąpił nieznany błąd" regardless of the real cause
  (PermissionDenied, FailedPrecondition, NotFound, Internal…). The new
  interceptor sits after the auth interceptor, translates 1:1, and
  slogs the original error type + procedure path so handler-side
  failures are visible in Cloud Logging. **Action item:** the SAME
  bug almost certainly exists in identity-svc and clinical-svc's
  Connect chain; lift the interceptor into `pkg/connectmd/` and add
  to all three services in a follow-up.
- **Staging Cloud SQL schema synced to migrations 035, 036, 037.**
  The webhook + audit flow had been silently failing for weeks
  because `audit_events.reason` didn't exist on staging Postgres —
  `golang-migrate up` against `superwizor-db-bc4c27de` applied
  invitations (035), audit_events.reason (036), and user_role_extend
  (037). DB is now at version 37, dirty=false. Done via cloud-sql-proxy
  on port 5438 with the password from the `superwizor-db-password`
  Secret Manager secret.

### Known-but-deferred

- **Marcin's stuck audio upload (session `5930f11c-...`).** Row in
  `audio_uploads` has status=PENDING, content_type=audio/flac, NULL
  file_size_bytes — Flutter never PUT to GCS. GCS audit logs confirm
  no PUT attempt. Two `billing reserve` log lines 6 min apart show
  the worker is retrying CreateAudioUpload (the `signedUrlExpired`
  classify path bounces phase=created → phase=pending after the PUT
  fails locally on Marcin's phone). Root cause is on his iPhone (most
  likely `file.readAsBytes()` throwing because iOS purged the tmp
  FLAC file between conversion + PUT). Row auto-expires
  `2026-05-31 11:11:28 UTC`; reserved token is released then.
  Definitive fix is the post-`a5e8f4c` Flutter build (M4A→FLAC
  staging-dir fix) but install on Marcin's iPhone is blocked on the
  Apple Developer Personal Team bundle-ID reclaim (task #147).
- **Apple Developer Personal Team reclaimed `ai.superwizor.superwizor`.**
  Xcode can't re-register the App ID; iOS builds for new devices
  fail at the provisioning step. Pending path chosen with the user:
  change bundle ID to `ai.superwizor.therapist`, register the new
  ID in Firebase Console (manual step the user owns), then update
  Xcode project + `GoogleService-Info.plist`. Long-term fix is
  enrolment in the paid Apple Developer Program.

## Slice plan (Slices 2-6)

Each slice branches `feat/web-app-slice-N` off the previous slice's merged
state. Slice merges into `feat/web-app` (NOT main) after evaluator PASS on
every feature.

### Slice 2 — `marketing-site-foundation`
Scaffolds Next.js, brand tokens, i18n, Connect-RPC client, Firebase Auth,
public marketing surface. Unblocks all registration/admin work.

1. `nextjs-scaffold` — Next.js App Router scaffold with Tailwind + brand tokens
2. `next-intl-pl-en` — next-intl wired with PL/EN, as-needed routing, hreflang
3. `connect-rpc-client` — Connect-ES generated clients + Firebase ID-token interceptor
4. `firebase-auth-init` — Firebase Web SDK init (Email/Password + Google) + emulator support
5. `landing-page` — Landing page (hero, screenshots, CTA) in PL+EN
6. `pricing-page` — Pricing page reading subscription_plans via Connect-RPC
7. `legal-static-pages` — Terms / Privacy / DPA markdown pages in PL+EN
8. `firebase-hosting-deploy` — Firebase Hosting site superwizor-www + CI deploy step

### Slice 3 — `registration-flows`
Therapist + org self-serve registration (email/pwd + Google), magic-link
invitation accept page. Verifies Slice 1 RPCs end-to-end.

1. `register-therapist-email` — /register/therapist email+password form per §13.2
2. `register-therapist-google` — Google OAuth path + /register/therapist/finish profile page
3. `register-organization-email` — /register/organization email+pwd form per §13.3
4. `register-organization-google` — Google OAuth org path + finish page
5. `email-verification-gate` — sendEmailVerification + verification-required interstitial
6. `accept-invite-page` — /accept-invite token validation + password set + AcceptInvitation RPC
7. `login-redirect` — /login as <a> redirect to app.superwizor.ai/login (R3 origin discipline)
8. `registration-e2e-playwright` — Playwright happy-path: therapist register → Trial → redirected

### Slice 4 — `admin-console`
Internal Superwizor admin panel at `superwizor.ai/admin/*`. Replaces psql
+ bash for support ops.

1. `admin-auth-guard` — Next.js middleware gating /admin/* on role=SUPERWIZOR_ADMIN
2. `admin-shell-nav` — Admin shell (sidebar, user menu, breadcrumbs) in PL+EN
3. `admin-orgs-list` — Orgs list with filters, pagination, TanStack Table
4. `admin-org-detail` — Org detail: usage chart, therapist list, audit panel
5. `admin-org-actions` — Block/unblock, AdminResetTokens, AdminChangePlan with reason dialogs
6. `admin-org-edit` — AdminUpdateOrganization form per §13.7
7. `admin-user-crud` — User list + AdminUpdateUser / AdminDeleteUser per §13.8
8. `admin-audit-log` — Global audit_events viewer with actor/action/date filters

### Slice 5 — `flutter-web-consoles`
Flutter Web for therapist console + org-admin tab on `app.superwizor.ai`.

1. `flutter-web-target` — flutter create --platforms web + kIsWeb branches
2. `flutter-web-login` — Login on app.superwizor.ai with Email/Pwd + Google
3. `flutter-web-therapist-console` — Kartoteki + sessions + transcript + report on web
4. `flutter-web-profile-edit` — Profile edit per §13.4 (UpdateMyProfile, avatar upload)
5. `org-admin-route-guard` — /admin route gated on role=ORG_ADMIN
6. `org-admin-therapists` — Therapists tab: list + InviteTherapist + RemoveTherapist
7. `org-admin-org-settings` — Org settings form per §13.5
8. `org-admin-billing-readonly` — Billing view (subscription, tier, usage, reservations)

### Slice 6 — `i18n-polish-launch`
i18n contract closure, error handling, email templates, both-locale E2E,
DNS cutover. Unblocks production launch.

1. `notification-svc-i18n-templates` — PL+EN for invitation/verify/quota emails
2. `error-code-translation-map` — Frontend error-code → translation map
3. `empty-loading-error-states` — Empty states, skeletons, toasts across surfaces
4. `l10n-parity-ci` — scripts/check-l10n-parity.sh + §13.11 drift test
5. `playwright-e2e-both-locales` — Happy-path E2E run once per locale
6. `shared-machine-warning` — Flutter Web shared-machine login notice
7. `production-dns-cutover` — DNS cutover to Firebase Hosting

## Notes / gotchas

- **Branch `fix/stt-stuck-pending-resubmit` (unmerged, off `main`, 2026-06-26):**
  Follow-up to the per-file fix below. Handles the *other* transient Chirp
  mode — an op that hangs `PENDING` forever (`done=false`, no error code),
  which the per-file path can't catch and `reapStuckSessions` only FAILs at
  26h. The watchdog's still-PENDING branch now cancels + re-submits a hung op
  (shared `maxChunkRetries` budget). Trigger needs BOTH age past a give-up
  window AND `metadata.update_time` stale — the staleness gate tells "one op
  hung" apart from "whole queue slow" and avoids a resubmit storm. Pure
  decision `shouldGiveUpOnPendingOp` is unit-tested (`TestShouldGiveUpOnPendingOp`);
  env knobs `STT_PENDING_GIVEUP_HOURS` (3), `STT_PENDING_STALE_MINUTES` (45).
  No new migration. **MERGED to `main` + pushed (commit `dac274b`) and
  deployed to staging** (stt-worker/finalize/watchdog redeployed ACTIVE
  2026-06-26 ~20:37 UTC; post-deploy watchdog smoke returned "0 stuck
  operations", confirming the new `submitted_at` projection runs clean). A
  live hung-op re-test isn't reproducible (can't make Chirp hang on demand),
  so the branch logic is verified by unit test + build/vet/test green rather
  than a staging replay.
- **Branch `fix/stt-per-file-transient-retry` (MERGED to `main` + pushed
  2026-06-26, commit `dd58b76`; migration 000060 applied to staging):**
  stt-worker watchdog used to mark a session FAILED on ANY non-zero Chirp
  per-file error code, so a transient `code=13 INTERNAL` on one chunk killed a
  49-min clinical session (incident `12c76823`). Fix: `isTerminalStatusCode`
  (single classifier; `isTerminalSTTError`'s gRPC branch delegates to it),
  watchdog now re-submits a fresh BatchRecognize on transient per-file codes
  (`resubmitChunk`, bounded by `maxChunkRetries=3`); migration **000060** adds
  `stt_operations.retry_count` + `source_audio_uri`. **Deployed to staging**
  (migration applied — staging DB at version 60; stt-worker/finalize/watchdog
  redeployed) and verified end-to-end: the watchdog auto-reclassified the real
  `code=13` and re-submitted instead of failing; session `12c76823` recovered
  to a 5759-word `pl-PL` transcript (`ANALYZING`). Gotcha observed: a
  re-submitted Chirp dynamic-batch op can hang *individually* for hours while
  the rest of the queue is healthy — the watchdog correctly leaves a stuck
  *pending* op alone (only done-with-transient-error triggers re-submit).
  NOT merged to main — confirm with user. Evidence under
  `superwizor-backend/evidence/fix-stt-per-file-transient-retry/`.
- **Toolchain ready:** Node 20.20.2 + pnpm 9.15.9 installed. Node 20 is
  keg-only at `/usr/local/opt/node@20/bin/node`; PATH is persisted in
  `~/.bash_profile` so every new login shell sees it. Corepack's pnpm
  shim was disabled (`corepack disable pnpm`) and pnpm@9 installed via
  npm-global so it resolves through `/usr/local/bin/pnpm` →
  `pnpm.cjs` running under node@20. `bash -lc 'node --version && pnpm
  --version'` should print `v20.20.2` and `9.15.9` from any new shell.
  The legacy 2017 Node v6 at `/usr/local/bin/node` is left in place but
  shadowed by node@20 via PATH order. Do NOT call `node` by absolute
  path `/usr/local/bin/node` — that hits v6 and will SyntaxError on
  modern JS.
- `feat/web-app` does NOT merge to main until end-to-end web is verified.
  Per-slice branches merge back into `feat/web-app`.
- Manual ops still pending: Firebase Console — enable Apple + Microsoft
  providers (task #64); SUPERWIZOR_ADMIN bootstrap SQL after a real
  account exists in Slice 3.
- sqlc tricky bits: `UpdateOrganizationParams.Type` is
  `*db.OrganizationType` (pointer), not `NullOrganizationType` — see
  `services/identity-svc/internal/handlers/org_profile.go`.
- `db.Subscription` has no `PlanTier`/`PlanCycle` fields directly — use
  `GetActiveSubscriptionByOrg` which JOINs `subscription_plans`.
- idtoken import path: `google.golang.org/api/idtoken` (NOT the
  oauth2/google variant).
- pkg/cors origins come from `CORS_ALLOWED_ORIGINS` env (terraform sets
  superwizor.ai + app.superwizor.ai + localhost on staging).
- Polish strings must route through next-intl translation keys — no
  hard-coded Polish in components.
- Evidence pattern: `evidence/slice-N/<feature-id>/<step>.{png,log}`.
  Evaluator denies a feature without evidence opened in-session.
