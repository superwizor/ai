import { useTranslations } from "next-intl";

export function TopBar() {
  const t = useTranslations("topbar");

  return (
    <div className="w-full bg-gradient-to-r from-[#000B0D] via-[#001418] to-[#000B0D] border-b border-white/[0.09] text-frost select-none hidden sm:block">
      <div className="mx-auto max-w-[1080px] px-6 py-1.5 flex flex-wrap items-center justify-center gap-x-7 gap-y-2 text-[11px] sm:text-[11.5px] tracking-[0.5px] font-medium text-center">
        {/* RODO / GDPR */}
        <span className="inline-flex items-center gap-2">
          <svg className="w-3.5 h-3.5 text-ember shrink-0" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <circle cx="12" cy="8" r="7" />
            <polyline points="8.21 13.89 7 23 12 20 17 23 15.79 13.88" />
          </svg>
          <span className="text-frost/90">{t("rodo")}</span>
        </span>

        <span className="hidden sm:block w-px h-3 bg-white/[0.12]" />

        {/* Encryption (AES-256 + UE) */}
        <span className="inline-flex items-center gap-2">
          <svg className="w-3.5 h-3.5 text-ember shrink-0" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <rect x="3" y="11" width="18" height="11" rx="2" ry="2" />
            <path d="M7 11V7a5 5 0 0 1 10 0v4" />
          </svg>
          <span className="text-frost/90">{t("encryption")}</span>
        </span>

        <span className="hidden sm:block w-px h-3 bg-white/[0.12]" />

        {/* Audio deleted */}
        <span className="inline-flex items-center gap-2">
          <svg className="w-3.5 h-3.5 text-ember shrink-0" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <polyline points="3 6 5 6 21 6" />
            <path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2" />
          </svg>
          <span className="text-frost/90">{t("audio")}</span>
        </span>

        <span className="hidden sm:block w-px h-3 bg-white/[0.12]" />

        {/* Confidentiality */}
        <span className="inline-flex items-center gap-2">
          <svg className="w-3.5 h-3.5 text-ember shrink-0" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" />
          </svg>
          <span className="text-frost/90">{t("confidentiality")}</span>
        </span>
      </div>
    </div>
  );
}
