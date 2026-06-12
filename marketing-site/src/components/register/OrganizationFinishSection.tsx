// Client wrapper around OrganizationFinishForm — see
// TherapistFinishSection for the rationale; both pages converted to
// the same shape for the 2026-05-28 static-export deploy.

"use client";

import { Suspense } from "react";
import { useSearchParams } from "next/navigation";
import { useTranslations } from "next-intl";

import { OrganizationFinishForm } from "./OrganizationFinishForm";

function Inner() {
  const t = useTranslations("register.organization");
  const params = useSearchParams();
  const email = params?.get("email") ?? "";
  const firstName = params?.get("firstName") ?? "";
  const lastName = params?.get("lastName") ?? "";

  return (
    <>
      <p className="font-sans text-mist text-center mt-4 max-w-lg mx-auto text-base leading-relaxed">
        {firstName
          ? t("finishSubhead", { firstName })
          : t("finishGenericSubhead")}
      </p>
      <div className="mt-10">
        <OrganizationFinishForm
          email={email}
          firstName={firstName}
          lastName={lastName}
        />
      </div>
    </>
  );
}

export function OrganizationFinishSection() {
  return (
    <Suspense fallback={null}>
      <Inner />
    </Suspense>
  );
}
