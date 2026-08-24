// Kompozycja sekcji raportu (M5) — edycja w Studio.
//
// To jest odpowiedź na pytanie „jak edytować sekcje raportu": NIE przez
// prompt (ten jest bazą legacy i stoi w miejscu do F6), tylko przez
// `report_profile` w ontologii. Kompozycja przechodzi wtedy tę samą
// ścieżkę co treść: wersjonowanie, four-eyes, diff przeglądu.
//
// Waga steruje KOLEJNOŚCIĄ, nigdy widocznością — sekcja pusta znika
// sama, a ukrycie zweryfikowanej treści byłoby decyzją o treści, której
// M5 podjąć nie może (dok. 15 §3.3).

"use client";

import { useTranslations } from "next-intl";

import {
  KNOWN_TONES,
  REPORT_SECTIONS,
  type ReportProfileView,
  type ReportSection,
  type SectionWeight,
} from "@/lib/ontology/model";

export function ReportCompositionPanel({
  profil,
  onWeight,
  onTone,
}: {
  profil: ReportProfileView | null;
  onWeight: (sekcja: ReportSection, waga: SectionWeight) => void;
  onTone: (ton: string) => void;
}) {
  const t = useTranslations("admin.ontologyComposition");

  return (
    <div className="grid gap-3" data-testid="report-composition">
      <p className="font-serif text-mist text-xs">{t("help")}</p>
      <div className="grid gap-2">
        {REPORT_SECTIONS.map((sekcja) => (
          <label key={sekcja} className="flex items-center justify-between gap-3">
            <span className="font-serif text-frost text-sm">{t(`section_${sekcja}`)}</span>
            <select
              value={profil?.sections[sekcja] ?? "normal"}
              onChange={(e) => onWeight(sekcja, e.target.value as SectionWeight)}
              className="bg-abyss border border-frost/20 text-frost px-2 py-1 font-mono text-xs"
              data-testid={`weight-${sekcja}`}
            >
              <option value="high">{t("weightHigh")}</option>
              <option value="normal">{t("weightNormal")}</option>
              <option value="low">{t("weightLow")}</option>
            </select>
          </label>
        ))}
      </div>
      <label className="flex items-center justify-between gap-3">
        <span className="font-serif text-frost text-sm">{t("tone")}</span>
        {/* Enum, nie wolny tekst: ton bez szablonu S4 odrzuca metaschemat,
            więc formularz nie może go zaoferować. */}
        <select
          value={profil?.defaultTone ?? ""}
          onChange={(e) => onTone(e.target.value)}
          className="bg-abyss border border-frost/20 text-frost px-2 py-1 font-mono text-xs"
          data-testid="composition-tone"
        >
          <option value="">{t("toneNone")}</option>
          {KNOWN_TONES.map((ton) => (
            <option key={ton} value={ton}>
              {t(`tone_${ton}`)}
            </option>
          ))}
        </select>
      </label>
    </div>
  );
}
