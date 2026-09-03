# E2E marketing-site — atrybucja bledow (2026-09-03)

CLAUDE.md mowi, ze suite ma 0-3 bledy i ze CI NIE uruchamia Playwrighta,
wiec porownanie robi ten, kto zmienia kod. Zrobione z czystego `.next`
w obu przebiegach.

| Przebieg | Bledy |
|---|---|
| Z naszymi zmianami (caly suite, 276 przypadkow) | **23** |
| Bez naszych zmian, te same 4 pliki spec | **23** (15 + 8) |

Wniosek: **zero regresji z naszej strony.**

Baseline zmierzony przez `git stash push -u -- marketing-site`, potem
osobne przebiegi:
- `register-therapist` + `crm-onboarding-stripe` + `accept-invite-phone` → 15 failed / 75 passed
- `register-flow` → 8 failed / 70 passed

Te same 23 przypadki zawodza po zmianach (lista w `e2e-po-zmianach.log`).

## Uwaga do przekazania dalej

Suite odjechal od udokumentowanego stanu "0-3 bledy" (CLAUDE.md, stan na
2026-08-07) do 23. Cztery pliki, ktore zawodza, to:
- `crm-onboarding-stripe.spec.ts` i `register-flow.spec.ts` — testy
  kontraktu `/api/checkout`. Endpoint zostal przeniesiony z trasy Next.js
  do billing-svc (rewrite Firebase Hosting), wiec w dev-serwerze go nie
  ma — testy sprawdzaja odpowiedzi 400/405 pod adresem, ktory lokalnie
  zwraca 404.
- `register-therapist.spec.ts` — przycisk submit nie staje sie widoczny
  (`pages/register.page.ts:112`).
- `accept-invite-phone.spec.ts` — telefon przy akceptacji zaproszenia.

To dlug zastany, nie skutek docs/70. Warte osobnego zadania, bo dopoki
tam siedzi, nastepna osoba nie odrozni swojej regresji od tla.
