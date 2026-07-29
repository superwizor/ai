---
type: Runbook
title: AI Chat Vertex API Setup
description: Procedura aktywacji API Firebase Vertex AI dla chata pacjenta.
resource: file:///Users/maciekckoklormam91/Desktop/Inne/02_APP - Superwizor AI/docs/57_AI_CHAT_VERTEX_API_SETUP.md
tags:
  - runbook
  - firebase
  - ai
  - chat
timestamp: 2026-07-29T12:45:00Z
---
# AI Chat Vertex API Setup

## Problem
Podczas użycia nowej funkcji asystenta AI w panelu pacjenta we Flutterze wystąpił błąd informujący, że usługa Firebase Vertex AI (wymagana przez pakiet Firebase AI Logic) jest wyłączona w projekcie GCP.
Zrzut ekranu wskazuje na błąd:
> Wystąpił błąd: Firebase AI Logic API has not been used in project 344724821207 before or it is disabled. Enable it by visiting https://console.developers.google.com/apis/api/firebasevertexai.googleapis.com/overview?project=344724821207 then retry.

Projekt Superwizor AI posiada ID: `superwizor-ai-25ecd` (numer: `344724821207`).

## Rozwiązanie

Aby czat Vertex AI (Gemini Flash) działał z Fluttera po stronie Firebase, należy włączyć dedykowane API w Google Cloud. 
W środowisku lokalnym, nałożone są jednak blokady uwierzytelniania w `gcloud` (tokeny serwisowe CI uległy przedawnieniu do komend bezobsługowych, przez co agent nie może sam wykonać uprawnionych komend z poziomu CLI).

Z tego względu aktywacja wymaga interaktywnego zalogowania w terminalu lub wyklikania w przeglądarce.

### Opcja 1: Z poziomu terminala (zalecana)
Otwórz nowy terminal w systemie macOS i wklej następujące komendy:

```bash
# Opcjonalnie zresetuj ustawienia konta serwisowego
gcloud config unset auth/impersonate_service_account

# Zaloguj się interaktywnie na swoje konto Google posiadające uprawnienia do projektu
gcloud auth login

# Uruchom usługę Firebase Vertex AI
gcloud services enable firebasevertexai.googleapis.com --project=superwizor-ai-25ecd
```

### Opcja 2: Z poziomu przeglądarki
Wejdź w poniższy link podany w komunikacie błędu i kliknij przycisk **"Enable" (Włącz)**:
[https://console.developers.google.com/apis/api/firebasevertexai.googleapis.com/overview?project=344724821207](https://console.developers.google.com/apis/api/firebasevertexai.googleapis.com/overview?project=344724821207)

## Rozwiązanie - Faza 2 (AI Logic Config Missing)
Pomimo aktywacji API z poziomu Google Cloud, sama platforma Firebase wymaga wygenerowania specyficznej "konfiguracji AI Logic" dla projektu. Bez tego Flutter zwraca błąd:
> AI logic config is missing for this project. Please complete the onboarding process in the Firebase Console to enable AI logic.

Aby to naprawić z poziomu terminala, wymagane jest ponowne uwierzytelnienie w systemie narzędzi `firebase-tools` i zainicjowanie usługi. Z racji autoryzacji webowej, musisz uruchomić te dwie komendy na swoim komputerze:

```bash
# Zaloguj / Odśwież tokeny autoryzacyjne dla Firebase CLI
npx firebase-tools login --reauth

# Zainicjuj usługę AI Logic dla danego projektu (zostanie to skonfigurowane po stronie chmury)
npx -y firebase-tools@latest init ailogic --project superwizor-ai-25ecd
```
Zatwierdź domyślne pytania i poczekaj na informację o pomyślnej instalacji. Możesz alternatywnie wykonać to w przeglądarce wchodząc w konsolę Firebase (Build -> Firebase AI Logic -> Get Started).

## Rozwiązanie - Faza 3 (Akceptacja Regulaminu API)
W niektórych przypadkach wykonanie powyższej konfiguracji (`init ailogic`) z poziomu terminala, może zwrócić błąd **HTTP 403** (Odmowa dostępu):
> Reason: TOS_REQUIRED: The following ToS's must be accepted: [generative-language-api].

Oznacza to, że administrator projektu musi jednorazowo zaakceptować warunki świadczenia usług (Terms of Service) dla generatywnego AI. 
Aby to zrobić:
1. Zaloguj się na konto Google Cloud i wejdź w link: [Akceptacja Regulaminu Generative Language API](https://console.cloud.google.com/terms/generative-language-api)
2. Zaznacz wymagane zgody i zapisz.
3. Po zaakceptowaniu regulaminu powtórz drugą komendę z Fazy 2: `npx -y firebase-tools@latest init ailogic --project superwizor-ai-25ecd`

## Weryfikacja
Po prawidłowym wygenerowaniu konfiguracji (bez błędów ToS):
1. Zrestartuj (Hot Restart) aplikację na macOS za pomocą litery `R` w działającym terminalu.
2. Uruchom nową rozmowę i wyślij testowy prompt (np. "Jaką diagnozę postawiłbyś temu człowiekowi?"). Czat powinien teraz zacząć poprawnie działać na streamowanym tekście ze strony Gemini.
