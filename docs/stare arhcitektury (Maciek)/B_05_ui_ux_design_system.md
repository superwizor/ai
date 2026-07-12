---
type: Legacy Architecture
title: "05_UI_UX_DESIGN_SYSTEM.md - EUPHIRE DESIGN SYSTEM & QUALITY GUARD"
description: "WERSJA: 2.0ClinicalCrisis STATUS: DOKUMENT WYKONAWCZY (UI/UX & CODE QUALITY). Każdy wygenerowany komponent UI oraz kod backendowy/frontendowy MUSI bezwzględn..."
resource: file:///Users/maciekckoklormam91/Desktop/Inne/APP%20-%20Superwizor%20AI/docs/stare%20arhcitektury%20%28Maciek%29/B_05_ui_ux_design_system.md
tags: [stare-arhcitektury--maciek-]
timestamp: 2026-05-30T14:32:36+02:00
---

# 05_UI_UX_DESIGN_SYSTEM.md - EUPHIRE DESIGN SYSTEM & QUALITY GUARD

**WERSJA:** 2.0_Clinical_Crisis
**STATUS:** DOKUMENT WYKONAWCZY (UI/UX & CODE QUALITY). Każdy wygenerowany komponent UI oraz kod backendowy/frontendowy MUSI bezwzględnie przejść przez filtry opisane w tym pliku.

---

## 🔌 1. INTEGRACJA ZE STITCH / FIGMA I ARCHITEKTURA (MCP WORKFLOW)
- **Komponentyzacja (Atomic Design):** Absolutnie zabronione jest hardkodowanie widoków i ekranów. Wszystko musi opierać się na reużywalnych komponentach. Budujemy klocki takie jak: `EuphireButton`, `EuphireHeader` (wspierający teksty poboczne), `EuphireBottomSheet`, `EuphirePopup`.
- **Zasady Głębi (Elevation):** Głównym kolorem tła aplikacji jest Ciemny (Evergreen). Kontenery i pudełka MUST be "wyżej". **ZASADA: TO CO JEST NA WIERZCHU, MA BYĆ JAŚNIEJSZE OD TEGO CO JEST POD SPODEM!** (Zamiast `nocturne` używaj np. `Colors.white.withValues(alpha: 0.05)`). Projektowanie ciemniejszych boksów na jasnym/Evergreen tle jest ZABRONIONE wizualnie.
- **Odczyt AI (Przekład na System):** W przypadku wklejania przez MCP Designów ze Stitcha, należy bezwzględnie zmapować je na Design System opisany poniżej: `Evergreen`, `Montserrat`, `Frost White`, a powiadomienia typu Snackbar zawsze zastępować modalami np. `EuphireBottomSheet`.

---

## 👁️ 2. IDENTYFIKACJA WIZUALNA I WERYFIKACJA (BRAND IDENTITY & CHECKER)
Marka EUPHIRE łączy nowoczesną elegancję z przyjaznym, ludzkim charakterem.

### A. Paleta Kolorów (Zmienne Flutter / Theme)
- ❌ **Hardcoded Kolory**: Nie używaj `Colors.red` lub `#FCAE2F` bezpośrednio w kodzie. `Colors.white`, `Color(0xFF141D2B)`.
- ✅ Odwołania do schematu, powiązane z `Evergreen`, `Ember`, `Frost White` poprzez `Theme.of(context)`.
- ✅ Tryb Ciemny (Dark Mode First): Tło aplikacji pozostaje Ciemne `Evergreen`, z jaśniejszymi elementami u góry (Containers, Cards).
- **Ember** (#FCAE2F) - Akcent, wezwania do akcji (CTA).
- **Evergreen** (#004D54) - Główny ton wizualny.
- **Obsidian Black** (#1F1F1F) - Neutralna baza, główny tekst.
- **Frost White** (#FAFAFA) - Neutralna baza, tła kart i Bottom Sheetów.
- **Mist** (#B2CACC) - Stonowany akcent, obrys.
- **Nocturne** (#002E32) - Głębia do gradientów tła.
- **Aurora** (#6759FF) & **Magma** (#D84515) - Rzadkie akcenty punktowe.

### B. Typografia (Lokalne czcionki w assets)
- ❌ `TextStyle(fontFamily: 'Arial')`.
- ❌ Mały, nieczytelny tekst poniżej 12sp. Dla lekarzy używamy dostępności!
- ❌ Zewnętrzne paczki takie jak `google_fonts`. ZAWSZE używamy zdefiniowanych lokalnych fontów przez `TextStyle(fontFamily: '...')`.
- ✅ **Montserrat (SemiBold, Medium):** Do nagłówków (Headlines) i tekstów na przyciskach. Nowoczesny.
- ✅ **Merriweather (Bold, Regular, Italic):** Paragraph text. Humanistyczny szeryf do dłuższych ciał artykułów (np. Raporty sztucznej inteligencji).
- ✅ **Roboto Mono (Medium, Regular):** Overlines, tagi, stample czasowe powiadomień.

### C. Zaokrąglenia i Elevation (Pudełka)
- ✅ `BorderRadius.circular(8)` dla małych kart.
- ✅ `BorderRadius.circular(12)` do standardowych pojemników głównych.
- ✅ Przezroczyste Glass efekty przy Bottom Sheets (`BackdropFilter`).
- ❌ Kwadratowe `border-radius: 0`, sztywne cienie rzucające się w oczy bez rozmycia.

### D. Interakcje (Hover i Click)
- ✅ Oczekujemy 300ms Duration mikroskopijnych animacji dla wciśnięć buttonów zamiast pustej błyskawicznej zmiany.

---

## ✍️ 3. CLINICAL UX WRITING (TRAUMA-INFORMED CARE)
Słowa to narzędzie lecznicze w naszej aplikacji dla pacjentów oraz w bezpiecznej przestrzeni dla specjalistów w kryzysie. Zdejmujemy brzemię presji z układu nerwowego.

### 🚨 Czego BEZWZGLĘDNIE NIE ROBIMY:
- **ZAKAZ Humoru/Sarkazmu:** Zero unieważniania uciążliwości losu.
- **ZAKAZ Toksycznej Pozytywności:** Ani słowa w stylu "Będzie dobrze" lub "Możesz wszystko". Tolerujemy cierpienie i zdejmujemy wstyd.
- **ZAKAZ Przypuszczeń i Moralizowania:** Maszyna mówi bezwarunkowo.
- **ZAKAZ Form Bezosobowych (ZOMBIE):** ❌ "Oczekujemy na logowanie". ✅ "Kliknij", "Wysłaliśmy powiadomienie".
- **ZAKAZ słów-bufonów / żargonu:** np. *Landing page, afekt, iż*!

### 📏 Język bez Napięcia:
- Zdania nie przekraczają 15 słów. Każdy komunikat błędu kończy się kropką.
- Zaimki **Cię, Ty, Tobie** ZAWSZE Dużą Literą. Wskazania własne **nasz, my, wysłaliśmy** małą.
- Polskie znaki interpunkcyjne: „ ” (Cudzysłowy w raportach) oraz półpauza –.

---

## 🛡️ 4. QUALITY GUARD (BEZPIECZEŃSTWO I KOD)
Zasady wymagane do codziennego programowania i szybkich Code Reviews.

### A. Globalność i Hardcoding
- ❌ **Hardcoded Kolekcje Firestore**: `FirebaseFirestore.instance.collection('users')` wpisane z palca na samym dole interfejsu.
- ✅ Każda kolekcja Firestore musi mieć swój const/stale repozytorium na warstwie `data`.

### B. Anty-Shortcuts
- ❌ `as dynamic` lub `as any` - wymuszamy Type Safety w Dart 3.0.
- ❌ Ignorowanie błędów w try-catch (połykanie błędu). 
- ✅ Każdy catch deleguje błąd do Crashlytics / lokalnego Loggera oraz wyświetla poprawne UI (`EuphireBottomSheet`).
- ❌ `setState` u góry gigantycznego modyfiku widgetu UI wywołujący niepotrzebne 200 re-renderów.
- ✅ Hermetyzacja stanu z wykorzystaniem odpowiedniej i docelowej biblioteki wstrzykiwania (np. Riverpod, Bloc, lokalny ValueNotifier).

### C. Bezpieczeństwo i Backend Boundary (Flutter <-> Firebase)
- ❌ Walidacja transkryptu na froncie, a potem wysyłka czystego stringa na Firestore. 
- ✅ Frontend to tylko "głupi klient". Logika wrażliwa i walidacje PII Dzieją się w **Google Cloud Functions / GCS**. 
- ❌ Kopiowanie wrażliwych danych użytkownika w klaster publiczny.
- ✅ Firestore Security Rules! Każde nowe Query z Fluttera **Musi posiadać** limit (`.limit()`). Czekanie na OOM appki u klienta to zbrodnia kliniczna.

### D. Wzorce MedTech
- Pamiętaj! Jesteś w systemie MedTech. Ustawiaj logikę w `Cloud Functions`, aby w razie błędu u pacjenta zmienić wersję diagnozy bez wysyłania łatki do AppStore lub Google Play!

---

## 🤖 5. KLAUZULA BEZWZGLĘDNEGO WYKONANIA AI (UX ENFORCER)
Przed dostarczeniem jakiegokolwiek kodu Flutterowego widoku, agent LLM musi automatycznie odpowiedzieć "TAK" na następującą checklistę i dopisać to na końcu wykonanej logiki:
1. [ ] Czy zbudowałem ekrany w oparciu o Component Driven Design bez wpisywania hardkodowanych kolorów HEX (tylko theme zmienne EUPHIRE)?
2. [ ] Czy alert zastąpiłem okrągłym przyjaznym `EuphirePopup` lub szufladą dolną `EuphireBottomSheet` zamiast defaultowych (np. `AlertDialog` lub `ScaffoldMessenger`)?
3. [ ] Czy w kodzie brak jest toksycznego zachęcania i humoru i czy zastosowano polskie poprawne cudzysłowy?
4. [ ] Czy wyciąłem CAŁĄ stronę bierną ze słów kluczy i zamieniłem na czyny?
5. [ ] Czy jest ZAWSZE KROPKA na końcu każdego nagłówka, powiadomienia oraz opisu na wyświetlaczu?
6. [ ] Zaimki `Ty/Twój` - kapitalizacja?
7. [ ] KONTRAST KART: Czy "to co jest na wierzchu jest jaśniejsze od tego co pod spodem"? Nie używaj mrocznego `nocturne` jako tła kontenerów!
8. [ ] OBSŁUGA BŁĘDÓW: Czy w `catch` do wyświetlania błędu użyto `showEuphireBottomSheet` i `EuphireActionSheet`?
9. [ ] ZAKAZ HARDKODU: Czy absolutnie wszystkie teksty prowadzą przez plik `l10n/app_pl.arb`?
