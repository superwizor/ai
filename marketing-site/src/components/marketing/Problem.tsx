"use client";

import { useTranslations } from "next-intl";

export function Problem() {
  const t = useTranslations("b.problem");

  return (
    <section className="relative w-full bg-gradient-to-b from-[#004D54] to-[#00383C] text-frost py-24 sm:py-32 border-b border-white/5 overflow-hidden">
      <div className="relative mx-auto w-full max-w-[1080px] px-6">
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-12 items-center">
          <div className="lg:col-span-7">
            <p className="font-mono text-[10px] sm:text-xs uppercase tracking-[3px] text-frost/60 font-semibold mb-5">
              {t("overline")}
            </p>

            <h2 className="font-display text-3xl sm:text-4xl md:text-[2.75rem] font-bold tracking-tight leading-[1.15] text-frost mb-5">
              {t("title")}
            </h2>

            <p className="font-serif text-base sm:text-lg text-mist/75 leading-relaxed max-w-[50ch] mb-10">
              {t("body")}
            </p>

            <blockquote className="border-l-2 border-ember/40 pl-5">
              <p className="font-serif text-base sm:text-lg text-frost/90 italic leading-relaxed">
                &ldquo;{t("quote")}&rdquo;
              </p>
              <footer className="mt-2 font-mono text-[10px] uppercase tracking-wider text-frost/40 font-semibold">
                {t("cite")}
              </footer>
            </blockquote>
          </div>

          <div className="lg:col-span-5 flex justify-center relative">
            <div className="relative w-full max-w-[420px]">
              <div className="relative w-full rounded-[24px] p-[1.5px] overflow-hidden shadow-[0_20px_50px_rgba(0,0,0,0.4)]">
                <div className="absolute inset-[-100%] bg-[conic-gradient(from_0deg,transparent_75%,rgba(252,174,47,0.2)_85%,#FCAE2F_92%,#FAFAFA_97%,white_99%,transparent_100%)] animate-rotate-beam pointer-events-none" />
                <div className="relative w-full rounded-[22.5px] aspect-square overflow-hidden bg-[#002E32]">
                  <img
                    src="/assets/wklej_to_zdjecie_jako_ekran_kwadrat.webp"
                    alt="Session"
                    width={420}
                    height={420}
                    loading="lazy"
                    className="absolute inset-0 w-full h-full object-cover select-none pointer-events-none block"
                  />
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
