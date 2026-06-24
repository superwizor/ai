# Wewnętrzna Polityka Zarządzania Danymi Osobowymi

**Euphire sp. z o.o. — SuperWizor AI**

**Wersja:** 1.0 DRAFT — do uzupełnienia o elementy organizacyjne i zatwierdzenia przez zarząd  
**Data wejścia w życie:** ___________  
**Odpowiedzialny:** Zarząd Euphire sp. z o.o.  
**Kontakt:** kontakt@superwizor.ai

---

## 1. Cel i Zakres

Niniejsza Polityka określa wewnętrzne zasady zarządzania danymi osobowymi w Euphire sp. z o.o. w związku z rozwojem, utrzymaniem i świadczeniem usług aplikacji SuperWizor AI.

Polityka obejmuje:
- Wszystkich pracowników, współpracowników, kontrahentów i podwykonawców mających potencjalny dostęp do danych osobowych
- Dane osobowe Użytkowników Profesjonalnych (administrator) oraz Klientów (procesor)
- Środowiska: produkcyjne, stagingowe, deweloperskie i lokalne

Polityka realizuje obowiązki wynikające z art. 24 i 32 RODO (obowiązek wdrożenia odpowiednich środków technicznych i organizacyjnych).

---

## 2. Zasady Ogólne

### 2.1. Zasada minimalizacji danych
- Przetwarzamy wyłącznie dane niezbędne do świadczenia usługi
- Nagrania audio usuwane natychmiast po transkrypcji (OLM 48h backstop)
- Pamięć kontekstowa RAG jest pseudonimizowana (bez PII)
- Embeddingi zawierają zredagowany tekst (`chunk_text_redacted`)
- Dane Klientów **NIGDY** nie są wykorzystywane do celów własnych firmy, w tym do trenowania modeli AI

### 2.2. Zasada ograniczonego dostępu (need-to-know)
- Dostęp do danych szczególnych kategorii (PHI) jest ograniczony do minimum
- Każdy mikroserwis posiada dedykowane Service Account z minimalnymi uprawnieniami
- Deweloperzy nie mają bezpośredniego dostępu do danych PHI w produkcji
- Dostęp do Cloud Console produkcyjnego jest ograniczony do osób z autoryzacją zarządu

### 2.3. Zasada szyfrowania domyślnego
- Wszystkie dane PHI podlegają envelope encryption (AEAD + Cloud KMS)
- Wszystkie połączenia wykorzystują TLS/SSL
- Cloud SQL: `ssl_mode = ENCRYPTED_ONLY`
- Cloud Storage: CMEK dla wszystkich bucketów z danymi

### 2.4. Zasada rozliczalności
- Każda istotna operacja na danych jest rejestrowana w `audit_events`
- Infrastruktura zarządzana jako kod (Terraform) pod kontrolą wersji
- Dokumentacja compliance wersjonowana w repozytorium (`docs/compliance/`)

---

## 3. Kontrola Dostępu

### 3.1. Poziomy dostępu

| Poziom | Kto | Dostęp do | Warunki |
|---|---|---|---|
| **L1 — Produkcja (pełny)** | Zarząd, CTO | Cloud Console, Secret Manager, Cloud SQL (admin) | Autoryzacja zarządu, 2FA, autoryzowany IP |
| **L2 — Produkcja (operacyjny)** | DevOps, SRE | Cloud Logging, Cloud Monitoring, Cloud Run, Terraform | Autoryzacja CTO, WIF (CI/CD) |
| **L3 — Staging** | Deweloperzy | Staging Cloud Console, staging DB (via cloud-sql-proxy) | Autoryzacja CTO, autoryzowany IP |
| **L4 — Kod źródłowy** | Deweloperzy | Repozytorium Git, code review | GitHub account + branch protection |
| **L5 — Dokumentacja** | Wszyscy upoważnieni | docs/, compliance/ | Członkostwo w organizacji GitHub |

### 3.2. Service Accounts (mikroserwisy)

Każdy mikroserwis posiada dedykowane Service Account z minimalnym zestawem uprawnień:

| Service Account | Serwis | Kluczowe uprawnienia |
|---|---|---|
| `identity-svc-sa` | identity-svc | Cloud SQL Client, Firebase Admin, Secret Manager Accessor |
| `clinical-svc-sa` | clinical-svc | Cloud SQL Client, KMS CryptoKey Encrypter/Decrypter, Secret Manager Accessor |
| `billing-svc-sa` | billing-svc | Cloud SQL Client, Secret Manager Accessor |
| `ingestion-svc-sa` | ingestion-svc | Cloud SQL Client, Storage Object Admin (audio bucket), Pub/Sub Publisher, KMS |
| `stt-worker-sa` | stt-worker (CF) | Speech-to-Text User, Storage Object Viewer/Admin, Pub/Sub Publisher, KMS |
| `llm-worker-sa` | llm-worker (CF) | Vertex AI User, Cloud SQL Client, Pub/Sub Publisher, KMS |
| `notification-svc-sa` | notification-svc | Cloud SQL Client, Firestore Writer, FCM Admin |
| `purger-sa` | GDPR Purger | Cloud SQL Client |
| `github-ci-sa` | CI/CD (WIF) | Artifact Registry Writer, Cloud Run Admin, Cloud Functions Admin — **bez dostępu do danych** |

### 3.3. Procedura nadawania i odbierania uprawnień

1. **Nadanie:** Na pisemny wniosek (e-mail/Slack) kierownika projektu, zatwierdzony przez CTO
2. **Przegląd:** Co 3 miesiące — przegląd listy osób z dostępem L1-L3
3. **Odebranie:** Natychmiast po zakończeniu współpracy; w ciągu 24h od zmiany stanowiska
4. **Rotacja kluczy:** Hasła do DB rotowane przy każdej zmianie osobowej w L1-L2

---

## 4. Zobowiązanie do Poufności

### 4.1. Pracownicy i współpracownicy

Każda osoba mająca potencjalny dostęp do danych osobowych (poziomy L1-L4) jest zobowiązana do:

1. **Podpisania zobowiązania do zachowania poufności** (NDA) obejmującego dane osobowe przetwarzane w ramach SuperWizor AI — przed uzyskaniem dostępu
2. **Zapoznania się** z niniejszą Polityką, Polityką Retencji oraz DPA
3. **Ukończenia szkolenia** z ochrony danych osobowych w ciągu 30 dni od uzyskania dostępu

### 4.2. Zakres poufności

Zobowiązanie obejmuje:
- Wszelkie dane osobowe Użytkowników Profesjonalnych i Klientów
- Dane techniczne umożliwiające dostęp (hasła, tokeny, klucze API)
- Treść transkrypcji, raportów i pomiarów HiTOP (nawet widzianą pośrednio w logach)
- Informacje o architekturze bezpieczeństwa

Zobowiązanie obowiązuje bezterminowo, również po zakończeniu współpracy.

---

## 5. Procedura Reagowania na Incydenty (Incident Response)

### 5.1. Definicja incydentu

**Naruszenie ochrony danych osobowych** — naruszenie bezpieczeństwa prowadzące do przypadkowego lub niezgodnego z prawem zniszczenia, utracenia, zmodyfikowania, nieuprawnionego ujawnienia lub nieuprawnionego dostępu do danych osobowych (art. 4 pkt 12 RODO).

### 5.2. Klasyfikacja incydentów

| Poziom | Opis | Przykłady |
|---|---|---|
| **P1 — Krytyczny** | Potwierdzone naruszenie danych szczególnych kategorii (PHI Klientów) | Wyciek transkrypcji/raportów, nieautoryzowany dostęp do Cloud SQL, kompromitacja KMS |
| **P2 — Poważny** | Potwierdzone naruszenie danych Użytkowników (nie-PHI) lub podejrzenie P1 | Wyciek listy email terapeutów, nieautoryzowany dostęp do konta admina |
| **P3 — Niski** | Potencjalne naruszenie bez potwierdzonego wycieku | Nieautoryzowana próba dostępu (zablokowana), anomalia w logach |

### 5.3. Procedura krok po kroku

#### Krok 1: Wykrycie i zgłoszenie (T+0)
- Każdy pracownik/współpracownik **natychmiast** zgłasza podejrzenie incydentu do CTO
- Kanał zgłoszenia: [do uzupełnienia — Slack channel / e-mail / telefon]
- Wypełnienie formularza zgłoszenia: co, kiedy, jak odkryto, kto jest dotknięty

#### Krok 2: Pierwsza ocena i izolacja (T+0 do T+1h)
- CTO dokonuje wstępnej oceny klasyfikacji (P1/P2/P3)
- Dla P1/P2:
  - **Izolacja:** Zablokowanie skompromitowanego SA, odwołanie tokenów, ograniczenie dostępu sieciowego
  - **Zachowanie dowodów:** Zrzut logów (`audit_events`, Cloud Logging) z momentu incydentu
  - **Powiadomienie zarządu**

#### Krok 3: Analiza zakresu (T+1h do T+12h)
- Identyfikacja: jakie dane, ile rekordów, którzy Administratorzy (terapeuci) dotknięci
- Query na `audit_events` + Cloud Logging:
  ```sql
  SELECT * FROM audit_events
  WHERE occurred_at BETWEEN '[start]' AND '[end]'
  ORDER BY occurred_at DESC;
  ```
- Ocena czy dane były zaszyfrowane (envelope encryption) — jeśli tak, ryzyko faktycznego wycieku jest minimalne

#### Krok 4: Powiadomienie Administratorów (T+0 do T+48h)
- **Obowiązek DPA (§3.6):** Powiadomienie dotkniętych Użytkowników Profesjonalnych (Administratorów) **w ciągu 48 godzin** od stwierdzenia naruszenia
- Treść powiadomienia:
  - Opis charakteru naruszenia
  - Kategorie i przybliżona liczba dotkniętych osób
  - Prawdopodobne konsekwencje
  - Środki podjęte i proponowane

#### Krok 5: Zgłoszenie do UODO (T+0 do T+72h)
- **Obowiązek Administratora (terapeuty):** Zgłoszenie do Prezesa UODO w ciągu 72h od stwierdzenia naruszenia (art. 33 RODO)
- Euphire wspiera Administratorów w przygotowaniu zgłoszenia (dostarcza informacje techniczne)
- Formularz UODO: https://uodo.gov.pl/pl/134/233

#### Krok 6: Remediation (T+12h do T+7d)
- Usunięcie przyczyny incydentu
- Wdrożenie dodatkowych zabezpieczeń
- Weryfikacja skuteczności poprawek

#### Krok 7: Post-mortem (T+7d do T+14d)
- Spisanie post-mortem: timeline, root cause, impact, remediation
- Aktualizacja niniejszej Polityki i DPIA
- Powiadomienie dotkniętych Administratorów o podjętych działaniach naprawczych

### 5.4. Rejestr incydentów

Każdy incydent (nawet P3) jest rejestrowany w wewnętrznym rejestrze:

| Pole | Opis |
|---|---|
| ID incydentu | Unikalny identyfikator |
| Data wykrycia | Kiedy stwierdzono naruszenie |
| Data zgłoszenia | Kiedy zgłoszono do CTO |
| Klasyfikacja | P1 / P2 / P3 |
| Opis | Co się stało |
| Dotknięte dane | Kategoria i zakres |
| Dotknięci Administratorzy | Lista dotkniętych terapeutów |
| Środki podjęte | Izolacja, remediation |
| Powiadomienie Administratorów | Data i treść |
| Zgłoszenie do UODO | Data i numer / „nie dotyczy" |
| Status | Otwarty / Zamknięty |

---

## 6. Bezpieczeństwo Środowisk Deweloperskich

### 6.1. Środowisko stagingowe

- Konfiguracja **identyczna** z produkcją pod kątem bezpieczeństwa (CMEK, VPC, SA)
- Dane testowe: **syntetyczne**, nie kopie danych produkcyjnych
- Dostęp ograniczony do deweloperów z poziomu L3
- Autoryzowane IP w Cloud SQL (`authorized_networks`)

### 6.2. Środowisko lokalne (laptopy deweloperów)

- **ZAKAZ** kopiowania danych produkcyjnych na lokalne maszyny
- `cloud-sql-proxy` wymagany do dostępu do staging DB
- Klucz SA (`sa-key.json`) w `.gitignore` — nigdy commitowany
- CI/CD via Workload Identity Federation — **bez długoterminowych kluczy**

### 6.3. Repozytorium kodu

- Prywatne repozytorium GitHub (`superwizor/ai`)
- Branch protection na `main` — wymagane code review
- `.gitignore` wyklucza: klucze, tokeny, logi, dane użytkowników
- Sekrety przechowywane w GCP Secret Manager — **nigdy** w kodzie źródłowym

---

## 7. Zarządzanie Sub-procesorami

### 7.1. Procedura dodawania nowego Sub-procesora

1. **Ocena:** Analiza sub-procesora pod kątem:
   - Lokalizacja przetwarzania (preferowane: EOG)
   - Certyfikaty bezpieczeństwa (ISO 27001, SOC 2)
   - Warunki DPA oferowane przez sub-procesora
   - Czy transfer poza EOG — jeśli tak, mechanizm prawny (DPF, SCC)

2. **Zatwierdzenie:** Decyzja CTO + konsultacja z radcą prawnym

3. **Podpisanie umowy podpowierzenia:** DPA z sub-procesorem nakładające co najmniej takie same obowiązki ochrony danych

4. **Powiadomienie Administratorów:** E-mail / powiadomienie w Aplikacji z **14-dniowym wyprzedzeniem** (DPA §5.4)

5. **Aktualizacja dokumentacji:**
   - Polityka Prywatności (tabela Sub-procesorów)
   - DPA (§5 lista Sub-procesorów)
   - Rejestr Czynności Przetwarzania
   - DPIA (jeśli zmienia profil ryzyka)

### 7.2. Aktualna lista Sub-procesorów

Aktualna lista Sub-procesorów jest utrzymywana w:
- DPA (§5.2) — dokument prawny
- Polityce Prywatności (Część I, pkt 6) — dokument publiczny
- Rejestrze Czynności Przetwarzania (Część C) — dokument wewnętrzny

---

## 8. Szkolenia i Świadomość

### 8.1. Szkolenia obowiązkowe

| Szkolenie | Częstotliwość | Dla kogo | Format |
|---|---|---|---|
| Podstawy RODO i ochrony danych | Przy onboardingu + co 12 miesięcy | Wszyscy (L1-L5) | [do uzupełnienia] |
| Bezpieczeństwo danych w chmurze | Przy onboardingu | Deweloperzy (L2-L4) | [do uzupełnienia] |
| Procedura Incident Response | Przy onboardingu + co 12 miesięcy | L1-L3 | [do uzupełnienia] |
| Specyfika danych wrażliwych (zdrowie psychiczne) | Przy onboardingu | Wszyscy | [do uzupełnienia] |

### 8.2. Ewidencja szkoleń

Każde szkolenie jest ewidencjonowane:
- Kto uczestniczył
- Kiedy
- Jaki zakres
- Potwierdzenie zapoznania się z Polityką (podpis / checkbox)

---

## 9. Prawa Osób Fizycznych — Procedura Wewnętrzna

### 9.1. Żądania Użytkowników Profesjonalnych

Euphire jako Administrator:
1. Żądanie wpływa na `kontakt@superwizor.ai`
2. Weryfikacja tożsamości żądającego (email z konta + ewentualnie dodatkowe pytanie)
3. Realizacja w terminie **do 1 miesiąca** (art. 12 ust. 3 RODO)
4. Odpowiedź drogą elektroniczną

### 9.2. Żądania Klientów (pacjentów)

Euphire jako Podmiot Przetwarzający:
1. Żądanie pacjenta powinno trafić do jego terapeuty (Administrator)
2. Terapeuta kontaktuje się z Euphire jeśli potrzebuje wsparcia technicznego
3. Euphire realizuje żądanie na polecenie Administratora za pomocą DSAR queries
4. **Euphire nie kontaktuje się bezpośrednio z pacjentami** — komunikacja przez Administratora

---

## 10. Przegląd i Aktualizacja Polityki

Niniejsza Polityka jest przeglądana:
- Co **6 miesięcy** przez CTO i radcę prawnego
- **Natychmiast** po incydencie bezpieczeństwa
- Po każdej istotnej zmianie w architekturze, zespole lub przepisach
- Każda zmiana jest wersjonowana w repozytorium (`docs/compliance/`)

---

## 11. Zatwierdzenie

| Rola | Imię i nazwisko | Data | Podpis |
|---|---|---|---|
| Zarząd Euphire sp. z o.o. | _______________ | _______________ | _______________ |
| CTO | _______________ | _______________ | _______________ |
| Radca prawny / IOD | _______________ | _______________ | _______________ |

---

*Dokument wygenerowany na podstawie analizy infrastruktury, konfiguracji IAM i Service Accounts, oraz architektury bezpieczeństwa SuperWizor AI w wersji z dnia 24.06.2026.*
