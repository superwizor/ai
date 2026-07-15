// src/components/admin/analytics/ChartCard.tsx
"use client";

import React, { useState } from "react";

interface ChartCardProps {
  title: string;
  description?: string;
  /** Plain-language explanation shown on ⓘ hover */
  info?: string;
  children: React.ReactNode;
  /** Shown when chart has no data */
  emptyLabel?: string;
  isEmpty?: boolean;
  action?: React.ReactNode;
}

export function ChartCard({ title, description, info, children, emptyLabel, isEmpty, action }: ChartCardProps) {
  const [showInfo, setShowInfo] = useState(false);

  return (
    <div className="rounded-card border border-frost/10 bg-surfaceTeal/20 backdrop-blur-md p-6 flex flex-col justify-between hover:border-frost/20 transition shadow-lg h-[400px]">
      <div className="mb-4">
        <div className="flex items-start gap-2">
          <h3 className="font-display text-frost text-base font-semibold tracking-wide flex-1">
            {title}
          </h3>
          {action && <div className="flex-shrink-0 mr-1">{action}</div>}
          {info && (
            <div className="relative flex-shrink-0">
              <button
                type="button"
                aria-label="Informacja o wykresie"
                onClick={() => setShowInfo((v) => !v)}
                onMouseEnter={() => setShowInfo(true)}
                onMouseLeave={() => setShowInfo(false)}
                className="w-5 h-5 rounded-full border border-frost/30 text-mist hover:text-frost hover:border-ember/60 transition flex items-center justify-center text-[11px] font-bold cursor-help"
              >
                i
              </button>
              {showInfo && (
                <div className="absolute right-0 top-7 z-50 w-72 p-3 rounded-lg bg-obsidian/95 border border-frost/20 shadow-xl backdrop-blur-lg animate-in fade-in-0 slide-in-from-top-2 duration-200">
                  <p className="font-serif text-xs text-frost/90 leading-relaxed">
                    {info}
                  </p>
                </div>
              )}
            </div>
          )}
        </div>
        {description && (
          <p className="font-serif text-xs text-mist/70 mt-1">
            {description}
          </p>
        )}
      </div>
      <div className="flex-1 min-h-0 relative w-full">
        {isEmpty ? (
          <div className="absolute inset-0 flex items-center justify-center">
            <div className="text-center">
              <div className="w-12 h-12 mx-auto mb-3 rounded-full bg-frost/5 flex items-center justify-center">
                <svg className="w-6 h-6 text-mist/40" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" d="M3 13.125C3 12.504 3.504 12 4.125 12h2.25c.621 0 1.125.504 1.125 1.125v6.75C7.5 20.496 6.996 21 6.375 21h-2.25A1.125 1.125 0 013 19.875v-6.75zM9.75 8.625c0-.621.504-1.125 1.125-1.125h2.25c.621 0 1.125.504 1.125 1.125v11.25c0 .621-.504 1.125-1.125 1.125h-2.25a1.125 1.125 0 01-1.125-1.125V8.625zM16.5 4.125c0-.621.504-1.125 1.125-1.125h2.25C20.496 3 21 3.504 21 4.125v15.75c0 .621-.504 1.125-1.125 1.125h-2.25a1.125 1.125 0 01-1.125-1.125V4.125z" />
                </svg>
              </div>
              <p className="font-serif text-sm text-mist/60">{emptyLabel || "Brak danych do wyświetlenia"}</p>
              <p className="font-mono text-[10px] text-mist/30 mt-1 uppercase">Dane pojawią się po pierwszych sesjach</p>
            </div>
          </div>
        ) : (
          children
        )}
      </div>
    </div>
  );
}
