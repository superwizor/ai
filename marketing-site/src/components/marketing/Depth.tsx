import { useTranslations } from "next-intl";

export function Depth() {
  const t = useTranslations("depth");

  return (
    <section className="relative w-full bg-gradient-to-b from-[#004D54] to-[#002E32] text-frost py-24 sm:py-32 overflow-hidden border-y border-frost/5">
      {/* Subtle background glow */}
      <div className="absolute top-1/2 left-2/3 -translate-x-1/2 -translate-y-1/2 w-[350px] h-[350px] bg-[radial-gradient(circle,rgba(252,174,47,0.05),transparent_70%)] rounded-full pointer-events-none" />

      <div className="relative mx-auto w-full max-w-[1080px] px-6">
        <div className="grid grid-cols-1 lg:grid-cols-12 gap-12 items-center">
          {/* Left Column: Text & Quote */}
          <div className="lg:col-span-7">
            <div className="inline-flex items-center gap-2 mb-6">
              <span className="w-1.5 h-1.5 rounded-full bg-ember animate-pulse"></span>
              <span className="font-mono text-[10px] sm:text-xs uppercase text-ember tracking-[var(--tracking-overline)]">
                {t("overline")}
              </span>
            </div>

            <h2 className="font-display text-3xl sm:text-4xl md:text-5xl font-semibold tracking-[var(--tracking-display)] leading-tight text-frost mb-6">
              {t("title")}
            </h2>

            <p className="font-sans text-base sm:text-lg text-mist/95 leading-relaxed max-w-[65ch] mb-8">
              {t("body")}
            </p>

            <div className="border-l-2 border-ember/40 pl-6 sm:pl-8 max-w-2xl mt-8">
              <p className="font-serif text-lg sm:text-xl md:text-2xl text-frost italic leading-relaxed">
                &ldquo;{t("quote")}&rdquo;
              </p>
              <cite className="block mt-4 not-italic font-mono text-[11px] sm:text-xs uppercase tracking-wider text-ember">
                {t("cite")}
              </cite>
            </div>
          </div>

          {/* Right Column: Depth Reflection Image */}
          <div className="lg:col-span-5 flex justify-center relative">
            <div className="relative w-full max-w-[450px] transition-transform duration-500 hover:scale-[1.01] z-10">
              {/* Outer Border Beam Wrapper */}
              <div className="relative w-full rounded-[24px] p-[1.5px] overflow-hidden bg-white/[0.08] shadow-[0_20px_50px_rgba(0,0,0,0.5)]">
                {/* The Border-Gliding Conic Gradient */}
                <div className="absolute inset-[-100%] bg-[conic-gradient(from_0deg,transparent_75%,rgba(103,89,255,0.3)_85%,#FCAE2F_92%,#FAFAFA_97%,white_99%,transparent_100%)] animate-rotate-beam pointer-events-none" />
                
                {/* Inner Content Card (Aspect [4/3]) */}
                <div className="relative w-full aspect-[4/3] rounded-[22.5px] overflow-hidden bg-[#002E32]">
                  <img
                    src="/assets/depth_reflection.webp"
                    alt="Depth reflection details"
                    className="absolute inset-0 w-full h-full object-cover object-center select-none pointer-events-none block"
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
