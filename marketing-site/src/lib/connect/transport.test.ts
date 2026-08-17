// Regresja z 2026-08-05: użytkownik ukończył rejestrację (CreateUser 200,
// UpdateProfile 200), po czym każde kolejne uwierzytelnione wywołanie
// dostawało 401 — trzynaście prób UpdateProfile pod rząd.
//
// Winowajcą było połączenie dwóch rzeczy: dostawca tokenu zwracał null,
// zanim Firebase odtworzył sesję, a interceptor przy null NIE zgłaszał
// błędu, tylko pomijał nagłówek Authorization i wysyłał żądanie
// anonimowo. Brak sesji był więc nieodróżnialny od awarii serwera.
//
// Te testy pilnują kontraktu interceptora. Wartości tokenu nie sprawdzamy
// „że jest niepusta" — sprawdzamy, że nagłówek NIESIE dokładnie to, co
// zwrócił dostawca, i że asynchroniczny dostawca jest ODCZEKANY.

import { describe, expect, it, vi } from "vitest";
import { bearerTokenInterceptor } from "./transport";

/** Minimalny stub żądania Connect — interceptor dotyka wyłącznie `header`. */
function fakeReq() {
  return { header: new Headers() } as unknown as Parameters<
    ReturnType<ReturnType<typeof bearerTokenInterceptor>>
  >[0];
}

/** Uruchamia interceptor i zwraca nagłówki, z którymi poszłoby żądanie. */
async function headersAfterIntercept(
  tokenProvider: Parameters<typeof bearerTokenInterceptor>[0],
): Promise<Headers> {
  const seen: Headers[] = [];
  const next = vi.fn(async (r: { header: Headers }) => {
    seen.push(r.header);
    return {} as never;
  });
  const interceptor = bearerTokenInterceptor(tokenProvider);
  await interceptor(next as never)(fakeReq() as never);
  return seen[0];
}

describe("bearerTokenInterceptor", () => {
  it("dołącza token zwrócony przez dostawcę", async () => {
    const h = await headersAfterIntercept(() => "abc123");
    expect(h.get("Authorization")).toBe("Bearer abc123");
  });

  // Sedno regresji: dostawca jest asynchroniczny (getIdToken zwraca
  // Promise). Interceptor, który by go nie odczekał, dostałby Promise
  // zamiast łańcucha i wysłał żądanie bez nagłówka.
  it("czeka na dostawcę asynchronicznego zamiast wysyłać bez nagłówka", async () => {
    const h = await headersAfterIntercept(
      async () =>
        new Promise<string>((r) => setTimeout(() => r("async-token"), 10)),
    );
    expect(h.get("Authorization")).toBe("Bearer async-token");
  });

  it("nie wstawia literału Promise ani undefined do nagłówka", async () => {
    const h = await headersAfterIntercept(async () => "tok");
    const v = h.get("Authorization") ?? "";
    expect(v).not.toContain("[object");
    expect(v).not.toContain("undefined");
    expect(v).not.toContain("Promise");
  });

  // Anonimowe wywołania są legalne — CheckEmailExists i CreateUser lecą
  // przed zalogowaniem. Kontraktem jest więc "brak nagłówka", a nie błąd.
  // Test istnieje, by ta decyzja była świadoma, a nie przypadkowa:
  // gdyby ktoś kiedyś chciał to zmienić, zobaczy tu wprost dlaczego.
  it("bez tokenu wysyła żądanie bez nagłówka (świadome, dla wywołań anonimowych)", async () => {
    const h = await headersAfterIntercept(() => null);
    expect(h.has("Authorization")).toBe(false);
  });

  it("pusty łańcuch traktuje jak brak tokenu, nie jak 'Bearer '", async () => {
    const h = await headersAfterIntercept(() => "");
    expect(h.get("Authorization")).not.toBe("Bearer ");
  });

  it("odpytuje dostawcę przy KAŻDYM żądaniu, nie zapamiętuje pierwszego", async () => {
    // Token Firebase wygasa po godzinie; zbuforowanie go tutaj dałoby
    // 401 dokładnie po tym czasie, trudne do powiązania z przyczyną.
    let n = 0;
    const provider = () => `token-${++n}`;
    const first = await headersAfterIntercept(provider);
    const second = await headersAfterIntercept(provider);
    expect(first.get("Authorization")).toBe("Bearer token-1");
    expect(second.get("Authorization")).toBe("Bearer token-2");
  });
});
