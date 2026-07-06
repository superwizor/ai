// Organizacja tab (docs/38 PR14): editable org data + manager management.
//
// - Org form: legal_name / tax_id / vat_id_eu → UpdateMyOrganization.
// - Managers: list active managers + pending ORG_ADMIN invites; invite a
//   new manager; deactivate/reactivate OTHER managers (never self — the
//   backend rejects it and the UI hides the control on the caller's row);
//   revoke a pending invite.

"use client";

import { useCallback, useEffect, useState } from "react";
import { useTranslations } from "next-intl";
import { create } from "@bufbuild/protobuf";
import { EmptySchema } from "@bufbuild/protobuf/wkt";

import { identityClient } from "@/lib/connect/clients";
import {
  UpdateMyOrganizationRequestSchema,
  InviteMyOrgManagerRequestSchema,
  SetMyOrgManagerStatusRequestSchema,
  RevokeMyOrgManagerInviteRequestSchema,
  type Organization,
  type ManagerEntry,
} from "@superwizor/proto-ts/identity/v1/identity_pb";
import { translateError } from "@/lib/errors/translate";

const inputCls =
  "rounded-button bg-obsidian border border-frost/25 text-frost px-3.5 py-2 font-display text-sm focus:outline-none focus:border-ember placeholder:text-mist/60 transition w-full";
const btnPrimary =
  "rounded-button bg-ember text-obsidian px-4 py-2 font-mono text-xs uppercase tracking-[var(--tracking-label)] hover:bg-ember/90 transition disabled:opacity-40 disabled:cursor-not-allowed";
const thCls =
  "text-left px-4 py-3 font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist";

export function OrgOrganizationTab({
  org,
  onOrgUpdated,
}: {
  org: Organization | null;
  onOrgUpdated: (o: Organization) => void;
}) {
  const t = useTranslations("org.panel");
  const tErrors = useTranslations("errors");

  // ── editable org form ──
  const [legalName, setLegalName] = useState(org?.legalName ?? "");
  const [taxId, setTaxId] = useState(org?.taxId ?? "");
  const [vatIdEu, setVatIdEu] = useState(org?.vatIdEu ?? "");
  const [savingOrg, setSavingOrg] = useState(false);
  const [orgFlash, setOrgFlash] = useState<string | null>(null);
  const [orgError, setOrgError] = useState<string | null>(null);

  useEffect(() => {
    setLegalName(org?.legalName ?? "");
    setTaxId(org?.taxId ?? "");
    setVatIdEu(org?.vatIdEu ?? "");
  }, [org]);

  const saveOrg = async () => {
    setSavingOrg(true);
    setOrgError(null);
    setOrgFlash(null);
    try {
      const updated = await identityClient.updateMyOrganization(
        create(UpdateMyOrganizationRequestSchema, {
          legalName: legalName.trim(),
          taxId: taxId.trim(),
          vatIdEu: vatIdEu.trim(),
        }),
      );
      onOrgUpdated(updated);
      setOrgFlash(t("orgSaved"));
    } catch (err) {
      setOrgError(translateError(err, tErrors));
    } finally {
      setSavingOrg(false);
    }
  };

  // ── managers ──
  const [managers, setManagers] = useState<ManagerEntry[]>([]);
  const [meId, setMeId] = useState<string>("");
  const [mgrError, setMgrError] = useState<string | null>(null);
  const [mgrFlash, setMgrFlash] = useState<string | null>(null);

  const reloadManagers = useCallback(async () => {
    try {
      const [list, me] = await Promise.all([
        identityClient.listMyOrgManagers(create(EmptySchema, {})),
        identityClient.getMyProfile(create(EmptySchema, {})).catch(() => null),
      ]);
      setManagers(list.managers);
      if (me) setMeId(me.id);
    } catch (err) {
      setMgrError(translateError(err, tErrors));
    }
  }, [tErrors]);

  useEffect(() => {
    void reloadManagers();
  }, [reloadManagers]);

  // invite form
  const [invEmail, setInvEmail] = useState("");
  const [invBusy, setInvBusy] = useState(false);

  const inviteManager = async () => {
    if (!invEmail.trim()) return;
    setInvBusy(true);
    setMgrError(null);
    setMgrFlash(null);
    try {
      await identityClient.inviteMyOrgManager(
        create(InviteMyOrgManagerRequestSchema, { email: invEmail.trim() }),
      );
      setInvEmail("");
      setMgrFlash(t("managerInvited"));
      await reloadManagers();
    } catch (err) {
      setMgrError(translateError(err, tErrors));
    } finally {
      setInvBusy(false);
    }
  };

  const setStatus = async (userId: string, isActive: boolean) => {
    setMgrError(null);
    setMgrFlash(null);
    try {
      await identityClient.setMyOrgManagerStatus(
        create(SetMyOrgManagerStatusRequestSchema, { userId, isActive }),
      );
      setMgrFlash(isActive ? t("reactivated") : t("deactivated"));
      await reloadManagers();
    } catch (err) {
      setMgrError(translateError(err, tErrors));
    }
  };

  const revokeInvite = async (invitationId: string) => {
    setMgrError(null);
    setMgrFlash(null);
    try {
      await identityClient.revokeMyOrgManagerInvite(
        create(RevokeMyOrgManagerInviteRequestSchema, { invitationId }),
      );
      setMgrFlash(t("managerRevoked"));
      await reloadManagers();
    } catch (err) {
      setMgrError(translateError(err, tErrors));
    }
  };

  return (
    <section className="mt-6 grid gap-8 max-w-3xl">
      {/* Editable org data */}
      <div className="rounded-card border border-frost/10 bg-frost/[0.03] p-6 grid gap-4">
        <h2 className="font-display text-frost text-lg font-semibold">{t("orgDataTitle")}</h2>
        <label className="grid gap-1.5">
          <span className="font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist">
            {t("orgLegalName")}
          </span>
          <input className={inputCls} value={legalName} onChange={(e) => setLegalName(e.target.value)} />
        </label>
        <div className="grid sm:grid-cols-2 gap-4">
          <label className="grid gap-1.5">
            <span className="font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist">
              {t("orgTaxId")}
            </span>
            <input className={inputCls} value={taxId} onChange={(e) => setTaxId(e.target.value)} />
          </label>
          <label className="grid gap-1.5">
            <span className="font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist">
              {t("orgVatIdEu")}
            </span>
            <input className={inputCls} value={vatIdEu} onChange={(e) => setVatIdEu(e.target.value)} />
          </label>
        </div>
        {orgError && <p className="font-serif text-sm text-magma">{orgError}</p>}
        {orgFlash && <p className="font-serif text-sm text-ember">{orgFlash}</p>}
        <div className="flex justify-end">
          <button className={btnPrimary} onClick={() => void saveOrg()} disabled={savingOrg}>
            {t("orgSaveCta")}
          </button>
        </div>
      </div>

      {/* Managers */}
      <div className="grid gap-4">
        <h2 className="font-display text-frost text-lg font-semibold">{t("managersTitle")}</h2>

        <div className="flex flex-col sm:flex-row gap-2 sm:items-end">
          <label className="grid gap-1.5 flex-1">
            <span className="font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist">
              {t("managerInviteEmail")}
            </span>
            <input
              className={inputCls}
              type="email"
              placeholder="menedzer@example.com"
              value={invEmail}
              onChange={(e) => setInvEmail(e.target.value)}
            />
          </label>
          <button
            className={btnPrimary}
            onClick={() => void inviteManager()}
            disabled={invBusy || !invEmail.trim()}
          >
            {t("managerInviteCta")}
          </button>
        </div>

        {mgrError && <p className="font-serif text-sm text-magma">{mgrError}</p>}
        {mgrFlash && <p className="font-serif text-sm text-ember">{mgrFlash}</p>}

        <div className="overflow-x-auto rounded-card border border-frost/10 bg-frost/[0.03]">
          <table className="w-full text-sm">
            <thead className="bg-frost/5">
              <tr>
                <th className={thCls}>{t("colManager")}</th>
                <th className={thCls}>{t("colStatus")}</th>
                <th className={`${thCls} text-right`} />
              </tr>
            </thead>
            <tbody>
              {managers.map((e, i) => {
                if (e.user) {
                  const u = e.user;
                  const isSelf = u.id === meId;
                  return (
                    <tr key={`u-${u.id}`} className="border-t border-frost/5">
                      <td className="px-4 py-3">
                        <span className="font-display text-frost">
                          {u.firstName} {u.lastName}
                          {isSelf && (
                            <span className="ml-2 font-mono text-[10px] uppercase text-ember">
                              {t("managerYou")}
                            </span>
                          )}
                        </span>
                        <div className="font-mono text-mist text-xs">{u.email}</div>
                      </td>
                      <td className="px-4 py-3">
                        <span
                          className={`inline-flex rounded-button px-2 py-0.5 font-mono text-[10px] uppercase tracking-[var(--tracking-label)] ${
                            u.isActive ? "bg-ember/15 text-ember" : "bg-frost/10 text-mist"
                          }`}
                        >
                          {u.isActive ? t("statusActive") : t("statusInactive")}
                        </span>
                      </td>
                      <td className="px-4 py-3 text-right">
                        {!isSelf && (
                          <button
                            className="font-mono text-xs uppercase tracking-[var(--tracking-label)] text-ember hover:underline"
                            onClick={() => void setStatus(u.id, !u.isActive)}
                          >
                            {u.isActive ? t("deactivateCta") : t("reactivateCta")}
                          </button>
                        )}
                      </td>
                    </tr>
                  );
                }
                const inv = e.pendingInvitation;
                if (!inv) return null;
                return (
                  <tr key={`i-${inv.id ?? i}`} className="border-t border-frost/5 opacity-70">
                    <td className="px-4 py-3 font-mono text-mist text-xs">{inv.email}</td>
                    <td className="px-4 py-3">
                      <span className="inline-flex rounded-button bg-frost/10 px-2 py-0.5 font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist">
                        {t("statusPending")}
                      </span>
                    </td>
                    <td className="px-4 py-3 text-right">
                      <button
                        className="font-mono text-xs uppercase tracking-[var(--tracking-label)] text-magma hover:underline"
                        onClick={() => void revokeInvite(inv.id)}
                      >
                        {t("managerRevokeCta")}
                      </button>
                    </td>
                  </tr>
                );
              })}
              {managers.length === 0 && (
                <tr>
                  <td colSpan={3} className="px-4 py-8 text-center font-serif text-mist">
                    {t("managersEmpty")}
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </div>
    </section>
  );
}
