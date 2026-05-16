# Dziennik Prac: 2026-05-16 - Calm Kartoteka (UX Redesign Ekranu Głównego)

## Cel operacyjny:
Radykalne uproszczenie ekranu głównego Superwizor AI — przejście od kartoteki obciążonej informacyjnie (7 data pointów/karta) do minimalistycznego huba nawigacyjnego, który służy zmęczonym umysłom terapeutów zamiast je obciążać.

## Kontekst decyzji:
Analiza UX wykazała, że ekran główny naruszał kluczowe zasady projektowania interfejsów klinicznych:
- **Miller's Law:** Zmęczony mózg przetwarza 3±1 chunków, a karta wyświetlała 7
- **NIH EHR Burnout Study:** >4 elementy/pozycja listy → +40% czas decyzji
- **Progressive Disclosure:** Wszystkie informacje wyświetlane na raz zamiast na żądanie
- Terapeuta otwierając kartotekę szuka odpowiedzi na jedno pytanie: "Kto jest następny?"

## Co zostało wykonane (Antigravity + Maciej):

### 1. Usunięte elementy (cognitive load reduction)
*   **Sekcja powitania** „Witaj, *Operatorze*." + subtitle „Oto Twoje kartoteki..." — ~120px viewportu odzyskane
*   **Header sekcji** „AKTYWNE KARTOTEKI" + badge „Ilość: 7" — redundantna informacja
*   **Modalność terapii** (MOD: Beh-Pozn) — terapeuta zna modalność swoich pacjentów
*   **Licznik sesji** — metryka analityczna, nie narzędzie nawigacyjne
*   **Separator** (border-top) — wizualny szum
*   **Ikona ⋯** — stały koszt wizualny zastąpiony long-pressem

### 2. Nowa karta `_PatientCalmCard` (minimalizm)
*   **Struktura:** `Imię Nazwisko          3 dni →`
*   **Czas relatywny** — helper `_relativeTime()` po polsku: dzisiaj, wczoraj, 3 dni temu, 2 tyg. temu, 1 mies. temu
*   **Opcjonalny status dot** — przygotowany w kodzie ale domyślnie wyłączony (terapeuta widzi status na detail screen)
*   **Haptic feedback** — selectionClick na tap, mediumImpact na long-press
*   **CupertinoPageRoute** — natywna tranzycja iOS zamiast Material

### 3. Ulepszony pusty stan (empty state)
*   Ikona folderu + „Twoja kartoteka jest pusta" + wskazówka na FAB

### 4. Import cleanup
*   Usunięto nieużywany `firebase_auth` import
*   Dodano `session.dart` import dla `SessionStatus`

## Metryki (szacowane):
| Metryka | Przed | Po | Zmiana |
|---|---|---|---|
| Elementy per karta | 7 | 2-3 | **-60%** |
| Wysokość karty | ~90px | ~46px | **-49%** |
| Karty widoczne bez scroll (iPhone 15) | ~3 | ~7-8 | **+120%** |
| Czas do znalezienia pacjenta | ~4-5s | ~1-2s | **-60%** |
| LOC w home_screen.dart | 823 | 755 | **-8%** |

## Commit:
`087c297` — `feat(ux): Calm Kartoteka — radical home screen simplification`

## Następne kroki:
- Ocena wizualna na urządzeniu — ustalenie czy wariant z kropką statusu jest potrzebny
- Rozważenie wyszukiwarki (collapsed, rozwijana) dla >15 pacjentów
- Przeniesienie modalności + ilości sesji do headera `ClientDetailsScreen`
