# Superwizor AI — Bezpieczeństwo danych w skrócie

*Jedna strona dla klientów enterprise. Wersja 1.0, 2026-07-18.*
*Szczegóły techniczne i prawne: dokument 06 oraz pakiet compliance (retencja, RCP, DPIA) — udostępniamy na życzenie.*

---

**Superwizor AI analizuje sesje terapeutyczne — czyli pracuje na najbardziej wrażliwych danych, jakie istnieją. Zaprojektowaliśmy system tak, żeby dane były chronione domyślnie, a nie na życzenie.**

---

### Dane zostają w Europie

Nagrania, transkrypcje i raporty są przechowywane i przetwarzane wyłącznie w Unii Europejskiej (Polska i Holandia). Rozpoznawanie mowy również odbywa się na infrastrukturze europejskiej — system jest zbudowany tak, że treść sesji nie ma technicznej możliwości opuszczenia UE.

### Nikt nie trenuje modeli na Waszych danych

Dostawcy AI, z których korzystamy, nie używają danych z sesji do ulepszania swoich modeli. To nie deklaracja handlowa, lecz właściwość wbudowana w system na stałe — niemożliwa do wyłączenia i możliwa do zaudytowania.

### Nagranie znika, zanim zdążysz o nim pomyśleć

Plik audio jest usuwany automatycznie natychmiast po transkrypcji — najpóźniej w ciągu 48 godzin, bezwarunkowo. Wszystkie pozostałe dane są szyfrowane zarówno podczas przesyłania, jak i przechowywania, z regularną rotacją kluczy.

### Pseudonimizacja wbudowana w produkt

Raporty z sesji, ich podsumowania i pamięć kontekstowa AI są automatycznie pseudonimizowane: nazwiska, adresy, numery telefonów i dokumentów, nazwy pracodawców, szkół i miejscowości są zastępowane neutralnymi oznaczeniami. Imiona pozostają — raport ma być czytelny klinicznie. Kartoteka pacjenta działa na pseudonimie, nie na nazwisku — **system w ogóle nie zbiera imion ani nazwisk klientów; jedynym identyfikatorem konta klienta jest adres e-mail**. Jakość pseudonimizacji jest kontrolowana automatycznymi testami przy każdej zmianie systemu.

Terapeuta zachowuje przy tym pełny wgląd w oryginalny zapis własnej sesji — świadomie nie cenzurujemy dokumentacji, którą specjalista musi móc zweryfikować. Chronimy dane wszędzie tam, gdzie wykraczają poza relację terapeuta–pacjent.

### Dostęp tylko dla właściwych osób

Każdy dostęp do danych klinicznych wymaga uwierzytelnienia i jest ograniczony do konkretnego terapeuty i jego pacjentów. Aktywacja konta pacjenta wymaga dwóch niezależnych czynników: linku e-mail **oraz** kodu przekazanego osobiście przez terapeutę — samo przechwycenie e-maila nie daje dostępu. Zaproszenie można w każdej chwili cofnąć. Operacje na danych są rejestrowane w dzienniku audytowym.

### Usuwanie danych naprawdę usuwa

Po usunięciu danych następuje 30-dniowy okres ochronny (możliwość cofnięcia pomyłki), a potem trwałe, nieodwracalne usunięcie — obejmujące również kopie zapasowe. Proces jest w pełni automatyczny. Danych kart płatniczych nie przechowujemy w ogóle.

### Jasny podział odpowiedzialności (RODO)

Terapeuta lub placówka pozostaje administratorem danych swoich pacjentów — Superwizor AI działa jako podmiot przetwarzający na podstawie umowy powierzenia (DPA). Prowadzimy pełną dokumentację compliance: rejestr czynności przetwarzania, politykę retencji i ocenę skutków dla ochrony danych (DPIA) — dostępne do wglądu przy onboardingu.

---

**Kontakt w sprawach bezpieczeństwa i ochrony danych:** kontakt@superwizor.ai
Euphire sp. z o.o. · ul. Odrzańska 10a/48, Kraków · KRS 0000907254
