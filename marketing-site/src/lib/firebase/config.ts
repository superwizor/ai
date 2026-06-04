// Firebase Web SDK config — driven entirely by NEXT_PUBLIC_* env vars
// so different builds (local emulator, staging, prod) just swap env.
//
// docs/18 §6.5 enumerates the providers we support at MVP:
//   - Email/Password (always on)
//   - Google (on at launch)
//   - Apple + Microsoft (deferred — Firebase Console enablement is the
//     manual op in task #64)
//
// Local dev defaults to the Firebase Auth emulator on :9099 (the port
// already configured in firebase.json at the project root). Production
// reads the real project credentials.

export type FirebaseConfig = {
  apiKey: string;
  authDomain: string;
  projectId: string;
  appId: string;
  // Optional — only set in environments that use them. The marketing
  // site doesn't write to Storage / Firestore directly, but the iOS app
  // shares the same project so these are populated server-side.
  storageBucket?: string;
  messagingSenderId?: string;
  measurementId?: string;
};

export function readFirebaseConfig(): FirebaseConfig {
  // Required vars — fallback to project defaults if not set in build environment.
  const apiKey = process.env.NEXT_PUBLIC_FIREBASE_API_KEY || "AIzaSyAHuHAzQ2btMDvzVIiP84DQaiM6xOzjnP8";
  const authDomain = process.env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN || "superwizor-ai-25ecd.firebaseapp.com";
  const projectId = process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID || "superwizor-ai-25ecd";
  const appId = process.env.NEXT_PUBLIC_FIREBASE_APP_ID || "1:344724821207:ios:74fa7d1d312fcec9a98c92";

  return {
    apiKey,
    authDomain,
    projectId,
    appId,
    storageBucket: process.env.NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET,
    messagingSenderId: process.env.NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID,
    measurementId: process.env.NEXT_PUBLIC_FIREBASE_MEASUREMENT_ID,
  };
}

/**
 * Whether to point the Web SDK at the local Auth emulator instead of
 * production Firebase Auth. Set NEXT_PUBLIC_FIREBASE_USE_EMULATOR=1 in
 * `.env.local` for dev. firebase.json declares the emulator on :9099.
 */
export function shouldUseAuthEmulator(): boolean {
  return process.env.NEXT_PUBLIC_FIREBASE_USE_EMULATOR === "1";
}

export const AUTH_EMULATOR_URL = "http://127.0.0.1:9099";
