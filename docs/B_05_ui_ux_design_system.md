# 05_UI_UX_DESIGN_SYSTEM.md - EUPHIRE DESIGN SYSTEM & UX WRITING

**WERSJA:** 1.0_Clinical_Crisis
**STATUS:** DOKUMENT WYKONAWCZY (UI/UX). Każdy wygenerowany komponent UI oraz każdy tekst (L10n/ARB) MUSI bezwzględnie przejść przez filtry opisane w tym pliku.

---

## 🔌 1. INTEGRACJA ZE STITCH / FIGMA I ARCHITEKTURA (MCP WORKFLOW)
- **Komponentyzacja (Atomic Design):** Absolutnie zabronione jest hardkodowanie widoków i ekranów. Wszystko musi opierać się na reużywalnych komponentach. Budujemy klocki takie jak: `EuphireButton`, `EuphireHeader` (wspierający teksty poboczne), `EuphireBottomSheet`, `EuphirePopup`.
- **Zasady Głębi (Elevation):** Głównym kolorem tła aplikacji jest Ciemny (Evergreen). Kontenery i pudełka MUST be "wyżej" - co oznacza że powinny być jaśniejsze (lub nakładać się lekko) od tła bazowego. Projektowanie ciemniejszych boksów na jasnym/Evergreen tle jest ZABRONIONE wizualnie.
- **Odczyt AI (Przekład na System):** W przypadku wklejania przez MCP Designów ze Stitcha, należy bezwzględnie zmapować je na Design System opisany poniżej: `Evergreen`, `Montserrat`, `Frost White`, a powiadomienia typu Snackbar zawsze zastępować `EuphirePopup`.

---

## 👁️ 2. IDENTYFIKACJA WIZUALNA (BRAND IDENTITY)
Marka EUPHIRE łączy nowoczesną elegancję z przyjaznym, ludzkim charakterem.

### A. Paleta Kolorów (Zmienne Flutter / Theme)
**1. Primary Palette (Baza):**
- **Ember** (#FCAE2F) - Akcent, wezwania do akcji (CTA).
- **Evergreen** (#004D54) - Główny ton wizualny. Tło dla jasnego logo, główny ekran profilu.
- **Obsidian Black** (#1F1F1F) - Neutralna baza, główny tekst i czcionki.
- **Frost White** (#FAFAFA) - Neutralna baza, tła kart i Bottom Sheetów.

**2. Complementary & Accent Palette:**
- **Mist** (#B2CACC) - Stonowany akcent, obrys.
- **Nocturne** (#002E32) - Głębia do gradientów tła.
- **Aurora** (#6759FF) & **Magma** (#D84515) - Rzadkie akcenty punktowe.

### B. Typografia (Fonty Google)
- **Montserrat (SemiBold, Medium):** Do nagłówków (Headlines) i tekstów na przyciskach. Nowoczesny. (Line-height: 120%, Letter-spacing: 1-2%).
- **Merriweather (Bold, Regular, Italic):** Paragraph text. Humanistyczny szeryf do dłuższych ciał artykułów (np. Raporty sztucznej inteligencji). Italic tylko dla wyjątkowych form. (Line-height: 150%).
- **Roboto Mono (Medium, Regular):** Overlines, tagi, stample czasowe powiadomień. (Line-height: 150%, Letter-spacing: 2-5%).

### C. Zastrzeganie Logo
Osadzone przez `flutter_svg`. EUPHIRE Primary to wektor `Ember` na tle `Evergreen`. Reszta to monochrome.

---

## ✍️ 3. CLINICAL UX WRITING (TRAUMA-INFORMED CARE)
Słowa to narzędzie lecznicze w naszej aplikacji dla pacjentów oraz w bezpiecznej przestrzeni dla specjalistów w kryzysie. Zdejmujemy brzemię presji z układu nerwowego.

### 🚨 Czego BEZWZGLĘDNIE NIE ROBIMY:
- **ZAKAZ Humoru/Sarkazmu:** Zero unieważniania uciążliwości losu.
- **ZAKAZ Toksycznej Pozytywności:** Ani słowa w stylu "Będzie dobrze" lub "Możesz wszystko". Tolerujemy cierpienie i zdejmujemy wstyd (Walidacja: "To zrozumiałe, że czujesz się zmęczony/a po 8 pacjentach").
- **ZAKAZ Przypuszczeń i Moralizowania:** Maszyna mówi bezwarunkowo.
- **ZAKAZ Form Bezosobowych (ZOMBIE):** ❌ "Oczekujemy na logowanie", "Należy kliknąć", "Zlecono aktualizację". ✅ "Kliknij", "Wysłaliśmy powiadomienie".
- **ZAKAZ słów-bufonów / żargonu:** np. *Landing page, afekt, iż*!

### 📏 Język bez Napięcia:
- Zdania nie przekraczają 15 słów. Każdy komunikat błędu kończy się kropką.
- Zaimki **Cię, Ty, Tobie** ZAWSZE Dużą Literą. Wskazania własne **nasz, my, wysłaliśmy** małą (Poczucie służebności techniki).
- Pierwsze słowa buttonów wielką literą -> **"Zapisz w pamięci sesji."**
- Polskie znaki interpunkcyjne: „ ” (Cudzysłowy w raportach) oraz półpauza –.

---

## 🤖 4. KLAUZULA BEZWZGLĘDNEGO WYKONANIA AI (UX ENFORCER)

Przed dostarczeniem jakiegokolwiek kodu Flutterowego widoku, agent LLM musi automatycznie odpowiedzieć "TAK" na następującą checklistę i dopisać to na końcu wykonanej logiki:
1. [ ] Czy zbudowałem ekrany w oparciu o Component Driven Design bez wpisywania hardkodowanych kolorów HEX (tylko theme zmienne EUPHIRE)?
2. [ ] Czy alert zastąpiłem okrągłym przyjaznym `EuphirePopup` lub szufladą dolną `EuphireBottomSheet`?
3. [ ] Czy w kodzie brak jest toksycznego zachęcania i humoru i czy zastosowano polskie poprawne cudzysłowy?
4. [ ] Czy wyciąłem CAŁĄ stronę bierną ze słów kluczy i zamieniłem na czyny?
5. [ ] Czy jest ZAWSZE KROPKA na końcu każdego nagłówka, powiadomienia oraz opisu na wyświetlaczu?
6. [ ] Zaimki `Ty/Twój` - kapitalizacja?
7. [ ] KONTRAST KART: Czy nie użyto `EuphireColors.nocturne` dla kart/pudełek na tle `evergreen`? (Należy użyć jaśniejszego tła np. `Colors.white.withValues(alpha: 0.05)` lub `0.1` by zbudować prawidłową elewację).
8. [ ] OBSŁUGA BŁĘDÓW: Czy w `catch` do wyświetlania błędu użyto `showEuphireBottomSheet` i `EuphireActionSheet` zamiast domyślnego `ScaffoldMessenger.showSnackBar`?
9. [ ] ZAKAZ HARDKODU: Czy absolutnie wszystkie teksty i komunikaty prowadzą przez plik `l10n/app_pl.arb` i `AppLocalizations.of(context)`?
