// Typed Connect-RPC clients per backend service.
//
// One client per service, each wired with the bearer-token interceptor.
// Components consume these via `import { identityClient } from
// "@/lib/connect/clients"` and call methods directly:
//
//   const user = await identityClient.getMyProfile({});
//
// Argument and return types are inferred from the generated GenService
// descriptors — full intellisense + compile-time errors if the proto
// changes. No protobuf serialisation boilerplate to write by hand.
//
// `tokenProvider` is a module-level mutable function pointer. Feature 4
// (firebase-auth-init) calls `setTokenProvider(() =>
// getAuth().currentUser?.getIdToken() ?? null)` once at app boot. Until
// then the default returns null (anonymous calls).

import { createClient } from "@connectrpc/connect";
import { IdentityService } from "@superwizor/proto-ts/identity/v1/identity_pb";
import { BillingService } from "@superwizor/proto-ts/billing/v1/billing_pb";
import { ClinicalService } from "@superwizor/proto-ts/clinical/v1/clinical_pb";
import {
  createServiceTransport,
  serviceEndpoints,
  type TokenProvider,
} from "./transport";

// Mutable token provider so feature 4 can swap in the real Firebase
// source without rewiring transports. The arrow indirection means
// importing modules always see the latest setter result, never a stale
// closure.
let currentTokenProvider: TokenProvider = () => null;

export function setTokenProvider(p: TokenProvider): void {
  currentTokenProvider = p;
}

const tokenProvider: TokenProvider = () => currentTokenProvider();

const identityTransport = createServiceTransport({
  baseUrl: serviceEndpoints.identity,
  tokenProvider,
});
const billingTransport = createServiceTransport({
  baseUrl: serviceEndpoints.billing,
  tokenProvider,
});
const clinicalTransport = createServiceTransport({
  baseUrl: serviceEndpoints.clinical,
  tokenProvider,
});

export const identityClient = createClient(IdentityService, identityTransport);
export const billingClient = createClient(BillingService, billingTransport);
export const clinicalClient = createClient(ClinicalService, clinicalTransport);

// Re-exports for callers that prefer building one-off clients
// (e.g. server-side calls from a route handler with a service-account
// token instead of a user token).
export { createServiceTransport, serviceEndpoints };
export type { TokenProvider };
