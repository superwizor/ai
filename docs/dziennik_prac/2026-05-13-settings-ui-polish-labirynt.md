# Sesja: Settings UI Polish — Labirynt Premium Standards

**Data:** 2026-05-13
**Cel sesji:** Finalizacja refaktoru ekranu Ustawień (MenuScreen) do standardu Labirynt Premium — kompletny design system z togglem, pięknym logout sheet, wielopoziomowym flow usuwania konta z wpisywaniem "USUWAM", poprawionymi dokumentami prawnymi i licencjami w boksach.

---

## 🛠 Zmiany w kodzie i plikach

- `lib/screens/menu_screen.dart` — Całkowita przebudowa: sekcje w kartach, toggle Dźwięki/Wibracje (białe kółko gdy ON), język z flagami inline, skrót wybranej modalności jako ember-badge (`CBT`, `Psychod.` itd.), piękny logout bottom sheet z ikoną, 3-poziomowy flow usuwania konta (toggle → warning sheet → ekran z "USUWAM"), licencje jako niestandardowy ekran w boksach (rozwijane kafle), layout identyczny z Labirynt Premium
- `lib/screens/delete_account_screen.dart` — Nowy ekran (push z prawej strony): ikona ostrzeżenia, lista 5 strat klinicznych, pole "USUWAM" z animowaną opacity przycisku, obsługa `requires-recent-login`
- `lib/providers/settings_provider.dart` — Nowy provider: `AppSettingsState` (soundEnabled, hapticsEnabled), Riverpod 3 `Notifier`, persystencja w SharedPreferences pod kluczami `sw_*`
- `lib/widgets/profile_edit_sheet.dart` — Aktualizacja: callback `onSaved` dla reaktywnego odświeżania nazwy w MenuScreen
- `lib/screens/legal_markdown_screen.dart` — Ekran prawny w stylu EUPHIRE Design System
- `assets/legal/terms.md` — Pełna przebudowa: czyste Markdown, TL;DR, tabela definicji, paragrafy `##`
- `assets/legal/privacy_policy.md` — Pełna przebudowa: 3 części (Terapeuta/Pacjent/Cookie), tabela sub-procesorów EU, prawa RODO
- `assets/legal/dpa.md` — Pełna przebudowa: DPA RODO-compliant, tabela sub-procesorów, TL;DR, przejrzysta struktura

---

## 🏗 Architektura i Decyzje

### Flutter — Stan i nawigacja

- **settings_provider.dart** używa `Notifier` (Riverpod 3), nie `StateNotifier` — zgodnie z resztą projektu.
- **Delete Account Flow** — 3 warstwy bezpieczeństwa UX:
  1. Toggle w sekcji "ZARZĄDZANIE KONTEM" (czerwony switch)
  2. Bottom sheet ostrzegawczy z ikoną magma + glow
  3. Pełny ekran (push z prawej, nie fullscreenDialog) z polem tekstowym "USUWAM"
- **Backend account deletion** — wyłącznie `FirebaseAuth.currentUser.delete()`. Changelog Darka (clinical-svc 2026-05-12) dotyczy wyłącznie clinical-svc (pacjenci/sesje) — brak endpointu `DeleteUser` w identity-svc. **Nic nie zmieniono w backendzie.**
- **Licencje** — własny `_LicensesScreen` zamiast `showLicensePage()`: kafle z ikoną `code`, licznikiem, rozwijane paragrafem tekstu. Wydajniejsze UX niż Flutter built-in.

### Zero Trust / Bezpieczeństwo (MedTech)
- Usunięcie konta wymaga 3-krokowej interakcji — chroni przed przypadkowym dotknięciem
- `requires-recent-login` jest obsługiwany: automatyczne wylogowanie + instrukcja

### Lokalizacja
- Wszystkie nowe teksty są na razie hardcoded po polsku (aplikacja jest Polish-first zgodnie z P3)
- TODO: wyciągnąć do ARB gdy aplikacja będzie wchodzić w pełną lokalizację EN

---

## 🚨 Znane problemy i Dług Technologiczny

- [ ] `iconColor` i `titleColor` w `_SettingsRow` mają warning `unused_element_parameter` — można je usunąć jeśli nie będą używane, lub zostawić jako API dla przyszłych wierszy
- [ ] `requires-recent-login` obsługiwany tylko przez wylogowanie — docelowo należy zaimplementować re-auth dialog z polem hasła
- [ ] Backend `DeleteUser` — identity-svc nie ma jeszcze endpointu czyszczenia rekordów Postgresowych przy usuwaniu konta Firebase. Potrzebna rozmowa z Darkiem o `DeleteTherapistAccount` RPC
- [ ] SharedPreferences keys prefixowane `sw_*` — docelowo przenieść do Secure Storage dla sensytywnych preferencji

---

## 🎯 Następne kroki

- [ ] Uzgodnić z Darkiem dodanie `DeleteTherapistAccount` RPC w identity-svc i podpiąć w `delete_account_screen.dart`
- [ ] Zaimplementować `UpdateSession` (rename) i `DeleteSession` z menu kontekstowego w session row (z changelog Darka)
- [ ] Zaimplementować `UpdatePatientUser` — panel edycji imienia/języka pacjenta
- [ ] `CreatePatientFile` form — dodać wymagane pole `patient_first_name` (breaking change z changelog Darka)
- [ ] Wyciągnąć hardcoded strings do ARB dla pełnej lokalizacji
