// Admin global users list — AdminListUsers with role filter + search.
//
// Same hand-rolled table pattern as OrgsList. Adds inline Edit and
// Delete dialogs powered by AdminUpdateUser + AdminDeleteUser.
// The edit dialog now covers the full docs/18 §13.8 surface: name,
// email, phone, role, organization_id transfer, default_modality_id,
// professional title + credentials number, biography, avatar URL,
// billing address (via shared AddressFields), UI language.
//
// Two fields still take a raw UUID string instead of a richer picker:
//   • organization_id — no global orgs lookup is fetched here; the
//     admin can copy the ID from /admin/orgs.
//   • default_modality_id — no ListModalities RPC yet on clinical-svc.
// Both validate as UUIDs in the backend handler; an unknown UUID is
// rejected with InvalidArgument.

"use client";

import { useCallback, useEffect, useState } from "react";
import { useTranslations } from "next-intl";
import { create } from "@bufbuild/protobuf";

import { identityClient, billingClient } from "@/lib/connect/clients";
import {
  AddressSchema,
  AdminListUsersRequestSchema,
  AdminListOrganizationsRequestSchema,
  AdminUpdateUserRequestSchema,
  AdminDeleteUserRequestSchema,
  UserRole,
  type User,
} from "@superwizor/proto-ts/identity/v1/identity_pb";
import {
  GetSubscriptionRequestSchema,
  AdminResetTokensRequestSchema,
  type Subscription,
} from "@superwizor/proto-ts/billing/v1/billing_pb";
import { ActionDialog, type ActionResult } from "./ActionDialog";
import { TableSkeleton } from "./TableSkeleton";
import {
  AddressFields,
  type AddressDraft,
  addressDiffers,
  addressFromProto,
  EMPTY_ADDRESS,
} from "./AddressFields";
import { translateError } from "@/lib/errors/translate";

const PAGE_SIZE = 25;

type LoadState = "idle" | "loading" | "ready" | "error";

const ROLE_KEYS = [
  "USER_ROLE_UNSPECIFIED",
  "USER_ROLE_THERAPIST",
  "USER_ROLE_PATIENT",
  "USER_ROLE_ORG_ADMIN",
  "USER_ROLE_SUPERWIZOR_ADMIN",
] as const;

function roleKey(r: unknown): (typeof ROLE_KEYS)[number] {
  // Connect-Web JSON ships enums as proto names; proto-es types them
  // as numeric. Coerce to the proto-name shape.
  if (typeof r === "string" && (ROLE_KEYS as readonly string[]).includes(r)) {
    return r as (typeof ROLE_KEYS)[number];
  }
  if (r === UserRole.THERAPIST) return "USER_ROLE_THERAPIST";
  if (r === UserRole.PATIENT) return "USER_ROLE_PATIENT";
  if (r === UserRole.ORG_ADMIN) return "USER_ROLE_ORG_ADMIN";
  if (r === UserRole.SUPERWIZOR_ADMIN) return "USER_ROLE_SUPERWIZOR_ADMIN";
  return "USER_ROLE_UNSPECIFIED";
}

function roleEnumFromKey(k: (typeof ROLE_KEYS)[number]): UserRole {
  switch (k) {
    case "USER_ROLE_THERAPIST":
      return UserRole.THERAPIST;
    case "USER_ROLE_PATIENT":
      return UserRole.PATIENT;
    case "USER_ROLE_ORG_ADMIN":
      return UserRole.ORG_ADMIN;
    case "USER_ROLE_SUPERWIZOR_ADMIN":
      return UserRole.SUPERWIZOR_ADMIN;
    default:
      return UserRole.UNSPECIFIED;
  }
}

export function UsersList() {
  const t = useTranslations("admin.users");
  const tCol = useTranslations("admin.users.columns");
  const tRole = useTranslations("admin.users.roleLabel");

  const [search, setSearch] = useState("");
  const [searchDebounced, setSearchDebounced] = useState("");
  const [roleFilter, setRoleFilter] = useState<"" | (typeof ROLE_KEYS)[number]>("");
  const [users, setUsers] = useState<User[]>([]);
  const [state, setState] = useState<LoadState>("idle");
  const [nextPageToken, setNextPageToken] = useState<string>("");
  const [pageStack, setPageStack] = useState<string[]>([""]);
  const [editing, setEditing] = useState<User | null>(null);
  const [deleting, setDeleting] = useState<User | null>(null);

  // org_id → legal_name lookup, populated on mount so the ORGANIZACJA
  // column can show a human-readable name instead of a UUID. Pages
  // through AdminListOrganizations until exhausted. For the launch
  // catalogue (<100 orgs) this is cheap; if it grows, replace with
  // a per-user JOIN on the backend (AdminListUsers → JOIN orgs).
  const [orgNames, setOrgNames] = useState<Record<string, string>>({});

  useEffect(() => {
    let cancelled = false;
    (async () => {
      const names: Record<string, string> = {};
      let pageToken = "";
      try {
        // Safety cap of 20 pages × 100/page = 2000 orgs.
        for (let i = 0; i < 20; i++) {
          const resp = await identityClient.adminListOrganizations(
            create(AdminListOrganizationsRequestSchema, {
              pageSize: 100,
              pageToken,
            }),
          );
          for (const summary of resp.organizations) {
            const o = summary.organization;
            if (o?.id) names[o.id] = o.legalName || "—";
          }
          if (!resp.nextPageToken) break;
          pageToken = resp.nextPageToken;
        }
        if (!cancelled) setOrgNames(names);
      } catch {
        // Non-fatal: column falls back to "—". We don't surface the
        // error because the rest of the page is fine.
      }
    })();
    return () => {
      cancelled = true;
    };
  }, []);

  useEffect(() => {
    const handle = setTimeout(() => setSearchDebounced(search), 300);
    return () => clearTimeout(handle);
  }, [search]);

  // Reset pagination when filters change.
  useEffect(() => {
    setPageStack([""]);
  }, [searchDebounced, roleFilter]);

  const fetchPage = useCallback(
    async (pageToken: string) => {
      setState("loading");
      try {
        const req = create(AdminListUsersRequestSchema, {
          pageSize: PAGE_SIZE,
          pageToken,
          search: searchDebounced,
        });
        if (roleFilter) {
          req.role = roleEnumFromKey(roleFilter);
        }
        const resp = await identityClient.adminListUsers(req);
        setUsers(resp.users);
        setNextPageToken(resp.nextPageToken);
        setState("ready");
      } catch {
        setState("error");
      }
    },
    [searchDebounced, roleFilter],
  );

  useEffect(() => {
    const currentToken = pageStack[pageStack.length - 1] ?? "";
    void fetchPage(currentToken);
  }, [pageStack, fetchPage]);

  const reload = () => fetchPage(pageStack[pageStack.length - 1] ?? "");

  return (
    <div className="px-4 sm:px-6 lg:px-8 py-8">
      <header className="flex flex-col sm:flex-row sm:items-end sm:justify-between gap-4 mb-6">
        <div>
          <h1 className="font-display text-frost text-2xl sm:text-3xl font-semibold tracking-[var(--tracking-display)]">
            {t("title")}
          </h1>
          <p className="font-serif text-mist mt-1 text-sm">{t("subhead")}</p>
        </div>
        <div className="flex flex-col sm:flex-row gap-2 w-full sm:w-auto">
          <select
            value={roleFilter}
            onChange={(e) =>
              setRoleFilter(e.target.value as typeof roleFilter)
            }
            className="rounded-button bg-obsidian border border-frost/25 text-frost px-3.5 py-2 font-display text-sm focus:outline-none focus:border-ember transition cursor-pointer"
          >
            <option value="">{t("roleFilterAll")}</option>
            {ROLE_KEYS.filter((k) => k !== "USER_ROLE_UNSPECIFIED").map((k) => (
              <option key={k} value={k}>
                {tRole(k)}
              </option>
            ))}
          </select>
          <input
            type="search"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder={t("searchPlaceholder")}
            className="rounded-button bg-obsidian border border-frost/25 text-frost px-3.5 py-2 font-display text-sm focus:outline-none focus:border-ember placeholder:text-mist/60 transition w-full sm:w-72"
          />
        </div>
      </header>

      {state === "loading" && (
        <>
          <span className="sr-only" role="status" aria-live="polite">
            {t("loading")}
          </span>
          <TableSkeleton columns={5} />
        </>
      )}

      {state === "error" && (
        <div className="rounded-card border border-magma/40 bg-magma/10 px-4 py-6 text-center">
          <p className="font-serif text-frost text-sm">{t("error")}</p>
          <button
            onClick={reload}
            className="mt-3 inline-flex items-center rounded-button border border-frost/20 px-4 py-2 font-mono text-xs uppercase tracking-[var(--tracking-label)] text-frost hover:bg-frost/5"
          >
            {t("retry")}
          </button>
        </div>
      )}

      {state === "ready" && users.length === 0 && (
        <p className="font-serif text-mist text-center py-12">{t("empty")}</p>
      )}

      {state === "ready" && users.length > 0 && (
        <>
          <div className="overflow-x-auto rounded-card border border-frost/10 bg-frost/[0.03]">
            <table className="w-full text-sm">
              <thead className="bg-frost/5">
                <tr>
                  <th className="text-left px-4 py-3 font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist">
                    {tCol("name")}
                  </th>
                  <th className="text-left px-4 py-3 font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist">
                    {tCol("email")}
                  </th>
                  <th className="text-left px-4 py-3 font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist">
                    {tCol("role")}
                  </th>
                  <th className="text-left px-4 py-3 font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist">
                    {tCol("orgId")}
                  </th>
                  <th className="text-right px-4 py-3 font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist">
                    {tCol("actions")}
                  </th>
                </tr>
              </thead>
              <tbody>
                {users.map((u) => {
                  const rk = roleKey(u.role);
                  return (
                    <tr key={u.id} className="border-t border-frost/5">
                      <td className="px-4 py-3 font-display text-frost">
                        {u.firstName} {u.lastName}
                      </td>
                      <td className="px-4 py-3 font-mono text-xs text-mist break-all">
                        {u.email}
                      </td>
                      <td className="px-4 py-3 font-serif text-mist">
                        {tRole(rk)}
                      </td>
                      <td className="px-4 py-3 font-serif text-mist">
                        {/* Prefer legal_name from the orgNames map; fall
                            back to the raw UUID if the lookup hasn't
                            populated yet (e.g. mid-flight). Dash for
                            users with no organization. */}
                        {u.organizationId
                          ? orgNames[u.organizationId] ?? u.organizationId
                          : "—"}
                      </td>
                      <td className="px-4 py-3 text-right">
                        <div className="inline-flex gap-2">
                          <button
                            onClick={() => setEditing(u)}
                            className="font-mono text-xs uppercase tracking-[var(--tracking-label)] text-ember hover:underline"
                          >
                            {t("edit")}
                          </button>
                          <button
                            onClick={() => setDeleting(u)}
                            className="font-mono text-xs uppercase tracking-[var(--tracking-label)] text-magma hover:underline"
                          >
                            {t("delete")}
                          </button>
                        </div>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>

          <div className="mt-6 flex items-center justify-end gap-3">
            <button
              onClick={() => setPageStack((s) => s.slice(0, -1))}
              disabled={pageStack.length <= 1}
              className="rounded-button border border-frost/15 px-4 py-2 font-mono text-xs uppercase tracking-[var(--tracking-label)] text-mist hover:text-frost hover:border-frost/30 transition disabled:opacity-40 disabled:cursor-not-allowed"
            >
              {t("prev")}
            </button>
            <button
              onClick={() =>
                nextPageToken && setPageStack((s) => [...s, nextPageToken])
              }
              disabled={!nextPageToken}
              className="rounded-button border border-frost/15 px-4 py-2 font-mono text-xs uppercase tracking-[var(--tracking-label)] text-mist hover:text-frost hover:border-frost/30 transition disabled:opacity-40 disabled:cursor-not-allowed"
            >
              {t("next")}
            </button>
          </div>
        </>
      )}

      {editing && (
        <UserEditDialog
          user={editing}
          onClose={() => setEditing(null)}
          onSuccess={() => {
            setEditing(null);
            void reload();
          }}
        />
      )}
      {deleting && (
        <UserDeleteDialog
          user={deleting}
          onClose={() => setDeleting(null)}
          onSuccess={() => {
            setDeleting(null);
            void reload();
          }}
        />
      )}
    </div>
  );
}

function UserEditDialog({
  user,
  onClose,
  onSuccess,
}: {
  user: User;
  onClose: () => void;
  onSuccess: () => void;
}) {
  const t = useTranslations("admin.users");
  const tRole = useTranslations("admin.users.roleLabel");
  const tErrors = useTranslations("errors");

  const [draft, setDraft] = useState({
    firstName: user.firstName,
    lastName: user.lastName,
    email: user.email,
    phoneNumber: user.phoneNumber,
    role: roleKey(user.role),
    uiLanguage: user.uiLanguage || "pl",
    organizationId: user.organizationId ?? "",
    defaultModalityId: user.defaultModalityId ?? "",
    professionalTitle: user.professionalTitle ?? "",
    credentialsNumber: user.credentialsNumber ?? "",
    biography: user.biography ?? "",
    avatarUrl: user.avatarUrl ?? "",
    // Billing address starts empty because the User proto carries only
    // billing_address_id, not the resolved Address. The admin sees a
    // blank sub-form; submission only sends the message when something
    // gets filled in (addressDiffers vs EMPTY_ADDRESS). If we ever
    // surface the address back on the User proto we can pre-seed here.
    billingAddress: addressFromProto(null) as AddressDraft,
  });

  // ── Token management state ──────────────────────────────────────
  const [subscription, setSubscription] = useState<Subscription | null>(null);
  const [tokenLoadState, setTokenLoadState] = useState<"idle" | "loading" | "ready" | "error" | "no-sub">("idle");
  const [newTokensUsed, setNewTokensUsed] = useState("");
  const [tokenResetBusy, setTokenResetBusy] = useState(false);
  const [tokenResetMsg, setTokenResetMsg] = useState<{ ok?: string; err?: string } | null>(null);

  // Fetch subscription for the user's org on mount.
  useEffect(() => {
    if (!user.organizationId) {
      setTokenLoadState("idle");
      return;
    }
    let cancelled = false;
    (async () => {
      setTokenLoadState("loading");
      try {
        const sub = await billingClient.getSubscription(
          create(GetSubscriptionRequestSchema, { organizationId: user.organizationId }),
        );
        if (!cancelled) {
          setSubscription(sub);
          setTokenLoadState("ready");
        }
      } catch {
        if (!cancelled) setTokenLoadState("no-sub");
      }
    })();
    return () => { cancelled = true; };
  }, [user.organizationId]);

  const handleResetTokens = async () => {
    if (!user.organizationId) return;
    const used = newTokensUsed.trim() === "" ? -1 : Number.parseInt(newTokensUsed, 10);
    if (newTokensUsed.trim() !== "" && (Number.isNaN(used) || used < 0)) {
      setTokenResetMsg({ err: t("tokenInvalidUsed") });
      return;
    }
    if (used === -1) {
      setTokenResetMsg({ err: t("tokenNoChange") });
      return;
    }
    setTokenResetBusy(true);
    setTokenResetMsg(null);
    try {
      const fresh = await billingClient.adminResetTokens(
        create(AdminResetTokensRequestSchema, {
          organizationId: user.organizationId,
          // Zakres: TA osoba. Bez tego pola karta użytkownika zerowała
          // licznik każdemu terapeucie w organizacji, a powód poniżej
          // wymieniał jedną osobę — ślad audytu opisywał mniej, niż
          // robiła operacja. W organizacji jednoosobowej backend sam
          // schodzi na licznik organizacyjny i odnotowuje to w audycie.
          therapistId: user.id,
          tokensUsed: used,
          // tokensLimit celowo nie: limit terapeuty wynika z planu jego
          // miejsca (org_seat_allocations). Limit organizacji ustawia się
          // na karcie organizacji, gdzie ma znaczenie.
          tokensLimit: -1,
          reason: `Admin reset tokens for ${user.email || user.firstName} via user edit`,
        }),
      );
      setSubscription(fresh);
      setNewTokensUsed("");
      setTokenResetMsg({ ok: t("tokenResetSuccess") });
    } catch (e) {
      setTokenResetMsg({ err: translateError(e, tErrors) });
    } finally {
      setTokenResetBusy(false);
    }
  };

  const onConfirm = async (reason: string): Promise<ActionResult> => {
    const req: Record<string, unknown> = { userId: user.id, reason };
    if (draft.firstName !== user.firstName) req.firstName = draft.firstName;
    if (draft.lastName !== user.lastName) req.lastName = draft.lastName;
    if (draft.email !== user.email) req.email = draft.email;
    if (draft.phoneNumber !== user.phoneNumber) req.phoneNumber = draft.phoneNumber;
    if (roleEnumFromKey(draft.role) !== user.role) req.role = roleEnumFromKey(draft.role);
    if (draft.uiLanguage !== (user.uiLanguage || "pl"))
      req.uiLanguage = draft.uiLanguage;
    if (draft.organizationId !== (user.organizationId ?? ""))
      req.organizationId = draft.organizationId;
    if (draft.defaultModalityId !== (user.defaultModalityId ?? ""))
      req.defaultModalityId = draft.defaultModalityId;
    if (draft.professionalTitle !== (user.professionalTitle ?? ""))
      req.professionalTitle = draft.professionalTitle;
    if (draft.credentialsNumber !== (user.credentialsNumber ?? ""))
      req.credentialsNumber = draft.credentialsNumber;
    if (draft.biography !== (user.biography ?? "")) req.biography = draft.biography;
    if (draft.avatarUrl !== (user.avatarUrl ?? "")) req.avatarUrl = draft.avatarUrl;
    if (addressDiffers(draft.billingAddress, EMPTY_ADDRESS)) {
      req.billingAddress = create(AddressSchema, draft.billingAddress);
    }

    if (Object.keys(req).length === 2) {
      return { error: t("noChange") };
    }
    try {
      await identityClient.adminUpdateUser(
        create(AdminUpdateUserRequestSchema, req),
      );
      onSuccess();
      return "success";
    } catch (e) {
      return { error: translateError(e, tErrors) };
    }
  };

  // Token usage progress percentage (clamped 0–100).
  const tokenPct = subscription
    ? Math.min(
        100,
        Math.round(
          ((subscription.tokensUsedThisPeriod) /
            Math.max(1, subscription.tokensPerPeriod)) *
            100,
        ),
      )
    : 0;

  return (
    <ActionDialog
      open
      title={t("editTitle")}
      body={t("editBody")}
      onClose={onClose}
      onConfirm={onConfirm}
    >
      <div className="grid gap-3">
        <div className="grid grid-cols-2 gap-3">
          <SimpleInput
            id="u-first"
            label={t("firstName")}
            value={draft.firstName}
            onChange={(v) => setDraft((d) => ({ ...d, firstName: v }))}
          />
          <SimpleInput
            id="u-last"
            label={t("lastName")}
            value={draft.lastName}
            onChange={(v) => setDraft((d) => ({ ...d, lastName: v }))}
          />
        </div>
        <SimpleInput
          id="u-email"
          label={t("email")}
          value={draft.email}
          onChange={(v) => setDraft((d) => ({ ...d, email: v }))}
          type="email"
        />
        <SimpleInput
          id="u-phone"
          label={t("phone")}
          value={draft.phoneNumber}
          onChange={(v) => setDraft((d) => ({ ...d, phoneNumber: v }))}
          type="tel"
        />
        <div className="grid grid-cols-2 gap-3">
          <SimpleSelect
            id="u-role"
            label={t("role")}
            value={draft.role}
            onChange={(v) =>
              setDraft((d) => ({ ...d, role: v as typeof d.role }))
            }
            options={ROLE_KEYS.filter((k) => k !== "USER_ROLE_UNSPECIFIED").map(
              (k) => ({ value: k, label: tRole(k) }),
            )}
          />
          <SimpleSelect
            id="u-lang"
            label={t("uiLanguage")}
            value={draft.uiLanguage}
            onChange={(v) => setDraft((d) => ({ ...d, uiLanguage: v }))}
            options={[
              { value: "pl", label: t("polish") },
              { value: "en", label: t("english") },
            ]}
          />
        </div>

        {/* Professional bona fides — therapists/org-admins surface these. */}
        <div className="grid grid-cols-2 gap-3">
          <SimpleInput
            id="u-title"
            label={t("professionalTitle")}
            value={draft.professionalTitle}
            onChange={(v) => setDraft((d) => ({ ...d, professionalTitle: v }))}
          />
          <SimpleInput
            id="u-creds"
            label={t("credentialsNumber")}
            value={draft.credentialsNumber}
            onChange={(v) => setDraft((d) => ({ ...d, credentialsNumber: v }))}
          />
        </div>

        {/* Biography is the public-facing therapist intro; the rendered
            HTML is sanitized on display so admins may paste markdown
            or paragraphs of plain text here. */}
        <div className="flex flex-col">
          <label
            htmlFor="u-bio"
            className="font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist mb-2"
          >
            {t("biography")}
          </label>
          <textarea
            id="u-bio"
            value={draft.biography}
            onChange={(e) =>
              setDraft((d) => ({ ...d, biography: e.target.value }))
            }
            rows={3}
            className="rounded-button bg-obsidian border border-frost/25 text-frost px-3.5 py-2.5 font-serif text-sm focus:outline-none focus:border-ember transition resize-y"
          />
        </div>

        <SimpleInput
          id="u-avatar"
          label={t("avatarUrl")}
          value={draft.avatarUrl}
          onChange={(v) => setDraft((d) => ({ ...d, avatarUrl: v }))}
          type="url"
        />

        {/* Organization transfer + clinical modality. No global lookup
            on either today — both are raw UUID inputs. The backend
            validates the UUID format and rejects unknowns. See the
            file header for context. */}
        <div className="flex flex-col">
          <label
            htmlFor="u-org"
            className="font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist mb-2"
          >
            {t("organizationId")}
          </label>
          <input
            id="u-org"
            type="text"
            value={draft.organizationId}
            onChange={(e) =>
              setDraft((d) => ({ ...d, organizationId: e.target.value.trim() }))
            }
            placeholder="00000000-0000-0000-0000-000000000000"
            className="rounded-button bg-obsidian border border-frost/25 text-frost px-3.5 py-2.5 font-mono text-xs focus:outline-none focus:border-ember transition placeholder:text-mist/60"
          />
          <p className="font-mono text-[10px] text-mist/60 mt-1.5">
            {t("organizationIdHint")}
          </p>
        </div>

        <div className="flex flex-col">
          <label
            htmlFor="u-modality"
            className="font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist mb-2"
          >
            {t("defaultModalityId")}
          </label>
          <input
            id="u-modality"
            type="text"
            value={draft.defaultModalityId}
            onChange={(e) =>
              setDraft((d) => ({
                ...d,
                defaultModalityId: e.target.value.trim(),
              }))
            }
            placeholder="00000000-0000-0000-0000-000000000000"
            className="rounded-button bg-obsidian border border-frost/25 text-frost px-3.5 py-2.5 font-mono text-xs focus:outline-none focus:border-ember transition placeholder:text-mist/60"
          />
          <p className="font-mono text-[10px] text-mist/60 mt-1.5">
            {t("defaultModalityIdHint")}
          </p>
        </div>

        {/* Billing address. Always seeded empty (the User proto carries
            only the FK), so any non-blank field counts as a change. */}
        <AddressFields
          idPrefix="u-billing"
          value={draft.billingAddress}
          onChange={(next) =>
            setDraft((d) => ({ ...d, billingAddress: next }))
          }
          title={t("billingAddressTitle")}
        />
        <p className="font-mono text-[10px] text-mist/60 -mt-2">
          {t("billingAddressHint")}
        </p>

        {/* ── Token management section ─────────────────────────── */}
        {user.organizationId ? (
          <div className="rounded-card border border-ember/30 bg-ember/5 p-4 mt-1">
            <h3 className="font-display text-frost text-sm font-semibold tracking-[var(--tracking-display)] mb-3">
              {t("tokenManagement")}
            </h3>

            {tokenLoadState === "loading" && (
              <p className="font-serif text-mist text-xs animate-pulse">
                {t("tokensLoading")}
              </p>
            )}

            {tokenLoadState === "no-sub" && (
              <p className="font-serif text-mist/70 text-xs">
                {t("tokensNoSub")}
              </p>
            )}

            {tokenLoadState === "ready" && subscription && (
              <>
                {/* Current usage display */}
                <div className="grid grid-cols-3 gap-2 mb-3">
                  <div className="text-center">
                    <p className="font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist">
                      {t("tokensUsed")}
                    </p>
                    <p className="font-display text-frost text-lg font-semibold">
                      {subscription.tokensUsedThisPeriod}
                    </p>
                  </div>
                  <div className="text-center">
                    <p className="font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist">
                      {t("tokensLimit")}
                    </p>
                    <p className="font-display text-frost text-lg font-semibold">
                      {subscription.tokensPerPeriod}
                    </p>
                  </div>
                  <div className="text-center">
                    <p className="font-mono text-[10px] uppercase tracking-[var(--tracking-label)] text-mist">
                      {t("tokensRemaining")}
                    </p>
                    <p className="font-display text-ember text-lg font-semibold">
                      {subscription.tokensRemaining}
                    </p>
                  </div>
                </div>

                {/* Progress bar */}
                <div className="w-full h-2 rounded-full bg-obsidian/60 mb-4 overflow-hidden">
                  <div
                    className="h-full rounded-full transition-all duration-300"
                    style={{
                      width: `${tokenPct}%`,
                      backgroundColor:
                        tokenPct > 90
                          ? "var(--color-magma)"
                          : tokenPct > 60
                            ? "var(--color-ember)"
                            : "var(--color-frost)",
                    }}
                  />
                </div>

                {/* Reset inputs */}
                {/* Tylko zużycie. Limit należy do planu/miejsca, nie do
                    osoby — ustawia się go na karcie organizacji. */}
                <div className="mb-3">
                  <SimpleInput
                    id="u-tokens-used"
                    label={t("newTokensUsed")}
                    value={newTokensUsed}
                    onChange={setNewTokensUsed}
                  />
                </div>
                <p className="font-mono text-[10px] text-mist/60 mb-3">
                  {t("tokenResetHint")}
                </p>

                {tokenResetMsg?.ok && (
                  <p className="mb-2 rounded-button border border-frost/30 bg-frost/10 px-3 py-2 font-serif text-xs text-frost">
                    {tokenResetMsg.ok}
                  </p>
                )}
                {tokenResetMsg?.err && (
                  <p className="mb-2 rounded-button border border-magma/40 bg-magma/10 px-3 py-2 font-serif text-xs text-frost">
                    {tokenResetMsg.err}
                  </p>
                )}

                <button
                  type="button"
                  onClick={handleResetTokens}
                  disabled={tokenResetBusy}
                  className="w-full rounded-button bg-ember/80 text-obsidian font-mono uppercase tracking-[var(--tracking-label)] text-xs px-4 py-2 hover:bg-ember transition disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  {tokenResetBusy ? "…" : t("tokenResetBtn")}
                </button>
              </>
            )}
          </div>
        ) : (
          <p className="font-mono text-[10px] text-mist/50 mt-1">
            {t("tokensNoOrg")}
          </p>
        )}
      </div>
    </ActionDialog>
  );
}

function UserDeleteDialog({
  user,
  onClose,
  onSuccess,
}: {
  user: User;
  onClose: () => void;
  onSuccess: () => void;
}) {
  const t = useTranslations("admin.users");
  const tErrors = useTranslations("errors");

  const onConfirm = async (reason: string): Promise<ActionResult> => {
    try {
      await identityClient.adminDeleteUser(
        create(AdminDeleteUserRequestSchema, { userId: user.id, reason }),
      );
      onSuccess();
      return "success";
    } catch (e) {
      return { error: translateError(e, tErrors) };
    }
  };

  return (
    <ActionDialog
      open
      title={t("deleteTitle")}
      body={`${t("deleteBody")} (${user.firstName} ${user.lastName} · ${user.email})`}
      onClose={onClose}
      onConfirm={onConfirm}
    />
  );
}

function SimpleInput({
  id,
  label,
  value,
  onChange,
  type = "text",
}: {
  id: string;
  label: string;
  value: string;
  onChange: (v: string) => void;
  type?: string;
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
        type={type}
        value={value}
        onChange={(e) => onChange(e.target.value)}
        className="rounded-button bg-obsidian border border-frost/25 text-frost px-3.5 py-2.5 font-display text-base focus:outline-none focus:border-ember transition"
      />
    </div>
  );
}

function SimpleSelect({
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
        className="rounded-button bg-obsidian border border-frost/25 text-frost px-3.5 py-2.5 font-display text-base focus:outline-none focus:border-ember transition appearance-none cursor-pointer"
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
