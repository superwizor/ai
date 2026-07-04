// Client wrapper for ClientOnboardingForm — reads the magic-link token
// from URL search params at runtime so the page shell stays statically
// exportable (same pattern as AcceptInviteSection).

"use client";

import { useSearchParams } from "next/navigation";
import { Suspense } from "react";

import { ClientOnboardingForm } from "./ClientOnboardingForm";

type Props = {
  missingTokenMessage: string;
};

function ClientOnboardingSectionInner({ missingTokenMessage }: Props) {
  const params = useSearchParams();
  const token = params?.get("token") ?? "";

  if (!token) {
    return (
      <p
        role="alert"
        className="rounded-button border border-magma/40 bg-magma/10 px-4 py-3 font-sans text-sm text-frost text-center"
      >
        {missingTokenMessage}
      </p>
    );
  }

  return <ClientOnboardingForm token={token} />;
}

export function ClientOnboardingSection(props: Props) {
  return (
    <Suspense fallback={null}>
      <ClientOnboardingSectionInner {...props} />
    </Suspense>
  );
}
