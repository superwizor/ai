// Diff semantyczny przy przeglądzie (dok. 17, K4).
//
// Ścieżka `draft → ready_for_review → approved` wymaga DRUGIEGO eksperta
// (four-eyes, egzekwowane w trzech warstwach). Dziś ten ekspert dostaje
// dwa bloki YAML i ma wypatrzeć różnicę okiem — przy PPT to 300 linii.
// W praktyce zatwierdzenie było więc pieczątką.
//
// Zmiany pogrupowane po KONSTRUKCIE, nie po rodzaju: recenzent czyta
// ontologię pojęcie po pojęciu, a nie „wszystko, co dodano" w oderwaniu
// od tego, gdzie.

"use client";

import { useMemo } from "react";
import { useTranslations } from "next-intl";

import { diffOntologii, type Zmiana } from "@/lib/ontology/diff";
import { parseDoc, readOntology } from "@/lib/ontology/model";

export function VersionDiff({
  poprzedniYaml,
  biezacyYaml,
}: {
  poprzedniYaml: string | null;
  biezacyYaml: string;
}) {
  const t = useTranslations("admin.ontologyDiff");

  const zmiany = useMemo(() => {
    if (poprzedniYaml === null) return null;
    try {
      return diffOntologii(
        readOntology(parseDoc(poprzedniYaml)),
        readOntology(parseDoc(biezacyYaml)),
      );
    } catch {
      return null;
    }
  }, [poprzedniYaml, biezacyYaml]);

  if (poprzedniYaml === null) {
    // Pierwsza wersja modalności nie ma z czym się porównać. Mówimy to
    // wprost, bo pusty diff i brak poprzednika wyglądają tak samo, a
    // znaczą co innego.
    return <p className="font-serif text-mist text-sm">{t("noPrevious")}</p>;
  }
  if (zmiany === null) {
    return <p className="text-magma text-sm">{t("unreadable")}</p>;
  }
  if (zmiany.length === 0) {
    return <p className="font-serif text-mist text-sm">{t("identical")}</p>;
  }

  const wgKonstruktu = new Map<string, Zmiana[]>();
  for (const z of zmiany) {
    const k = z.konstrukt || "__naglowek__";
    wgKonstruktu.set(k, [...(wgKonstruktu.get(k) ?? []), z]);
  }

  return (
    <div className="grid gap-4" data-testid="version-diff">
      <p className="font-serif text-mist text-sm">
        {t("summary", { count: zmiany.length, constructs: wgKonstruktu.size })}
      </p>
      {[...wgKonstruktu.entries()].map(([konstrukt, lista]) => (
        <div key={konstrukt} className="grid gap-1">
          <p className="font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-ember">
            {konstrukt === "__naglowek__" ? t("headerSection") : konstrukt}
          </p>
          <ul className="grid gap-1">
            {lista.map((z, i) => (
              <li key={i} className="flex gap-2 items-baseline">
                <span
                  className={`font-mono text-xs w-4 ${
                    z.rodzaj === "dodano"
                      ? "text-ember"
                      : z.rodzaj === "usunieto"
                        ? "text-magma"
                        : "text-mist"
                  }`}
                  aria-hidden
                >
                  {z.rodzaj === "dodano" ? "+" : z.rodzaj === "usunieto" ? "−" : "~"}
                </span>
                <span className="font-serif text-frost text-sm">
                  {/* Klucze komunikatów żyją w i18n, żeby funkcja diffu
                      pozostała czysta i testowalna bez tłumaczeń. */}
                  {t(z.klucz, (z.dane ?? {}) as Record<string, string | number>)}
                </span>
              </li>
            ))}
          </ul>
        </div>
      ))}
    </div>
  );
}
