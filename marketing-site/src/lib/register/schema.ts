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

// Therapist registration via email/password — fields from docs/18 §13.2.
export const therapistEmailSchema = z.object({
  email: z.string().email(),
  password,
  firstName: z.string().min(1),
  lastName: z.string().min(1),
  professionalTitle: z.string().optional(),
  credentialsNumber: z.string().optional(),
  modalityCode: z.enum(["UNIV", "CBT", "PSYCHO"]),
  uiLanguage: z.enum(["pl", "en"]),
  phoneNumber: z.string().optional(),
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
  phoneNumber: z.string().min(4), // required for org admins
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
  modalityCode: z.enum(["UNIV", "CBT", "PSYCHO"]),
  uiLanguage: z.enum(["pl", "en"]),
  hasAcceptedTos: z.literal(true),
  hasMarketingConsent: z.boolean().optional(),
});

export type AcceptInviteForm = z.infer<typeof acceptInviteSchema>;
