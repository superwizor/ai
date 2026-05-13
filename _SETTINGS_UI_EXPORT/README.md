# 📦 Settings UI Export – EUPHIRE Design System

Eksport kodu UI z Labirynt Premium do ponownego wykorzystania w drugiej apce EUPHIRE.
**52 plików** (47 Dart + 5 Markdown)

## Struktura plików

```
_SETTINGS_UI_EXPORT/
│
├── settings/                              ← GŁÓWNY EKRAN USTAWIEŃ
│   ├── screens/
│   │   └── settings_screen.dart           ← Kompozycja wszystkich sekcji
│   ├── widgets/
│   │   ├── account_section.dart           ← TWOJE KONTO (imię, email, avatar)
│   │   ├── account_management_section.dart ← ZARZĄDZANIE KONTEM + WYLOGUJ SIĘ
│   │   ├── preferences_section.dart       ← PREFERENCJE (wibracje, dźwięki, język)
│   │   ├── support_section.dart           ← WSPARCIE
│   │   ├── legal_section.dart             ← INFORMACJE PRAWNE
│   │   ├── marketing_section.dart         ← MARKETING I SPOŁECZNOŚĆ
│   │   ├── session_section.dart           ← Sekcja sesji
│   │   └── settings_header.dart           ← Nagłówek (logo + tytuł + zamknięcie)
│   └── data/
│       └── app_config_repository.dart     ← Remote Config / wersjonowanie
│
├── auth/                                  ← KONTO UŻYTKOWNIKA (pełna logika!)
│   ├── screens/
│   │   ├── profile_screen.dart            ← Ekran profilu
│   │   ├── avatar_upload_screen.dart      ← Zdjęcie profilowe (picker+crop+upload)
│   │   ├── account_delete_screen.dart     ← Usuwanie konta (potwierdzenie + bottom sheet)
│   │   └── account_reset_screen.dart      ← Resetowanie konta (potwierdzenie)
│   ├── data/
│   │   ├── auth_repository.dart           ← Firebase Auth (login/logout/delete)
│   │   └── user_repository.dart           ← Firestore CRUD profilu użytkownika
│   └── services/
│       └── auth_checker_service.dart      ← Sprawdzanie stanu autoryzacji
│
├── legal/                                 ← DOKUMENTY PRAWNE
│   ├── screens/
│   │   ├── legal_document_screen.dart     ← Renderowanie regulaminów (Markdown)
│   │   └── licenses_screen.dart           ← Licencje open-source (auto z Flutter)
│   └── assets/
│       ├── terms_pl.md / terms_en.md      ← Regulamin PL/EN
│       └── privacy_pl.md / privacy_en.md  ← Polityka prywatności PL/EN
│
├── core/                                  ← CAŁY DESIGN SYSTEM EUPHIRE
│   ├── theme/
│   │   ├── euphire_design_tokens.dart     ← Kolory, spacing, typography tokens
│   │   ├── eu_text_styles.dart            ← Style tekstowe
│   │   └── app_theme.dart                 ← ThemeData (dark/light)
│   ├── ui/
│   │   ├── eu_components.dart             ← Barrel file (eksportuje wszystko poniżej)
│   │   ├── eu_photo_source_picker.dart    ← Picker źródła zdjęcia (galeria/aparat)
│   │   ├── eu_toast.dart                  ← Toast notyfikacje
│   │   ├── eu_bottom_sheet.dart           ← Bottom sheet bazowy
│   │   ├── buttons/eu_button.dart         ← Przycisk EUPHIRE
│   │   ├── cards/eu_card.dart             ← Karta
│   │   ├── cards/eu_glass_card.dart       ← Karta szklana (glassmorphism)
│   │   ├── feedback/eu_snackbar.dart      ← Snackbar (success/error/info)
│   │   ├── feedback/eu_error_widget.dart  ← Widget błędu
│   │   ├── inputs/eu_toggle.dart          ← Toggle switch
│   │   ├── inputs/eu_input.dart           ← Pole tekstowe
│   │   ├── layout/eu_section.dart         ← Sekcja z nagłówkiem
│   │   ├── layout/eu_list_tile.dart       ← List tile
│   │   ├── layout/eu_scaffold.dart        ← Scaffold z gradientem
│   │   └── modals/eu_bottom_sheet.dart    ← Modal bottom sheet
│   ├── providers/
│   │   ├── settings_provider.dart         ← Stan ustawień (dźwięk, wibracje, język)
│   │   ├── session_provider.dart          ← Stan sesji
│   │   └── user_provider.dart             ← Stan użytkownika (Firestore stream)
│   ├── extensions/
│   │   └── l10n_extension.dart            ← Extension `context.l10n`
│   └── services/
│       ├── analytics_service.dart         ← Analytics (Firebase)
│       └── connectivity_service.dart      ← Sprawdzanie połączenia z internetem
│
├── core_utils/
│   └── app_haptics.dart                   ← Helper do wibracji
│
└── models/
    ├── user_profile.dart                  ← Model UserProfile
    ├── favorite_item.dart                 ← Model FavoriteItem
    └── favorite_item.g.dart              ← Generated (json_serializable)
```

## Zależności zewnętrzne (pubspec.yaml)

```yaml
dependencies:
  flutter_riverpod:          # State management
  firebase_auth:             # Autentykacja
  cloud_firestore:           # Baza danych profili
  firebase_storage:          # Upload zdjęć profilowych
  image_picker:              # Wybór zdjęcia z galerii/aparatu
  go_router:                 # Nawigacja
  package_info_plus:         # Wersja apki w stopce
  url_launcher:              # Otwieranie linków (wsparcie, social)
  flutter_markdown:          # Renderowanie regulaminów (.md)
  share_plus:                # Udostępnianie (marketing)
  shared_preferences:        # Lokalne ustawienia
  font_awesome_flutter:      # Ikony (social media)
  google_sign_in:            # Google Sign-In
  sign_in_with_apple:        # Apple Sign-In
  uuid:                      # Generowanie UUID
```

## Co wymaga adaptacji przy przenoszeniu

1. **Import paths** – zmień `package:labirynt_premium/` na `package:<nowa_apka>/` we WSZYSTKICH plikach
2. **Sekcje do usunięcia z settings_screen.dart:**
   - `DuoModeSection` (import + widget)
   - `CategoriesSection` (import + widget)
   - `NotificationsSection` (import + widget)
   - `PremiumSection` (import + widget)
   - `_PartyPlayersHeader` (cała klasa + logika)
3. **preferences_section.dart** – `gameRepositoryProvider` jest użyty przy zmianie języka (linia 239/256). Zamień na logikę ładowania danych nowej apki lub usuń.
4. **Routing** – dodaj routy do nowego routera:
   - `/legal-terms` → `LegalDocumentScreen`
   - `/legal-privacy` → `LegalDocumentScreen`
   - `/licenses` → `LicensesScreen`
   - `/profile` → `ProfileScreen`
   - `/profile/avatar-upload` → `AvatarUploadScreen`
   - `/profile/account-reset` → `AccountResetScreen`
   - `/profile/account-delete` → `AccountDeleteScreen`
5. **Assets** – skopiuj `legal/assets/*.md` → `assets/legal/` i zarejestruj w `pubspec.yaml`
6. **Tłumaczenia** – skopiuj klucze `settings*`, `paywall*` z plików `.arb`
7. **eu_components.dart** – popraw ścieżki eksportów w barrel file na nowe paths
