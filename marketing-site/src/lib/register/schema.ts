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
