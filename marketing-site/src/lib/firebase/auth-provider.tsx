// React context bridge for Firebase Auth.
//
// Wraps `getFirebaseAuth()` + `onAuthStateChanged` into a tree-level
// provider so any component can read the current user + loading state
// via the `useAuth()` hook. Exposes the supported sign-in flows from
// docs/18 §6.5:
//
//   - signInWithEmail(email, password)         — existing user
//   - signUpWithEmail(email, password)         — new account, sends
//                                                verification email
//   - signInWithGoogle()                       — popup OAuth
//   - signOut()
//
// Apple + Microsoft helpers are stubbed in to fail loud — gated on the
// Firebase Console toggles (manual op #64). Wiring them in later is a
// 3-line change once the providers are enabled.

"use client";

import {
  createContext,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
  type ReactNode,
} from "react";
import {
  GoogleAuthProvider,
  OAuthProvider,
  createUserWithEmailAndPassword,
  onAuthStateChanged,
  sendEmailVerification,
  signInWithEmailAndPassword,
  signInWithPopup,
  signOut as fbSignOut,
  type User,
} from "firebase/auth";

import { getFirebaseAuth } from "./init";

type Status = "loading" | "signed-in" | "signed-out";

export type AuthContextValue = {
  status: Status;
  user: User | null;
  signInWithEmail: (email: string, password: string) => Promise<User>;
  signUpWithEmail: (email: string, password: string, continueUrl?: string) => Promise<User>;
  signInWithGoogle: () => Promise<User>;
  signInWithApple: () => Promise<User>;
  signInWithMicrosoft: () => Promise<User>;
  signOut: () => Promise<void>;
};

const AuthContext = createContext<AuthContextValue | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  // Auth instance is created lazily on mount (browser-only). SSR/SSG
  // renders the provider with status="loading" and no auth object;
  // the effect kicks in on hydration and subscribes to changes.
  const authRef = useRef<ReturnType<typeof getFirebaseAuth> | null>(null);
  const [user, setUser] = useState<User | null>(null);
  const [status, setStatus] = useState<Status>("loading");

  useEffect(() => {
    try {
      const a = getFirebaseAuth();
      authRef.current = a;
      return onAuthStateChanged(a, (u) => {
        setUser(u);
        setStatus(u ? "signed-in" : "signed-out");
      });
    } catch (err) {
      // Firebase SDK may fail to initialise (e.g. stale Turbopack chunk
      // serving an old API key, network issues, etc.). Catch here so the
      // page still renders — auth-gated pages simply show the signed-out
      // state and the landing page works unimpeded.
      console.error("[AuthProvider] Firebase Auth init failed:", err);
      setStatus("signed-out");
      return undefined;
    }
  }, []);

  const value: AuthContextValue = useMemo(() => {
    // Pre-mount auth is null (during SSR/SSG render and the brief
    // moment between hydration and the useEffect tick). All sign-in
    // helpers route through this guard so a stray click can't crash
    // — instead the user gets a clear console error and the promise
    // rejects.
    const requireAuth = () => {
      if (!authRef.current) throw new Error(
        "Firebase Auth not initialised yet — sign-in actions can only run after the AuthProvider has mounted on the client.",
      );
      return authRef.current;
    };

    return {
      status,
      user,
      signInWithEmail: async (email, password) =>
        (await signInWithEmailAndPassword(requireAuth(), email, password)).user,
      signUpWithEmail: async (email, password, continueUrl) => {
        const cred = await createUserWithEmailAndPassword(
          requireAuth(),
          email,
          password,
        );
        // Fire-and-forget verification email. Failures here aren't fatal
        // (the user can resend from settings). docs/18 §6.5 R2 — every
        // new account gets verification at signup.
        let actionCodeSettings = undefined;
        if (continueUrl) {
          actionCodeSettings = {
            url: continueUrl,
            handleCodeInApp: false,
          };
        }
        sendEmailVerification(cred.user, actionCodeSettings).catch((err) => {
          console.error("sendEmailVerification FAILED:", err);
        });
        return cred.user;
      },
      signInWithGoogle: async () => {
        const provider = new GoogleAuthProvider();
        // Hint: prefer the Polish account picker. Doesn't enforce locale
        // but biases Google's UI when the user has multiple accounts.
        provider.setCustomParameters({ prompt: "select_account" });
        return (await signInWithPopup(requireAuth(), provider)).user;
      },
      signInWithApple: async () => {
        // Gated on Firebase Console enablement (manual op #64).
        const provider = new OAuthProvider("apple.com");
        return (await signInWithPopup(requireAuth(), provider)).user;
      },
      signInWithMicrosoft: async () => {
        const provider = new OAuthProvider("microsoft.com");
        return (await signInWithPopup(requireAuth(), provider)).user;
      },
      signOut: async () => {
        await fbSignOut(requireAuth());
      },
    };
  }, [status, user]);

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth(): AuthContextValue {
  const ctx = useContext(AuthContext);
  if (!ctx) {
    throw new Error("useAuth must be called inside <AuthProvider>");
  }
  return ctx;
}
