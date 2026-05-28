// Client wrapper around TherapistFinishForm — reads email/firstName/
// lastName from URL search params at runtime so the parent page can
// stay statically exportable. The personalised "Hi {firstName}"
// subhead is rendered here via useTranslations (next-intl's client
// hook) — passing a function from the server component to here would
// break server-component serialisation.

"use client";

import { Suspense } from "react";
import { useSearchParams } from "next/navigation";
import { useTranslations } from "next-intl";

import { TherapistFinishForm } from "./TherapistFinishForm";
import type { ModalityRow } from "@/lib/clinical/modalities";

type Props = {
  modalities: ReadonlyArray<ModalityRow>;
};

function Inner({ modalities }: Props) {
  const t = useTranslations("register.therapist");
  const params = useSearchParams();
  const email = params?.get("email") ?? "";
  const firstName = params?.get("firstName") ?? "";
  const lastName = params?.get("lastName") ?? "";

  return (
    <>
      <p className="font-serif text-mist text-center mt-4 max-w-md mx-auto text-base leading-relaxed">
        {firstName
          ? t("finishSubhead", { firstName })
          : t("finishGenericSubhead")}
      </p>
      <div className="mt-10">
        <TherapistFinishForm
          modalities={modalities}
          email={email}
          firstName={firstName}
          lastName={lastName}
        />
      </div>
    </>
  );
}

export function TherapistFinishSection(props: Props) {
  return (
    <Suspense fallback={null}>
      <Inner {...props} />
    </Suspense>
  );
}
