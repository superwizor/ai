// Animated skeleton rows for the admin tables. Replaces the plain
// "Loading…" text that used to fill the table area during the initial
// fetch. Three goals:
//   1. Maintain page height so the layout doesn't jump when rows arrive.
//   2. Pulse subtly so it's obvious data is on the way.
//   3. Honour reduced-motion preferences (Tailwind's animate-pulse
//      already disables itself under prefers-reduced-motion).
//
// The skeleton renders the same border-and-card chrome the live table
// uses, so when the real data swaps in the visual diff is minimal.

import type { ReactNode } from "react";

export function TableSkeleton({
  columns,
  rows = 6,
}: {
  columns: number;
  rows?: number;
}) {
  return (
    <div className="overflow-x-auto rounded-card border border-frost/10 bg-frost/[0.03]">
      <table className="w-full text-sm" aria-hidden="true">
        <tbody>
          {Array.from({ length: rows }).map((_, r) => (
            <tr key={r} className="border-t border-frost/5 first:border-t-0">
              {Array.from({ length: columns }).map((_, c) => (
                <td key={c} className="px-4 py-4">
                  <SkeletonBar
                    // First column gets a slightly wider bar to suggest a
                    // primary label; trailing columns are narrower to
                    // hint at status / numeric / action data.
                    widthClass={
                      c === 0
                        ? "w-32 sm:w-44"
                        : c === columns - 1
                          ? "w-12"
                          : "w-20 sm:w-28"
                    }
                  />
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

// CardSkeleton renders the same Card chrome OrgDetail uses, so the
// org-detail page also pulses while waiting on AdminGetOrganization.
export function CardSkeleton({ title }: { title?: ReactNode }) {
  return (
    <div className="rounded-card border border-frost/10 bg-frost/[0.04] p-5">
      {title && (
        <h2 className="font-mono text-[10px] uppercase tracking-[var(--tracking-overline)] text-ember mb-3">
          {title}
        </h2>
      )}
      <div className="grid gap-3">
        <SkeletonBar widthClass="w-40" />
        <SkeletonBar widthClass="w-56" />
        <SkeletonBar widthClass="w-32" />
      </div>
    </div>
  );
}

function SkeletonBar({ widthClass }: { widthClass: string }) {
  return (
    <span
      className={`block h-3 rounded-full bg-frost/10 animate-pulse ${widthClass}`}
    />
  );
}
