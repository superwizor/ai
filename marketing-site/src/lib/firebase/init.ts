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
      const u = auth.currentUser;
      return u ? await u.getIdToken() : null;
    });
    _tokenProviderWired = true;
  }

  _auth = auth;
  return auth;
}
