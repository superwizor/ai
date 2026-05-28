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

// E.164-ish phone format. Accept an optional leading `+`, then 6–18
// digits with allowed spaces / dashes / parens between them. We
// deliberately don't require `+48` — the placeholder hints at the
// PL format but visitors from other countries still need to type a
// usable number. Backend stores the canonical form per docs/18
// §13.2 D5.
const PHONE_REGEX = /^[+\d][\d\s\-()]{5,18}$/;

// optionalPhone: accept empty (react-hook-form's default for an
// untouched field) OR a string matching PHONE_REGEX. Anything else
// fails with "phone-invalid" — surfaced to the user as a localized
// hint by the form via tErr("phoneInvalid").
const optionalPhone = z
  .string()
  .optional()
  .refine((v) => !v || PHONE_REGEX.test(v), { message: "phone-invalid" });

const requiredPhone = z
  .string()
  .min(1, { message: "phone-required" })
  .regex(PHONE_REGEX, { message: "phone-invalid" });

// Therapist registration via email/password — fields from docs/18 §13.2.
//
// `modalityId` is a `modalities.id` UUID fetched live from
// clinical-svc.ListModalities (see lib/clinical/modalities.ts). It maps
// directly onto identity-svc UpdateProfile.default_modality_id, which
// validates it as a UUID FK into the modalities table. The earlier
// schema took `modalityCode` (a "CBT"-style system_code string) and
// passed it through unchanged — identity-svc rejected with
// InvalidArgument "invalid default_modality_id". Fixed 2026-05-28.
export const therapistEmailSchema = z.object({
  email: z.string().email(),
  password,
  firstName: z.string().min(1),
  lastName: z.string().min(1),
  professionalTitle: z.string().optional(),
  credentialsNumber: z.string().optional(),
  modalityId: z.string().uuid({ message: "modality-required" }),
  uiLanguage: z.enum(["pl", "en"]),
  phoneNumber: optionalPhone,
  hasAcceptedTos: z.literal(true),
  hasMarketingConsent: z.boolean().optional(),
});

export type TherapistEmailForm = z.infer<typeof therapistEmailSchema>;

// Organisation registration via email/password — fields from docs/18 §13.3.
// Combines founder + organisation + headquarters address in one payload,
// matching the single-transaction RegisterOrganization RPC.
export const organizationEmailSchema = z.object({
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
export const acceptInviteSchema = z.object({
  email: z.string().email(),
  password,
  firstName: z.string().min(1),
  lastName: z.string().min(1),
  modalityId: z.string().uuid({ message: "modality-required" }),
  uiLanguage: z.enum(["pl", "en"]),
  hasAcceptedTos: z.literal(true),
  hasMarketingConsent: z.boolean().optional(),
});

export type AcceptInviteForm = z.infer<typeof acceptInviteSchema>;

// "Finish profile" schemas — used by the social-login paths where
// Firebase Auth has already given us email + name, but Superwizor-
// specific fields (modality, ui_language, ToS) must still be collected
// before the identity-svc row gets created.

export const therapistFinishSchema = z.object({
  firstName: z.string().min(1),
  lastName: z.string().min(1),
  modalityId: z.string().uuid({ message: "modality-required" }),
  uiLanguage: z.enum(["pl", "en"]),
  phoneNumber: optionalPhone,
  professionalTitle: z.string().optional(),
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
