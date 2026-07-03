// /admin/orgs/new — 3-step org provisioning wizard (docs/38 §5.1).
//
// Step 1: company data (legal name, NIP, type, HQ address).
// Step 2: seat allocations — plan × seats × negotiated per-seat price,
//         with a live monthly-value + token total footer.
// Step 3: subscription start + manager e-mails + audit reason; submit
//         calls AdminCreateOrganization then AdminSetSeatAllocations
//         (both idempotent, safe to retry on a blip).

"use client";

import { useEffect, useMemo, useState } from "react";
import { useTranslations, useLocale } from "next-intl";
import { create } from "@bufbuild/protobuf";
import { timestampFromDate } from "@bufbuild/protobuf/wkt";

import { identityClient, billingClient } from "@/lib/connect/clients";
import {
  AdminCreateOrganizationRequestSchema,
  AddressSchema,
  OrganizationType,
} from "@superwizor/proto-ts/identity/v1/identity_pb";
import {
  AdminSetSeatAllocationsRequestSchema,
  type PlanInfo,
} from "@superwizor/proto-ts/billing/v1/billing_pb";
import { translateError } from "@/lib/errors/translate";
import { usePlanName } from "@/lib/plans";
import { AddressFields, EMPTY_ADDRESS, type AddressDraft } from "./AddressFields";

type SeatRow = { planId: string; seats: string; price: string };

export function OrgCreateWizard() {
  const t = useTranslations("admin.orgCreate");
  const planName = usePlanName();
  const tErrors = useTranslations("errors");
  const locale = useLocale();
  const prefix = locale === "en" ? "/en" : "";

  const [step, setStep] = useState<1 | 2 | 3>(1);

  // Step 1
  const [legalName, setLegalName] = useState("");
  const [taxId, setTaxId] = useState("");
  const [vatIdEu, setVatIdEu] = useState("");
  const [orgType, setOrgType] = useState<"SOLO" | "CLINIC">("CLINIC");
  const [address, setAddress] = useState<AddressDraft>({
    ...EMPTY_ADDRESS,
    countryCode: "PL",
  });

  // Step 2
  const [plans, setPlans] = useState<PlanInfo[]>([]);
  const [plansError, setPlansError] = useState(false);
  const [rows, setRows] = useState<SeatRow[]>([{ planId: "", seats: "1", price: "" }]);

  // Step 3
  const [startDate, setStartDate] = useState(() => new Date().toISOString().slice(0, 10));
  const [managerEmails, setManagerEmails] = useState("");
  const [reason, setReason] = useState("");

  const [submitting, setSubmitting] = useState(false);
  const [submitError, setSubmitError] = useState<string | null>(null);

  useEffect(() => {
    billingClient
      .adminListPlans({})
      .then((resp) => setPlans(resp.plans))
      .catch(() => setPlansError(true));
  }, []);

  const planById = useMemo(
    () => new Map(plans.map((p) => [p.planId, p])),
    [plans],
  );

  const totals = useMemo(() => {
    let value = 0;
    let tokens = 0;
    let seats = 0;
    for (const r of rows) {
      const plan = planById.get(r.planId);
      const n = parseInt(r.seats, 10);
      if (!plan || Number.isNaN(n) || n <= 0) continue;
      const unit = r.price.trim() !== "" ? Number(r.price) : Number(plan.priceGross);
      if (!Number.isNaN(unit)) value += n * unit;
      tokens += n * plan.tokensPerPeriod;
      seats += n;
    }
    return { value, tokens, seats };
  }, [rows, planById]);

  const step1Valid =
    legalName.trim().length > 1 &&
    address.city.trim() !== "" &&
    address.postalCode.trim() !== "" &&
    address.streetLine.trim() !== "" &&
    address.buildingNumber.trim() !== "";
  const step2Valid = rows.some((r) => {
    const n = parseInt(r.seats, 10);
    return r.planId !== "" && !Number.isNaN(n) && n > 0;
  });
  const emailsParsed = managerEmails
    .split(/[\s,;]+/)
    .map((e) => e.trim())
    .filter(Boolean);
  const step3Valid = emailsParsed.length > 0 && reason.trim().length >= 10;

  const updateRow = (i: number, patch: Partial<SeatRow>) =>
    setRows((rs) => rs.map((r, idx) => (idx === i ? { ...r, ...patch } : r)));

  const submit = async () => {
    setSubmitting(true);
    setSubmitError(null);
    try {
      const created = await identityClient.adminCreateOrganization(
        create(AdminCreateOrganizationRequestSchema, {
          legalName: legalName.trim(),
          taxId: taxId.trim(),
          vatIdEu: vatIdEu.trim(),
          type:
            orgType === "CLINIC"
              ? OrganizationType.CLINIC
              : OrganizationType.SOLO,
          headquarters: create(AddressSchema, {
            countryCode: address.countryCode,
            region: address.region,
            city: address.city,
            postalCode: address.postalCode,
            streetLine: address.streetLine,
            buildingNumber: address.buildingNumber,
            unitNumber: address.unitNumber,
            directions: address.directions,
          }),
          managerEmails: emailsParsed,
          reason: reason.trim(),
        }),
      );
      const orgId = created.organization?.id ?? "";

      await billingClient.adminSetSeatAllocations(
        create(AdminSetSeatAllocationsRequestSchema, {
          organizationId: orgId,
          allocations: rows
            .filter((r) => r.planId && parseInt(r.seats, 10) > 0)
            .map((r) => ({
              planId: r.planId,
              seats: parseInt(r.seats, 10),
              priceGrossPerSeat: r.price.trim(),
            })),
          subscriptionStart: timestampFromDate(new Date(`${startDate}T00:00:00Z`)),
          reason: reason.trim(),
        }),
      );

      window.location.href = `${prefix}/admin/orgs/${orgId}`;
    } catch (err) {
      setSubmitError(translateError(err, tErrors));
      setSubmitting(false);
    }
  };

  const stepLabel = (n: 1 | 2 | 3) => (
    <span
      className={`inline-flex h-6 w-6 items-center justify-center rounded-full font-mono text-[11px] ${
        step === n
          ? "bg-ember text-abyss"
          : step > n
            ? "bg-ember/25 text-ember"
            : "bg-frost/10 text-mist"
      }`}
    >
      {n}
    </span>
  );

  const inputCls =
    "rounded-button bg-frost/5 border border-frost/15 text-frost px-3.5 py-2 font-display text-sm focus:outline-none focus:border-ember focus:bg-frost/[0.07] placeholder:text-mist/40 transition w-full";
  const btnPrimary =
    "rounded-button bg-ember text-abyss px-5 py-2.5 font-mono text-xs uppercase tracking-[var(--tracking-label)] hover:bg-ember/90 transition disabled:opacity-40 disabled:cursor-not-allowed";
  const btnGhost =
    "rounded-button border border-frost/15 px-5 py-2.5 font-mono text-xs uppercase tracking-[var(--tracking-label)] text-mist hover:text-frost hover:border-frost/30 transition";

  return (
    <div className="px-4 sm:px-6 lg:px-8 py-8 max-w-3xl">
      <header className="mb-8">
        <h1 className="font-display text-frost text-2xl sm:text-3xl font-semibold tracking-[var(--tracking-display)]">
          {t("title")}
        </h1>
        <p className="font-serif text-mist mt-1 text-sm">{t("subhead")}</p>
        <div className="mt-4 flex items-center gap-2">
          {stepLabel(1)}
          <span className="h-px w-8 bg-frost/15" />
          {stepLabel(2)}
          <span className="h-px w-8 bg-frost/15" />
          {stepLabel(3)}
          <span className="ml-3 font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist">
            {t(`step${step}Name`)}
          </span>
        </div>
      </header>

      {step === 1 && (
        <div className="grid gap-4">
          <label className="grid gap-1.5">
            <span className="font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist">
              {t("legalName")}
            </span>
            <input className={inputCls} value={legalName} onChange={(e) => setLegalName(e.target.value)} />
          </label>
          <div className="grid grid-cols-2 gap-3">
            <label className="grid gap-1.5">
              <span className="font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist">
                {t("taxId")}
              </span>
              <input className={inputCls} value={taxId} onChange={(e) => setTaxId(e.target.value)} />
            </label>
            <label className="grid gap-1.5">
              <span className="font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist">
                {t("vatIdEu")}
              </span>
              <input className={inputCls} value={vatIdEu} onChange={(e) => setVatIdEu(e.target.value)} />
            </label>
          </div>
          <label className="grid gap-1.5">
            <span className="font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist">
              {t("orgType")}
            </span>
            <select
              className={inputCls}
              value={orgType}
              onChange={(e) => setOrgType(e.target.value as "SOLO" | "CLINIC")}
            >
              <option value="SOLO">{t("typeSolo")}</option>
              <option value="CLINIC">{t("typeClinic")}</option>
            </select>
          </label>
          <AddressFields idPrefix="neworg" value={address} onChange={setAddress} title={t("hqAddress")} />
          <div className="flex justify-end gap-3 mt-2">
            <button className={btnPrimary} disabled={!step1Valid} onClick={() => setStep(2)}>
              {t("next")}
            </button>
          </div>
        </div>
      )}

      {step === 2 && (
        <div className="grid gap-4">
          {plansError && (
            <p className="font-serif text-magma text-sm">{t("plansError")}</p>
          )}
          <div className="overflow-x-auto rounded-card border border-frost/10 bg-frost/[0.03]">
            <table className="w-full text-sm">
              <thead className="bg-frost/5">
                <tr>
                  {[t("colPlan"), t("colSeats"), t("colPrice"), ""].map((h, i) => (
                    <th
                      key={i}
                      className="text-left px-4 py-3 font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist"
                    >
                      {h}
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {rows.map((r, i) => {
                  const plan = planById.get(r.planId);
                  return (
                    <tr key={i} className="border-t border-frost/5">
                      <td className="px-4 py-2">
                        <select
                          className={inputCls}
                          value={r.planId}
                          onChange={(e) => updateRow(i, { planId: e.target.value })}
                        >
                          <option value="">{t("pickPlan")}</option>
                          {plans.map((p) => (
                            <option key={p.planId} value={p.planId}>
                              {planName(p.tier)} ({p.cycle}) — {p.priceGross} {p.currencyCode},{" "}
                              {p.tokensPerPeriod} tok.
                            </option>
                          ))}
                        </select>
                      </td>
                      <td className="px-4 py-2 w-24">
                        <input
                          className={inputCls}
                          inputMode="numeric"
                          value={r.seats}
                          onChange={(e) => updateRow(i, { seats: e.target.value.replace(/\D/g, "") })}
                        />
                      </td>
                      <td className="px-4 py-2 w-36">
                        <input
                          className={inputCls}
                          placeholder={plan ? plan.priceGross : t("catalogPrice")}
                          value={r.price}
                          onChange={(e) => updateRow(i, { price: e.target.value.replace(/[^\d.]/g, "") })}
                        />
                      </td>
                      <td className="px-4 py-2 text-right">
                        {rows.length > 1 && (
                          <button
                            className="font-mono text-[10px] uppercase text-magma hover:underline"
                            onClick={() => setRows((rs) => rs.filter((_, idx) => idx !== i))}
                          >
                            {t("removeRow")}
                          </button>
                        )}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
              <tfoot>
                <tr className="border-t border-frost/10 bg-frost/[0.04]">
                  <td className="px-4 py-3 font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist">
                    {t("totals", { seats: totals.seats })}
                  </td>
                  <td colSpan={3} className="px-4 py-3 text-right font-mono text-xs text-frost">
                    {totals.tokens} tok. · {totals.value.toFixed(2)} PLN
                  </td>
                </tr>
              </tfoot>
            </table>
          </div>
          <button
            className="justify-self-start font-mono text-xs uppercase tracking-[var(--tracking-label)] text-ember hover:underline"
            onClick={() => setRows((rs) => [...rs, { planId: "", seats: "1", price: "" }])}
          >
            {t("addRow")}
          </button>
          <div className="flex justify-between gap-3 mt-2">
            <button className={btnGhost} onClick={() => setStep(1)}>
              {t("back")}
            </button>
            <button className={btnPrimary} disabled={!step2Valid} onClick={() => setStep(3)}>
              {t("next")}
            </button>
          </div>
        </div>
      )}

      {step === 3 && (
        <div className="grid gap-4">
          <label className="grid gap-1.5">
            <span className="font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist">
              {t("startDate")}
            </span>
            <input
              type="date"
              className={inputCls}
              value={startDate}
              onChange={(e) => setStartDate(e.target.value)}
            />
          </label>
          <label className="grid gap-1.5">
            <span className="font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist">
              {t("managerEmails")}
            </span>
            <textarea
              className={`${inputCls} min-h-20`}
              placeholder={t("managerEmailsPlaceholder")}
              value={managerEmails}
              onChange={(e) => setManagerEmails(e.target.value)}
            />
            <span className="font-serif text-mist text-xs">{t("managerEmailsHint")}</span>
          </label>
          <label className="grid gap-1.5">
            <span className="font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist">
              {t("reason")}
            </span>
            <textarea
              className={`${inputCls} min-h-16`}
              placeholder={t("reasonPlaceholder")}
              value={reason}
              onChange={(e) => setReason(e.target.value)}
            />
          </label>

          {submitError && (
            <p className="rounded-card border border-magma/40 bg-magma/10 px-4 py-3 font-serif text-frost text-sm">
              {submitError}
            </p>
          )}

          <div className="flex justify-between gap-3 mt-2">
            <button className={btnGhost} onClick={() => setStep(2)} disabled={submitting}>
              {t("back")}
            </button>
            <button className={btnPrimary} disabled={!step3Valid || submitting} onClick={() => void submit()}>
              {submitting ? t("submitting") : t("submit")}
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
