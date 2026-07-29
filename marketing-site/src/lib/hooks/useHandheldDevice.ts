// src/lib/hooks/useHandheldDevice.ts
"use client";

import { useEffect, useState } from "react";

/**
 * True when the page is running on a phone or a tablet.
 *
 * Deliberately device-shaped, not viewport-shaped: a narrow desktop
 * window is still a desktop, while a full-screen iPad is still a
 * tablet. Callers use this to steer handheld users to the native
 * iOS/Android app instead of the Flutter web build.
 *
 * Signals, in order:
 *   1. `navigator.userAgentData.mobile` — the modern client hint.
 *      Chromium-only, and it reports `false` on tablets, so it can
 *      confirm a phone but never rule a tablet out.
 *   2. User-agent match for the phone/tablet families (plain "Android"
 *      covers Android tablets, which omit the "Mobile" token).
 *   3. iPadOS 13+ serves a desktop-class Safari UA that says
 *      "Macintosh"; multi-touch support gives it away.
 *
 * Returns `false` during prerender and on the first client render —
 * the site is a static export (next.config.ts: `output: "export"`), so
 * there are no request headers to read at build time. Anything that
 * must not flash on handhelds should ALSO carry the
 * `[@media(pointer:coarse)]:hidden` utility, which applies before
 * hydration.
 */
export function useHandheldDevice(): boolean {
  const [isHandheld, setIsHandheld] = useState(false);

  useEffect(() => {
    setIsHandheld(detectHandheld());
  }, []);

  return isHandheld;
}

function detectHandheld(): boolean {
  if (typeof navigator === "undefined") return false;

  const uaData = (
    navigator as Navigator & { userAgentData?: { mobile?: boolean } }
  ).userAgentData;
  if (uaData?.mobile === true) return true;

  const ua = navigator.userAgent;

  // Phones (and Android tablets, which also carry the "Android" token).
  if (/Android|iPhone|iPod|Windows Phone|IEMobile|BlackBerry|webOS|Opera Mini/i.test(ua)) {
    return true;
  }

  // Tablets that announce themselves.
  if (/iPad|Tablet|PlayBook|Silk|Kindle|Nexus (7|9|10)|SM-T/i.test(ua)) {
    return true;
  }

  // iPadOS 13+ in its default "desktop site" mode.
  if (/Macintosh/.test(ua) && navigator.maxTouchPoints > 1) return true;

  return false;
}
