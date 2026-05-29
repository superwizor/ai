// Locale-aware request proxy. Renamed from `middleware.ts` per Next.js 16
// convention (functionality is unchanged — Next renamed Middleware to Proxy
// to better reflect intent: a fast pre-request hook for rewrites and
// redirects, NOT a place for slow data fetching or session work).
//
// What runs here: next-intl's locale negotiation. For each incoming URL it
// either:
//   - serves the default locale (pl) at the bare path, or
//   - serves a non-default locale (en) when the path is prefixed (/en/...),
//   - or redirects to add/remove the prefix per the chosen routing mode.
// SEO note (docs/18 §14.4): "as-needed" mode keeps PL URLs unchanged so
// existing inbound links to /pricing don't redirect.

import createMiddleware from "next-intl/middleware";
import { routing } from "./i18n/routing";

export default createMiddleware(routing);

export const config = {
  // Match every route except Next internals, static assets, and any future
  // /api routes that should never participate in locale prefixing.
  matcher: ["/((?!api|_next|_vercel|.*\\..*).*)"],
};
