## 1. Administrator danych

Administratorem danych osobowych użytkowników Serwisu jest spółka Superwizor sp. z o.o. (dalej: **Administrator**), z siedzibą w Polsce.

> **Status dokumentu.** Wersja robocza — przed uruchomieniem komercyjnym zostanie zweryfikowana przez inspektora ochrony danych.

## 2. Kategorie przetwarzanych danych

Administrator przetwarza następujące kategorie danych:

- **Dane konta** — adres email, imię i nazwisko, modalność terapeutyczna.
- **Dane organizacji** — nazwa prawna, adres, dane administratora.
- **Dane sesji** — nagrania audio sesji terapeutycznych, transkrypcje, raporty.
- **Dane techniczne** — adres IP, identyfikator urządzenia, znacznik czasu logowania.

## 3. Podstawa prawna i cele

| Cel przetwarzania | Podstawa prawna (RODO) |
|---|---|
| Świadczenie usług | art. 6 ust. 1 lit. b — wykonanie umowy |
| Wystawianie faktur | art. 6 ust. 1 lit. c — obowiązek prawny |
| Marketing własnych usług | art. 6 ust. 1 lit. a — zgoda |
| Bezpieczeństwo i ochrona przed nadużyciami | art. 6 ust. 1 lit. f — prawnie uzasadniony interes |

## 4. Lokalizacja danych

Wszystkie dane są przechowywane w infrastrukturze Google Cloud Platform w regionie `europe-central2` (Warszawa). Dane nie są transferowane poza Europejski Obszar Gospodarczy.

## 5. Okres przechowywania

- Dane konta — przez okres trwania umowy oraz 6 lat po jej rozwiązaniu (obowiązki podatkowe).
- Nagrania audio — domyślnie 30 dni od końca sesji, chyba że Użytkownik wybierze dłuższy okres przechowywania w ustawieniach.
- Transkrypcje i raporty — przez okres trwania umowy, do momentu manualnego usunięcia przez Użytkownika.

## 6. Prawa Użytkownika

Użytkownikowi przysługują następujące prawa, które można zrealizować w wymienionej kolejności:

1. dostęp do danych (art. 15 RODO),
2. sprostowanie (art. 16),
3. usunięcie ("prawo do bycia zapomnianym", art. 17),
4. ograniczenie przetwarzania (art. 18),
5. przenoszenie danych (art. 20),
6. sprzeciw wobec przetwarzania (art. 21),
7. skarga do Prezesa UODO (uodo.gov.pl).

Realizacja tych praw odbywa się przez email: `dpo@superwizor.ai`.

## 7. Bezpieczeństwo

Dane są szyfrowane w spoczynku (AES-256) oraz w trakcie transmisji (TLS 1.3). Dostęp do danych klinicznych mają wyłącznie autoryzowani terapeuci. Modele AI **nie są trenowane na danych Użytkownika** — szczegóły w [DPA](/legal/dpa).
