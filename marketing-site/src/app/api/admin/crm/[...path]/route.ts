// CRM sub-routes proxy — forwards to billing-svc CRM endpoints.
// Handles notes, follow-ups, tags, exclude, and user detail.

import { NextResponse, type NextRequest } from "next/server";

export const dynamic = "force-static";

const BILLING_SVC_URL = process.env.BILLING_SVC_URL || "http://localhost:8081";

export async function GET(
  req: NextRequest,
  { params }: { params: Promise<{ path: string[] }> },
) {
  const { path } = await params;
  const subPath = path.join("/");
  const { searchParams } = req.nextUrl;
  const qs = searchParams.toString();
  const url = `${BILLING_SVC_URL}/admin/crm/${subPath}${qs ? `?${qs}` : ""}`;

  try {
    const resp = await fetch(url, { cache: "no-store" });
    const data = await resp.json();
    return NextResponse.json(data, { status: resp.status });
  } catch (err) {
    console.error("CRM proxy error:", err);
    return NextResponse.json({ error: "billing-svc unreachable" }, { status: 502 });
  }
}

export async function POST(
  req: NextRequest,
  { params }: { params: Promise<{ path: string[] }> },
) {
  const { path } = await params;
  const subPath = path.join("/");
  const url = `${BILLING_SVC_URL}/admin/crm/${subPath}`;
  const body = await req.text();

  try {
    const resp = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body,
    });
    const data = await resp.json();
    return NextResponse.json(data, { status: resp.status });
  } catch (err) {
    console.error("CRM proxy POST error:", err);
    return NextResponse.json({ error: "billing-svc unreachable" }, { status: 502 });
  }
}

export async function PATCH(
  req: NextRequest,
  { params }: { params: Promise<{ path: string[] }> },
) {
  const { path } = await params;
  const subPath = path.join("/");
  const url = `${BILLING_SVC_URL}/admin/crm/${subPath}`;
  const body = await req.text();

  try {
    const resp = await fetch(url, {
      method: "PATCH",
      headers: { "Content-Type": "application/json" },
      body,
    });
    const data = await resp.json();
    return NextResponse.json(data, { status: resp.status });
  } catch (err) {
    console.error("CRM proxy PATCH error:", err);
    return NextResponse.json({ error: "billing-svc unreachable" }, { status: 502 });
  }
}

export async function DELETE(
  req: NextRequest,
  { params }: { params: Promise<{ path: string[] }> },
) {
  const { path } = await params;
  const subPath = path.join("/");
  const url = `${BILLING_SVC_URL}/admin/crm/${subPath}`;

  try {
    const resp = await fetch(url, { method: "DELETE" });
    const data = await resp.json();
    return NextResponse.json(data, { status: resp.status });
  } catch (err) {
    console.error("CRM proxy DELETE error:", err);
    return NextResponse.json({ error: "billing-svc unreachable" }, { status: 502 });
  }
}
