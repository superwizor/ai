"use client";

import { useEffect } from "react";

/**
 * ScrollEffects — Drop-in client component that adds:
 *  1. Fade-in-up on scroll for every <section> inside <main>
 *  2. Organic smooth-scroll for all anchor (#) links — fast start,
 *     decelerating finish (ease-out-cubic), like a physical throw.
 *
 * Renders nothing visible — just wires up observers + listeners.
 */
export function ScrollEffects() {
  useEffect(() => {
    /* ─── 1. Section fade-in via IntersectionObserver ─────────── */
    // Only apply the b-reveal (opacity: 0) class to sections that
    // start BELOW the viewport. Above-fold sections render instantly
    // — no hide→reveal layout thrash. This eliminates ~400ms of
    // unnecessary Style & Layout work on the main thread.
    const sections = document.querySelectorAll("main > section, main > div > section");
    const mainEl = document.querySelector("main");
    const allChildren = mainEl
      ? Array.from(mainEl.children).filter(
          (el) => el.tagName !== "SCRIPT" && el.tagName !== "STYLE"
        )
      : [];

    const targets = new Set<Element>([...sections, ...allChildren]);
    const vh = window.innerHeight;

    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            entry.target.classList.add("b-revealed");
            observer.unobserve(entry.target);
          }
        });
      },
      { threshold: 0.08, rootMargin: "0px 0px -40px 0px" }
    );

    targets.forEach((el) => {
      const rect = el.getBoundingClientRect();
      // If the element starts above or within the viewport, let it
      // paint immediately — no animation, no layout thrash.
      if (rect.top < vh) return;
      el.classList.add("b-reveal");
      observer.observe(el);
    });

    /* ─── 2. Organic smooth-scroll for anchor links ──────────── */
    function handleAnchorClick(e: Event) {
      const anchor = (e.target as HTMLElement).closest("a[href*='#']");
      if (!anchor) return;

      const href = anchor.getAttribute("href");
      if (!href) return;

      // Extract the hash part
      const hashIndex = href.indexOf("#");
      if (hashIndex === -1) return;
      const hash = href.slice(hashIndex);
      if (!hash || hash === "#") return;

      // Only intercept same-page anchors
      const hrefPath = href.slice(0, hashIndex) || "/";
      const currentPath = window.location.pathname;
      // Allow if href has no path, or path matches current page
      const samePage =
        hrefPath === "/" ||
        hrefPath === "" ||
        currentPath.endsWith(hrefPath) ||
        (hrefPath.endsWith("/b") && currentPath.includes("/b"));

      if (!samePage) return;

      const target = document.querySelector(hash);
      if (!target) return;

      e.preventDefault();

      const start = window.scrollY;
      const targetRect = target.getBoundingClientRect();
      const navHeight = 72; // approximate sticky nav height
      const end = start + targetRect.top - navHeight;

      // Native smooth scroll starts instantly and is GPU-accelerated
      window.scrollTo({
        top: end,
        behavior: "smooth"
      });

      // Update URL hash without jumping
      history.pushState(null, "", hash);
    }

    document.addEventListener("click", handleAnchorClick);

    return () => {
      observer.disconnect();
      document.removeEventListener("click", handleAnchorClick);
    };
  }, []);

  return null;
}
