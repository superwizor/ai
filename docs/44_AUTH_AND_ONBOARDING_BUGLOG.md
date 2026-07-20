---
type: Developer Worklog
title: Rejestr Bugów Autentykacji i Onboardingu
description: Żywy dokument zbierający wszystkie napotkane problemy z logowaniem, rejestracją, onboardingiem i autoryzacją. Rozszerzany po każdej iteracji testów.
resource: file:///Users/maciekckoklormam91/Desktop/Inne/APP%20-%20Superwizor%20AI/docs/44_AUTH_AND_ONBOARDING_BUGLOG.md
tags:
  - auth
  - onboarding
  - buglog
  - firebase
  - login
timestamp: 2026-07-16T14:00:00+02:00
---

# 🐛 Rejestr Bugów: Autentykacja i Onboarding

Żywy dokument. Rozszerzamy po każdej rundzie testów (Google Sign-In, Apple Sign-In, nowe konta, edge cases).

---

## 1. Onboarding — Nowe konto wrzucane na ostatni krok

| | |
|---|---|
| **Status** | ✅ Naprawione (`b341936`) |
| **Środowisko** | Web (marketing-site), produkcja |
| **Zgłoszenie** | Nowy użytkownik po kliknięciu linka aktywacyjnego widzi krok 7 ("Subskrypcje kupujesz na WWW") zamiast kroku 4 (wybór nurtu). |

**Root cause:**  
`localStorage` przechowywał postęp onboardingu pod globalnym kluczem `sw_onboarding_step` — wspólnym dla **wszystkich kont** na tej samej przeglądarce. Gdy user A doszedł do kroku 7, przeglądarka zapamiętała `7`. Nowy user B na tym samym komputerze odziedziczył ten postęp.

`useState` (synchroniczny) odczytywał `7` z localStorage i renderował krok 7 **natychmiast**, zanim jakikolwiek `useEffect` (asynchroniczny) mógł to naprawić.

**Fix:**  
Klucz localStorage jest teraz **per-user**: `sw_onboarding_step_{firebase_uid}`.  
Nowe konto = nowy UID = brak klucza = domyślny krok 4. Zero wyścigów.

**Pliki:**
- `marketing-site/src/components/onboarding/OnboardingWizard.tsx` — per-user `storageKey`
- `marketing-site/src/lib/firebase/auth-provider.tsx` — czyszczenie klucza przy `signOut`

---

## 2. Onboarding — Krok 7 pomijany (skok do dashboardu)

| | |
|---|---|
| **Status** | ✅ Naprawione (`d7c066c`) |
| **Środowisko** | Web (marketing-site), produkcja |
| **Zgłoszenie** | Po wypełnieniu formularza (krok 6) aplikacja przeskakiwała prosto do dashboardu, pomijając ekran "Subskrypcje kupujesz na WWW" (krok 7). |

**Root cause:**  
`handleDone()` po zapisaniu profilu wysyłał `BroadcastChannel` message `{ type: "onboarding_complete" }` z **nowego** obiektu kanału. Listener w tym samym tab-ie nasłuchiwał na **innym** obiekcie kanału. `BroadcastChannel` nie dostarcza wiadomości do tego samego *obiektu*, który ją wysłał — ale to były różne obiekty, więc listener otrzymywał wiadomość i natychmiast wywoływał `router.replace('/dashboard')`.

**Fix:**  
Dodano `useRef` flagę `selfCompleted`. `handleDone` ustawia `selfCompleted.current = true` przed wysłaniem broadcastu. Listener ignoruje wiadomość, jeśli flaga jest ustawiona (ten sam tab). Inne karty (bez flagi) nadal dostają redirect.

**Pliki:**
- `marketing-site/src/components/onboarding/OnboardingWizard.tsx` — `selfCompleted` ref

---

## 3. Onboarding — Pętla nieskończona (powrót do onboardingu po zakończeniu)

| | |
|---|---|
| **Status** | ✅ Naprawione (`630039b`) |
| **Środowisko** | Web (marketing-site), produkcja |
| **Zgłoszenie** | Użytkownik przeszedł cały onboarding, ale po przekierowaniu na dashboard został z powrotem odesłany na onboarding. Klikał go wielokrotnie w kółko. |

**Root cause:**  
`handleDone` miał jedną wspólną konstrukcję `try/catch` dla `updateProfile` (krytyczny) i `CRM note` (telemetria). Gdy `CRM note` zawiódł (np. brak internetu), `catch` wyświetlał błąd, ale `setStep(7)` już się wykonał. Dashboard guard (`!me.defaultModalityId`) widział brak modalityId i odsyłał z powrotem na onboarding.

Dodatkowo `router.push` pozwalał wrócić przyciskiem "Wstecz" do onboardingu.

**Fix:**
1. Rozdzielono ścieżki: `updateProfile` → jeśli fail → hard stop (zostań na kroku 6). `CRM note` → fire-and-forget, nigdy nie blokuje.
2. `router.push` → `router.replace` (brak historii = brak powrotu "Wstecz").

**Pliki:**
- `marketing-site/src/components/onboarding/OnboardingWizard.tsx` — refaktor `handleDone`

---

## 4. Rejestracja — Błąd przy zmianie adresu email

| | |
|---|---|
| **Status** | ✅ Naprawione (konwersacja `7cad5669`) |
| **Środowisko** | Web (marketing-site), produkcja |
| **Zgłoszenie** | Próba poprawienia emaila w trakcie rejestracji kończyła się komunikatem "Wystąpił błąd podczas zapisywania adresu". |

**Root cause:**  
Formularz rejestracji próbował zaktualizować email w Firebase Auth, ale użytkownik nie miał jeszcze zweryfikowanego tokena — Firebase wymaga re-autentykacji przed zmianą emaila.

**Fix:**  
Przebudowano flow zmiany maila — zapis maila do bazy odbywa się przed weryfikacją Firebase Auth, a link aktywacyjny jest wysyłany na nowy adres.

---

## 5. Face ID — Wielokrotna autoryzacja przy starcie

| | |
|---|---|
| **Status** | 🔴 Nienaprawione (P0, zaplanowane) |
| **Środowisko** | Flutter (iOS), produkcja |
| **Zgłoszenie (beta testerzy)** | Aplikacja po każdym uruchomieniu prosi 2-3x o Face ID. Przy przełączaniu zakładek w telefonie ponownie prosi o kod/Face ID. Po wyłączeniu Face ID w ustawieniach iPhone'a, aplikacja 2x prosi o kod PIN. |

**Root cause (hipoteza):**  
`LocalAuthGuard` w Flutterze nie tworzy "sesji odblokowania" — każde przeładowanie widgetu wymusza nową autoryzację. Brak debounce'a i brak okna czasowego (np. "nie pytaj ponownie przez 5 min w foreground").

**Planowany fix:**
- Refaktor `LocalAuthGuard` — sesja odblokowania trwająca dopóki app jest w foreground.
- Blokada dopiero po X minutach w tle.

---

## 🔜 Do przetestowania

### Google Sign-In (Web + Flutter)
- [ ] Nowe konto przez Google → czy onboarding startuje od kroku 4?
- [ ] Istniejące konto (email+hasło) → logowanie przez Google z tym samym emailem → czy łączy konta?
- [ ] Google Sign-In na iOS → czy popup / redirect działa?
- [ ] Google Sign-In na Android → czy działa?
- [ ] Wylogowanie po Google Sign-In → czy localStorage się czyści?

### Apple Sign-In (Web + Flutter)  
- [ ] Nowe konto przez Apple → czy onboarding startuje od kroku 4?
- [ ] Apple "Hide My Email" → czy wygenerowany email relay działa z naszym systemem?
- [ ] Apple Sign-In na iOS (natywny) → czy Flow jest płynny?
- [ ] Apple Sign-In na Web → czy popup działa w Safari / Chrome?
- [ ] Wylogowanie po Apple Sign-In → czy sesja się czyści poprawnie?

### Edge Cases
- [ ] Rejestracja emailem → potem logowanie Google z tym samym emailem → merge?
- [ ] Rejestracja Google → potem próba logowania emailem z tym samym adresem
- [ ] Dwa konta (email + Google) → ten sam adres → co się dzieje?
- [ ] Usunięcie konta → ponowna rejestracja tym samym emailem
- [ ] Wygaśnięcie tokena Firebase w trakcie onboardingu
- [ ] Utrata internetu w trakcie `handleDone` (krok 6 → 7)
