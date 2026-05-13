# 🛠️ INSTRUKCJE WDROŻENIA — Moduł Ustawień z Labirynt Premium → Superwizor AI

## Kontekst

Przenosimy kompletny moduł **Ustawień (Settings)** z aplikacji **Labirynt Premium** (gra relacyjna dla par) do aplikacji **Superwizor AI** (kliniczny asystent AI dla psychoterapeutów). Obie aplikacje należą do marki **EUPHIRE** i dzielą ten sam Design System wizualny (kolory, typografia, zasada glassmorphism, dark mode first).

**Cel:** Superwizor AI ma dostać profesjonalny, dopracowany moduł ustawień wzorowany 1:1 na Labiryncie, ale oczyszczony z elementów specyficznych dla gry.

---

## 📍 Kluczowe ścieżki

| Co | Ścieżka |
|----|---------|
| **Projekt Flutter Superwizor** | `/flutter-app/superwizor/` |
| **pubspec.yaml** | `/flutter-app/superwizor/pubspec.yaml` |
| **Kod źródłowy** | `/flutter-app/superwizor/lib/` |
| **Theme (EUPHIRE)** | `/flutter-app/superwizor/lib/theme/euphire_theme.dart` |
| **Istniejące widgety** | `/flutter-app/superwizor/lib/widgets/` |
| **Istniejące ekrany** | `/flutter-app/superwizor/lib/screens/` |
| **Istniejące providery** | `/flutter-app/superwizor/lib/providers/` |
| **Tłumaczenia** | `/flutter-app/superwizor/lib/l10n/` |
| **Legal assets** | `/flutter-app/superwizor/assets/legal/` |
| **Folder referencyjny (eksport z Labiryntu)** | `/_SETTINGS_UI_EXPORT/` |
| **README eksportu** | `/_SETTINGS_UI_EXPORT/README.md` |
| **Dokumentacja projektu** | `/docs/` (B_05 = Design System, 09 = UI MVP) |

---

## 🔍 FAZA 0: Audyt przed implementacją

**ZANIM cokolwiek zaimplementujesz**, przeczytaj i sprawdź:

### 0.1 Przeczytaj dokumentację projektu
- [ ] `/docs/B_05_ui_ux_design_system.md` — zasady Design System EUPHIRE
- [ ] `/docs/B_04_core_rules.md` — core rules (bezpieczeństwo, quality)
- [ ] `/docs/09_UI_MVP_FLUTTER.md` — architektura UI Flutter
- [ ] `/docs/B_09_trauma_informed_writing.md` — zasady pisania tekstów (Clinical UX Writing)

### 0.2 Sprawdź istniejący stan Superwizora
Superwizor **MA JUŻ** częściowy moduł ustawień w postaci:
- `lib/screens/menu_screen.dart` — ekran Menu (hamburger z home screena)
- `lib/widgets/main_drawer.dart` — Drawer (alternatywna nawigacja, może nieużywany)
- `lib/widgets/profile_edit_sheet.dart` — edycja profilu (imię)
- `lib/widgets/hard_delete_sheet.dart` — usuwanie konta
- `lib/widgets/language_sheet.dart` — zmiana języka
- `lib/widgets/modality_sheet.dart` — wybór modalności terapeutycznej
- `lib/screens/legal_markdown_screen.dart` — wyświetlanie regulaminów (prosty)

**WAŻNE:** Te pliki stanowią bazę. NIE usuwaj ich bezmyślnie — zaadaptuj i rozbuduj na wzór Labiryntu.

### 0.3 Sprawdź zależności w `pubspec.yaml`
Sprawdź czy w `pubspec.yaml` projektu Superwizor są już te paczki (większość powinna być):
- [ ] `flutter_riverpod` ✅ (jest)
- [ ] `firebase_auth` ✅ (jest)
- [ ] `cloud_firestore` ✅ (jest)
- [ ] `firebase_storage` ✅ (jest)
- [ ] `go_router` ✅ (jest)
- [ ] `flutter_markdown` ✅ (jest)
- [ ] `image_picker` ✅ (jest)
- [ ] `url_launcher` ✅ (jest)
- [ ] `share_plus` ✅ (jest)
- [ ] `shared_preferences` ✅ (jest)
- [ ] `package_info_plus` ✅ (jest)

Jeśli czegoś brakuje — dodaj przez `flutter pub add <paczka>`.

### 0.4 Sprawdź Firebase Storage
Superwizor ma `firebase_storage` w pubspec, ale sprawdź czy w Firebase Console jest włączony Storage dla tego projektu. Jeśli nie — zapytaj użytkownika, jak chce to skonfigurować (możliwe że trzeba włączyć w konsoli Firebase).

---

## 📋 FAZA 1: Sekcje do wdrożenia

Oto dokładna lista sekcji, które mają się pojawić na ekranie ustawień Superwizora. Kolejność od góry do dołu:

### 1. TWOJE KONTO (Account Section)
**Referencja:** `_SETTINGS_UI_EXPORT/settings/widgets/account_section.dart`
- Avatar użytkownika (z możliwością zmiany — upload zdjęcia)
- Imię i nazwisko
- Email
- Przycisk edycji profilu

**Istniejąca baza w Superwizorze:**
- `widgets/profile_edit_sheet.dart` — bottom sheet edycji imienia (ZACHOWAJ, ale rozbuduj o avatar)
- `screens/menu_screen.dart` linie 88-143 — sekcja profilu z avatarem i picker zdjęcia

**Upload zdjęcia — logika:**
Superwizor MA JUŻ upload zdjęcia w `menu_screen.dart` (metoda `_pickImage()`). Przenieś tę logikę do dedykowanego widgetu/sheetu (wzoruj się na `_SETTINGS_UI_EXPORT/auth/screens/avatar_upload_screen.dart` z Labiryntu).

### 2. PREFERENCJE (Preferences Section)
**Referencja:** `_SETTINGS_UI_EXPORT/settings/widgets/preferences_section.dart`
- Toggle: Wibracje (haptic feedback)
- Toggle: Dźwięki
- Wybór języka (PL / EN)

**Istniejąca baza w Superwizorze:**
- `widgets/language_sheet.dart` — zmiana języka (ZACHOWAJ, ale przenieś do sekcji Preferencje)
- `providers/locale_provider.dart` — provider języka

**UWAGA:** W referencji z Labiryntu `preferences_section.dart` jest import `game_repository.dart` (linie 239, 256) — to jest specyficzne dla Labiryntu. **USUŃ** te odwołania. Przy zmianie języka wystarczy wywołać `ref.read(localeProvider.notifier).setLocale(Locale(code))`, jak robi to istniejący `language_sheet.dart`.

**UWAGA 2:** Superwizor może nie mieć jeszcze `settings_provider.dart` do zarządzania stanami wibracji i dźwięków. Stwórz go wzorując się na `_SETTINGS_UI_EXPORT/core/providers/settings_provider.dart`.

### 3. WSPARCIE (Support Section)
**Referencja:** `_SETTINGS_UI_EXPORT/settings/widgets/support_section.dart`
- Link email: `kontakt@superwizor.ai`
- Ewentualnie link do FAQ / strony pomocy

### 4. INFORMACJE PRAWNE (Legal Section)
**Referencja:** `_SETTINGS_UI_EXPORT/settings/widgets/legal_section.dart`
- Regulamin → otwiera ekran z Markdown
- Polityka Prywatności → otwiera ekran z Markdown
- Umowa DPA → otwiera ekran z Markdown (Superwizor ma dodatkowy dokument!)
- Licencje oprogramowania → ekran auto-generowany z `LicenseRegistry`

**Istniejąca baza w Superwizorze:**
- `screens/legal_markdown_screen.dart` — prosty ekran Markdown (DZIAŁA, ale jest brzydki)
- `assets/legal/` — 7 plików MD z regulaminami

**⚠️ KRYTYCZNE ZADANIE: Naprawa dokumentów prawnych**
Pliki `.md` w `assets/legal/` wyglądają źle — prawdopodobnie problem z formatowaniem Markdown (złe nagłówki, brak podziału na sekcje, zła struktura). MUSISZ:

1. Przeczytać każdy plik MD w `assets/legal/`
2. Porównać strukturę i formatowanie z plikami referencyjnymi z Labiryntu: `_SETTINGS_UI_EXPORT/legal/assets/terms_pl.md` i `_SETTINGS_UI_EXPORT/legal/assets/privacy_pl.md`
3. Przeformatować pliki Superwizora tak, aby:
   - Miały czysty, czytelny Markdown (nagłówki #, ##, ###)
   - Miały przejrzystą strukturę sekcji
   - Wyglądały pięknie po wyrenderowaniu (tak jak w Labiryncie)
4. NIE zmieniaj treści prawnej! Zmień TYLKO formatowanie Markdown.

Dodatkowo, usprawnij `legal_markdown_screen.dart` — wzoruj się na pięknym `_SETTINGS_UI_EXPORT/legal/screens/legal_document_screen.dart` z Labiryntu (gradient tła, ładne kolory nagłówków, swipe-to-go-back, MarkdownStyleSheet dopasowany do EUPHIRE).

### 5. MARKETING I SPOŁECZNOŚĆ (Marketing Section)
**Referencja:** `_SETTINGS_UI_EXPORT/settings/widgets/marketing_section.dart`
- Na razie TYLKO link do strony: `https://euphire.pl/superwizor-ai-lista-oczekujacych`
- Bez social media (jeszcze nie ma)

### 6. ZARZĄDZANIE KONTEM (Account Management Section)
**Referencja:** `_SETTINGS_UI_EXPORT/settings/widgets/account_management_section.dart`
- Reset konta (opcjonalnie — jeśli ma sens w Superwizorze)
- Usunięcie konta → otwiera dedykowany ekran/sheet z potwierdzeniem (wpisanie "USUWAM")

**Istniejąca baza w Superwizorze:**
- `widgets/hard_delete_sheet.dart` — bottom sheet usuwania konta z polem tekstowym "USUWAM"
  → Ten widget jest DOBRY i ZACHOWANY. Upewnij się, że jest podpięty do sekcji Zarządzanie Kontem.

### 7. WYLOGUJ SIĘ (Logout)
- Przycisk wylogowania na samym dole
- `await FirebaseAuth.instance.signOut()` + nawigacja do ekranu logowania
- Opcjonalnie: potwierdzenie w bottom sheet ("Na pewno chcesz się wylogować?")

---

## 🏗️ FAZA 2: Implementacja

### Krok 1: Architektura plików
Stwórz (lub rozbuduj) następującą strukturę w `lib/`:

```
lib/
├── screens/
│   ├── menu_screen.dart          ← ROZBUDUJ (główny ekran ustawień)
│   └── legal_markdown_screen.dart ← USPRAWNIJ (piękniejszy render)
├── widgets/
│   ├── settings/                  ← NOWY FOLDER
│   │   ├── account_section.dart
│   │   ├── preferences_section.dart
│   │   ├── support_section.dart
│   │   ├── legal_section.dart
│   │   ├── marketing_section.dart
│   │   └── account_management_section.dart
│   ├── profile_edit_sheet.dart    ← ROZBUDUJ (avatar upload)
│   ├── hard_delete_sheet.dart     ← ZACHOWAJ
│   ├── language_sheet.dart        ← ZACHOWAJ
│   └── licenses_screen.dart       ← NOWY (auto-licencje z LicenseRegistry)
├── providers/
│   └── settings_provider.dart     ← NOWY (wibracje, dźwięki)
```

### Krok 2: Rozbudowa `menu_screen.dart`
Obecny `menu_screen.dart` to płaska lista. Przekształć go na strukturę sekcji (wzoruj się na `_SETTINGS_UI_EXPORT/settings/screens/settings_screen.dart`):
- Zachowaj istniejący styl EUPHIRE Superwizora (`EuphireColors`, `backgroundGradient`)
- Dodaj sekcje z nagłówkami (styl `labelMedium` + RobotoMono)
- Każda sekcja to osobny widget (modularność)
- Na dole: wersja aplikacji (`package_info_plus`)

### Krok 3: Nawigacja
Superwizor UŻYWA JUŻ ikony hamburgera w AppBar `home_screen.dart` (linia 44-49):
```dart
leading: IconButton(
  icon: const Icon(Icons.menu, color: EuphireColors.frostWhite),
  onPressed: () {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const MenuScreen(),
    ));
  },
),
```
**To jest dokładnie to, czego chcemy.** Hamburger po lewej otwiera pełnoekranowy MenuScreen. NIE zmieniaj tego flow, tylko rozbuduj `MenuScreen`.

### Krok 4: Tłumaczenia (l10n)
Superwizor używa systemu `AppLocalizations` z plików `.arb` w `lib/l10n/`.
- Wszystkie nowe teksty UI dodaj do plików `.arb`
- NIE hardkoduj tekstów po polsku w widgetach (to łamie zasadę z B_05)
- Referencja kluczy z Labiryntu: patrz pliki ARB w oryginalnym projekcie

### Krok 5: Styl i Design System
**KRYTYCZNE:** Superwizor ma **własną wersję** design systemu w `lib/theme/euphire_theme.dart`. Używa klas:
- `EuphireColors` (nie `EuDesignTokens` jak w Labiryncie!)
- `EuphireTheme.themeData` (nie `AppTheme`)
- Widgety: `EuphireButton`, `EuphireCard`, `EuphireTextField`, `EuphireBottomSheet`, `EuphireListTile`, `EuphireActionSheet`

**NIE przenoś** komponentów UI z Labiryntu (`EuSection`, `EuToggle`, `EuButton` itp.). Zamiast tego **używaj istniejących widgetów Superwizora** lub stwórz nowe zgodne z lokalnym design systemem.

Mapowanie komponentów:
| Labirynt | Superwizor |
|----------|------------|
| `EuSection` | Stwórz sekcję z nagłówkiem `labelMedium` + Container z glass decoration |
| `EuToggle` | `Switch` lub `SwitchListTile` ostylowany na EUPHIRE |
| `EuButton` | `EuphireButton` |
| `EuSnackbar` | `showEuphireBottomSheet` + `EuphireActionSheet` |
| `EuDesignTokens.ember` | `EuphireColors.ember` |
| `EuDesignTokens.nocturne` | `EuphireColors.nocturne` |

---

## 🔧 FAZA 3: Naprawa dokumentów prawnych

### Problem
Pliki Markdown w `assets/legal/` renderują się brzydko. Agent MUSI:

1. Otworzyć i przeczytać każdy plik:
   - `assets/legal/terms.md`
   - `assets/legal/privacy_policy.md`
   - `assets/legal/dpa.md`
   - `assets/legal/terms_pl.md` / `terms_en.md`
   - `assets/legal/privacy_pl.md` / `privacy_en.md`

2. Ustalić, które pliki są aktualne (prawdopodobne duplikaty — `terms.md` vs `terms_pl.md`)

3. Przeformatować aktywne pliki:
   - Czyste nagłówki Markdown (`#`, `##`, `###`)
   - Listy numerowane i punktowane
   - Pogrubienia dla kluczowych definicji
   - Separatory `---` między sekcjami
   - Bez HTML-a (czysty Markdown)

4. Wzorce formatowania — patrz pliki referencyjne:
   - `_SETTINGS_UI_EXPORT/legal/assets/terms_pl.md`
   - `_SETTINGS_UI_EXPORT/legal/assets/privacy_pl.md`

---

## ✅ Checklist końcowa

Po wdrożeniu sprawdź:
- [ ] Hamburger na home screen otwiera ekran ustawień
- [ ] Sekcja TWOJE KONTO wyświetla avatar, imię, email
- [ ] Można zmienić zdjęcie profilowe (upload do Firebase Storage)
- [ ] Można edytować imię (bottom sheet)
- [ ] Sekcja PREFERENCJE ma toggle wibracji i dźwięków
- [ ] Zmiana języka (PL/EN) działa
- [ ] Sekcja WSPARCIE ma link kontaktowy
- [ ] Sekcja INFORMACJE PRAWNE prowadzi do regulaminu, polityki prywatności, DPA
- [ ] Dokumenty prawne renderują się czytelnie i pięknie
- [ ] Licencje oprogramowania się ładują (auto z LicenseRegistry)
- [ ] Sekcja MARKETING ma link do strony www
- [ ] Usunięcie konta wymaga wpisania "USUWAM" i działa
- [ ] Wylogowanie działa i przekierowuje na login
- [ ] Wersja aplikacji widoczna w stopce
- [ ] Wszystkie teksty przechodzą przez l10n (zero hardkodu)
- [ ] Kolory z `EuphireColors` (zero hardkodowanych HEX)
- [ ] Zasada głębi: elementy na wierzchu jaśniejsze od tła
- [ ] Brak `ScaffoldMessenger` / `SnackBar` — używaj `showEuphireBottomSheet`

---

## 🧠 FAZA 4: Kontekst architektoniczny (OBOWIĄZKOWE do przeczytania)

### 4.1 Architektura backend — co musisz wiedzieć

Przeczytaj koniecznie przed pracą:
- `/docs/agents/00_GLOBAL_CONTEXT.md` — globalne zasady (P1–P5)
- `/docs/agents/06_flutter-therapist-app.md` — specyfika Flutter app
- `/docs/agents/01_identity-svc.md` — serwis tożsamości (profil)

### 4.2 Zasada P4: Flutter jest READ-ONLY na raportach AI

Flutter NIGDY nie pisze raportów. To jest nienaruszalna zasada architektury. Ustawienia nie dotyczą raportów, więc to OK — ale pamiętaj, żeby żadna sekcja ustawień nie próbowała modyfikować danych klinicznych (sesji, transkrypcji, raportów).

### 4.3 Profil użytkownika — DWUPOZIOMOWA aktualizacja

W Superwizorze edycja profilu to NIE TYLKO `FirebaseAuth.updateDisplayName()`. Istniejący `profile_edit_sheet.dart` (linie 27-59) pokazuje wzorzec:

```dart
// 1. Firebase Auth update (wyświetlane imię)
await user.updateDisplayName(_controller.text);

// 2. Backend gRPC update (identity-svc PostgreSQL)
await ref.read(grpcClientsProvider).identity.updateProfile(
  UpdateProfileRequest(firstName: firstName, lastName: lastName),
);

// 3. Invalidate provider
ref.invalidate(currentUserProvider);
```

**ZACHOWAJ ten wzorzec** przy rozbudowie profilu. Każda zmiana profilu musi iść zarówno do Firebase Auth JAK I do identity-svc przez gRPC.

### 4.4 Upload zdjęcia — istniejący wzorzec

`menu_screen.dart` ma działający upload (linia 24-60):
```
ImagePicker → File → FirebaseStorage (users/{uid}/profile.jpg) → updatePhotoURL
```
Przenieś tę logikę do osobnego widgetu, ale NIE zmieniaj ścieżki Storage (`users/{uid}/profile.jpg`).

### 4.5 Usuwanie konta — istniejący `HardDeleteSheet`

`hard_delete_sheet.dart` ma flow:
1. Wpisz "USUWAM" → walidacja
2. `fcmTokenService.unregister()` (FCM cleanup)
3. `FirebaseAuth.instance.currentUser?.delete()` (kasuje konto Firebase)
4. Redirect na `LoginScreen`

Jest tam TODO na backend hard delete (`identity.hardDeleteUser`). NIE implementuj tego teraz — zostaw TODO jak jest.

### 4.6 Providery — co już istnieje

| Provider | Plik | Co robi |
|----------|------|---------|
| `grpcClientsProvider` | `providers/grpc_provider.dart` | Singleton klientów gRPC (identity, clinical, ingestion) |
| `currentUserProvider` | `providers/current_user_provider.dart` | Backend `users` row (UUID, email, role) z identity-svc |
| `therapistIdProvider` | `providers/current_user_provider.dart` | Convenience: `users.id` jako String |
| `firebaseAuthProvider` | `providers/services_provider.dart` | `FirebaseAuth.instance` |
| `localeProvider` | `providers/locale_provider.dart` | Aktualny język (PL/EN) |
| `fcmTokenServiceProvider` | `providers/services_provider.dart` | FCM token management |

Używaj tych providerów. NIE twórz duplikatów.

### 4.7 Istniejące widgety EUPHIRE w Superwizorze

| Widget | Plik | Użycie |
|--------|------|--------|
| `EuphireButton` | `widgets/euphire_button.dart` | Przyciski CTA (Ember bg) |
| `EuphireCard` | `widgets/euphire_card.dart` | Karta z glass decoration |
| `EuphireTextField` | `widgets/euphire_text_field.dart` | Pole tekstowe |
| `EuphireListTile` | `widgets/euphire_list_tile.dart` | Wiersz listy |
| `EuphireBottomSheet` | `widgets/euphire_bottom_sheet.dart` | `showEuphireBottomSheet()` |
| `EuphireActionSheet` | `widgets/euphire_action_sheet.dart` | Sheet z przyciskami akcji |
| `EuphireHeader` | `widgets/euphire_header.dart` | Nagłówek sekcji |

### 4.8 Clinical UX Writing — OBOWIĄZKOWE zasady tekstów

Każdy tekst w UI musi przestrzegać (pełne zasady: `/docs/B_05_ui_ux_design_system.md` §3, `/docs/B_09_trauma_informed_writing.md`):

- **ZAKAZ** humoru, sarkazmu, toksycznej pozytywności
- **ZAKAZ** formy bezosobowej ("Oczekujemy na...") → **NAKAZ** formy czynnej ("Kliknij", "Wysłaliśmy")
- Zaimki **Ty/Twój/Cię** ZAWSZE wielką literą
- Zdania max 15 słów
- Każdy komunikat błędu kończy się **kropką**
- Polskie cudzysłowy: „ " (nie " ")

### 4.9 Anti-patterny — czego NIE robić

- ❌ `ScaffoldMessenger.showSnackBar()` → ✅ `showEuphireBottomSheet()` + `EuphireActionSheet`
- ❌ `AlertDialog` → ✅ `showEuphireBottomSheet()`
- ❌ Hardcoded kolory (`Color(0xFF...)`) → ✅ `EuphireColors.*`
- ❌ Hardcoded teksty po polsku → ✅ `AppLocalizations.of(context)!.klucz`
- ❌ `Colors.black` na tle jako container → ✅ Jaśniejsze elementy na ciemnym tle (zasada głębi)
- ❌ Bypass `AuthInterceptor` przy gRPC → ✅ Zawsze przez `ref.read(grpcClientsProvider)`
- ❌ Cachowanie Firebase ID token → ✅ `getIdToken()` przy każdym wywołaniu (auto-refresh)
