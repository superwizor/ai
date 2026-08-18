// src/components/admin/analytics/TabNav.tsx
"use client";

import React from "react";
import { useTranslations } from "next-intl";

export type TabKey = "overview" | "usage" | "clientloop" | "costs" | "quality" | "funnel" | "ops" | "feedback";

interface TabNavProps {
  activeTab: TabKey;
  onChange: (tab: TabKey) => void;
}

// "usage" i "clientloop" tuż po przeglądzie: odpowiadają na pytanie
// "jak ludzie korzystają", które reszta zakładek pomijała.
const TAB_KEYS: TabKey[] = ["overview", "usage", "clientloop", "costs", "quality", "funnel", "ops", "feedback"];

export function TabNav({ activeTab, onChange }: TabNavProps) {
  const t = useTranslations("admin.analytics.tabs");

  return (
    <nav className="flex border-b border-frost/10 mb-6 overflow-x-auto gap-2 scrollbar-none">
      {TAB_KEYS.map((key) => {
        const isActive = activeTab === key;
        return (
          <button
            key={key}
            onClick={() => onChange(key)}
            className={`font-display text-sm pb-3 px-4 transition border-b-2 -mb-[2px] whitespace-nowrap cursor-pointer ${
              isActive
                ? "border-ember text-frost font-semibold"
                : "border-transparent text-mist hover:text-frost"
            }`}
          >
            {t(key)}
          </button>
        );
      })}
    </nav>
  );
}
