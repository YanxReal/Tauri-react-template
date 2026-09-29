import * as React from "react"

import { isTauriRuntime, usePlatform } from "@/components/layout/native-chrome"

const GLASS_CARDS_KEY = "glass-cards"
const GLASS_CARDS_ON = "1"
const GLASS_CARDS_OFF = "0"

type GlassCardsContextValue = {
  enabled: boolean
  /** `false` on platforms where the glass look is vetoed (Linux/WebKitGTK). */
  supported: boolean
  setEnabled: (enabled: boolean) => void
}

const GlassCardsContext = React.createContext<
  GlassCardsContextValue | undefined
>(undefined)

/**
 * Global "glass" demo switch for the template.
 *
 * Purpose is purely demonstrative: it lets you toggle the whole sample app
 * between its two visual directions — the standard solid components and the
 * reusable `glass-*` components from `@workspace/ui`. It's frontend-only (no
 * Rust invoke), so it works identically in the Tauri shell and in the
 * browser dev server. The preference is persisted in localStorage and
 * defaults to OFF (i.e. the standard, non-glass look).
 *
 * It is INDEPENDENT from the native window material (`VibrancyProvider`):
 * you can run native vibrancy with solid cards, or glass cards on a plain
 * window. Each has its own switch (`GlassControls`).
 *
 * Linux (WebKitGTK) vetoes the glass look: `backdrop-blur` + DMABUF causes
 * yellow glitches and runaway RAM, so `supported` is `false` there and the
 * effective `enabled` collapses to `false` (the switch renders disabled).
 */
export function GlassCardsProvider({
  children,
}: {
  children: React.ReactNode
}) {
  const [enabled, setEnabledState] = React.useState(false)
  const platform = usePlatform()
  const supported = platform !== "linux"
  // In the Tauri shell the platform arrives one IPC round-trip later; applying
  // the glass class before it resolves flashed blur on Linux (the WebKitGTK
  // veto exists precisely to avoid that). In the browser (no IPC) there is
  // nothing to wait for.
  const platformKnown = platform !== null || !isTauriRuntime()
  const effectiveEnabled = enabled && supported && platformKnown

  // Boot: restore the persisted preference (default OFF).
  React.useEffect(() => {
    const stored = localStorage.getItem(GLASS_CARDS_KEY)
    if (stored === GLASS_CARDS_ON) setEnabledState(true)
  }, [])

  React.useEffect(() => {
    document.documentElement.classList.toggle("glass-cards", effectiveEnabled)
  }, [effectiveEnabled])

  const value = React.useMemo<GlassCardsContextValue>(
    () => ({
      enabled: effectiveEnabled,
      supported,
      setEnabled: (next: boolean) => {
        setEnabledState(next)
        localStorage.setItem(
          GLASS_CARDS_KEY,
          next ? GLASS_CARDS_ON : GLASS_CARDS_OFF
        )
      },
    }),
    [effectiveEnabled, supported]
  )

  return (
    <GlassCardsContext.Provider value={value}>
      {children}
    </GlassCardsContext.Provider>
  )
}

export function useGlassCards() {
  const ctx = React.useContext(GlassCardsContext)
  if (ctx === undefined) {
    throw new Error("useGlassCards must be used within a GlassCardsProvider")
  }
  return ctx
}
