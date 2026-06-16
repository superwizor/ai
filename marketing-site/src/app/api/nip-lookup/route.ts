import { NextRequest, NextResponse } from "next/server";

export async function GET(request: NextRequest) {
  try {
    const searchParams = request.nextUrl.searchParams;
    const rawNip = searchParams.get("nip");

    if (!rawNip) {
      return NextResponse.json({ error: "NIP jest wymagany" }, { status: 400 });
    }

    // Normalize NIP: remove spaces and hyphens
    const normalizedNip = rawNip.replace(/[\s\-]/g, "");

    if (!/^\d{10}$/.test(normalizedNip)) {
      return NextResponse.json({ error: "NIP musi składać się dokładnie z 10 cyfr" }, { status: 400 });
    }

    // Get current date in Warsaw timezone (YYYY-MM-DD)
    const now = new Date();
    const dTF = new Intl.DateTimeFormat("en-CA", {
      timeZone: "Europe/Warsaw",
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
    });
    const date = dTF.format(now);

    const apiUrl = `https://wl-api.mf.gov.pl/api/search/nip/${normalizedNip}?date=${date}`;
    console.log(`[nip-lookup] Querying MF API: ${apiUrl}`);

    const res = await fetch(apiUrl, {
      headers: {
        "User-Agent": "SuperWizorAI-LocalDev/1.0",
      },
    });

    if (!res.ok) {
      const text = await res.text();
      console.error(`[nip-lookup] MF API error response: ${text}`);
      try {
        const parsed = JSON.parse(text);
        if (parsed.message) {
          return NextResponse.json({ error: parsed.message }, { status: res.status });
        }
      } catch {}
      return NextResponse.json(
        { error: "Błąd podczas łączenia z rejestrem MF" },
        { status: res.status }
      );
    }

    const data = await res.json();
    const subject = data.result?.subject;

    if (!subject) {
      return NextResponse.json(
        { error: "Nie znaleziono podmiotu o podanym numerze NIP w rejestrze MF" },
        { status: 404 }
      );
    }

    const legalName = subject.name || "";
    const rawAddress = subject.workingAddress || subject.residenceAddress || "";
    console.log(`[nip-lookup] Found: ${legalName}, Address: ${rawAddress}`);

    const parsedAddress = parsePolishAddress(rawAddress);

    return NextResponse.json({
      legalName,
      taxId: normalizedNip,
      vatIdEu: `PL${normalizedNip}`, // Autopopulate VAT ID with PL prefix
      ...parsedAddress,
    });
  } catch (err) {
    console.error("[nip-lookup] Error looking up NIP:", err);
    return NextResponse.json(
      { error: "Wystąpił nieoczekiwany błąd podczas pobierania danych" },
      { status: 500 }
    );
  }
}

interface ParsedAddress {
  streetLine: string;
  buildingNumber: string;
  unitNumber: string;
  postalCode: string;
  city: string;
}

function parsePolishAddress(rawAddress: string): ParsedAddress {
  const result: ParsedAddress = {
    streetLine: "",
    buildingNumber: "",
    unitNumber: "",
    postalCode: "",
    city: "",
  };

  if (!rawAddress) return result;

  // Normalize spaces
  const normalized = rawAddress.replace(/\s+/g, " ").trim();

  // Try splitting by comma: "UL. ULICA 12A/4, 00-001 WARSZAWA"
  const commaIndex = normalized.lastIndexOf(",");
  if (commaIndex !== -1) {
    const leftPart = normalized.substring(0, commaIndex).trim();
    const rightPart = normalized.substring(commaIndex + 1).trim();

    // Parse right part: "00-001 WARSZAWA"
    const postalMatch = rightPart.match(/^(\d{2}-\d{3})\s+(.+)$/);
    if (postalMatch) {
      result.postalCode = postalMatch[1];
      result.city = postalMatch[2].trim();
    } else {
      result.city = rightPart;
    }

    let streetAndBuilding = leftPart;

    // Check for " m. " or " lok. " or "m." or "lok." at the end of the left part (unit number)
    const unitMatch = streetAndBuilding.match(/\s+(?:m\.|lok\.|m|lok)\s*([a-zA-Z0-9\-]+)$/i);
    if (unitMatch) {
      result.unitNumber = unitMatch[1];
      streetAndBuilding = streetAndBuilding.substring(0, unitMatch.index).trim();
    }

    // Now look for building number (e.g. "12", "19C", "19C/4", "12/14") at the end
    const buildingMatch = streetAndBuilding.match(/\s+(\d+[a-zA-Z]*(?:\/\d+[a-zA-Z]*)?)$/);
    if (buildingMatch) {
      const bld = buildingMatch[1];
      result.streetLine = streetAndBuilding.substring(0, buildingMatch.index).trim();

      if (bld.includes("/")) {
        const parts = bld.split("/");
        result.buildingNumber = parts[0];
        result.unitNumber = result.unitNumber || parts[1];
      } else {
        result.buildingNumber = bld;
      }
    } else {
      result.streetLine = streetAndBuilding;
    }
  } else {
    // Fallback: If no comma, try matching postal code "dd-ddd" anywhere
    const postalMatch = normalized.match(/(\d{2}-\d{3})/);
    if (postalMatch) {
      result.postalCode = postalMatch[1];
      const idx = normalized.indexOf(result.postalCode);
      const leftPart = normalized.substring(0, idx).trim();
      const rightPart = normalized.substring(idx + 6).trim();
      result.city = rightPart;

      const buildingMatch = leftPart.match(/\s+(\d+[a-zA-Z]*(?:\/\d+[a-zA-Z]*)?)$/);
      if (buildingMatch) {
        const bld = buildingMatch[1];
        result.streetLine = leftPart.substring(0, buildingMatch.index).trim();
        if (bld.includes("/")) {
          const parts = bld.split("/");
          result.buildingNumber = parts[0];
          result.unitNumber = parts[1];
        } else {
          result.buildingNumber = bld;
        }
      } else {
        result.streetLine = leftPart;
      }
    } else {
      result.streetLine = normalized;
    }
  }

  // Remove leading "UL." or "ULICA" if present on streetLine
  result.streetLine = result.streetLine.replace(/^(?:ul\.\s+|ulica\s+)/i, "").trim();

  return result;
}
