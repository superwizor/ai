---
type: Legacy Architecture
title: "Superwizor AI - Konstytucja Projektu i Kodeks Inżynieryjny (Core Rules)"
description: "WERSJA: 3.0 STATUS: DOKUMENT NADRZĘDNY. Żadna linijka kodu, zmiana architektoniczna czy prompt AI nie może stać w sprzeczności z tym plikiem."
resource: file:///Users/maciekckoklormam91/Desktop/Inne/APP%20-%20Superwizor%20AI/docs/stare%20arhcitektury%20%28Maciek%29/B_04_core_rules.md
tags: [stare-arhcitektury--maciek-]
timestamp: 2026-05-30T14:32:36+02:00
---

# Superwizor AI - Konstytucja Projektu i Kodeks Inżynieryjny (Core Rules)

**WERSJA:** 3.0
**STATUS:** DOKUMENT NADRZĘDNY. Żadna linijka kodu, zmiana architektoniczna czy prompt AI nie może stać w sprzeczności z tym plikiem.

---

## 🌍 1. MISJA I KOMPAS ETYCZNY (THE "WHY")
SuperWizor AI to system klasy **MedTech (Clinical Decision Support System)**. Naszym celem absolutnym jest ratowanie żyć poprzez ochronę zdrowia psychicznego i zapobieganie wypaleniu zawodowemu psychoterapeutów oraz psychiatrów.
1. **Etyka ponad Zysk:** Niezawodność i bezpieczeństwo są ważniejsze niż czas dostarczenia funkcji czy wygoda deweloperska.
2. **AI to Asystent, nie Diagnosta:** System pełni rolę "lustra superwizyjnego". Generuje hipotezy, ale ZAWSZE używa języka warunkowego i probabilistycznego ("materiał sugeruje..."). Ostateczna odpowiedzialność w 100% leży po stronie człowieka.
3. **Poufność Absolutna:** Pielęgnowane tajemnice ludzkiego życia zabezpieczamy tak, jakby od tego zależało nasze własne życie.

## 🚨 2. ZŁOTA REGUŁA: ŚWIĘTOŚĆ NAGRANIA (ZERO DATA LOSS)
Transkrypt to najważniejszy artefakt. Aplikacja Flutter jest pancerną "Czarną Skrzynką".
1. **Zapis Przyrostowy (Local-First Chunking):** Dźwięk kompresowany w locie (.m4a, 16kHz, mono) i strumieniowo zapisywany do ukrytego cache'u. NIGDY w pamięci RAM.
2. **Odporność na OS:** Wymuszamy działanie w tle (`flutter_background_service`, `Background Audio`). Widoczne powiadomienie "SuperWizor nasłuchuje". Przeciwdziałanie usypianiu procesora.
3. **Wskrzeszanie (Auto-Recovery):** Wykrywanie fizycznych restartów i osieroconych plików .m4a.
4. **Offline-First Upload:** Brak WiFi nie blokuje zapisu. System bezgłośnie czeka i wysyła dźwięk (LTE) po udanym powrocie sygnału (`Workmanager`).

## 🔒 3. BEZPIECZEŃSTWO I FIREWALL (ZERO TRUST)
1. **Zasada Ślepoty (Kategoryczny Zakaz PII):** Nie przetrzymujemy imion, nazwisk, etc. Wymuszone aliasy ("Pacjent A.").
2. **Krematorium Danych:** OLM (Object Lifecycle Management) na Cloud Storage usuwa trwale każdy plik po upływie 48h (Dead Man's Switch). Logika w Cloud Functions wymusza skasowanie tuż po wygenerowaniu tekstowego JSON-a.
3. **Izolacja B2B i RBAC:** Wprowadzone profile, rozróżnienie na `ROLE_THERAPIST` oraz `ROLE_PATIENT`. Dostęp uregulowany przez Reguły Bezpieczeństwa (Security Rules - zero dostępu do odczytów innych sesji bez własności `therapistId` / `patientId`). Zakaz zapisu raportów na Firebase bezpośrednio z urządzenia Fluttera!

---

## ⚙️ KODEKS INŻYNIERYJNY I TELEMETRIA

**[DLA AGENTA AI - THE ENFORCER CHECKLIST]:** Zanim wygenerujesz kod we Flutter, MUSISZ odhaczyć poniższe w swoim oknie roboczym:
1. **[i18n Check]**: Czy 100% tekstów trafi do `.arb` jako `@klucz` powiązane z opisem kontekstu / emocji dla tłumacza?
2. **[Analytics Check]**: Czy w logice dodano eventy Firebase ułatwiające analitykę u klientów B2B? (Uwaga: ZERO PII!).
3. **[Logs Check]**: Czy owinąłeś żądania sieciowe w odporne i "nieme" bloki `try-catch`, odkładające błędy pod Crashlytics?
4. **[Clean Code Check]**: Czy funkcje nazywają się czasownikami odpowiadającymi psychoterapii (`anonymizeAndSendTranscriptToAI`)?
5. **[Test Check]**: TDD - najpierw testy. Izolacja dzięki bibliotekom typu mocktail.

*Jeśli złamiesz te reguły, narazisz wrażliwe środowisko leczenia.*
