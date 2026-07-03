// Admin org detail — AdminGetOrganization → renders the org card,
// therapists list, and recent-audit panel side-by-side.
//
// docs/18 §8.2 spec section that this maps to:
//   "Org detail — usage history chart (sessions/day, tokens/period),
//    therapist list, audit log for this org."
//
// Usage chart is deferred to a follow-up (needs sessions-per-day RPC
// the proto doesn't surface yet). Therapist list + audit panel are
// the two halves of the live data we DO have via OrganizationDetails.

"use client";

import { useCallback, useEffect, useState } from "react";
import { useTranslations, useLocale } from "next-intl";
import { create } from "@bufbuild/protobuf";
import { timestampDate } from "@bufbuild/protobuf/wkt";

import { identityClient, billingClient } from "@/lib/connect/clients";
import {
  AddressSchema,
  AdminGetOrganizationRequestSchema,
  AdminSetOrganizationStatusRequestSchema,
  AdminUpdateOrganizationRequestSchema,
  OrganizationType,
  type OrganizationDetails,
} from "@superwizor/proto-ts/identity/v1/identity_pb";
import {
  AdminResetTokensRequestSchema,
  AdminChangePlanRequestSchema,
  AdminGetOrgSeatUsageRequestSchema,
  AdminSetSeatAllocationsRequestSchema,
  type OrgSeatSummary,
  type PlanInfo,
} from "@superwizor/proto-ts/billing/v1/billing_pb";
import { ActionDialog, type ActionResult } from "./ActionDialog";
import {
  AddressFields,
  type AddressDraft,
  addressDiffers,
  addressFromProto,
} from "./AddressFields";
import { translateError } from "@/lib/errors/translate";
import { usePlanName } from "@/lib/plans";
import { CardSkeleton } from "./TableSkeleton";

type LoadState = "loading" | "ready" | "not-found" | "error";

export function OrgDetail({ orgId }: { orgId: string }) {
  const t = useTranslations("admin.orgDetail");
  const tOrgs = useTranslations("admin.orgs");
  const tA = useTranslations("admin.actions");
  const tEdit = useTranslations("admin.orgEdit");
  const tSeats = useTranslations("admin.orgSeats");
  const planName = usePlanName();
  const tErrors = useTranslations("errors");
  const locale = useLocale();
  const prefix = locale === "en" ? "/en" : "";

  const [state, setState] = useState<LoadState>("loading");
  const [details, setDetails] = useState<OrganizationDetails | null>(null);
  const [openDialog, setOpenDialog] = useState<
    null | "block" | "unblock" | "resetTokens" | "changePlan" | "edit" | "seats"
  >(null);

  // Form state for action-specific fields. Lives at this level so
  // re-opening a dialog after cancel doesn't lose typed values.
  const [tokensUsed, setTokensUsed] = useState("0");
  const [tokensLimit, setTokensLimit] = useState("");
  const [tier, setTier] = useState<"TRIAL" | "SOLO" | "PRO" | "CLINIC">("PRO");
  const [cycle, setCycle] = useState<"MONTHLY" | "ANNUAL">("MONTHLY");

  // Edit-org dialog draft state — seeded from the loaded org each
  // time the dialog opens. Tracks both the original snapshot (for
  // change detection) and the current draft.
  const [editDraft, setEditDraft] = useState<{
    legalName: string;
    type: "SOLO" | "CLINIC" | "ENTERPRISE";
    taxId: string;
    vatIdEu: string;
    primaryAdminUserId: string;
    address: AddressDraft;
  }>({
    legalName: "",
    type: "CLINIC",
    taxId: "",
    vatIdEu: "",
    primaryAdminUserId: "",
    address: addressFromProto(null),
  });
  const [editOriginalAddress, setEditOriginalAddress] = useState<AddressDraft>(
    addressFromProto(null),
  );
  const [editOriginalPrimaryAdmin, setEditOriginalPrimaryAdmin] = useState("");

  const reload = useCallback(async () => {
    setState("loading");
    try {
      const resp = await identityClient.adminGetOrganization(
        create(AdminGetOrganizationRequestSchema, { organizationId: orgId }),
      );
      setDetails(resp);
      setState("ready");
    } catch {
      setState("not-found");
    }
  }, [orgId]);

  // Seat allocations (docs/38): the CLINIC edit surface mirrors the
  // creation wizard's plan × seats × price table. SOLO orgs skip it.
  const [seatUsage, setSeatUsage] = useState<OrgSeatSummary | null>(null);
  const [plans, setPlans] = useState<PlanInfo[]>([]);
  const [seatRows, setSeatRows] = useState<
    { planId: string; seats: string; price: string }[]
  >([]);

  const reloadSeats = useCallback(async () => {
    try {
      const usage = await billingClient.adminGetOrgSeatUsage(
        create(AdminGetOrgSeatUsageRequestSchema, { organizationId: orgId }),
      );
      setSeatUsage(usage);
    } catch {
      setSeatUsage(null); // org without allocations / older billing — hide the card
    }
  }, [orgId]);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      setState("loading");
      try {
        const resp = await identityClient.adminGetOrganization(
          create(AdminGetOrganizationRequestSchema, { organizationId: orgId }),
        );
        if (cancelled) return;
        setDetails(resp);
        setState("ready");
      } catch {
        if (!cancelled) setState("not-found");
      }
    })();
    void reloadSeats();
    billingClient
      .adminListPlans({})
      .then((resp) => setPlans(resp.plans))
      .catch(() => setPlans([]));
    return () => {
      cancelled = true;
    };
  }, [orgId, reloadSeats]);

  const fmtDate = (ts: Parameters<typeof timestampDate>[0] | undefined) => {
    if (!ts) return "—";
    const d = timestampDate(ts);
    return new Intl.DateTimeFormat(locale === "en" ? "en-GB" : "pl-PL", {
      year: "numeric",
      month: "short",
      day: "numeric",
      hour: "2-digit",
      minute: "2-digit",
    }).format(d);
  };

  if (state === "loading") {
    return (
      <div className="px-4 sm:px-6 lg:px-8 py-8 grid gap-6">
        <span className="sr-only" role="status" aria-live="polite">
          {t("loading")}
        </span>
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          <CardSkeleton title={t("sectionDetails")} />
          <CardSkeleton title={t("sectionTherapists")} />
          <CardSkeleton title={t("sectionAudit")} />
        </div>
      </div>
    );
  }

  if (state === "not-found" || state === "error" || !details?.organization) {
    return (
      <div className="px-4 sm:px-6 lg:px-8 py-12 text-center">
        <p className="font-serif text-mist">{t("notFound")}</p>
        <a
          href={`${prefix}/admin/orgs`}
          className="mt-4 inline-flex items-center rounded-button border border-frost/20 px-4 py-2 font-mono text-xs uppercase tracking-[var(--tracking-label)] text-frost hover:bg-frost/5"
        >
          {t("backToList")}
        </a>
      </div>
    );
  }

  const org = details.organization;

  // Action handlers — each returns ActionResult so ActionDialog can
  // surface inline errors or close on success.
  const onSetStatus = (desired: "active" | "blocked") =>
    async (reason: string): Promise<ActionResult> => {
      try {
        await identityClient.adminSetOrganizationStatus(
          create(AdminSetOrganizationStatusRequestSchema, {
            organizationId: org.id,
            desiredStatus: desired,
            reason,
          }),
        );
        await reload();
        return "success";
      } catch (e) {
        return { error: translateError(e, tErrors) };
      }
    };

  const onResetTokens = async (reason: string): Promise<ActionResult> => {
    const used = Number.parseInt(tokensUsed, 10);
    if (Number.isNaN(used) || used < 0) {
      return { error: tA("tokensUsedLabel") };
    }
    const limit = tokensLimit.trim() === "" ? -1 : Number.parseInt(tokensLimit, 10);
    if (tokensLimit.trim() !== "" && (Number.isNaN(limit) || limit <= 0)) {
      return { error: tA("tokensLimitLabel") };
    }
    try {
      await billingClient.adminResetTokens(
        create(AdminResetTokensRequestSchema, {
          organizationId: org.id,
          tokensUsed: used,
          tokensLimit: limit,
          reason,
        }),
      );
      await reload();
      return "success";
    } catch (e) {
      return { error: translateError(e, tErrors) };
    }
  };

  const isSolo =
    (org.type as unknown) === OrganizationType.SOLO ||
    org.type === ("ORGANIZATION_TYPE_SOLO" as unknown as OrganizationType);

  const openSeats = () => {
    // Seed the editor from the live allocations; empty row when none.
    const rows = (seatUsage?.allocations ?? []).map((a) => ({
      planId: a.planId,
      seats: String(a.seats),
      price: a.priceGrossPerSeat,
    }));
    setSeatRows(rows.length > 0 ? rows : [{ planId: "", seats: "1", price: "" }]);
    setOpenDialog("seats");
  };

  const onSubmitSeats = async (reason: string): Promise<ActionResult> => {
    const allocations = seatRows
      .filter((r) => r.planId && Number.parseInt(r.seats, 10) >= 0)
      .map((r) => ({
        planId: r.planId,
        seats: Number.parseInt(r.seats, 10),
        priceGrossPerSeat: r.price.trim(),
      }));
    if (allocations.length === 0) {
      return { error: tSeats("noRows") };
    }
    try {
      await billingClient.adminSetSeatAllocations(
        create(AdminSetSeatAllocationsRequestSchema, {
          organizationId: org.id,
          allocations,
          reason,
        }),
      );
      await reloadSeats();
      return "success";
    } catch (e) {
      return { error: translateError(e, tErrors) };
    }
  };

  const openEdit = () => {
    // Seed the draft from the loaded org. proto-es types
    // organization.type as the numeric enum but Connect-Web JSON ships
    // it as a name — coerce to one of our four-string shape.
    const typeStr =
      (org.type as unknown) === OrganizationType.SOLO || org.type === ("ORGANIZATION_TYPE_SOLO" as unknown as OrganizationType)
        ? "SOLO"
        : (org.type as unknown) === OrganizationType.ENTERPRISE ||
            org.type === ("ORGANIZATION_TYPE_ENTERPRISE" as unknown as OrganizationType)
          ? "ENTERPRISE"
          : "CLINIC";
    const seededAddress = addressFromProto(org.headquartersAddress);
    setEditDraft({
      legalName: org.legalName,
      type: typeStr,
      taxId: org.taxId,
      vatIdEu: org.vatIdEu,
      primaryAdminUserId: org.primaryAdminUserId ?? "",
      address: seededAddress,
    });
    setEditOriginalAddress(seededAddress);
    setEditOriginalPrimaryAdmin(org.primaryAdminUserId ?? "");
    setOpenDialog("edit");
  };

  const onSubmitEdit = async (reason: string): Promise<ActionResult> => {
    // Only send fields that changed — the proto's `optional` wrappers
    // distinguish "no change" from "set to empty string".
    const orgTypeMap = {
      SOLO: OrganizationType.SOLO,
      CLINIC: OrganizationType.CLINIC,
      ENTERPRISE: OrganizationType.ENTERPRISE,
    } as const;
    const req: Record<string, unknown> = { organizationId: org.id, reason };
    if (editDraft.legalName !== org.legalName) req.legalName = editDraft.legalName;
    if (orgTypeMap[editDraft.type] !== org.type) req.type = orgTypeMap[editDraft.type];
    if (editDraft.taxId !== org.taxId) req.taxId = editDraft.taxId;
    if (editDraft.vatIdEu !== org.vatIdEu) req.vatIdEu = editDraft.vatIdEu;
    if (
      editDraft.primaryAdminUserId !== "" &&
      editDraft.primaryAdminUserId !== editOriginalPrimaryAdmin
    ) {
      req.primaryAdminUserId = editDraft.primaryAdminUserId;
    }
    if (addressDiffers(editDraft.address, editOriginalAddress)) {
      req.headquartersAddress = create(AddressSchema, editDraft.address);
    }

    if (Object.keys(req).length === 2) {
      // organizationId + reason only — nothing to change.
      return { error: tEdit("noChange") };
    }
    try {
      await identityClient.adminUpdateOrganization(
        create(AdminUpdateOrganizationRequestSchema, req),
      );
      await reload();
      return "success";
    } catch (e) {
      return { error: translateError(e, tErrors) };
    }
  };

  const onChangePlan = async (reason: string): Promise<ActionResult> => {
    try {
      await billingClient.adminChangePlan(
        create(AdminChangePlanRequestSchema, {
          organizationId: org.id,
          planTier: tier,
          planCycle: cycle,
          reason,
        }),
      );
      await reload();
      return "success";
    } catch (e) {
      return { error: translateError(e, tErrors) };
    }
  };

  return (
    <div className="px-4 sm:px-6 lg:px-8 py-8 grid gap-6">
      <header className="flex flex-col sm:flex-row sm:items-end sm:justify-between gap-4">
        <div>
          <a
            href={`${prefix}/admin/orgs`}
            className="font-mono text-[10px] uppercase tracking-[var(--tracking-overline)] text-mist hover:text-frost transition"
          >
            ← {t("backToList")}
          </a>
          <h1 className="font-display text-frost text-3xl font-semibold tracking-[var(--tracking-display)] mt-2">
            {org.legalName}
          </h1>
        </div>
        <span
          className={`inline-flex items-center rounded-button px-3 py-1 font-mono text-[10px] uppercase tracking-[var(--tracking-label)] ${
            org.isBlocked ? "bg-magma/20 text-magma" : "bg-ember/15 text-ember"
          }`}
        >
          {org.isBlocked ? tOrgs("status.blocked") : tOrgs("status.active")}
        </span>
      </header>

      <div className="flex flex-wrap gap-3">
        <ActionBtn onClick={openEdit}>{tEdit("edit")}</ActionBtn>
        {org.isBlocked ? (
          <ActionBtn onClick={() => setOpenDialog("unblock")}>
            {tA("unblock")}
          </ActionBtn>
        ) : (
          <ActionBtn onClick={() => setOpenDialog("block")} danger>
            {tA("block")}
          </ActionBtn>
        )}
        <ActionBtn onClick={() => setOpenDialog("resetTokens")}>
          {tA("resetTokens")}
        </ActionBtn>
        <ActionBtn onClick={() => setOpenDialog("changePlan")}>
          {tA("changePlan")}
        </ActionBtn>
        {!isSolo && (
          <ActionBtn onClick={openSeats}>{tSeats("manageCta")}</ActionBtn>
        )}
      </div>

      <section className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <Card title={t("sectionDetails")}>
          <DefRow label="ID" value={org.id} mono />
          <DefRow label="NIP" value={org.taxId || "—"} mono />
          <DefRow label="VAT-EU" value={org.vatIdEu || "—"} mono />
          {org.headquartersAddress && (
            <DefRow
              label="Adres"
              value={`${org.headquartersAddress.streetLine} ${org.headquartersAddress.buildingNumber}, ${org.headquartersAddress.postalCode} ${org.headquartersAddress.city}, ${org.headquartersAddress.countryCode}`}
            />
          )}
          <DefRow
            label="Utworzone"
            value={fmtDate(org.createdAt)}
            mono
          />
        </Card>

        <Card title={t("sectionTherapists")}>
          {details.therapists.length === 0 ? (
            <p className="font-serif text-mist text-sm">
              {t("noTherapists")}
            </p>
          ) : (
            <ul className="grid gap-2">
              {details.therapists.map((u) => (
                <li
                  key={u.id}
                  className="flex justify-between gap-3 font-serif text-sm"
                >
                  <span className="text-frost">
                    {u.firstName} {u.lastName}
                  </span>
                  <span className="text-mist truncate">{u.email}</span>
                </li>
              ))}
            </ul>
          )}
        </Card>

        <Card title={t("sectionAudit")}>
          {details.recentAudit.length === 0 ? (
            <p className="font-serif text-mist text-sm">{t("noAudit")}</p>
          ) : (
            <ul className="grid gap-3">
              {details.recentAudit.map((a) => (
                <li
                  key={a.id}
                  className="border-l-2 border-ember/40 pl-3 text-sm"
                >
                  <p className="font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist">
                    {a.action}
                  </p>
                  <p className="font-serif text-frost">{a.actorEmail}</p>
                  <p className="font-mono text-[10px] text-mist/70">
                    {fmtDate(a.occurredAt)}
                  </p>
                  {a.reason && (
                    <p className="font-serif text-mist text-xs mt-1">
                      {a.reason}
                    </p>
                  )}
                </li>
              ))}
            </ul>
          )}
        </Card>
      </section>

      {/* Seat allocations — CLINIC orgs mirror the creation wizard
          (docs/38 §5); SOLO orgs have no seat surface. */}
      {!isSolo && seatUsage && seatUsage.allocations.length > 0 && (
        <section>
          <Card title={tSeats("sectionTitle")}>
            <ul className="grid gap-3">
              {seatUsage.allocations.map((a) => {
                const used = a.seatsAssigned + a.seatsPending;
                const pct = a.seats > 0 ? Math.min(100, (used / a.seats) * 100) : 0;
                return (
                  <li key={a.allocationId} className="grid gap-1.5">
                    <div className="flex items-baseline justify-between font-serif text-sm">
                      <span className="text-frost">
                        {planName(a.planTier)} · {a.planCycle}
                      </span>
                      <span className="font-mono text-xs text-mist">
                        {used}/{a.seats} · {a.priceGrossPerSeat} {a.currencyCode}
                        {tSeats("perSeatSuffix")}
                      </span>
                    </div>
                    <div className="h-1.5 rounded-full bg-frost/10 overflow-hidden">
                      <div
                        className={`h-full ${pct >= 100 ? "bg-magma" : "bg-ember"}`}
                        style={{ width: `${pct}%` }}
                      />
                    </div>
                    {a.seatsPending > 0 && (
                      <p className="font-serif text-mist text-xs">
                        {tSeats("pendingNote", { count: a.seatsPending })}
                      </p>
                    )}
                  </li>
                );
              })}
            </ul>
          </Card>
        </section>
      )}

      {/* Action dialogs ----------------------------------------- */}
      <ActionDialog
        open={openDialog === "block"}
        title={tA("blockTitle")}
        body={tA("blockBody")}
        onClose={() => setOpenDialog(null)}
        onConfirm={onSetStatus("blocked")}
      />
      <ActionDialog
        open={openDialog === "unblock"}
        title={tA("unblockTitle")}
        body={tA("unblockBody")}
        onClose={() => setOpenDialog(null)}
        onConfirm={onSetStatus("active")}
      />
      <ActionDialog
        open={openDialog === "resetTokens"}
        title={tA("resetTokensTitle")}
        body={tA("resetTokensBody")}
        onClose={() => setOpenDialog(null)}
        onConfirm={onResetTokens}
      >
        <NumberField
          id="tokens-used"
          label={tA("tokensUsedLabel")}
          value={tokensUsed}
          onChange={setTokensUsed}
          required
        />
        <NumberField
          id="tokens-limit"
          label={tA("tokensLimitLabel")}
          value={tokensLimit}
          onChange={setTokensLimit}
        />
      </ActionDialog>
      <ActionDialog
        open={openDialog === "edit"}
        title={tEdit("title")}
        body={tEdit("body")}
        onClose={() => setOpenDialog(null)}
        onConfirm={onSubmitEdit}
      >
        <div className="grid gap-3">
          <div className="flex flex-col">
            <label
              htmlFor="edit-legal-name"
              className="font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist mb-2"
            >
              {tEdit("legalNameLabel")}
            </label>
            <input
              id="edit-legal-name"
              type="text"
              value={editDraft.legalName}
              onChange={(e) =>
                setEditDraft((d) => ({ ...d, legalName: e.target.value }))
              }
              className="rounded-button bg-frost/5 border border-frost/15 text-frost px-3.5 py-2.5 font-display text-base focus:outline-none focus:border-ember focus:bg-frost/[0.07] transition"
            />
          </div>
          <SelectField
            id="edit-type"
            label={tEdit("typeLabel")}
            value={editDraft.type}
            onChange={(v) =>
              setEditDraft((d) => ({ ...d, type: v as typeof d.type }))
            }
            options={[
              { value: "SOLO", label: tOrgs("typeLabel.SOLO") },
              { value: "CLINIC", label: tOrgs("typeLabel.CLINIC") },
              { value: "ENTERPRISE", label: tOrgs("typeLabel.ENTERPRISE") },
            ]}
          />
          <div className="grid grid-cols-2 gap-3">
            <div className="flex flex-col">
              <label
                htmlFor="edit-tax-id"
                className="font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist mb-2"
              >
                {tEdit("taxIdLabel")}
              </label>
              <input
                id="edit-tax-id"
                type="text"
                inputMode="numeric"
                value={editDraft.taxId}
                onChange={(e) =>
                  setEditDraft((d) => ({ ...d, taxId: e.target.value }))
                }
                className="rounded-button bg-frost/5 border border-frost/15 text-frost px-3.5 py-2.5 font-display text-base focus:outline-none focus:border-ember focus:bg-frost/[0.07] transition"
              />
            </div>
            <div className="flex flex-col">
              <label
                htmlFor="edit-vat-eu"
                className="font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist mb-2"
              >
                {tEdit("vatIdEuLabel")}
              </label>
              <input
                id="edit-vat-eu"
                type="text"
                value={editDraft.vatIdEu}
                onChange={(e) =>
                  setEditDraft((d) => ({ ...d, vatIdEu: e.target.value }))
                }
                className="rounded-button bg-frost/5 border border-frost/15 text-frost px-3.5 py-2.5 font-display text-base focus:outline-none focus:border-ember focus:bg-frost/[0.07] transition"
              />
            </div>
          </div>

          {/* Primary admin transfer. Source is the loaded therapists list
              — pragmatic MVP since AdminGetOrganization already returns
              them. If the new owner needs to be an ORG_ADMIN not yet on
              this list, set them via AdminUpdateUser → role first. */}
          <div className="flex flex-col">
            <label
              htmlFor="edit-primary-admin"
              className="font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist mb-2"
            >
              {tEdit("primaryAdminLabel")}
            </label>
            <select
              id="edit-primary-admin"
              value={editDraft.primaryAdminUserId}
              onChange={(e) =>
                setEditDraft((d) => ({
                  ...d,
                  primaryAdminUserId: e.target.value,
                }))
              }
              className="rounded-button bg-frost/5 border border-frost/15 text-frost px-3.5 py-2.5 font-display text-base focus:outline-none focus:border-ember focus:bg-frost/[0.07] transition appearance-none cursor-pointer"
            >
              <option value="">{tEdit("primaryAdminUnchanged")}</option>
              {details.therapists.map((u) => (
                <option key={u.id} value={u.id}>
                  {u.firstName} {u.lastName} — {u.email}
                </option>
              ))}
            </select>
            <p className="font-mono text-[10px] text-mist/60 mt-1.5">
              {tEdit("primaryAdminHint")}
            </p>
          </div>

          {/* Headquarters address sub-form. The proto Address has 9
              fields; we surface 8 (id is server-set). Blank fields are
              fine — submission only sends the message when something
              actually changed vs. the seeded value. */}
          <AddressFields
            idPrefix="edit-hq"
            value={editDraft.address}
            onChange={(next) => setEditDraft((d) => ({ ...d, address: next }))}
            title={tEdit("addressTitle")}
          />
        </div>
      </ActionDialog>
      <ActionDialog
        open={openDialog === "seats"}
        title={tSeats("dialogTitle")}
        body={tSeats("dialogBody")}
        onClose={() => setOpenDialog(null)}
        onConfirm={onSubmitSeats}
      >
        <div className="grid gap-2.5">
          {seatRows.map((r, i) => (
            <div key={i} className="grid grid-cols-[1fr_5rem_6rem_auto] gap-2 items-center">
              <select
                value={r.planId}
                onChange={(e) =>
                  setSeatRows((rs) =>
                    rs.map((row, idx) => (idx === i ? { ...row, planId: e.target.value } : row)),
                  )
                }
                className="rounded-button bg-frost/5 border border-frost/15 text-frost px-3 py-2 font-display text-sm focus:outline-none focus:border-ember transition appearance-none cursor-pointer"
              >
                <option value="">{tSeats("pickPlan")}</option>
                {plans.map((p) => (
                  <option key={p.planId} value={p.planId}>
                    {planName(p.tier)} ({p.cycle})
                  </option>
                ))}
              </select>
              <input
                inputMode="numeric"
                aria-label={tSeats("seatsLabel")}
                value={r.seats}
                onChange={(e) =>
                  setSeatRows((rs) =>
                    rs.map((row, idx) =>
                      idx === i ? { ...row, seats: e.target.value.replace(/\D/g, "") } : row,
                    ),
                  )
                }
                className="rounded-button bg-frost/5 border border-frost/15 text-frost px-3 py-2 font-mono text-sm focus:outline-none focus:border-ember transition"
              />
              <input
                aria-label={tSeats("priceLabel")}
                placeholder={tSeats("catalogPrice")}
                value={r.price}
                onChange={(e) =>
                  setSeatRows((rs) =>
                    rs.map((row, idx) =>
                      idx === i ? { ...row, price: e.target.value.replace(/[^\d.]/g, "") } : row,
                    ),
                  )
                }
                className="rounded-button bg-frost/5 border border-frost/15 text-frost px-3 py-2 font-mono text-sm focus:outline-none focus:border-ember transition"
              />
              {seatRows.length > 1 ? (
                <button
                  type="button"
                  onClick={() => setSeatRows((rs) => rs.filter((_, idx) => idx !== i))}
                  className="font-mono text-[10px] uppercase text-magma hover:underline"
                >
                  {tSeats("removeRow")}
                </button>
              ) : (
                <span />
              )}
            </div>
          ))}
          <button
            type="button"
            onClick={() => setSeatRows((rs) => [...rs, { planId: "", seats: "1", price: "" }])}
            className="justify-self-start font-mono text-xs uppercase tracking-[var(--tracking-label)] text-ember hover:underline"
          >
            {tSeats("addRow")}
          </button>
          <p className="font-mono text-[10px] text-mist/60">{tSeats("hint")}</p>
        </div>
      </ActionDialog>
      <ActionDialog
        open={openDialog === "changePlan"}
        title={tA("changePlanTitle")}
        body={tA("changePlanBody")}
        onClose={() => setOpenDialog(null)}
        onConfirm={onChangePlan}
      >
        <div className="grid grid-cols-2 gap-3">
          <SelectField
            id="tier"
            label={tA("tierLabel")}
            value={tier}
            onChange={(v) => setTier(v as typeof tier)}
            options={[
              { value: "TRIAL", label: "TRIAL" },
              { value: "SOLO", label: "SOLO" },
              { value: "PRO", label: "PRO" },
              { value: "CLINIC", label: "CLINIC" },
            ]}
          />
          <SelectField
            id="cycle"
            label={tA("cycleLabel")}
            value={cycle}
            onChange={(v) => setCycle(v as typeof cycle)}
            options={[
              { value: "MONTHLY", label: tA("cycleMonthly") },
              { value: "ANNUAL", label: tA("cycleAnnual") },
            ]}
          />
        </div>
      </ActionDialog>
    </div>
  );
}

function ActionBtn({
  children,
  onClick,
  danger = false,
}: {
  children: React.ReactNode;
  onClick: () => void;
  danger?: boolean;
}) {
  return (
    <button
      onClick={onClick}
      className={`rounded-button border px-3 py-2 font-mono text-xs uppercase tracking-[var(--tracking-label)] transition ${
        danger
          ? "border-magma/40 text-magma hover:bg-magma/10"
          : "border-frost/15 text-frost hover:bg-frost/5 hover:border-frost/30"
      }`}
    >
      {children}
    </button>
  );
}

function NumberField({
  id,
  label,
  value,
  onChange,
  required = false,
}: {
  id: string;
  label: string;
  value: string;
  onChange: (v: string) => void;
  required?: boolean;
}) {
  return (
    <div className="flex flex-col">
      <label
        htmlFor={id}
        className="font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist mb-2"
      >
        {label}
        {required && <span aria-hidden className="text-ember ml-1">*</span>}
      </label>
      <input
        id={id}
        type="number"
        inputMode="numeric"
        value={value}
        onChange={(e) => onChange(e.target.value)}
        className="rounded-button bg-frost/5 border border-frost/15 text-frost px-3.5 py-2.5 font-display text-base focus:outline-none focus:border-ember focus:bg-frost/[0.07] transition"
      />
    </div>
  );
}

function SelectField({
  id,
  label,
  value,
  onChange,
  options,
}: {
  id: string;
  label: string;
  value: string;
  onChange: (v: string) => void;
  options: { value: string; label: string }[];
}) {
  return (
    <div className="flex flex-col">
      <label
        htmlFor={id}
        className="font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist mb-2"
      >
        {label}
      </label>
      <select
        id={id}
        value={value}
        onChange={(e) => onChange(e.target.value)}
        className="rounded-button bg-frost/5 border border-frost/15 text-frost px-3.5 py-2.5 font-display text-base focus:outline-none focus:border-ember focus:bg-frost/[0.07] transition appearance-none cursor-pointer"
      >
        {options.map((o) => (
          <option key={o.value} value={o.value}>
            {o.label}
          </option>
        ))}
      </select>
    </div>
  );
}

function Card({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div className="rounded-card border border-frost/10 bg-frost/[0.04] p-5">
      <h2 className="font-mono text-[10px] uppercase tracking-[var(--tracking-overline)] text-ember mb-3">
        {title}
      </h2>
      <div className="grid gap-2">{children}</div>
    </div>
  );
}

function DefRow({
  label,
  value,
  mono = false,
}: {
  label: string;
  value: string;
  mono?: boolean;
}) {
  return (
    <div className="grid grid-cols-3 gap-2 text-sm">
      <span className="font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist self-center col-span-1">
        {label}
      </span>
      <span
        className={`text-frost col-span-2 ${mono ? "font-mono text-xs break-all" : "font-serif"}`}
      >
        {value}
      </span>
    </div>
  );
}
