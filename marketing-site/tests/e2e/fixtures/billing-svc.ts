// Wykrywanie lokalnego billing-svc dla testów kontraktu /api/checkout.
//
// `/api/checkout` i `/api/billing-portal` NIE są trasami Next.js — od
// migracji ze statycznego eksportu obsługuje je billing-svc, a
// `next.config.ts` przepisuje je w dev-serwerze na `127.0.0.1:8081`
// (na produkcji robi to rewrite Firebase Hosting). Bez uruchomionego
// billing-svc Next zwraca 500 z ECONNREFUSED.
//
// Do tej pory oznaczało to czternaście testów świecących na czerwono w
// każdym przebiegu — nie dlatego, że coś jest zepsute, tylko dlatego, że
// zależność nie była podniesiona. Czerwień, która nic nie znaczy, uczy
// ignorowania czerwieni, więc te przypadki mają się teraz POMIJAĆ z
// wyraźnym powodem.
//
// Sam kontrakt (400 na złe wejście, 405 na GET, 503 bez klucza Stripe)
// jest pilnowany tam, gdzie mieszka — w
// `services/billing-svc/internal/adapters/http/checkout_handler_test.go`
// (httptest, bez sieci, uruchamiany przez CI). Wersja E2E sprawdza to,
// czego tamta sprawdzić nie może: że przepisanie trasy naprawdę dowozi
// żądanie z przeglądarki do usługi.
//
// Żeby je uruchomić lokalnie:
//
//   cd superwizor-backend/services/billing-svc
//   DATABASE_URL=postgres://... PORT=8081 go run ./cmd/server

const BILLING_SVC_HEALTH = "http://127.0.0.1:8081/healthz";

let cached: boolean | null = null;

/**
 * Czy lokalny billing-svc odpowiada. Sonda idzie raz na proces —
 * dwadzieścia przypadków nie ma powodu pytać dwadzieścia razy.
 */
export async function billingSvcReachable(): Promise<boolean> {
  if (cached !== null) return cached;
  try {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), 1500);
    const resp = await fetch(BILLING_SVC_HEALTH, { signal: controller.signal });
    clearTimeout(timer);
    cached = resp.ok;
  } catch {
    cached = false;
  }
  return cached;
}

export const BILLING_SVC_SKIP_REASON =
  "billing-svc nie odpowiada na 127.0.0.1:8081 — /api/checkout jest jego trasą, " +
  "nie Next.js. Kontrakt walidacji pokrywa checkout_handler_test.go; ten test " +
  "sprawdza przepisanie trasy i wymaga uruchomionej usługi.";
