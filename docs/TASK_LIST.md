# 📋 Master Task List — SuperWizor AI

> Priorytetyzacja: 🔴 krytyczne → 🟡 ważne → 🟢 nice-to-have
> Ten plik jest źródłem prawdy dla tasków. Agenci NIE POWINNI go nadpisywać.

---

## 🔴 P0 — Stabilność przed App Store

### 1. Debug Mode — Dokończenie stanów i komunikatów
**Claude robi:**
- [x] Upload pada w 50% → dopisać komunikat dla usera (dialog/banner: "Przesyłanie zostało przerwane. Spróbuj ponownie.")
- [x] Przejrzeć wszystkie stany (`pendingUpload`, `error`, `inProgress`, `quotaBlocked`) i upewnić się, że każdy ma czytelny feedback w UI
- [x] Sprawdzić czy `ActiveAnalysisBanner` poprawnie reaguje na każdy stan 

### 2. Tryb Debug → ukryty gest (7 kliknięć)
**Claude robi:**
- [x] Zamienić widoczny DEBUG pill na hidden gesture: 7× tap na logo "Superwizor AI" w AppBar
- [x] Po 7 tapach → otworzyć debug sheet
- [x] Dodać counter reset po 2s bez tapa (żeby przypadkiem nie triggerować)
- [x] `kDebugMode` gate — w release brak reakcji na tapy

### 3. 🔊 Śmieszny dźwięk przy aktywacji debug mode
**Maciej robi:**
- [x] Nagrać coś zabawnego mikrofonem 😂
- [x] Wrzucić plik `.mp3` do `assets/sounds/` (np. `SFX_debug_mode.mp3`)

**Claude robi:**
- [x] Podpiąć odtwarzanie dźwięku po sukcesie 7 tapów (AudioPlayer, best-effort)
- [x] Respektować `soundEnabled` z ustawień

---

## 🟡 P1 — Jakość raportów & UX

### 4. Audyt raportów LLM (markdown + kafelki)
**Maciej robi** (ludzkie oczy):
- [ ] Przejrzeć 5–10 raportów i zanotować: ile kafelków generuje (7 vs 15+), gdzie markdown się psuje
- [ ] Screenshoty problematycznych raportów → wrzucić do docs/

**Claude robi:**
- [x] Quick fix: jeśli problem to rendering markdown w Flutter → poprawić parser/widgety (dodano poprawkę ignorującą nagłówki 3 rzędu przy generowaniu zakładek)
- [ ] Jeśli problem po stronie LLM prompt → przejrzeć prompt i dodać constraints (max sections, format enforcement)
- [ ] Opcja fundamentalna: structured output (JSON schema) zamiast raw markdown → do dyskusji

### 5. Ustawienia — pełen audyt
**Maciej robi:**
- [ ] Przeklikać każdy toggle w Ustawieniach i zanotować co nie działa / jest nieintuicyjne

**Claude robi:**
- [ ] Naprawić zgłoszone problemy

### 6. Preferencje raportów
- [ ] Rework UX na podstawie feedbacku Macieja

---

## 🟡 P1 — Backend Sync (migracja 000059)

### 7. Cross-device sync: Viewed Reports + Avatar Config ✅ ZAIMPLEMENTOWANE
- [x] SQL migration 000059 (report_viewed_at + avatar_config)
- [x] sqlc queries (MarkReportViewed + SetAvatarConfig)
- [x] Proto updates (2 new RPCs + new fields)
- [x] Go handlers + Connect adapters
- [x] Flutter providers rewrite (backend-backed + local→backend migration)
- [x] Session model + SessionDto (reportViewedAt field)
- [x] Tests (18 passing — DTO roundtrip + avatar config)
- [ ] Migracja DB na GCP
- [ ] Deploy clinical-svc

---

## 🟢 P2 — Nice-to-have

### 8. Strona rekrutacyjna (Intern / Praktyki)
- [x] Zaprojektować i dodać do marketing-site

### 9. Sugestie tytułu zawodowego
- [x] Terapeuta, Psycholog, Psychiatra — lista sugestii przy rejestracji

### 10. App Store push
- [ ] Dopiero gdy P0 + P1 stabilne
