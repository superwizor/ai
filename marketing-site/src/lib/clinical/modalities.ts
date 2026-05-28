// Therapeutic modality catalogue — fetched live from
// clinical-svc.ListModalities, which clinical-svc's auth interceptor
// explicitly allowlists for anonymous callers (registration pages don't
// have a Firebase token yet). See:
//   superwizor-backend/services/clinical-svc/internal/adapters/grpc/auth_interceptor.go
//
// The DB stores only an English `display_name`. UI labels are localised
// here, keyed by `system_code`. Add a new entry to LABELS when the DB
// gains a new modality; missing entries fall back to the server-provided
// `displayName` for both locales (no broken UI, just untranslated).
//
// What changed (2026-05-28): previously this module hardcoded the
// catalogue and exposed only `systemCode`. The three registration forms
// then submitted `defaultModalityId: data.modalityCode`, e.g. "CBT", to
// identity-svc, which validates that field as a `modalities.id` UUID and
// returned 500 InvalidArgument. Now we surface the real UUID so forms
// can submit it directly.

import { clinicalClient } from "@/lib/connect/clients";

export type ModalityRow = {
  /** UUID from clinical-svc — what identity-svc.UpdateProfile wants. */
  id: string;
  /** "UNIV" | "CBT" | "PSYCHO" — used for localised label lookup. */
  systemCode: string;
  /** English display name straight from the DB row. */
  displayName: string;
  /** Localised display labels. Keys are locale codes from i18n/routing. */
  labels: Record<"pl" | "en", string>;
  isSupported: boolean;
};

// Localised labels keyed by system_code. The DB column display_name is
// Polish (per the seed), so this map provides EN labels and any tweaked
// PL phrasing. Keys mirror the supported modalities in the modalities
// table (system_code column). Unknown codes fall back to display_name
// in both locales — see getModalityCatalog below.
const LABELS: Record<string, ModalityRow["labels"]> = {
  UNIV: {
    pl: "Uniwersalny / Integracyjny",
    en: "Universal / Integrative",
  },
  CBT: {
    pl: "Poznawczo-behawioralna (CBT)",
    en: "Cognitive Behavioural Therapy (CBT)",
  },
  PSYCHO: {
    pl: "Psychodynamiczna",
    en: "Psychodynamic",
  },
  GESTALT: {
    pl: "Gestalt",
    en: "Gestalt",
  },
  PPT: {
    pl: "Pozytywna (PPT)",
    en: "Positive Psychotherapy (PPT)",
  },
  EFT: {
    pl: "Skoncentrowana na emocjach (EFT)",
    en: "Emotion-Focused Therapy (EFT)",
  },
  SYS: {
    pl: "Systemowa (pary i rodziny)",
    en: "Systemic (couples & families)",
  },
  ST: {
    pl: "Terapia schematów (ST)",
    en: "Schema Therapy (ST)",
  },
  COACH: {
    pl: "Coaching (ICF/GROW)",
    en: "Coaching (ICF/GROW)",
  },
};

export async function getModalityCatalog(): Promise<ReadonlyArray<ModalityRow>> {
  const resp = await clinicalClient.listModalities({});
  return resp.modalities.map((m) => ({
    id: m.id,
    systemCode: m.systemCode,
    displayName: m.displayName,
    labels: LABELS[m.systemCode] ?? { pl: m.displayName, en: m.displayName },
    isSupported: m.isSupported,
  }));
}
