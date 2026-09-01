import * as React from "react"

const GLASS_CARDS_KEY = "glass-cards"
const GLASS_CARDS_ON = "1"
const GLASS_CARDS_OFF = "0"

type GlassCardsContextValue = {
  enabled: boolean
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
 */
export function GlassCardsProvider({
  children,
}: {
  children: React.ReactNode
}) {
  const [enabled, setEnabledState] = React.useState(false)

  // Boot: restore the persisted preference (default OFF).
  React.useEffect(() => {
    const stored = localStorage.getItem(GLASS_CARDS_KEY)
    if (stored === GLASS_CARDS_ON) setEnabledState(true)
  }, [])

  React.useEffect(() => {
    document.documentElement.classList.toggle("glass-cards", enabled)
  }, [enabled])

  const value = React.useMemo<GlassCardsContextValue>(
    () => ({
      enabled,
      setEnabled: (next: boolean) => {
        setEnabledState(next)
        localStorage.setItem(
          GLASS_CARDS_KEY,
          next ? GLASS_CARDS_ON : GLASS_CARDS_OFF
        )
      },
    }),
    [enabled]
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
