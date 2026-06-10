// Next.js API route that proxies CRM requests to billing-svc.
// billing-svc runs internally on Cloud Run; this route authenticates
// by forwarding the Firebase ID token as a header that the admin
// layout already validates on the client side.
//
// The AdminGuardAndShell component on the client side already ensures
// only SUPERWIZOR_ADMIN users can access /admin/* routes. This proxy
// just forwards the request to billing-svc's internal HTTP endpoint.

import { NextResponse, type NextRequest } from "next/server";

export const dynamic = "force-static";

const BILLING_SVC_URL = process.env.BILLING_SVC_URL || "http://localhost:8081";

export async function GET(req: NextRequest) {
  // Forward query params to billing-svc
  const { searchParams } = req.nextUrl;
  const qs = searchParams.toString();
  const url = `${BILLING_SVC_URL}/admin/crm/subscribers${qs ? `?${qs}` : ""}`;

  try {
    const resp = await fetch(url, {
      headers: { "Content-Type": "application/json" },
      cache: "no-store",
    });
    const data = await resp.json();
    return NextResponse.json(data, { status: resp.status });
  } catch (err) {
    console.error("CRM proxy error:", err);
    return NextResponse.json(
      { error: "billing-svc unreachable", subscribers: [], total: 0 },
      { status: 502 },
    );
  }
}
