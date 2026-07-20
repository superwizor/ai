---
type: System Documentation
title: "51 — Autoryzacja zaproszeń klienta: kod parowania  cofanie (O0O1)"
description: "(patrz §4: stare zaproszenia grandfathered)."
resource: file:///Users/maciekckoklormam91/Desktop/Inne/APP - Superwizor AI/docs/51_AUTORYZACJA_ZAPROSZEN_KLIENTA.md
tags: [ai, analytics, crm, database, frontend, identity, infrastructure, testing]
timestamp: 2026-07-18T23:26:24.735737
---

# 51 — Autoryzacja zaproszeń klienta: kod parowania + cofanie (O0+O1)

**Status:** design + implementacja (2026-07-17). Branch
`feat/client-invite-authz`. Bez flagi env — bramkowanie data-driven
(patrz §4: stare zaproszenia grandfathered).

## 1. Problem

Zaproszenie „Zaproś klienta" to magic link **na okaziciela**
(`/register/client?token=…`, TTL 7 dni): literówka w adresie → obcy
człowiek aktywuje konto przypięte do kartoteki i widzi dane kliniczne.
Akcji nie da się jawnie cofnąć (jedyne obejście: re-invite rotuje
token). Analiza opcji O0–O4: rozmowa 2026-07-17; wybrano **O0
(higiena/cofanie) + O1 (kod parowania od terapeuty)**.

## 2. Model zagrożenia i zasada

Link e-mailowy dowodzi tylko władania skrzynką. Kod parowania,
przekazany **poza e-mailem** (na sesji / telefonicznie), dowodzi
relacji terapeuta↔pacjent. Aktywacja wymaga OBU czynników. Kodu nigdy
nie ma w e-mailu; w bazie tylko hash.

## 3. Przepływ docelowy

```
Terapeuta: „Zaproś klienta"
  → dialog potwierdzenia adresu (jawnie pokazany e-mail + ostrzeżenie
    o typosquatach popularnych domen)
  → InviteClient: token (jak dziś) + KOD PAROWANIA 6 cyfr
    (crypto/rand, hash SHA-256 w invitations.pairing_code_hash;
    plaintext zwrócony JEDEN raz w odpowiedzi RPC)
  → aplikacja pokazuje kod terapeucie: „Przekaż pacjentowi osobiście”
    (kod można ponownie wyświetlić TYLKO przez re-invite = nowy kod)
Pacjent: klika link → formularz rejestracji + pole „Kod od terapeuty”
  → AcceptInvitation(token, pairing_code, …)
      kod zły → attempts+1; po 5 → zaproszenie zablokowane
                (terapeuta musi zaprosić ponownie: nowy token+kod)
      kod OK  → aktywacja jak dziś
Terapeuta (do kliknięcia): „Cofnij zaproszenie” → RevokeClientInvite
  → revoked_at = now(); token martwy; status wraca do NONE
```

## 4. Zmiany danych i API

Migracja `000076_invitations_pairing_code`:

```sql
ALTER TABLE invitations
    ADD COLUMN pairing_code_hash BYTEA,        -- NULL = zaproszenie sprzed featury
    ADD COLUMN code_attempts     INT NOT NULL DEFAULT 0,
    ADD COLUMN revoked_at        TIMESTAMPTZ;  -- NULL = nie cofnięte
```

Proto (`identity.proto`), zmiany addytywne:

- `Invitation.pairing_code = 10` — **wypełniane wyłącznie w odpowiedzi
  `InviteClient`**; każdy inny odczyt zwraca puste (komentarz w proto).
- `AcceptInvitationRequest.pairing_code = 10`.
- `rpc RevokeClientInvite(RevokeClientInviteRequest) returns (ClientInviteStatus)`
  — authz jak `InviteClient` (`requireKartotekaAccess`), działa tylko
  na PENDING; idempotentne (drugi revoke → NONE bez błędu).
- `ClientInviteStatus`: bez nowych stanów — zaproszenie cofnięte /
  zablokowane po 5 próbach raportuje `NONE` (UI pokazuje „Zaproś
  ponownie”).

**Bramkowanie data-driven (bez flagi env):** `AcceptInvitation` wymaga
kodu ⟺ `pairing_code_hash IS NOT NULL`. Zaproszenia sprzed deployu
(hash NULL) akceptują się po staremu aż wygasną — zero łamania
wiszących zaproszeń, automatyczny rollout dla nowych.

Semantyka błędów `AcceptInvitation` (bez wyroczni enumeracyjnej):

| Przypadek | Kod gRPC | Komunikat klienta |
|---|---|---|
| zły kod, attempts < 5 | `InvalidArgument` `PAIRING_CODE_INVALID` | „Nieprawidłowy kod — sprawdź kod od terapeuty” |
| attempts ≥ 5 | `FailedPrecondition` `INVITATION_BLOCKED` | „Zaproszenie zablokowane — poproś terapeutę o nowe” |
| cofnięte / wygasłe / nieznany token | jak dziś `NotFound` | „Zaproszenie nieaktualne” |

Inkrement `code_attempts` atomowo (`UPDATE … SET code_attempts =
code_attempts + 1 WHERE … RETURNING`), porównanie hashy
constant-time. Blokada liczona per zaproszenie, więc rotacja
tokenu+kodu (re-invite) zeruje licznik.

## 5. O0 — higiena (w tym samym wydaniu)

- **TTL zaproszeń klienta: 7 d → 72 h** (osobna stała
  `clientInvitationTTL`; menedżerskie zostają na 7 d — inna klasa
  ryzyka, brak danych klinicznych za linkiem).
- **Audit events**: `client_invite.sent` / `.revoked` / `.accepted` /
  `.blocked` (action, patient_file_id, maskowany e-mail).
- **Dialog potwierdzenia adresu** w `client_invite_sheet.dart`:
  pokazany adres + heurystyka typosquatów (`gmail.com`, `onet.pl`,
  `wp.pl`, `o2.pl`, `interia.pl` — odległość Levenshteina ≤2 →
  ostrzeżenie „czy chodziło o …?”).
- **Kill-switch po aktywacji** (konto ACTIVE): istniejący mechanizm
  deaktywacji (docs/38 §4, `SetUserActivation`) — do wystawienia z
  kartoteki wymaga rozszerzenia authz (terapeuta → jego pacjent).
  Świadomie POZA tym wydaniem (osobny PR; ryzyko authz większe niż
  zysk czasowy); do tego czasu ścieżka operacyjna: ORG_ADMIN.

## 6. Frontend

**Flutter (`client_invite_sheet.dart`):** po sukcesie `InviteClient`
ekran z kodem (format `123 456`, przycisk kopiowania) + copy: „Przekaż
kod pacjentowi osobiście lub telefonicznie. Nie wysyłaj go e-mailem.”;
chip PENDING w kartotece dostaje akcję „Cofnij zaproszenie”
(confirm-dialog). i18n PL/EN.

**Web (`marketing-site` `AcceptInviteForm.tsx`):** pole „Kod od
terapeuty” (6 cyfr, auto-format) pokazywane, gdy preview zaproszenia
ma `requires_pairing_code=true` (nowe pole w `InvitationPreview`);
mapowanie błędów §4. Stare zaproszenia bez kodu → formularz bez pola.

**E-mail klienta:** bez zmian technicznych (kodu tam nie ma); dopisek
w szablonie: „Do aktywacji potrzebny będzie kod, który otrzymasz od
terapeuty.”

## 7. Testy

- unit identity-svc (`client_invites_test.go`): kod wymagany iff hash;
  5 prób → blokada; revoke → NotFound na accept; re-invite zeruje
  licznik i rotuje kod; constant-time compare (test wektorowy).
- e2e: `TestClientPanel_AcceptInvitation_MagicLink` + `FullFlow`
  rozszerzone o kod (z odpowiedzi InviteClient); nowe:
  `TestClientInvite_WrongCodeLockout`, `TestClientInvite_Revoke`.
- web: RTL test formularza (pole warunkowe, błędy).

## 8. Poza zakresem (zapisane decyzje)

O2 (kod zwrotny do terapeuty) — odrzucone na rzecz O1 (ta sama
gwarancja, mniejsza friction). O3 (approve-after-login) — zbędne przy
O1. O4 (onboarding QR w gabinecie) — roadmapa; usuwa klasę błędu u
źródła, zaproszenie e-mail+kod zostanie fallbackiem. Kill-switch
z kartoteki — osobny PR (§5).

Dokumenty powiązane: docs/38 (aktywacja/seaty), docs/39-client-panel
(C-PR6/7/10 — przepływ paneli), docs/37 (zgodność).
