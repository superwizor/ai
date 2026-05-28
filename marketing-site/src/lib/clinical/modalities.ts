// Therapeutic modality catalog for registration / profile dropdowns.
//
// docs/18 §13.2 specifies the dropdown is sourced from
// `clinical-svc.ListModalities` — RPC that doesn't exist yet in the
// proto. This module mirrors the seed migration 000006_seed_modalities
// (UNIV / CBT / PSYCHO are the supported entries at MVP) and provides
// localised labels so the form can render without a backend round-trip.
//
// When clinical-svc.ListModalities ships, swap getModalityCatalog() to
// the RPC and delete the static list — same swap-point pattern as
// lib/billing/plans.ts.

export type ModalitySystemCode = "UNIV" | "CBT" | "PSYCHO";

export type ModalityRow = {
  systemCode: ModalitySystemCode;
  /** Localised display labels. Keys are locale codes from i18n/routing. */
  labels: Record<"pl" | "en", string>;
  isSupported: boolean;
};

const MODALITIES: ReadonlyArray<ModalityRow> = [
  {
    systemCode: "UNIV",
    labels: { pl: "Uniwersalny (modality-agnostic)", en: "Universal (modality-agnostic)" },
    isSupported: true,
  },
  {
    systemCode: "CBT",
    labels: { pl: "Terapia poznawczo-behawioralna (CBT)", en: "Cognitive Behavioural Therapy (CBT)" },
    isSupported: true,
  },
  {
    systemCode: "PSYCHO",
    labels: { pl: "Psychodynamiczna", en: "Psychodynamic" },
    isSupported: true,
  },
];

export async function getModalityCatalog(): Promise<ReadonlyArray<ModalityRow>> {
  return MODALITIES;
}
