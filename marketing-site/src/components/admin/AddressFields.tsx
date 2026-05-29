// Shared address sub-form. Used by:
//   • OrgDetail's edit dialog (headquarters_address per docs/18 §13.7)
//   • UsersList's edit dialog (billing_address per docs/18 §13.8)
//
// State shape mirrors the Address proto message — keep field names
// aligned with proto camelCase so the consumer can pass the draft
// straight into create(AddressSchema, draft) without renaming.
//
// "Required" fields per the proto comments: country_code, city,
// postal_code, street_line, building_number. region/unit_number/
// directions are optional free text. We don't enforce required at
// this level — the consumer's submit handler does — so a blank
// address (every field empty) is allowed and means "no change" to
// the upstream form logic.

"use client";

import type { ReactNode } from "react";
import { useTranslations } from "next-intl";

export type AddressDraft = {
  countryCode: string;
  region: string;
  city: string;
  postalCode: string;
  streetLine: string;
  buildingNumber: string;
  unitNumber: string;
  directions: string;
};

export const EMPTY_ADDRESS: AddressDraft = {
  countryCode: "",
  region: "",
  city: "",
  postalCode: "",
  streetLine: "",
  buildingNumber: "",
  unitNumber: "",
  directions: "",
};

// Compare two address drafts field-by-field. Returns true if any
// non-empty value differs — used so the form only sends the address
// when something actually changed.
export function addressDiffers(a: AddressDraft, b: AddressDraft): boolean {
  return (
    a.countryCode !== b.countryCode ||
    a.region !== b.region ||
    a.city !== b.city ||
    a.postalCode !== b.postalCode ||
    a.streetLine !== b.streetLine ||
    a.buildingNumber !== b.buildingNumber ||
    a.unitNumber !== b.unitNumber ||
    a.directions !== b.directions
  );
}

// Best-effort convert a proto Address into the draft shape. The proto
// type is generated; we treat it loosely here so this file doesn't
// have to import from proto-ts (callers can pass either the proto
// message or null/undefined when no address exists yet).
export function addressFromProto(
  src:
    | undefined
    | null
    | {
        countryCode?: string;
        region?: string;
        city?: string;
        postalCode?: string;
        streetLine?: string;
        buildingNumber?: string;
        unitNumber?: string;
        directions?: string;
      },
): AddressDraft {
  if (!src) return { ...EMPTY_ADDRESS };
  return {
    countryCode: src.countryCode ?? "",
    region: src.region ?? "",
    city: src.city ?? "",
    postalCode: src.postalCode ?? "",
    streetLine: src.streetLine ?? "",
    buildingNumber: src.buildingNumber ?? "",
    unitNumber: src.unitNumber ?? "",
    directions: src.directions ?? "",
  };
}

export function AddressFields({
  idPrefix,
  value,
  onChange,
  title,
}: {
  idPrefix: string;
  value: AddressDraft;
  onChange: (next: AddressDraft) => void;
  title?: ReactNode;
}) {
  const t = useTranslations("admin.address");

  const update = (patch: Partial<AddressDraft>) =>
    onChange({ ...value, ...patch });

  return (
    <fieldset className="grid gap-3 rounded-card border border-frost/10 bg-frost/[0.03] p-4">
      {title && (
        <legend className="font-mono text-[10px] uppercase tracking-[var(--tracking-overline)] text-ember px-1">
          {title}
        </legend>
      )}
      <div className="grid grid-cols-2 gap-3">
        <Field
          id={`${idPrefix}-country`}
          label={t("countryCode")}
          value={value.countryCode}
          onChange={(v) => update({ countryCode: v.toUpperCase().slice(0, 2) })}
          placeholder="PL"
          maxLength={2}
        />
        <Field
          id={`${idPrefix}-region`}
          label={t("region")}
          value={value.region}
          onChange={(v) => update({ region: v })}
        />
      </div>
      <Field
        id={`${idPrefix}-street`}
        label={t("streetLine")}
        value={value.streetLine}
        onChange={(v) => update({ streetLine: v })}
      />
      <div className="grid grid-cols-2 gap-3">
        <Field
          id={`${idPrefix}-building`}
          label={t("buildingNumber")}
          value={value.buildingNumber}
          onChange={(v) => update({ buildingNumber: v })}
        />
        <Field
          id={`${idPrefix}-unit`}
          label={t("unitNumber")}
          value={value.unitNumber}
          onChange={(v) => update({ unitNumber: v })}
        />
      </div>
      <div className="grid grid-cols-2 gap-3">
        <Field
          id={`${idPrefix}-postal`}
          label={t("postalCode")}
          value={value.postalCode}
          onChange={(v) => update({ postalCode: v })}
          placeholder="00-000"
        />
        <Field
          id={`${idPrefix}-city`}
          label={t("city")}
          value={value.city}
          onChange={(v) => update({ city: v })}
        />
      </div>
      <Field
        id={`${idPrefix}-directions`}
        label={t("directions")}
        value={value.directions}
        onChange={(v) => update({ directions: v })}
      />
    </fieldset>
  );
}

function Field({
  id,
  label,
  value,
  onChange,
  placeholder,
  maxLength,
}: {
  id: string;
  label: string;
  value: string;
  onChange: (v: string) => void;
  placeholder?: string;
  maxLength?: number;
}) {
  return (
    <div className="flex flex-col">
      <label
        htmlFor={id}
        className="font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist mb-2"
      >
        {label}
      </label>
      <input
        id={id}
        type="text"
        value={value}
        onChange={(e) => onChange(e.target.value)}
        placeholder={placeholder}
        maxLength={maxLength}
        className="rounded-button bg-frost/5 border border-frost/15 text-frost px-3.5 py-2.5 font-display text-base focus:outline-none focus:border-ember focus:bg-frost/[0.07] transition placeholder:text-mist/40"
      />
    </div>
  );
}
