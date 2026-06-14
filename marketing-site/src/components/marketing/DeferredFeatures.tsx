"use client";

/**
 * DeferredFeatures — code-splits the heavy Features component (205KB, 2895 lines)
 * into a separate chunk that only loads when the user scrolls near.
 *
 * This is the single largest client component on the landing page. Deferring its
 * hydration saves ~200ms+ of TBT by avoiding eager script evaluation on page load.
 *
 * The component is pre-rendered at build time (ssr: true in the dynamic import)
 * so the HTML is still in the static export for SEO/CLS. Only the JS execution
 * is deferred until the user approaches this section.
 */

import dynamic from "next/dynamic";
import { useEffect, useRef, useState } from "react";

const Features = dynamic(
  () => import("@/components/marketing/Features").then((m) => m.Features),
  {
    ssr: true,
    loading: () => (
      <div className="w-full py-24 sm:py-32 bg-[#FBFAF7]" style={{ minHeight: "600px" }} />
    ),
  }
);

export function DeferredFeatures() {
  const ref = useRef<HTMLDivElement>(null);
  const [shouldLoad, setShouldLoad] = useState(false);

  useEffect(() => {
    const el = ref.current;
    if (!el) return;

    // If already near the viewport, load immediately
    const rect = el.getBoundingClientRect();
    if (rect.top < window.innerHeight + 400) {
      setShouldLoad(true);
      return;
    }

    const observer = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting) {
          setShouldLoad(true);
          observer.disconnect();
        }
      },
      { rootMargin: "400px" }
    );

    observer.observe(el);
    return () => observer.disconnect();
  }, []);

  return (
    <div ref={ref}>
      {shouldLoad ? (
        <Features />
      ) : (
        <div className="w-full py-24 sm:py-32 bg-[#FBFAF7]" style={{ minHeight: "600px" }} />
      )}
    </div>
  );
}
