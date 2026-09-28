import { invoke } from "@tauri-apps/api/core"
import * as React from "react"

const VIBRANCY_KEY = "vibrancy"
const VIBRANCY_ON = "1"
const VIBRANCY_OFF = "0"

type VibrancyContextValue = {
  enabled: boolean
  supported: boolean
  setEnabled: (enabled: boolean) => void
}

const VibrancyContext = React.createContext<VibrancyContextValue | undefined>(
  undefined
)

function isTauriRuntime() {
  return "__TAURI_INTERNALS__" in window
}

function resolvedDark(): boolean {
  return document.documentElement.classList.contains("dark")
}

/**
 * Tells Rust to apply or clear the native window "cristal" material
 * (vibrancy on macOS / Mica on Windows 11) via
 * `window_effects_set { enabled, dark? }`. Answers false on unsupported
 * platforms (Linux, mobile, browser dev) so the toggle hides.
 */
async function applyWindowEffect(
  enabled: boolean,
  dark: boolean
): Promise<boolean> {
  if (!isTauriRuntime()) return false
  try {
    await invoke<boolean | null>("window_effects_set", { enabled, dark })
    return true
  } catch {
    return false
  }
}

/**
 * Native window translucency ("efecto cristal"). Mirror of the theme
 * hydration pattern: the stored preference arrives from localStorage and is
 * applied on top of the default (ON where supported). When enabled, the
 * webview stops painting a background (`html.vibrancy` in globals.css) so
 * the OS material shows through; the actual effect comes from the Rust
 * `window_effects_set` command. `dark` is the RESUMED theme (resolved on
 * <html>), so the crystal material follows the app theme — even when the
 * user picks "system".
 */
export function VibrancyProvider({ children }: { children: React.ReactNode }) {
  const [enabled, setEnabledState] = React.useState(false)
  const [supported, setSupported] = React.useState(false)
  const [dark, setDark] = React.useState(false)

  // Boot: restore the persisted preference and probe platform support.
  // Default OFF — user must explicitly enable. Probe with wanted (false by
  // default) still returns ok=true on supported platforms (clear is a no-op
  // that succeeds), so we can detect support without applying the effect.
  React.useEffect(() => {
    let cancelled = false
    void (async () => {
      const stored = localStorage.getItem(VIBRANCY_KEY)
      const wanted = stored === VIBRANCY_ON
      const ok = await applyWindowEffect(wanted, resolvedDark())
      if (cancelled) return
      if (ok) {
        setSupported(true)
        setEnabledState(wanted)
      }
    })()
    return () => {
      cancelled = true
    }
  }, [])

  // Track the RESOLVED theme on <html> (ThemeProvider toggles `.dark` there,
  // including when the user picks "system") so the crystal material can
  // follow the app theme.
  React.useEffect(() => {
    const update = () => setDark(resolvedDark())
    update()
    const observer = new MutationObserver(update)
    observer.observe(document.documentElement, {
      attributes: true,
      attributeFilter: ["class"],
    })
    return () => observer.disconnect()
  }, [])

  // Re-apply whenever the toggle or the theme changes (Mica's dark tint
  // follows the theme; macOS material adapts on its own).
  React.useEffect(() => {
    if (!supported) return
    void applyWindowEffect(enabled, dark)
  }, [enabled, dark, supported])

  // The webview background must be transparent for the native material to
  // show through (global.css `html.vibrancy`).
  React.useEffect(() => {
    document.documentElement.classList.toggle("vibrancy", enabled && supported)
  }, [enabled, supported])

  const value = React.useMemo<VibrancyContextValue>(
    () => ({
      enabled,
      supported,
      setEnabled: (next: boolean) => {
        setEnabledState(next)
        localStorage.setItem(VIBRANCY_KEY, next ? VIBRANCY_ON : VIBRANCY_OFF)
      },
    }),
    [enabled, supported]
  )

  return (
    <VibrancyContext.Provider value={value}>
      {children}
    </VibrancyContext.Provider>
  )
}

export function useVibrancy() {
  const ctx = React.useContext(VibrancyContext)
  if (ctx === undefined) {
    throw new Error("useVibrancy must be used within a VibrancyProvider")
  }
  return ctx
}
