// Zod schemas for registration forms.
//
// Validation lives client-side first — errors render inline before
// any RPC fires. The same schemas are re-used by react-hook-form's
// zodResolver. Backend still validates independently per
// docs/18 §13.1; we never trust the client.

import { z } from "zod";

const password = z
  .string()
  .min(8)
  .regex(/\d/, "password-no-digit");

function isValidPhone(v: string): boolean {
  const stripped = v.replace(/[^\d+]/g, "");

  // Must start with + followed by 7 to 15 digits
  if (!/^\+\d{7,15}$/.test(stripped)) {
    return false;
  }

  const digits = stripped.replace("+", "");

  // 1. Block numbers with all identical digits (e.g. +48 111 111 111)
  const firstDigit = digits[0];
  const allSame = digits.split("").every((d) => d === firstDigit);
  if (allSame) return false;

  // 2. Block sequential digits (e.g. +48 123 456 789, +48 987 654 321)
  const sequentialAsc = "01234567890123456789";
  const sequentialDesc = "98765432109876543210";
  if (sequentialAsc.includes(digits) || sequentialDesc.includes(digits)) {
    return false;
  }

  // 3. Special rules for Polish phone numbers (+48)
  if (stripped.startsWith("+48")) {
    const local = stripped.slice(3);
    // Polish numbers (mobile and landline) must have exactly 9 digits
    if (local.length !== 9) {
      return false;
    }
    // Polish numbers do not start with 0
    if (local.startsWith("0")) {
      return false;
    }
    // Block all-same or sequential in the local part specifically
    const firstLocalDigit = local[0];
    const localAllSame = local.split("").every((d) => d === firstLocalDigit);
    if (localAllSame) return false;

    if (sequentialAsc.includes(local) || sequentialDesc.includes(local)) {
      return false;
    }
  }

  return true;
}

const requiredPhone = z
  .string()
  .min(1, { message: "phone-required" })
  .refine(
    (v) => isValidPhone(v),
    { message: "phone-invalid" }
  );

const optionalPhone = z
  .string()
  .optional()
  .refine(
    (v) => {
      if (!v) return true;
      return isValidPhone(v);
    },
    { message: "phone-invalid" }
  );

// Therapist registration via email/password — fields from docs/18 §13.2.
//
// `modalityId` is a `modalities.id` UUID fetched live from
// clinical-svc.ListModalities (see lib/clinical/modalities.ts). It maps
// directly onto identity-svc UpdateProfile.default_modality_id, which
// validates it as a UUID FK into the modalities table. The earlier
// schema took `modalityCode` (a "CBT"-style system_code string) and
// passed it through unchanged — identity-svc rejected with
// InvalidArgument "invalid default_modality_id". Fixed 2026-05-28.
export const therapistEmailSchema = z
  .object({
    email: z.string().email(),
    password,
    firstName: z.string().min(1),
    lastName: z.string().min(1),
    credentialsNumber: z.string().optional(),
    uiLanguage: z.enum(["pl", "en"]),
    phoneNumber: requiredPhone,
    hasAcceptedTos: z.literal(true),
    hasMarketingConsent: z.boolean().optional(),
  });

export type TherapistEmailForm = z.infer<typeof therapistEmailSchema>;

// Organisation registration via email/password — fields from docs/18 §13.3.
// Combines founder + organisation + headquarters address in one payload,
// matching the single-transaction RegisterOrganization RPC.
export const organizationEmailSchema = z
  .object({
    // Founder account
    email: z.string().email(),
    password,
    firstName: z.string().min(1),
    lastName: z.string().min(1),
    phoneNumber: requiredPhone, // required for org admins
    uiLanguage: z.enum(["pl", "en"]),

    // Organisation
    legalName: z.string().min(1),
    orgType: z.enum(["SOLO", "CLINIC", "ENTERPRISE"]),
    // Polish NIP is 10 digits. Strict for the launch (PL-only); relax
    // once we expand to other tax jurisdictions.
    taxId: z.string().regex(/^\d{10}$/, "tax-id-invalid"),
    vatIdEu: z.string().optional(),

    // Headquarters address
    // No zod default — react-hook-form's defaultValues handles that.
    // Keeping the .default() here breaks the input/output type-split.
    countryCode: z.string().length(2),
    region: z.string().optional(),
    city: z.string().min(1),
    // PL postal-code format: 00-000. Loose for non-PL countries.
    postalCode: z.string().min(3),
    streetLine: z.string().min(1),
    buildingNumber: z.string().min(1),
    unitNumber: z.string().optional(),
    directions: z.string().optional(),

    // Consents
    hasAcceptedTos: z.literal(true),
    hasMarketingConsent: z.boolean().optional(),
  });

export type OrganizationEmailForm = z.infer<typeof organizationEmailSchema>;

// Invitation acceptance schema — the invitee sets password + name +
// optional modality override. Email is required because we don't
// surface it from the token client-side; the backend cross-checks
// it against the invitations row by hashing the token. If they
// mismatch the AcceptInvitation RPC returns an error.
const acceptInviteBase = z.object({
  email: z.string().email(),
  password,
  // Required for THERAPIST invites, hidden+absent for PATIENT invites
  // (docs/39) — the form enforces per invited_role from
  // GetInvitationPreview; the schema stays permissive.
  modalityId: z
    .string()
    .uuid({ message: "modality-required" })
    .optional()
    .or(z.literal("")),
  uiLanguage: z.enum(["pl", "en"]),
  hasAcceptedTos: z.literal(true),
  hasMarketingConsent: z.boolean().optional(),
});

// THERAPIST / ORG_ADMIN invites: first/last name stay required.
export const acceptInviteSchema = acceptInviteBase.extend({
  firstName: z.string().min(1),
  lastName: z.string().min(1),
});

// PATIENT invites (docs/43 §4): the client account is pseudonymous —
// e-mail is the only identifier, so names are neither collected nor
// required. The backend ignores first_name/last_name for PATIENT
// acceptances; the proto fields remain for wire compatibility only.
export const clientAcceptInviteSchema = acceptInviteBase.extend({
  firstName: z.string().optional(),
  lastName: z.string().optional(),
});

// The form type uses the permissive (client) variant so one
// react-hook-form instance can swap resolvers per invited_role;
// the strict schema still rejects missing names for staff invites.
export type AcceptInviteForm = z.infer<typeof clientAcceptInviteSchema>;

// "Finish profile" schemas — used by the social-login paths where
// Firebase Auth has already given us email + name, but Superwizor-
// specific fields (modality, ui_language, ToS) must still be collected
// before the identity-svc row gets created.

export const therapistFinishSchema = z.object({
  firstName: z.string().min(1),
  lastName: z.string().min(1),
  uiLanguage: z.enum(["pl", "en"]),
  phoneNumber: requiredPhone,
  hasAcceptedTos: z.literal(true),
  hasMarketingConsent: z.boolean().optional(),
});

export type TherapistFinishForm = z.infer<typeof therapistFinishSchema>;

export const organizationFinishSchema = z.object({
  firstName: z.string().min(1),
  lastName: z.string().min(1),
  phoneNumber: requiredPhone,
  uiLanguage: z.enum(["pl", "en"]),
  legalName: z.string().min(1),
  orgType: z.enum(["SOLO", "CLINIC", "ENTERPRISE"]),
  taxId: z.string().regex(/^\d{10}$/, "tax-id-invalid"),
  vatIdEu: z.string().optional(),
  countryCode: z.string().length(2),
  region: z.string().optional(),
  city: z.string().min(1),
  postalCode: z.string().min(3),
  streetLine: z.string().min(1),
  buildingNumber: z.string().min(1),
  unitNumber: z.string().optional(),
  directions: z.string().optional(),
  hasAcceptedTos: z.literal(true),
  hasMarketingConsent: z.boolean().optional(),
});

export type OrganizationFinishForm = z.infer<typeof organizationFinishSchema>;
