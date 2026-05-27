// Connect-RPC transport for the Superwizor marketing site.
//
// Single place to configure where the browser talks to. Per docs/18 §5
// (R1), every Go service runs an h2c mixed handler that answers gRPC +
// gRPC-Web + Connect on one port; from the browser we always speak
// Connect. The endpoint URLs are environment-driven so staging vs prod
// vs local-emulator can swap freely.
//
// ## Auth interceptor
//
// Every outgoing call gets a Firebase ID token in the `Authorization`
// header — that's what identity-svc.ValidateToken (and downstream
// services' ContextFromMD) expect. The actual Firebase SDK init lands
// in Slice 2 feature 4 (`firebase-auth-init`); for now the
// `tokenProvider` argument is an injectable async () => string|null
// callback so this module compiles + tests cleanly without Firebase
// loaded. Feature 4 will plug in `() => getAuth().currentUser?.getIdToken()`.

import {
  createConnectTransport,
  type ConnectTransportOptions,
} from "@connectrpc/connect-web";
import type { Interceptor } from "@connectrpc/connect";

export type TokenProvider = () => Promise<string | null> | string | null;

/**
 * Returns an interceptor that adds `Authorization: Bearer <id-token>` to
 * every outgoing request when the provider yields a token. If the
 * provider returns null (unauthenticated visitor on the marketing page),
 * the header is omitted and the call proceeds anonymously — fine for
 * RPCs like `pricing` reads that don't require auth.
 */
export function bearerTokenInterceptor(
  tokenProvider: TokenProvider,
): Interceptor {
  return (next) => async (req) => {
    const token = await tokenProvider();
    if (token) req.header.set("Authorization", `Bearer ${token}`);
    return next(req);
  };
}

/**
 * Build a Connect transport pointed at the given service base URL with
 * the bearer-token interceptor wired up. Each service (identity, billing,
 * clinical) gets its own transport because they live on different Cloud
 * Run hostnames in staging/prod.
 */
export function createServiceTransport(opts: {
  baseUrl: string;
  tokenProvider: TokenProvider;
  extraOptions?: Omit<ConnectTransportOptions, "baseUrl" | "interceptors">;
}) {
  return createConnectTransport({
    baseUrl: opts.baseUrl,
    interceptors: [bearerTokenInterceptor(opts.tokenProvider)],
    // CORS: superwizor-backend sets allowed origins via CORS_ALLOWED_ORIGINS
    // env. credentials="include" would only matter for cookie auth; we
    // ride on the Authorization header, so leave it default (omit).
    ...opts.extraOptions,
  });
}

/**
 * Public-environment URLs for each backend service.
 *
 * NEXT_PUBLIC_* prefix makes these vars available in browser bundles;
 * any non-prefixed env var stays server-side only. See the docs:
 * marketing-site/.env.local for dev overrides (gitignored).
 */
export const serviceEndpoints = {
  identity: process.env.NEXT_PUBLIC_IDENTITY_URL ?? "http://localhost:8080",
  billing: process.env.NEXT_PUBLIC_BILLING_URL ?? "http://localhost:8081",
  clinical: process.env.NEXT_PUBLIC_CLINICAL_URL ?? "http://localhost:8082",
} as const;
