"use client";

import { useTranslations, useLocale } from "next-intl";

export function Security() {
  const t = useTranslations("b.security");
  const locale = useLocale();
  const tHero = useTranslations("hero");

  const steps = locale === "en"
    ? [
        { icon: "mic", label: "Recording", sub: "on your device" },
        { icon: "wave", label: "Transcription", sub: "encrypted in transit" },
        { icon: "trash", label: "Audio deleted", sub: "immediately" },
        { icon: "lock", label: "Report", sub: "encrypted at rest" },
      ]
    : [
        { icon: "mic", label: "Nagranie", sub: "na Twoim urządzeniu" },
        { icon: "wave", label: "Transkrypcja", sub: "szyfrowana w transmisji" },
        { icon: "trash", label: "Audio usunięte", sub: "natychmiast" },
        { icon: "lock", label: "Raport", sub: "zaszyfrowany na serwerze" },
      ];

  const badges = locale === "en"
    ? [
        { label: "EU servers", detail: "Frankfurt / Warsaw" },
        { label: "No AI training", detail: "on your data" },
        { label: "Envelope encryption", detail: "Google KMS" },
        { label: "GDPR ready", detail: "DPA included" },
      ]
    : [
        { label: "Serwery w UE", detail: "Frankfurt / Warszawa" },
        { label: "Brak trenowania AI", detail: "na Twoich danych" },
        { label: "Szyfrowanie kopertowe", detail: "Google KMS" },
        { label: "Zgodność z RODO", detail: "DPA w zestawie" },
      ];

  return (
    <section id="bezpieczenstwo" aria-label="Security" className="relative w-full bg-gradient-to-b from-[#002E32] to-[#001A1D] text-frost py-24 sm:py-28 border-y border-white/[0.04] overflow-hidden">
      <div className="absolute inset-0 bg-[radial-gradient(ellipse_80%_50%_at_50%_0%,rgba(0,77,84,0.15),transparent)] pointer-events-none" />

      <div className="relative mx-auto w-full max-w-[1120px] px-6">
        <div className="flex flex-col lg:flex-row gap-10 lg:gap-14 items-stretch">
          {/* LEFT — Security content */}
          <div className="flex-1">
            {/* Heading */}
            <div className="text-center lg:text-left mb-16">
              <div className="inline-flex items-center justify-center w-12 h-12 rounded-full bg-white/[0.04] border border-white/[0.06] mb-5">
                <svg className="w-5 h-5 text-frost/50" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
                  <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" />
                </svg>
              </div>
              <h2 className="font-display text-frost text-2xl sm:text-3xl lg:text-4xl font-bold tracking-tight leading-tight max-w-2xl">
                {t("title")}
              </h2>
            </div>

            {/* Data journey — horizontal pipeline */}
            <div className="relative max-w-[700px] mb-16">
              {/* Connecting line segments */}
              <div className="hidden sm:block absolute top-7 left-[12%] right-[12%] h-px pointer-events-none">
                <div className="absolute left-[calc(12.5%+28px)] right-[calc(62.5%+28px)] top-0 h-px bg-gradient-to-r from-frost/10 to-frost/15" />
                <div className="absolute left-[calc(37.5%+28px)] right-[calc(37.5%+28px)] top-0 h-px bg-gradient-to-r from-frost/15 to-ember/25" />
                <div className="absolute left-[calc(62.5%+28px)] right-[calc(12.5%+28px)] top-0 h-px bg-gradient-to-r from-ember/25 to-frost/10" />
              </div>

              <div className="grid grid-cols-2 sm:grid-cols-4 gap-6 sm:gap-0">
                {steps.map((step, i) => (
                  <div key={i} className="flex flex-col items-center text-center relative">
                    <div className={`relative z-10 w-14 h-14 rounded-full flex items-center justify-center mb-3 ${
                      i === 2
                        ? "bg-[#1a1208] border border-ember/30 shadow-[0_0_20px_rgba(252,174,47,0.15)]"
                        : "bg-[#001A1D] border border-white/[0.08]"
                    }`}>
                      <StepIcon name={step.icon} isHighlight={i === 2} />
                    </div>
                    <span className={`font-sans text-sm font-semibold tracking-tight ${
                      i === 2 ? "text-ember" : "text-frost/80"
                    }`}>
                      {step.label}
                    </span>
                    <span className="font-sans text-[11px] text-frost/30 mt-0.5">
                      {step.sub}
                    </span>
                  </div>
                ))}
              </div>
            </div>

            {/* Trust badges */}
            <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 max-w-[700px]">
              {badges.map((badge, i) => (
                <div
                  key={i}
                  className="rounded-[14px] bg-white/[0.03] border border-white/[0.05] px-4 py-4 text-center hover:bg-white/[0.05] hover:border-white/[0.08] transition-all duration-300"
                >
                  <span className="font-sans text-sm text-frost/80 font-semibold block">
                    {badge.label}
                  </span>
                  <span className="font-sans text-[11px] text-frost/30 mt-0.5 block">
                    {badge.detail}
                  </span>
                </div>
              ))}
            </div>
          </div>

          {/* RIGHT — Cozy image (mirrors BAudience left image) */}
          <div className="w-full lg:w-[35%] shrink-0 hidden lg:block">
            <div className="relative rounded-[24px] overflow-hidden h-full min-h-[400px]">
              <img
                src="/assets/therapy-cozy.webp"
                alt=""
                className="absolute inset-0 w-full h-full object-cover"
                loading="lazy"
              />
              <div className="absolute inset-0 bg-[#0A1612]/[0.25] mix-blend-multiply rounded-[24px]" />
            </div>
          </div>
        </div>

        {/* CTA Button */}
        <div className="mt-16 flex flex-col items-center">
          <a
            href="#cennik"
            className="group relative inline-flex items-center justify-center rounded-[12px] bg-frost text-[#004D54] font-sans font-bold uppercase tracking-wider text-xs sm:text-sm px-8 py-4 transition-all duration-300 hover:bg-white active:scale-[0.97] whitespace-nowrap overflow-hidden"
          >
            <span className="absolute inset-0 bg-gradient-to-r from-transparent via-[#004D54]/5 to-transparent translate-x-[-100%] group-hover:translate-x-[100%] transition-transform duration-700" />
            <span className="relative">
              {tHero("ctaPrimary")}
            </span>
          </a>
        </div>

      </div>
    </section>
  );
}

function StepIcon({ name, isHighlight }: { name: string; isHighlight: boolean }) {
  const color = isHighlight ? "text-ember" : "text-frost/40";
  const cls = `w-5 h-5 ${color}`;

  switch (name) {
    case "mic":
      return (
        <svg className={cls} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round">
          <path d="M12 1a3 3 0 00-3 3v8a3 3 0 006 0V4a3 3 0 00-3-3z" />
          <path d="M19 10v2a7 7 0 01-14 0v-2M12 19v4M8 23h8" />
        </svg>
      );
    case "wave":
      return (
        <svg className={cls} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round">
          <path d="M2 12h2l3-9 4 18 4-18 3 9h2" strokeLinejoin="round" />
        </svg>
      );
    case "trash":
      return (
        <svg className={cls} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
          <path d="M3 6h18M8 6V4a2 2 0 012-2h4a2 2 0 012 2v2" />
          <path d="M19 6l-1 14a2 2 0 01-2 2H8a2 2 0 01-2-2L5 6" />
          <path d="M10 11v6M14 11v6" />
        </svg>
      );
    case "lock":
      return (
        <svg className={cls} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
          <rect x="3" y="11" width="18" height="11" rx="2" ry="2" />
          <path d="M7 11V7a5 5 0 0110 0v4" />
        </svg>
      );
    default:
      return null;
  }
}
