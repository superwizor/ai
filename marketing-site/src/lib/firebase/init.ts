// Firebase Web SDK initialiser.
//
// Run-once on the browser. Returns the singleton FirebaseApp + Auth so
// every importer shares state (the Web SDK already handles re-init
// idempotently with `getApps()`, but we centralise here to make
// emulator wiring + token-provider hookup explicit).
//
// What this also does:
//   1. Calls `connectAuthEmulator` when NEXT_PUBLIC_FIREBASE_USE_EMULATOR=1
//      so dev never accidentally hits prod Firebase.
//   2. Calls `setTokenProvider(...)` from @/lib/connect/clients with a
//      function that yields `getAuth().currentUser?.getIdToken() ?? null`
//      — this is the wiring promised by feature 3
//      (connect-rpc-client) that closes the loop: any Connect RPC sent
//      while a user is signed in carries their Firebase ID token in the
//      Authorization header, exactly as identity-svc.ValidateToken
//      expects.
//
// We initialise lazily on first import inside a browser context — that
// keeps Firebase out of server bundles (it'd error at build time
// otherwise: Firebase Auth's persistence layer needs `window`).

"use client";

import {
  getApps,
  getApp,
  initializeApp,
  type FirebaseApp,
} from "firebase/app";
import {
  getAuth,
  setPersistence,
  browserLocalPersistence,
  connectAuthEmulator,
  onAuthStateChanged,
  type Auth,
} from "firebase/auth";
import {
  initializeAppCheck,
  ReCaptchaEnterpriseProvider,
} from "firebase/app-check";

import { setTokenProvider } from "@/lib/connect/clients";
import {
  readFirebaseConfig,
  shouldUseAuthEmulator,
  AUTH_EMULATOR_URL,
} from "./config";

let _app: FirebaseApp | null = null;
let _auth: Auth | null = null;
let _emulatorConnected = false;
let _tokenProviderWired = false;

// Rozstrzyga się przy PIERWSZYM zdarzeniu onAuthStateChanged, czyli w
// chwili, gdy Firebase skończył odtwarzać sesję z pamięci trwałej.
//
// Bez tego oczekiwania dostawca tokenu czytał auth.currentUser, które
// jest synchronicznie null aż do końca odtwarzania — a interceptor przy
// null NIE zgłasza błędu, tylko pomija nagłówek Authorization i wysyła
// żądanie anonimowo. Efektem jest 401 wyglądający jak awaria serwera.
//
// Tak wyglądał incydent z 2026-08-05: rejestracja przeszła (CreateUser i
// UpdateProfile po 200), po czym twarda nawigacja przeładowała aplikację
// i każde kolejne uwierzytelnione wywołanie dostawało 401 — trzynaście
// prób UpdateProfile pod rząd, bo użytkownik klikał "Dalej" w kółko.
let _authReady: Promise<void> | null = null;

const AUTH_READY_TIMEOUT_MS = 5000;

function authRestored(auth: Auth): Promise<void> {
  if (!_authReady) {
    _authReady = new Promise<void>((resolve) => {
      let done = false;
      // stop i timer są deklarowane PRZED finish i przypisywane później,
      // bo onAuthStateChanged wolno wywołać obserwatora synchronicznie.
      // Przy odwołaniu do `const` zadeklarowanego niżej byłby wtedy
      // ReferenceError (temporal dead zone), który wywróciłby całe
      // uwierzytelnianie — a TypeScript tego nie zgłasza.
      let stop: (() => void) | null = null;
      let timer: ReturnType<typeof setTimeout> | null = null;

      const finish = () => {
        if (done) return;
        done = true;
        if (timer !== null) clearTimeout(timer);
        if (stop !== null) stop();
        resolve();
      };

      // Bezpiecznik. onAuthStateChanged powinien zgłosić się raz na
      // starcie (z użytkownikiem albo z null), ale gdyby tego nie
      // zrobił, każde RPC w aplikacji wisiałoby w nieskończoność — to
      // gorsze niż 401, bo użytkownik widzi samą zawieszoną kręciołkę.
      // Po upływie limitu wracamy do zachowania sprzed zmiany.
      timer = setTimeout(finish, AUTH_READY_TIMEOUT_MS);
      stop = onAuthStateChanged(auth, finish, finish);
      // Gdyby obserwator wystrzelił synchronicznie, finish już przebiegł
      // i nasłuch trzeba wyrejestrować tutaj.
      if (done) stop();
    });
  }
  return _authReady;
}
let _appCheckInitialized = false;

function ensureApp(): FirebaseApp {
  if (_app) return _app;
  _app = getApps().length > 0 ? getApp() : initializeApp(readFirebaseConfig());

  if (typeof window !== "undefined" && !_appCheckInitialized) {
    const recaptchaKey = process.env.NEXT_PUBLIC_RECAPTCHA_ENTERPRISE_KEY;
    if (recaptchaKey) {
      try {
        // Enable App Check debug token during local development
        if (process.env.NODE_ENV !== "production") {
          const debugToken = process.env.NEXT_PUBLIC_APP_CHECK_DEBUG_TOKEN;
          (window as any).FIREBASE_APPCHECK_DEBUG_TOKEN = debugToken || true;
        }
        initializeAppCheck(_app, {
          provider: new ReCaptchaEnterpriseProvider(recaptchaKey),
          isTokenAutoRefreshEnabled: true,
        });
        _appCheckInitialized = true;
        console.log("[Firebase Init] App Check successfully initialised with reCAPTCHA Enterprise.");
      } catch (err) {
        console.error("[Firebase Init] App Check initialisation failed:", err);
      }
    }
  }

  return _app;
}

/**
 * Returns the singleton Auth instance, initialising the Firebase app on
 * first call. Calls `setPersistence(browserLocalPersistence)` so the
 * user stays signed in across page reloads (the default would be
 * session-only). Connects to the emulator when the env var asks.
 *
 * The token provider for Connect-RPC is wired here once per page load —
 * the first call from any importer triggers it, then short-circuits.
 */
export function getFirebaseAuth(): Auth {
  if (_auth) return _auth;

  const auth = getAuth(ensureApp());

  // Persistence — wraps an async call, but the rest of our code doesn't
  // need to await it; the SDK queues sign-in/out until persistence is
  // ready, so worst-case the first sign-in is a few ms slower.
  void setPersistence(auth, browserLocalPersistence);

  if (shouldUseAuthEmulator() && !_emulatorConnected) {
    connectAuthEmulator(auth, AUTH_EMULATOR_URL, { disableWarnings: true });
    _emulatorConnected = true;
  }

  if (!_tokenProviderWired) {
    setTokenProvider(async () => {
      // Czekamy na odtworzenie sesji ZANIM sięgniemy po currentUser.
      // Zwrócenie null przed tym momentem jest nieodróżnialne od
      // "użytkownik naprawdę niezalogowany", a jedno i drugie kończy
      // się cichym wysłaniem żądania bez tokenu.
      await authRestored(auth);
      const u = auth.currentUser;
      return u ? await u.getIdToken() : null;
    });
    _tokenProviderWired = true;
  }

  _auth = auth;
  return auth;
}
