"use client";

import { useState, useEffect } from "react";

export interface Founder {
  id: string;
  name: string;
  role: string;
  description: string;
  bio: string;
  image: string;
  linkedin: string;
  euphire?: string;
}

interface AboutFoundersProps {
  title: string;
  founders: Founder[];
}

export function AboutFounders({ title, founders }: AboutFoundersProps) {
  // Start with server-safe initial state (original order)
  const [shuffled, setShuffled] = useState<Founder[]>(founders);

  useEffect(() => {
    // Egalitarian shuffle on client-side mount to avoid hydration mismatch
    const shuffledTeam = [...founders].sort(() => Math.random() - 0.5);
    setShuffled(shuffledTeam);
  }, [founders]);

  return (
    <section className="w-full bg-[#FAF9F5] text-[#1B2522] border-t border-b border-[#E2DED5] py-20 sm:py-28">
      <div className="mx-auto w-full max-w-[1140px] px-6">
        <div className="text-center mb-16 lg:mb-20">
          <h2 className="font-display text-[#004D54] text-3xl font-bold tracking-tight">
            {title}
          </h2>
          <div className="h-[2px] w-12 bg-ember mx-auto mt-4" />
        </div>

        {/* Alternating Shuffled Founders List */}
        <div className="flex flex-col gap-12 lg:gap-16">
          {shuffled.map((founder, index) => {
            const isEven = index % 2 === 0;
            return (
              <div
                key={founder.id}
                className="grid grid-cols-1 lg:grid-cols-12 gap-12 lg:gap-16 items-center py-12 border-t border-[#E2DED5] first:border-t-0"
              >
                {/* Photo container */}
                <div className={`lg:col-span-5 ${isEven ? "" : "lg:order-2"}`}>
                  <div className="relative aspect-[4/5] w-full overflow-hidden rounded-[24px] border border-[#E2DED5] shadow-md bg-[#ECE9E1]">
                    <img
                      src={founder.image}
                      alt={founder.name}
                      width={500}
                      height={625}
                      loading="lazy"
                      decoding="async"
                      className="object-cover w-full h-full brightness-[0.98] contrast-[1.01]"
                    />
                  </div>
                </div>

                {/* Text container */}
                <div className={`lg:col-span-7 flex flex-col gap-4 ${isEven ? "" : "lg:order-1"}`}>
                  <span className="font-mono text-[9px] uppercase tracking-wider text-[#004D54] font-bold bg-[#EAE7DF] px-3 py-1 rounded-full w-max">
                    {founder.role}
                  </span>
                  <h3 className="font-display text-2xl sm:text-3xl font-bold text-[#004D54]">
                    {founder.name}
                  </h3>
                  <p className="font-sans text-sm sm:text-base text-[#1B2522] font-semibold leading-relaxed">
                    {founder.description}
                  </p>
                  <p className="font-sans text-xs sm:text-sm text-[#1B2522]/75 leading-relaxed">
                    {founder.bio}
                  </p>
                  <div className="flex gap-4 pt-4 border-t border-[#E2DED5] mt-4">
                    <a
                      href={founder.linkedin}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="font-mono text-[10px] uppercase text-[#004D54] hover:text-ember transition font-bold tracking-wider"
                    >
                      LinkedIn
                    </a>
                    {founder.euphire && (
                      <a
                        href={founder.euphire}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="font-mono text-[10px] uppercase text-[#004D54] hover:text-ember transition font-bold tracking-wider"
                      >
                        EUPHIRE
                      </a>
                    )}
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      </div>
    </section>
  );
}
