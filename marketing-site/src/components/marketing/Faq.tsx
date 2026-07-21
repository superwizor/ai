"use client";

import { useState } from "react";
import { useTranslations } from "next-intl";

const faqKeys = [
  "afterSession",
  "modalityStyle",
  "sessionThreads",
  "supervisionScope",
  "audioHandling",
  "dataSecurity",
  "clientConsent",
  "pricingTrial",
  "cancellation",
] as const;

export function Faq() {
  const t = useTranslations("b.faq");
  const tItems = useTranslations("b.faq.items");
  const tHero = useTranslations("hero");
  const [openIndex, setOpenIndex] = useState<number | null>(null);

  const toggleFaq = (index: number) => {
    setOpenIndex(openIndex === index ? null : index);
  };

  return (
    <section className="relative w-full bg-[#FBFAF7] text-[#1B2522] py-24 sm:py-32 overflow-hidden border-y border-[#E2DED5]/60">
      <div className="relative mx-auto w-full max-w-[760px] px-6">
        <div className="text-center mb-16">
          <h2 className="font-display text-3xl sm:text-4xl font-bold tracking-tight leading-tight text-[#004D54]">
            {t("title")}
          </h2>
        </div>

        <div className="divide-y divide-[#E2DED5]/60 border-y border-[#E2DED5]/60">
          {faqKeys.map((k, index) => {
            const isOpen = openIndex === index;
            return (
              <div key={k} className="py-2">
                <button
                  type="button"
                  onClick={() => toggleFaq(index)}
                  className="w-full text-left py-5 flex items-center justify-between gap-6 group hover:text-[#004D54] transition-colors focus-visible:outline focus-visible:outline-[#004D54]"
                  aria-expanded={isOpen}
                >
                  <span className="font-serif text-lg sm:text-xl font-medium tracking-tight text-[#1B2522] group-hover:text-[#004D54] transition-colors">
                    {tItems(`${k}.q`)}
                  </span>
                  <span className="relative flex items-center justify-center w-6 h-6 shrink-0 text-[#004D54]">
                    <span
                      className={`absolute w-4 h-0.5 bg-[#004D54] transition-transform duration-300 ${isOpen ? "rotate-180" : ""}`}
                    />
                    <span
                      className={`absolute w-0.5 h-4 bg-[#004D54] transition-transform duration-300 ${isOpen ? "rotate-90 opacity-0" : ""}`}
                    />
                  </span>
                </button>

                <div
                  className={`grid transition-all duration-300 ease-in-out ${
                    isOpen ? "grid-rows-[1fr] opacity-100 pb-6" : "grid-rows-[0fr] opacity-0"
                  }`}
                >
                  <div className="overflow-hidden min-h-0">
                    <p className="font-sans text-sm sm:text-base text-[#4E5A55] leading-relaxed">
                      {tItems(`${k}.a`)}
                    </p>
                  </div>
                </div>
              </div>
            );
          })}
        </div>

        {/* CTA Button */}
        <div className="mt-16 flex flex-col items-center">
          <a
            href="#cennik"
            className="group relative inline-flex items-center justify-center rounded-[12px] bg-[#004D54] text-frost font-sans font-bold uppercase tracking-wider text-xs sm:text-sm px-8 py-4 transition-all duration-300 hover:bg-[#002E32] active:scale-[0.97] whitespace-nowrap overflow-hidden"
          >
            <span className="absolute inset-0 bg-gradient-to-r from-transparent via-white/5 to-transparent translate-x-[-100%] group-hover:translate-x-[100%] transition-transform duration-700" />
            <span className="relative">
              {tHero("ctaPrimary")}
            </span>
          </a>
        </div>

      </div>
    </section>
  );
}
