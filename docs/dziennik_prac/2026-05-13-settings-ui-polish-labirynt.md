---
type: Developer Worklog
title: "Sesja: Settings UI Polish — Labirynt Premium Standards"
description: "Data: 2026-05-13 Cel sesji: Finalizacja refaktoru ekranu Ustawień (MenuScreen) do standardu Labirynt Premium — kompletny design system z białymi togglemi, pi..."
resource: file:///Users/maciekckoklormam91/Desktop/Inne/APP%20-%20Superwizor%20AI/docs/dziennik_prac/2026-05-13-settings-ui-polish-labirynt.md
tags: [dziennik-prac]
timestamp: 2026-05-13T15:24:48+02:00
---

# Sesja: Settings UI Polish — Labirynt Premium Standards

**Data:** 2026-05-13
**Cel sesji:** Finalizacja refaktoru ekranu Ustawień (MenuScreen) do standardu Labirynt Premium — kompletny design system z białymi togglemi, pięknym logout bottom sheet, wielopoziomowym flow usuwania konta, poprawionymi dokumentami prawnymi i licencjami w boksach.

---

## 🛠 Zmiany w kodzie i plikach

- `lib/screens/menu_screen.dart` — Całkowita przebudowa: sekcje w kartach, toggle Dźwięki/Wibracje (białe kółko gdy ON), język z flagami inline, skrót wybranej modalności jako ember-badge (`CBT`, `Psychod.` itd.), piękny logout bottom sheet z ikoną, wiersz „Usuń konto bezpowrotnie" z chevronem (nawigacja na nowy ekran), licencje jako niestandardowy ekran w boksach (rozwijane kafle), layout identyczny z Labirynt Premium
- `lib/screens/delete_account_screen.dart` — Nowy ekran (push z prawej): italic tytuł „Usuń konto" + 3 punkty konsekwencji z czerwonymi circle-check ikonami; na dole sticky: toggle „Rozumiem konsekwencje i chcę usunąć konto" (czerwony) + przycisk „Usuń moje konto" (aktywny tylko gdy toggle ON); po kliknięciu → bottom sheet z polem „USUWAM" (przycisk aktywny dopiero po wpisaniu), obsługa `requires-recent-login`
- `lib/providers/settings_provider.dart` — Nowy provider: `AppSettingsState` (soundEnabled, hapticsEnabled), Riverpod 3 `Notifier`, persystencja w SharedPreferences pod kluczami `sw_*`
- `lib/widgets/profile_edit_sheet.dart` — Callback `onSaved` dla reaktywnego odświeżania nazwy w MenuScreen
- `lib/screens/legal_markdown_screen.dart` — Ekran prawny w stylu EUPHIRE Design System
- `assets/legal/terms.md` — Pełna przebudowa: czyste Markdown, TL;DR, tabela definicji, paragrafy `##`
- `assets/legal/privacy_policy.md` — Pełna przebudowa: 3 części (Terapeuta/Pacjent/Cookie), tabela sub-procesorów EU, prawa RODO
- `assets/legal/dpa.md` — Pełna przebudowa: DPA RODO-compliant, tabela sub-procesorów, TL;DR

---

## 🏗 Architektura i Decyzje

### Flutter — Delete Account Flow (finalny)

3 warstwy UX bezpieczeństwa:
1. **Wiersz z chevronem** w sekcji „ZARZĄDZANIE KONTEM" → push z prawej na `DeleteAccountScreen`
2. **Ekran** z listą konsekwencji (circle-check ikony) + toggle „Rozumiem konsekwencje..." + przycisk „Usuń moje konto" (disabled dopóki toggle OFF)
3. **Bottom sheet** po kliknięciu aktywnego przycisku: pole tekstowe „USUWAM" (RobotoMono) + przycisk „USUWAM KONTO" aktywny dopiero po wpisaniu

### Riverpod 3 — settings_provider
- `Notifier`/`NotifierProvider` (nie `StateNotifier`) — zgodne z resztą projektu
- Persystencja w SharedPreferences pod kluczami `sw_sound`, `sw_haptics`

### Backend account deletion
- Wyłącznie `FirebaseAuth.currentUser.delete()` — brak `DeleteUser` RPC w identity-svc
- **Backend nienaruszony** (changelog Darka dotyczy clinical-svc)
- `requires-recent-login` → auto-signOut + SnackBar z instrukcją

### Bezpieczeństwo (MedTech)
- Użytkownik musi wykonać 3 świadome akcje zanim dane zostaną usunięte
- Tekst przycisków jednoznaczny: „NIEODWRACALNA", „bezpowrotnie"

---

## 🚨 Znane problemy i Dług Technologiczny

- [ ] `iconColor`/`titleColor` w `_SettingsRow` mają `unused_element_parameter` warning — API do przyszłego użytku
- [ ] identity-svc nie ma endpointu czyszczenia rekordów Postgresowych przy usuwaniu konta Firebase — potrzebna rozmowa z Darkiem o `DeleteTherapistAccount` RPC
- [ ] SharedPreferences bez szyfrowania — dla wrażliwych preferencji rozważyć `flutter_secure_storage`
- [ ] Re-auth po `requires-recent-login`: brak okna dialogowego z polem hasła (tylko wylogowanie)

---

## 🎯 Następne kroki

- [ ] Uzgodnić z Darkiem `DeleteTherapistAccount` RPC w identity-svc i podpiąć w delete flow
- [ ] `CreatePatientFile` form — dodać wymagane pole `patient_first_name` (breaking change z changelog Darka 2026-05-12)
- [ ] `UpdateSession` (rename) + `DeleteSession` z menu kontekstowego session row
- [ ] `UpdatePatientUser` — panel edycji imienia/języka pacjenta
- [ ] Zmiana transcript view na `turns` (speaker-grouped) per changelog Darka
