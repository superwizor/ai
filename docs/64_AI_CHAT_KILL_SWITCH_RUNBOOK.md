---
description: "Operator runbook for disabling or restricting the AI chat. Target: effective in under 5 minutes; ADR 62 §11 requires under 1 hour."
---

# 64 — Runbook: wyłączenie / ograniczenie AI Chat

**Status:** AKTYWNY od F0 (2026-08-20)
**Powiązania:** ADR `docs/kronikarz/62_…v1.0_2.md` §11 · plan `docs/63_…` F0/F5
**Właściciel:** dyżurny inżynier; decyzja o użyciu — PO lub dyżurny przy
incydencie bezpieczeństwa klinicznego.

## 0. Kiedy tego użyć

| sytuacja | akcja |
|---|---|
| Model wygenerował treść diagnostyczną / lekową / ocenę ryzyka mimo guardraili | **Krok 1** (twarde wyłączenie) |
| Podejrzenie dryfu jakości hipotez A8–A10, brak przesłanki o naruszeniu granic | **Krok 2** (`defined_ops`) |
| Awaria Vertex / przekroczony budżet | **Krok 2**, potem decyzja |
| Pojedyncza organizacja zgłasza problem | **Krok 3** (nadpisanie per-org) |

Zasada: **`defined_ops` jest tańsze operacyjnie niż pełne wyłączenie** —
terapeuta zachowuje wyszukiwanie cytatów (A1/A7) i statystyki (A2/A6),
traci wyłącznie funkcje generatywne. Pełne wyłączenie tylko wtedy, gdy
problem może dotyczyć również ścieżek ekstraktywnych.

## 1. Twarde wyłączenie (globalnie)

```sql
UPDATE app_config
   SET value = 'false',
       updated_at = now(),
       note = 'INCYDENT <id> — wyłączone przez <kto> <kiedy>'
 WHERE key = 'AI_CHAT_ENABLED' AND organization_id IS NULL;
```

Efekt: RPC czatu odmawiają kodem `FEATURE_DISABLED`. UI pokazuje komunikat
o czasowej niedostępności; **informacja kryzysowa pozostaje widoczna**
(nie przechodzi przez czat — ADR §11).

## 2. Ograniczenie do operacji zdefiniowanych

```sql
UPDATE app_config
   SET value = 'defined_ops',
       updated_at = now(),
       note = 'INCYDENT <id> — degradacja przez <kto> <kiedy>'
 WHERE key = 'AI_CHAT_MODE' AND organization_id IS NULL;
```

Efekt: A8–A10 niedostępne, zastępowane przez A7/A2. Reszta działa.

## 3. Nadpisanie dla jednej organizacji

```sql
INSERT INTO app_config (key, value, organization_id, note)
VALUES ('AI_CHAT_MODE', 'defined_ops', '<org-uuid>', 'zgłoszenie <id>')
ON CONFLICT (key, organization_id) WHERE organization_id IS NOT NULL
DO UPDATE SET value = EXCLUDED.value, note = EXCLUDED.note, updated_at = now();
```

## 4. Pomiar propagacji (obowiązkowy po każdej zmianie)

Cache czytnika (`pkg/appconfig`) ma TTL **30 s**. Zmiana jest widoczna we
wszystkich instancjach najpóźniej po TTL — bez restartu, bez deployu.

```bash
date -u +%H:%M:%S && psql "$DSN" -c "UPDATE app_config SET value='false' WHERE key='AI_CHAT_ENABLED' AND organization_id IS NULL"
```

Następnie odpytuj czat co 5 s aż do odmowy i zanotuj różnicę czasu.
**Wynik zapisz w incydencie** — pomiar jest częścią dowodu, że wymóg
§11 (< 1 h) jest spełniony.

Oczekiwane: ≤ 30 s. Próg alarmowy: > 60 s oznacza, że któraś instancja
serwuje nieświeży snapshot — sprawdź logi `appconfig.refresh_failed`.

## 5. Powrót

```sql
UPDATE app_config SET value = 'true',  updated_at = now(), note = 'przywrócone po <id>' WHERE key = 'AI_CHAT_ENABLED' AND organization_id IS NULL;
UPDATE app_config SET value = 'full',  updated_at = now(), note = 'przywrócone po <id>' WHERE key = 'AI_CHAT_MODE'    AND organization_id IS NULL;
```

Warunek powrotu: przyczyna rozpoznana **i** pokryta testem w
`guardrail-evals/`. Powrót bez testu regresyjnego = ten sam incydent za
tydzień.

## 6. Zachowanie awaryjne (dlaczego to jest bezpieczne)

`pkg/appconfig` zawodzi **zamknięcie**, nie otwarcie:

- brak wiersza → domyślne skompilowane: czat **wyłączony**, tryb `defined_ops`;
- wartość nieparsowalna (`'ture'`, `'unrestricted'`) → domyślne, z logiem;
- baza niedostępna przy starcie → domyślne (czat wyłączony);
- baza niedostępna **po** udanym odczycie → serwowany ostatni dobry
  snapshot. To celowe: chwilowa awaria bazy nie może cofnąć świadomej
  decyzji operatora.

Wszystkie cztery zachowania są pokryte testami w
`pkg/appconfig/appconfig_test.go`.

## 7. Status wykonania na stagingu

| krok | stan |
|---|---|
| Migracja 000084 zastosowana | ⏳ czeka na deploy F1 |
| Próba wyłączenia + pomiar propagacji | ⏳ do wykonania po deployu |
| Wpis pomiaru w tym dokumencie | ⏳ |

⚠ Do czasu uzupełnienia tej tabeli DoD fazy F0 jest **niekompletne** —
runbook jest opisany i pokryty testami jednostkowymi, ale nie wykonany na
żywym środowisku. Czat startuje wyłączony (`AI_CHAT_ENABLED='false'`
w seedzie migracji), więc brak wykonanej próby nie tworzy ekspozycji.
