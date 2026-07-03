// /org — organization manager panel (docs/38 §5.4).

import { setRequestLocale } from "next-intl/server";
import { OrgPanel } from "@/components/org/OrgPanel";

export default async function OrgPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  setRequestLocale(locale);
  return <OrgPanel />;
}
