// Edytor slotów kompozytu (dok. 17, K3).
//
// Typ slotu ma w metaschemacie cztery legalne formy: `span_ref`,
// `entry_ref`, `construct_ref(<id>)`, `enum_ref(<id>)`. Formularz składa
// je z WYBORU rodzaju i pickera konstruktu, więc wyrażenie regularne
// walidatora nie ma jak się nie zgodzić — to ta sama zasada co przy
// `is_not` w K2, przeniesiona na sloty.
//
// Konstrukt jest wykluczony z pickera własnych slotów: `enum_ref(ja)` w
// moim własnym kompozycie to samo-referencja, której metaschemat nie
// przyjmie.

"use client";

import { useTranslations } from "next-intl";

import {
  SLOT_KINDS,
  slotNeedsTarget,
  type SlotKind,
  type SlotView,
} from "@/lib/ontology/model";

export function SlotEditor({
  sloty,
  minComplete,
  wlasnyId,
  wszystkieId,
  etykiety,
  onSlots,
  onMinComplete,
}: {
  sloty: SlotView[];
  minComplete: number | null;
  wlasnyId: string;
  wszystkieId: string[];
  etykiety: Record<string, string>;
  onSlots: (v: SlotView[]) => void;
  onMinComplete: (v: number | null) => void;
}) {
  const t = useTranslations("admin.ontologySlots");
  const cele = wszystkieId.filter((id) => id !== wlasnyId);

  const zmien = (i: number, patch: Partial<SlotView>) => {
    const next = [...sloty];
    next[i] = { ...next[i], ...patch };
    onSlots(next);
  };

  return (
    <div className="grid gap-4" data-testid="slot-editor">
      {sloty.map((s, i) => (
        <div key={i} className="grid gap-2 border-l-2 border-ember/30 pl-3">
          <div className="flex flex-wrap gap-2 items-end">
            <label className="grid gap-1">
              <span className="font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist">
                {t("slotName")}
              </span>
              <input
                value={s.name}
                onChange={(e) => zmien(i, { name: e.target.value })}
                className="bg-abyss border border-frost/20 text-frost px-3 py-2 font-mono text-sm w-40"
              />
            </label>

            <label className="grid gap-1">
              <span className="font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist">
                {t("slotKind")}
              </span>
              <select
                value={s.kind}
                onChange={(e) => {
                  const kind = e.target.value as SlotKind;
                  // Zmiana rodzaju na taki, który celu nie potrzebuje,
                  // czyści cel — inaczej zostałby w pamięci i wrócił przy
                  // powrocie do enum_ref, ciągnąc nieaktualny konstrukt.
                  zmien(i, { kind, target: slotNeedsTarget(kind) ? s.target : "" });
                }}
                className="bg-abyss border border-frost/20 text-frost px-3 py-2 font-mono text-sm"
              >
                {SLOT_KINDS.map((k) => (
                  <option key={k} value={k}>
                    {t(`kind_${k}`)}
                  </option>
                ))}
              </select>
            </label>

            {slotNeedsTarget(s.kind) && (
              <label className="grid gap-1">
                <span className="font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist">
                  {t("slotTarget")}
                </span>
                <select
                  value={s.target}
                  onChange={(e) => zmien(i, { target: e.target.value })}
                  className="bg-abyss border border-frost/20 text-frost px-3 py-2 font-serif text-sm"
                >
                  <option value="">{t("pickTarget")}</option>
                  {cele.map((id) => (
                    <option key={id} value={id}>
                      {etykiety[id] ?? id}
                    </option>
                  ))}
                </select>
              </label>
            )}

            <button
              type="button"
              onClick={() => onSlots(sloty.filter((_, j) => j !== i))}
              className="border border-frost/25 text-frost/70 px-3 py-2 font-mono text-xs hover:bg-frost/10"
              aria-label={t("removeSlot")}
            >
              ×
            </button>
          </div>

          <div className="flex flex-wrap gap-4">
            <label className="flex items-center gap-2">
              <input
                type="checkbox"
                checked={s.required}
                onChange={(e) => zmien(i, { required: e.target.checked })}
              />
              <span className="font-serif text-frost text-sm">{t("slotRequired")}</span>
            </label>

            {/* Wymóg dowodowy: deklaracja „jestem punktualny" i opis
                „przyszedł 20 minut po czasie" nie są tym samym rodzajem
                dowodu, a slot może żądać właśnie tego drugiego. */}
            <label className="flex items-center gap-2">
              <span className="font-serif text-frost text-sm">{t("slotKindHint")}</span>
              <select
                value={s.kindHint}
                onChange={(e) => zmien(i, { kindHint: e.target.value })}
                className="bg-abyss border border-frost/20 text-frost px-2 py-1 font-serif text-sm"
              >
                <option value="">{t("hintAny")}</option>
                <option value="declarative">{t("hintDeclarative")}</option>
                <option value="behavioral">{t("hintBehavioral")}</option>
              </select>
            </label>
          </div>
        </div>
      ))}

      <button
        type="button"
        onClick={() =>
          onSlots([
            ...sloty,
            { name: "", kind: "span_ref", target: "", required: true, kindHint: "", quantity: false },
          ])
        }
        className="justify-self-start border border-frost/30 text-frost px-3 py-1.5 font-mono text-[10px] uppercase tracking-[var(--tracking-label)] hover:bg-frost/10"
        data-testid="slot-add"
      >
        {t("addSlot")}
      </button>

      {sloty.length > 0 && (
        <label className="grid gap-1">
          <span className="font-serif text-frost text-sm">{t("minComplete")}</span>
          <span className="font-serif text-mist text-xs">{t("minCompleteHelp")}</span>
          <input
            type="number"
            min={1}
            max={sloty.length}
            value={minComplete ?? sloty.length}
            onChange={(e) => {
              const v = Number(e.target.value);
              if (Number.isFinite(v)) onMinComplete(v);
            }}
            className="bg-abyss border border-frost/20 text-frost px-3 py-2 w-20 font-mono text-sm"
            data-testid="slot-min-complete"
          />
        </label>
      )}
    </div>
  );
}
