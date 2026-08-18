// Właściwa przyczyna incydentu z 2026-08-05.
//
// Dostawca tokenu czytał `auth.currentUser`, które jest synchronicznie
// null, dopóki Firebase nie odtworzy sesji z pamięci trwałej. Rejestracja
// kończy się twardą nawigacją (window.location.href), która przeładowuje
// aplikację — więc na nowej stronie currentUser był jeszcze null, token
// nie leciał, a serwer odpowiadał 401.
//
// Testujemy tu KONTRAKT KOLEJNOŚCI, bo to on był złamany: dostawca nie
// wolno mu odpowiedzieć, zanim Firebase zgłosi stan uwierzytelnienia.
// Sam init.ts jest nierozdzielnie związany z SDK, więc odtwarzamy tę samą
// konstrukcję na atrapie — test pilnuje reguły, nie linijek.

import { describe, expect, it, vi } from "vitest";

type Observer = (u: unknown) => void;

/** Atrapa Firebase Auth: zgłasza stan dopiero, gdy sami mu każemy. */
function fakeAuth() {
  const observers: Observer[] = [];
  return {
    currentUser: null as unknown,
    onAuthStateChanged(obs: Observer) {
      observers.push(obs);
      return () => {
        const i = observers.indexOf(obs);
        if (i >= 0) observers.splice(i, 1);
      };
    },
    /** Symuluje zakończenie odtwarzania sesji przez SDK. */
    settle(user: unknown) {
      this.currentUser = user;
      for (const o of [...observers]) o(user);
    },
    observerCount: () => observers.length,
  };
}

/** Ta sama konstrukcja co authRestored + dostawca tokenu w init.ts. */
function makeTokenProvider(auth: ReturnType<typeof fakeAuth>, timeoutMs = 5000) {
  let ready: Promise<void> | null = null;
  const restored = () => {
    if (!ready) {
      ready = new Promise<void>((resolve) => {
        let done = false;
        let stop: (() => void) | null = null;
        let timer: ReturnType<typeof setTimeout> | null = null;
        const finish = () => {
          if (done) return;
          done = true;
          if (timer !== null) clearTimeout(timer);
          if (stop !== null) stop();
          resolve();
        };
        timer = setTimeout(finish, timeoutMs);
        stop = auth.onAuthStateChanged(finish);
        if (done) stop();
      });
    }
    return ready;
  };
  return async () => {
    await restored();
    const u = auth.currentUser as { getIdToken: () => Promise<string> } | null;
    return u ? await u.getIdToken() : null;
  };
}

const userWithToken = (t: string) => ({ getIdToken: async () => t });

describe("dostawca tokenu — kolejność wobec odtwarzania sesji", () => {
  // TO jest test regresji. Bez oczekiwania dostawca zwróciłby null
  // natychmiast i żądanie poszłoby bez nagłówka → 401.
  it("nie odpowiada, dopóki Firebase nie zgłosi stanu", async () => {
    const auth = fakeAuth();
    const provider = makeTokenProvider(auth);

    let settled = false;
    const p = provider().then((t) => {
      settled = true;
      return t;
    });

    // Kilka tików pętli zdarzeń — gdyby dostawca nie czekał, już by
    // odpowiedział.
    await Promise.resolve();
    await Promise.resolve();
    expect(settled).toBe(false);

    auth.settle(userWithToken("tok-po-odtworzeniu"));
    await expect(p).resolves.toBe("tok-po-odtworzeniu");
  });

  it("zwraca null, gdy po odtworzeniu naprawdę nie ma użytkownika", async () => {
    const auth = fakeAuth();
    const provider = makeTokenProvider(auth);
    const p = provider();
    auth.settle(null);
    await expect(p).resolves.toBeNull();
  });

  // Bez limitu czasu awaria nasłuchu zawiesiłaby KAŻDE wywołanie w
  // aplikacji — użytkownik widziałby samą kręciołkę, bez błędu.
  it("po upływie limitu przestaje czekać zamiast wisieć", async () => {
    vi.useFakeTimers();
    try {
      const auth = fakeAuth();
      const provider = makeTokenProvider(auth, 5000);
      const p = provider();
      await vi.advanceTimersByTimeAsync(5001);
      await expect(p).resolves.toBeNull();
    } finally {
      vi.useRealTimers();
    }
  });

  // Nasłuch jest jednorazowy. Gdyby każde wywołanie zakładało własny i
  // go nie zdejmowało, obserwatorzy narastaliby przy każdym RPC.
  it("nie mnoży obserwatorów przy wielu wywołaniach", async () => {
    const auth = fakeAuth();
    const provider = makeTokenProvider(auth);
    const calls = [provider(), provider(), provider()];
    expect(auth.observerCount()).toBe(1);
    auth.settle(userWithToken("t"));
    await Promise.all(calls);
    expect(auth.observerCount()).toBe(0);
  });

  // Firebase wolno wywołać obserwatora synchronicznie. Wersja z `const`
  // zadeklarowanym poniżej `finish` dawała wtedy ReferenceError
  // (temporal dead zone), którego TypeScript nie zgłasza.
  it("znosi synchroniczne zgłoszenie obserwatora", async () => {
    const user = userWithToken("natychmiast");
    const sync = {
      currentUser: user as unknown,
      onAuthStateChanged: (obs: Observer) => {
        obs(user); // synchronicznie, jeszcze przed zwrotem funkcji
        return () => {};
      },
      settle: () => {},
      observerCount: () => 0,
    } as unknown as ReturnType<typeof fakeAuth>;

    const provider = makeTokenProvider(sync);
    await expect(provider()).resolves.toBe("natychmiast");
  });
});
