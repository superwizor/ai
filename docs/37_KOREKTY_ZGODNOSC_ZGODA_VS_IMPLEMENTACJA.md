---
type: System Documentation
title: "37 — Korekty: zgodność wzoru zgody z implementacją"
description: "Źródło: audyt WzorZgodaSesjeTERAPEUTAv0.122026-07-02.docx ↔ kod (2026-07-03). Werdykt: dokument w większości zgodny; 4 istotne rozbieżności — 2 do poprawy w ..."
resource: file:///Users/maciekckoklormam91/Desktop/Inne/APP%20-%20Superwizor%20AI/docs/37_KOREKTY_ZGODNOSC_ZGODA_VS_IMPLEMENTACJA.md
tags: []
timestamp: 2026-07-02T23:34:01+02:00
---

# 37 — Korekty: zgodność wzoru zgody z implementacją

Źródło: audyt `Wzor_Zgoda_Sesje_TERAPEUTA_v0.12_2026-07-02.docx` ↔ kod
(2026-07-03). Werdykt: dokument w większości zgodny; 4 istotne rozbieżności —
2 do poprawy w dokumencie (→ v0.13), 2 w kodzie (w tym 1 luka bezpieczeństwa).

## 1. Macierz rozbieżności (skrót)

| # | Twierdzenie zgody | Stan faktyczny | Korekta w |
|---|---|---|---|
| R1 | „nagranie usuwane **zaraz po** transkrypcji" (str. 1) | Pipeline po STT nie kasuje audio; usuwa je reguła GCS lifecycle `age=2` (48 h) — `infra/modules/storage/main.tf:34-42`. Str. 2 pkt 6 („najpóźniej po 48 h") jest poprawna | dokument **lub** kod (§3.3) |
| R2 | „dane sesji **nie są przekazywane poza EOG**"; subprocesor tylko Google Cloud | Plan działań (treść pochodna sesji) wysyłany e-mailem przez **Resend, Inc. (USA)** — `notification-svc/internal/adapters/grpc/action_plan_email.go:45-48`. Polityka prywatności wymienia Resend + SCC, zgoda go pomija | dokument + docelowo kod (§4) |
| R3 | „raport **oznaczany w aplikacji** jako treść wygenerowana przez AI" (pkt 9) | Brak jakiegokolwiek oznaczenia w `report_screen.dart`; brak klucza i18n | kod (§3.2) |
| R4 | „dostęp mam **wyłącznie ja**" | `GetSessionDetails` nie sprawdza właściciela — IDOR na odszyfrowane PHI (`clinical-svc/.../session.go` ~47; `GetSession` = `WHERE id=$1` bez `therapist_id`, `queries/sessions.sql:125-127`) | kod (§3.1, **krytyczne**) |

Twierdzenia zweryfikowane jako **zgodne**: tylko dźwięk; brak wersjonowania
bucketa (nieodtwarzalność po usunięciu); kasowanie z urządzenia natychmiast po
uploadzie; etykiety ról Terapeuta/Klient/Osoba N generowane programowo
(`pkg/i18n/rolelabels`); szyfrowanie kopertowe KMS transkryptów / segmentów /
raportów / notatek / pamięci RAG + CMEK na Cloud SQL; regiony EOG (GCS +
Cloud SQL `europe-central2` Warszawa, STT `eu-speech`, LLM Vertex Gemini
`europe-west4` Holandia — „Warszawa, Holandia" w zgodzie się zgadza);
Firestore bez PHI (status + notyfikacje); brak trenowania AI (warunki
Google Cloud/Vertex); pamięć kontekstowa istnieje (`summary_short` + RAG,
szyfrowane); art. 22 — raport pomocniczy, decyzje terapeuty.

## 2. Korekty w dokumencie zgody (→ v0.13)

1. **Str. 1, „Najważniejsze informacje":** zamienić
   „Nagranie jest trwale usuwane zaraz po wykonaniu transkrypcji." na
   „Nagranie jest trwale i automatycznie usuwane najpóźniej w ciągu 48 godzin
   od przesłania." (spójnie z pkt 6). *Jeśli* zaimplementujemy §3.3, można
   przywrócić „zaraz po transkrypcji, najpóźniej w ciągu 48 godzin".
2. **Pkt 2 (Podmiot przetwarzający) i pkt 5 (Odbiorcy):** do czasu migracji z
   §4 dopisać: „Resend, Inc. (USA) — wysyłka wiadomości e-mail (w tym planu
   działań przekazywanego klientowi na jego adres e-mail); transfer na
   podstawie standardowych klauzul umownych (art. 46 ust. 2 lit. c RODO)."
   Oraz złagodzić zdanie kategoryczne: „Dane sesji przechowywane są wyłącznie
   w EOG; wysyłka e-mail do klienta realizowana jest przez dostawcę
   wskazanego powyżej." Po migracji na dostawcę EU — przywrócić brzmienie
   „nie są przekazywane poza EOG" i usunąć Resend z listy.
3. **Spójność wewnętrzna:** str. 1 vs pkt 6 mówiły co innego o momencie
   usunięcia audio — po korekcie (1) znika.

## 3. Korekty w kodzie

### 3.1 KRYTYCZNE — brak kontroli własności w `GetSessionDetails` (IDOR)

`services/clinical-svc/internal/adapters/grpc/session.go` (~47): handler
zwraca odszyfrowany transkrypt + raporty bez porównania
`sess.TherapistID` z `ctx.Value(UserIDKey)` (wzorzec jest w `RenameSession`
~253 i `DeleteSession` ~379). Naprawa: check właściciela zaraz po
`GetSession` (zwracać `NotFound`, nie ujawniać istnienia), audyt pozostałych
handlerów odczytu (raporty, notatki, transkrypty, listy) + test regresyjny
„obcy terapeuta → NotFound". Wystawione jako zadanie
*Fix IDOR in GetSessionDetails* (branch `fix/session-details-idor`).

### 3.2 Oznaczenie „treść wygenerowana przez AI" w raporcie

`flutter-app/superwizor/lib/screens/report_screen.dart`: dodać stały,
widoczny disclaimer/badge nad treścią raportu (i18n:
`report_ai_generated_badge`, PL: „Treść wygenerowana przez AI — charakter
wyłącznie pomocniczy", EN analogicznie). Wymóg pkt 9 zgody + transparentność
(AI Act). Niski koszt.

### 3.3 (Opcjonalne) kasowanie audio natychmiast po transkrypcji

`ai-pipeline-svc/cmd/stt-worker/finalize.go`: po utrwaleniu transkryptu
usunąć obiekt audio (`source_audio_uri`) z bucketa `audio-uploads`
(idempotentnie; lifecycle 48 h zostaje jako backstop). Pozwala przywrócić
mocniejsze brzmienie zgody i skraca ekspozycję nagrania z 48 h do minut.
Uwaga: dedup generacji (`processed_generation`) i retry chunków muszą być
odporne na brak obiektu.

### 3.4 (Niekrytyczne) surowe wyniki Chirp w `transcripts-raw`

JSON-y z tekstem transkrypcji leżą 7 dni z domyślnym szyfrowaniem GCS (bez
koperty aplikacyjnej) — formalnie „zaszyfrowane", ale to najsłabiej chroniona
kopia treści sesji. Rozważyć: skrócenie lifecycle do 1–2 dni **lub**
kasowanie w finalize po scaleniu chunków.

## 4. Alternatywa dla Resend (wysyłka e-mail)

Stan: `notification-svc/internal/email/sender.go` ma już interfejs `Sender`
(`ResendSender` to jedna implementacja) — podmiana dostawcy = nowa
implementacja + env. E-maile dzielą się na: **(a) z treścią pochodną sesji**
(plan działań / notatki dla klienta — PHI) i **(b) bez PHI** (drip, renewal
reminders, transakcyjne).

| Opcja | Podmiot / dane | Ocena |
|---|---|---|
| **A. Scaleway TEM (Transactional Email)** | Francja, dane w EU (Paryż) | **Rekomendowana dla (a)**: dostawca unijny (bez problemu CLOUD Act), proste REST API + SMTP, tanio; wystarczy `ScalewaySender` implementujący `Sender` |
| **B. Brevo (d. Sendinblue)** | Francja, DC w EU | Równorzędna do A; dojrzalszy produkt, lepsza obserwowalność doręczeń; API + SMTP |
| **C. AWS SES `eu-central-1`** | Amazon (USA), rezydencja danych EU | Ten sam status prawny co Google Cloud (dostawca z USA + region EU + SCC); OK jeśli akceptujemy tę konstrukcję dla GCP — ale nie poprawia brzmienia „wyłącznie EOG" mocniej niż A/B |
| **D. Nie wysyłać PHI e-mailem** | — | Najczystsza RODO-wo: e-mail tylko z powiadomieniem + tokenizowany, wygasający link do treści serwowanej z EOG. Największy koszt (nowy publiczny endpoint + strona), do rozważenia długoterminowo |
| Resend „EU region" | — | Zweryfikować aktualną ofertę rezydencji EU u Resend; jeśli istnieje i obejmuje treść wiadomości — najmniejsza zmiana, ale nadal podmiot z USA (jak C) |

**Rekomendacja:** krótkoterminowo **A (Scaleway TEM)** dla e-maili klasy (a)
— nowa implementacja `Sender` + routing per typ wiadomości (PHI → EU sender);
Resend może pozostać dla (b) albo zostać zmigrowany w całości (mniej
subprocesorów w dokumentach). Długoterminowo rozważyć **D**. Po migracji —
korekta dokumentu z §2 pkt 2 (usunięcie Resend, przywrócenie „wyłącznie
EOG").

## 5. Kolejność wdrożenia

1. §3.1 IDOR — natychmiast (bezpieczeństwo, niezależne od dokumentu).
2. §2 — poprawki w zgodzie (v0.13) przed jej dystrybucją do terapeutów.
3. §3.2 badge AI — przy najbliższym wydaniu aplikacji.
4. §4 migracja e-mail (Scaleway TEM) → potem druga korekta zgody.
5. §3.3 / §3.4 — opcjonalne wzmocnienia retencji.
