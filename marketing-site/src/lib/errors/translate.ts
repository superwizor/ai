// Central error → i18n helper.
//
// Every catch-block in the admin / register / public surfaces previously
// surfaced raw `e.message` to the user. That's noisy at best ("Internal:
// pgx: timeout reached") and confusing at worst ("rpc error: code =
// PermissionDenied desc = reason must be >= 10 characters"). This module
// centralizes the mapping so:
//
//   try { … } catch (e) { return { error: translateError(e, tErr) }; }
//
// gives the user one of a handful of localized, human-friendly strings.
//
// Coverage:
//   1. ConnectError with a known Code → errors.code.<name>.
//   2. ConnectError with one of our recognized backend error-string
//      substrings (e.g. "reason must be >= 10 characters" from the
//      writeAuditEvent helper in identity-svc) → errors.backend.<key>.
//   3. Generic JS Error → errors.generic.
//   4. Anything else stringified → errors.generic.
//
// Adding new mappings: add a localized key to messages/{pl,en}.json
// under the `errors` namespace, and append a case here. Keep the case
// list short — for catch-all UX the generic key is fine; specific
// strings are only worth it when the failure is recoverable by the
// user (e.g. "fill in the reason" vs "we're temporarily down").

import { ConnectError, Code } from "@connectrpc/connect";

// Loose typing for the translator function so callers can pass either
// `useTranslations("errors")` or `useTranslations()` and reach into
// the namespace with dotted keys. Both shapes are common in the
// codebase.
export type ErrorTranslator = (key: string) => string;

// Substring patterns that map straight to user-facing keys. Order
// matters: the FIRST match wins, so put the most specific patterns
// near the top. Matching is case-insensitive.
const BACKEND_PATTERNS: Array<{ contains: string; key: string }> = [
  // identity-svc handler — every SUPERWIZOR_ADMIN mutation gates on
  // reason length. The user can fix this by typing more.
  { contains: "reason must be >=", key: "backend.reasonTooShort" },
  // clinical-svc AdminUpdateModalityPrompt — optimistic lock. Licznik
  // wersji jest wspólny dla promptu raportu i czatu, więc zapis
  // „tamtego" klucza (albo drugie okno Studia) unieważnia expectedVersion
  // tej instancji. Generyczne „obecny stan" nie mówiło, że wystarczy
  // spróbować ponownie; PromptStudio przy tym błędzie sam odświeża stan.
  { contains: "prompt was changed by someone else", key: "backend.promptVersionConflict" },
  // identity-svc AdminAssignTherapistToOrg — organizacja ma WIĘCEJ NIŻ
  // JEDEN przydział miejsc, więc backend nie zgadnie, do którego planu
  // wpiąć terapeutę, i żąda jawnego seat_allocation_id. Bez tej reguły
  // admin dostaje generyczne „sprawdź wprowadzone wartości" i nie ma
  // czego sprawdzić — pola do poprawienia nie widać w formularzu.
  { contains: "seat_allocation_required", key: "backend.seatAllocationRequired" },
  // billing-svc AdminResetTokens — nowy tokens_limit poniżej limitu z
  // planu. Ten sam kłopot co wyżej: dane formularza SĄ poprawne, więc
  // "sprawdź wprowadzone wartości" wysyłało admina szukać błędu tam,
  // gdzie go nie ma. 2026-08-07 skończyło się to czterema próbami pod
  // rząd i zgłoszeniem. Kod pochodzi z admin.go — zmiana po jednej
  // stronie wymaga zmiany po drugiej (pilnuje tego test w Go).
  { contains: "tokens_limit_below_plan", key: "backend.tokensLimitBelowPlan" },
  // identity-svc AcceptInvitation.
  { contains: "invitation expired", key: "backend.invitationExpired" },
  { contains: "invitation already accepted", key: "backend.invitationAccepted" },
  // billing-svc — quota gates.
  { contains: "quota exceeded", key: "backend.quotaExceeded" },
  { contains: "subscription past_due", key: "backend.subscriptionPastDue" },
  // identity-svc AdminDeleteUser — hard delete is gated on the user
  // owning no clinical data; the admin's remedy is deactivation.
  { contains: "user_has_sessions", key: "backend.userHasSessions" },
  { contains: "user_has_data", key: "backend.userHasData" },
  // identity-svc AdminCreateOrganization — NIP already used by another
  // active org. MUST precede the generic "already exists" rule so the
  // admin sees a NIP-specific message, not the misleading e-mail one.
  { contains: "tax_id", key: "backend.taxIdConflict" },
  // identity-svc — duplicate detection.
  { contains: "already exists", key: "backend.alreadyExists" },
  { contains: "duplicate key", key: "backend.alreadyExists" },
];

// Maps Connect error codes to user-facing i18n keys. Each entry pairs
// with errors.code.<name> in messages/{pl,en}.json. Codes the backend
// doesn't surface today are still listed so future RPC changes stay
// covered without UI work.
const CODE_KEYS: Record<Code, string> = {
  [Code.Canceled]: "code.canceled",
  [Code.Unknown]: "code.unknown",
  [Code.InvalidArgument]: "code.invalidArgument",
  [Code.DeadlineExceeded]: "code.deadlineExceeded",
  [Code.NotFound]: "code.notFound",
  [Code.AlreadyExists]: "code.alreadyExists",
  [Code.PermissionDenied]: "code.permissionDenied",
  [Code.ResourceExhausted]: "code.resourceExhausted",
  [Code.FailedPrecondition]: "code.failedPrecondition",
  [Code.Aborted]: "code.aborted",
  [Code.OutOfRange]: "code.outOfRange",
  [Code.Unimplemented]: "code.unimplemented",
  [Code.Internal]: "code.internal",
  [Code.Unavailable]: "code.unavailable",
  [Code.DataLoss]: "code.dataLoss",
  [Code.Unauthenticated]: "code.unauthenticated",
};

// translateError is the only export every caller needs. Pass any caught
// value + a translator scoped to the "errors" namespace
// (e.g. `useTranslations("errors")`) and you get a human, localized
// string back.
//
// The lookup order — substring match first, then ConnectError.code —
// is deliberate. Specific patterns ("reason must be >=") are more
// actionable than the generic "InvalidArgument" they roll up to;
// surfacing the specific key turns a generic error into "please type
// at least 10 characters in the reason field".
export function translateError(error: unknown, tErr: ErrorTranslator): string {
  if (error instanceof ConnectError) {
    const msg = (error.message || "").toLowerCase();
    for (const p of BACKEND_PATTERNS) {
      if (msg.includes(p.contains)) {
        return tryT(tErr, p.key);
      }
    }
    const codeKey = CODE_KEYS[error.code];
    if (codeKey) {
      return tryT(tErr, codeKey);
    }
    return tryT(tErr, "generic");
  }

  if (error instanceof Error) {
    const msg = error.message.toLowerCase();
    for (const p of BACKEND_PATTERNS) {
      if (msg.includes(p.contains)) {
        return tryT(tErr, p.key);
      }
    }
    return tryT(tErr, "generic");
  }

  // Non-Error throwables (string, number, undefined…). We don't get
  // any extra info from them — fall back to the generic message.
  return tryT(tErr, "generic");
}

// tryT is a small belt-and-suspenders helper: if the i18n key is
// missing (which happens in dev when adding new mappings before
// localizing), it falls back to the key itself rather than throwing
// a render-time MissingTranslationError that nukes the dialog.
function tryT(tErr: ErrorTranslator, key: string): string {
  try {
    return tErr(key);
  } catch {
    return key;
  }
}
