// Client wrapper around AcceptInviteForm — reads the magic-link
// token from URL search params at runtime so the parent page can
// stay statically exportable. The server component shell used to
// read `searchParams` directly which forced dynamic rendering and
// broke the Firebase Hosting static-export deploy.

"use client";

import { useSearchParams } from "next/navigation";
import { Suspense } from "react";

import { AcceptInviteForm } from "./AcceptInviteForm";
import type { ModalityRow } from "@/lib/clinical/modalities";

type Props = {
  modalities: ReadonlyArray<ModalityRow>;
  missingTokenMessage: string;
};

function AcceptInviteSectionInner({ modalities, missingTokenMessage }: Props) {
  const params = useSearchParams();
  const token = params?.get("token") ?? "";

  if (!token) {
    return (
      <p
        role="alert"
        className="rounded-button border border-magma/40 bg-magma/10 px-4 py-3 font-serif text-sm text-frost text-center"
      >
        {missingTokenMessage}
      </p>
    );
  }

  return <AcceptInviteForm token={token} modalities={modalities} />;
}

export function AcceptInviteSection(props: Props) {
  // useSearchParams() requires a Suspense boundary in App Router —
  // otherwise the static prerender bails. Empty fallback is fine
  // here; the form area is below the hero copy which has already
  // rendered.
  return (
    <Suspense fallback={null}>
      <AcceptInviteSectionInner {...props} />
    </Suspense>
  );
}
