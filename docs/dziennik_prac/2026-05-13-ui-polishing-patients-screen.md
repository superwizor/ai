# Zmiany EUPHIRE – 2026-05-13: UI Ekranu Pacjentów & Wybór Języka

## Zadania zrealizowane
1. **Polishing Ekranu Głównego (`home_screen.dart`)**:
   - Wdrożono układ ze Stitcha (Design: "Patients List - Data Shield v2").
   - Dodano obsługę "Glassmorphism" w kartach, przezroczystości `0.04` z borderem `0.08` dla zgodności z platformą EUPHIRE.
   - Zastąpiono tradycyjny AppBar nowoczesnym dwupoziomowym nagłówkiem zawierającym przywitanie oraz logo SVG z napisem "Superwizor AI".
   - Przesunięto hamburger (ikonę menu) na prawą stronę (usunięto baner "DEBUG" blokujący go).
   - Wprowadzono logikę menu kontekstowego ("3 kropki") wywołującego BottomSheet (Zarządzaj kartoteką: Edytuj/Usuń).
   - Oparto proces usuwania klienta o nową 3-warstwową logikę: Trigger -> Ostrzeżenie z toggle (RODO) -> Potwierdzenie z hasłem `USUWAM`.

2. **Wybór języka raportu AI (`add_patient_modal.dart` & `patient_provider.dart`)**:
   - Dodano pole do definiowania języka (pl-PL, en-US, de-DE, es-ES) podczas tworzenia nowej kartoteki (Modal dodawania pacjenta).
   - Zaktualizowano `addPatient` w `patient_provider.dart`, aby akceptował i przesyłał `languageCode` pod kluczem `patientLanguageCode` w `CreatePatientFileRequest` do usługi gRPC.

## Napotkane Blokady
- Błędy ze zrekonstruowanym plikiem `menu_screen.dart` zostały naprawione (błędne przypisania w konstruktorach `LegalMarkdownScreen` i `ProfileEditSheet`).

## Następne kroki
- Integracja edycji danych pacjenta (`_editName`).
- Upewnienie się z zespołem backendowym, jak dalej procesować parametr `patientLanguageCode`.
