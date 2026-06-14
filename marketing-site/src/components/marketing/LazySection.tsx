"use client";

import { useEffect, useRef, useState, type ReactNode } from "react";

/**
 * LazySection — defers hydration of heavy below-fold components.
 *
 * Renders `fallback` (a lightweight placeholder) until the component
 * enters the viewport, at which point it swaps in `children` (the
 * real component). This prevents heavy client components like
 * Features.tsx (205KB) from blocking the main thread on initial load.
 *
 * For static export (`output: "export"`), the server-rendered HTML is
 * baked into the page at build time. This wrapper only controls when
 * the client JS chunk actually *executes* (hydrates), which is
 * where the TBT savings come from.
 */
export function LazySection({
  children,
  fallback,
  rootMargin = "200px",
  minHeight = "400px",
}: {
  children: ReactNode;
  fallback?: ReactNode;
  /** How far before the viewport to trigger loading. */
  rootMargin?: string;
  /** Minimum height of the placeholder to prevent layout shift. */
  minHeight?: string;
}) {
  const ref = useRef<HTMLDivElement>(null);
  const [isVisible, setIsVisible] = useState(false);

  useEffect(() => {
    const el = ref.current;
    if (!el) return;

    // If already in viewport (e.g. user scrolled fast or small page),
    // show immediately.
    const rect = el.getBoundingClientRect();
    if (rect.top < window.innerHeight + 200) {
      setIsVisible(true);
      return;
    }

    const observer = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting) {
          setIsVisible(true);
          observer.disconnect();
        }
      },
      { rootMargin }
    );

    observer.observe(el);
    return () => observer.disconnect();
  }, [rootMargin]);

  if (isVisible) {
    return <>{children}</>;
  }

  return (
    <div ref={ref} style={{ minHeight }}>
      {fallback}
    </div>
  );
}
