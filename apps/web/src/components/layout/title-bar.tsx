import { getCurrentWindow } from "@tauri-apps/api/window"
import { Copy, Minus, Square, X } from "lucide-react"
import { useEffect, useState } from "react"
import { useTranslation } from "react-i18next"
import { BAND_PX, useMacDragRegion, usePlatform } from "./native-chrome"

const DESKTOP_PLATFORMS = new Set(["macos", "windows", "linux"])

function runWindowAction(action: "minimize" | "maximize" | "close"): void {
  const appWindow = getCurrentWindow()
  switch (action) {
    case "minimize":
      void appWindow.minimize()
      break
    case "maximize":
      void appWindow.toggleMaximize()
      break
    case "close":
      void appWindow.close()
      break
  }
}

/**
 * Files native window titlebar for frameless desktop windows (Prestly pattern).
 *
 * macOS uses `titleBarStyle: "Overlay"` + `hiddenTitle`: the window keeps its
 * NATIVE rounded corners, shadow and traffic lights (system-drawn ABOVE the
 * webview) and this component renders NO element — Tauri needs a custom drag
 * region under Overlay (the webview swallows the titlebar mouse events), so
 * `useMacDragRegion` initiates drags over the reserved top band. The band
 * itself is reserved via `.titlebar` on <html> + an empty top strip so it is
 * a real drag surface.
 *
 * Windows/Linux use `decorations: false` with an app-drawn strip hosting the
 * caption buttons; `data-tauri-drag-region` lets Tauri's own script handle
 * dragging and double-click-to-maximize. Rounded corners on Windows come from
 * DWM in Rust.
 *
 * Every variant mounts the `titlebar` class on <html> so CSS reserves the band
 * (globals.css) and pushes the app content below it. Renders nothing in the
 * non-Tauri browser dev server or on mobile.
 */
export function TitleBar() {
  const { t } = useTranslation()
  const platform = usePlatform()
  const [maximized, setMaximized] = useState(false)

  const visible = platform !== null && DESKTOP_PLATFORMS.has(platform)
  const isMac = platform === "macos"
  const hasCaption = platform === "windows" || platform === "linux"

  // Reserve the top band on <html> for the drag/caption strip.
  useEffect(() => {
    if (!visible) return
    document.documentElement.classList.add("titlebar")
    return () => document.documentElement.classList.remove("titlebar")
  }, [visible])

  // Windows/Linux: believable maximize state for the restore glyph.
  useEffect(() => {
    if (!hasCaption) return
    const appWindow = getCurrentWindow()
    let active = true
    let stop: (() => void) | null = null
    const refresh = () => {
      void appWindow.isMaximized().then(value => {
        if (active) setMaximized(value)
      })
    }
    refresh()
    void appWindow
      .onResized(() => refresh())
      .then(unlisten => {
        if (active) stop = unlisten
        else unlisten()
      })
    return () => {
      active = false
      stop?.()
    }
  }, [hasCaption])

  // macOS Overlay: reserved top band = drag surface.
  useMacDragRegion(visible && isMac)

  const barHeight = BAND_PX

  if (!visible || isMac) {
    // macOS: the empty reserved band is the drag surface; traffic lights are
    // system-drawn. No element rendered — CSS reserves the band already.
    return null
  }

  // Windows/Linux: app-drawn caption strip.
  return (
    <header
      data-tauri-drag-region
      className="native-glass fixed inset-x-0 top-0 z-50 flex select-none items-stretch justify-end"
      style={{ height: `${barHeight}px` }}
    >
      <CaptionButton
        label={t("header.minimize")}
        onClick={() => runWindowAction("minimize")}
      >
        <Minus className="size-3.5" />
      </CaptionButton>
      <CaptionButton
        label={maximized ? t("header.restore") : t("header.maximize")}
        onClick={() => runWindowAction("maximize")}
      >
        {maximized ? (
          <Copy className="size-3.5" />
        ) : (
          <Square className="size-3.5" />
        )}
      </CaptionButton>
      <CaptionButton
        label={t("header.close")}
        danger
        onClick={() => runWindowAction("close")}
      >
        <X className="size-3.5" />
      </CaptionButton>
    </header>
  )
}

function CaptionButton({
  label,
  danger,
  onClick,
  children,
}: {
  label: string
  danger?: boolean
  onClick: () => void
  children: React.ReactNode
}) {
  return (
    <button
      type="button"
      data-no-drag
      aria-label={label}
      onClick={onClick}
      className={`flex h-full w-[46px] items-center justify-center text-muted-foreground transition-colors ${
        danger
          ? "hover:bg-red-600 hover:text-white"
          : "hover:bg-muted hover:text-foreground"
      }`}
    >
      {children}
    </button>
  )
}
