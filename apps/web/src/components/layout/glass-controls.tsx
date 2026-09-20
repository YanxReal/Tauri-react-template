import { GlassCardsToggle } from "@/components/layout/glass-cards-toggle"
import { VibrancyToggle } from "@/components/layout/vibrancy-toggle"

/**
 * The two independent glass switches.
 *
 * They used to be a single combined switch (both ON or both OFF). Splitting
 * them lets you mix the combinations the template is meant to demo:
 * native translucency with solid cards, glass cards on an opaque window,
 * or both at once.
 *
 * - `VibrancyToggle` — native OS material (macOS vibrancy / Windows Mica).
 *   Hides itself where the platform has no material.
 * - `GlassCardsToggle` — the reusable `glass-*` components from
 *   `@workspace/ui`. Disabled on Linux (WebKitGTK veto).
 */
export function GlassControls() {
  return (
    <div className="flex flex-wrap items-center gap-x-6 gap-y-2">
      <VibrancyToggle />
      <GlassCardsToggle />
    </div>
  )
}
