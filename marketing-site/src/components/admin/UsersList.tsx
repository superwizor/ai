// Admin global users list — AdminListUsers with role filter + search.
//
// Same hand-rolled table pattern as OrgsList. Adds inline Edit and
// Delete dialogs powered by AdminUpdateUser + AdminDeleteUser.
// docs/18 §13.8 spec calls for a richer user-form (full address +
// avatar + biography); MVP ships the high-frequency fields (name,
// email, role, phone, ui_language) and defers the rest.

"use client";

import { useCallback, useEffect, useState } from "react";
import { useTranslations } from "next-intl";
import { create } from "@bufbuild/protobuf";

import { identityClient } from "@/lib/connect/clients";
import {
  AdminListUsersRequestSchema,
  AdminUpdateUserRequestSchema,
  AdminDeleteUserRequestSchema,
  UserRole,
  type User,
} from "@superwizor/proto-ts/identity/v1/identity_pb";
import { ActionDialog, type ActionResult } from "./ActionDialog";

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
            className="rounded-button bg-frost/5 border border-frost/15 text-frost px-3.5 py-2 font-display text-sm focus:outline-none focus:border-ember transition cursor-pointer"
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
            className="rounded-button bg-frost/5 border border-frost/15 text-frost px-3.5 py-2 font-display text-sm focus:outline-none focus:border-ember focus:bg-frost/[0.07] placeholder:text-mist/40 transition w-full sm:w-72"
          />
        </div>
      </header>

      {state === "loading" && (
        <p className="font-mono text-[10px] uppercase tracking-[var(--tracking-overline)] text-mist/70 py-12 text-center">
          {t("loading")}
        </p>
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
                      <td className="px-4 py-3 font-mono text-[10px] text-mist/70 break-all">
                        {u.organizationId || "—"}
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

  const [draft, setDraft] = useState({
    firstName: user.firstName,
    lastName: user.lastName,
    email: user.email,
    phoneNumber: user.phoneNumber,
    role: roleKey(user.role),
    uiLanguage: user.uiLanguage || "pl",
  });

  const onConfirm = async (reason: string): Promise<ActionResult> => {
    const req: Record<string, unknown> = { userId: user.id, reason };
    if (draft.firstName !== user.firstName) req.firstName = draft.firstName;
    if (draft.lastName !== user.lastName) req.lastName = draft.lastName;
    if (draft.email !== user.email) req.email = draft.email;
    if (draft.phoneNumber !== user.phoneNumber) req.phoneNumber = draft.phoneNumber;
    if (roleEnumFromKey(draft.role) !== user.role) req.role = roleEnumFromKey(draft.role);
    if (draft.uiLanguage !== (user.uiLanguage || "pl"))
      req.uiLanguage = draft.uiLanguage;

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
      return { error: e instanceof Error ? e.message : String(e) };
    }
  };

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

  const onConfirm = async (reason: string): Promise<ActionResult> => {
    try {
      await identityClient.adminDeleteUser(
        create(AdminDeleteUserRequestSchema, { userId: user.id, reason }),
      );
      onSuccess();
      return "success";
    } catch (e) {
      return { error: e instanceof Error ? e.message : String(e) };
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
        className="rounded-button bg-frost/5 border border-frost/15 text-frost px-3.5 py-2.5 font-display text-base focus:outline-none focus:border-ember focus:bg-frost/[0.07] transition"
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
