import { invoke } from "@tauri-apps/api/core"
import { getCurrentWindow } from "@tauri-apps/api/window"
import { useEffect, useState } from "react"

/** Fusioned header height for macOS drag zone (h-[64px]) */
const DRAG_LIMIT_Y = 64

/** Targets that keep their click even inside the drag region (Prestly). */
const INTERACTIVE_SELECTOR =
  "button, a, input, select, textarea, label, [role='button'], [data-no-drag]"

function isTauriRuntime() {
  return "__TAURI_INTERNALS__" in window
}
type Platform = "macos" | "windows" | "linux" | "ios" | "android" | null

/**
 * Detect the runtime OS via the existing `platform_info` Rust command
 * (returns "macos"|"windows"|"linux"|...). Falls back to null (no chrome)
 * in plain browser dev.
 */
function usePlatform(): Platform {
  const [platform, setPlatform] = useState<Platform>(null)

  useEffect(() => {
    if (!isTauriRuntime()) return
    let active = true
    void invoke<string>("platform_info")
      .then(value => {
        if (active) setPlatform(value as Platform)
      })
      .catch(() => {})
    return () => {
      active = false
    }
  }, [])

  return platform
}

/**
 * macOS Overlay titlebars have no system drag surface (the WKWebView covers
 * the whole window), so drags are initiated manually — Prestly pattern:
 * any primary mousedown inside the fusioned header whose target is not
 * interactive starts a window drag; a double click toggles maximize.
 * IMPORTANT: do NOT call `preventDefault()` here on macOS — Tauri's
 * `startDragging` uses `[NSWindow performWindowDragWithEvent: currentEvent]`,
 * which needs the live current mouse event; `preventDefault` cancels the
 * tracking and the window never moves. (Windows/Linux get dragging natively
 * from Tauri's injected `data-tauri-drag-region` script on the header.)
 */
function useMacDragRegion(enabled: boolean): void {
  useEffect(() => {
    if (!enabled || !isTauriRuntime()) return
    const onMouseDown = (event: MouseEvent) => {
      if (event.button !== 0) return
      if (event.clientY > DRAG_LIMIT_Y) return
      const target = event.target instanceof Element ? event.target : null
      if (target?.closest(INTERACTIVE_SELECTOR)) return
      if (event.detail === 2) {
        void getCurrentWindow().toggleMaximize()
        return
      }
      if (event.detail === 1) void getCurrentWindow().startDragging()
    }
    document.addEventListener("mousedown", onMouseDown)
    return () => document.removeEventListener("mousedown", onMouseDown)
  }, [enabled])
}

export { isTauriRuntime, useMacDragRegion, usePlatform }
