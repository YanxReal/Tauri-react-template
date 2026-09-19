import type { ReactNode } from "react"

import { GlassCardsProvider } from "@/components/glass-cards-provider"
import { ThemeProvider } from "@/components/theme-provider"
import { VibrancyProvider } from "@/components/vibrancy-provider"

/**
 * Provider stack that wraps `App` — single source of truth.
 *
 * `main.tsx` (webview boot) and `App.test.tsx` (tests) both compose it, so the
 * tree rendered under test always matches the tree that runs in the app. Adding
 * a new provider here updates both paths at once (see `main.tsx:51`).
 */
export function AppProviders({ children }: { children: ReactNode }) {
  return (
    <ThemeProvider>
      <VibrancyProvider>
        <GlassCardsProvider>{children}</GlassCardsProvider>
      </VibrancyProvider>
    </ThemeProvider>
  )
}
