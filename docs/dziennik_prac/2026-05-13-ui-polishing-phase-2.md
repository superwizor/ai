# Zmiany EUPHIRE – 2026-05-13: Wyczesane UI Faza 2 z 3 (Stabilne)

## Zadania zrealizowane
1. **Nawigacja Swipe-to-Go-Back (`home_screen.dart` / `menu_screen.dart`)**:
   - Zastąpiono `MaterialPageRoute` użyciem `CupertinoPageRoute` przy przechodzeniu do ekranu menu. Zapewnia to natywny dla iOS gest "przeciągnij by cofnąć", znacznie poprawiając wrażenia z użytkowania.
   
2. **Polishing Ekranu Sesji (`new_session_screen.dart`)**:
   - Całkowicie usunięto zbyteczny wybór języka raportu na poziomie tworzenia nowej sesji. Zmienne stanu oraz flagi z nim powiązane zostały usunięte, a język bazowy (`pl`) został ustawiony w żądaniach `CreateAudioUploadRequest` i `CompleteAudioUploadRequest` na sztywno.
   - Przeprojektowano boks informacyjny ochrony danych osobowych ("Twoje nagrania są chronione szyfrowaniem end-to-end...") stosując elegancki Glassmorphism dopasowany do motywu Nocturne. Zmieniono jaskrawozielony kolor tła na delikatnie przezroczysty z obwódkami o małym opacity, a ikonkę zmieniono na stonowany `mist`.

3. **Naprawa Overflow Nazwy Użytkownika (`menu_screen.dart`)**:
   - Zabezpieczono ekran Ustawień (`MenuScreen`) przed błędami "Right Overflowed" przy długim imieniu użytkownika. Zastosowano widget `Flexible()` obejmujący element wchodzący do parametru `trailing` sekcji `_SettingsRow`, co gwarantuje poprawne ucięcie tekstu do elipsy (`...`).

4. **Mapowanie Nazw Nurtów (`home_screen.dart`)**:
   - Zastąpiono surowe identyfikatory nurtów w kafelkach domowych (`CBT`, `PPT`, `PSYCHO`) eleganckimi, pełnymi nazwami dla lepszej czytelności (np. "Beh-Pozn", "Pozytywna", "Psychodynamiczna").

## Stan Aplikacji
- Wyczesane UI Faza 2 z 3.
- Stabilne.
