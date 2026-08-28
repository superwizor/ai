// src/lib/hooks/useNbpRate.ts
"use client";

import { useState, useEffect } from "react";

interface NbpRate {
  /** PLN per 1 USD */
  rate: number;
  /** Date of the rate, e.g. "2026-06-06". Empty when `isFallback`. */
  effectiveDate: string;
  /** Whether we're still loading */
  loading: boolean;
  /**
   * True when the NBP API did not answer and `rate` is the hard-coded
   * fallback. The UI must NOT present such a number as an NBP rate —
   * a stale constant labelled "kurs NBP" is a wrong number, not a
   * degraded one.
   */
  isFallback: boolean;
}

/** Used only when the NBP API is unreachable. Never labelled as an NBP rate. */
const FALLBACK_RATE = 4.05;

/**
 * Fetches the current USD → PLN exchange rate from the
 * National Bank of Poland (NBP) Table A API.
 * Free, no auth, no CORS issues from browser.
 * Falls back to a reasonable estimate if the API is down.
 */
export function useNbpRate(): NbpRate {
  const [rate, setRate] = useState<number>(FALLBACK_RATE);
  const [effectiveDate, setEffectiveDate] = useState<string>("");
  const [loading, setLoading] = useState(true);
  const [isFallback, setIsFallback] = useState(true);

  useEffect(() => {
    let cancelled = false;

    async function fetchRate() {
      try {
        const res = await fetch(
          "https://api.nbp.pl/api/exchangerates/rates/a/usd/?format=json",
          { next: { revalidate: 3600 } } // cache for 1h in Next.js
        );
        if (!res.ok) throw new Error(`NBP API ${res.status}`);
        const data = await res.json();
        if (!cancelled && data.rates?.[0]) {
          setRate(data.rates[0].mid);
          setEffectiveDate(data.rates[0].effectiveDate);
          setIsFallback(false);
        }
      } catch (err) {
        console.warn("NBP rate fetch failed, using fallback:", err);
        // Keep the fallback rate
      } finally {
        if (!cancelled) setLoading(false);
      }
    }

    void fetchRate();
    return () => { cancelled = true; };
  }, []);

  return { rate, effectiveDate, loading, isFallback };
}
