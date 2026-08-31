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
 * App-drawn titlebar for frameless desktop windows — Prestly pattern.
 *
 * macOS uses `titleBarStyle: "Overlay"` + `hiddenTitle` (native corners,
 * shadow, traffic lights ABOVE the webview) and renders NO element; the
 * webview swallows titlebar mouse events, so `useMacDragRegion` replicates
 * Tauri's injected drag script over the CSS-reserved top band.
 *
 * Windows/Linux use `decorations: false` with an app-drawn strip hosting
 * the caption buttons; `data-tauri-drag-region` lets Tauri's own script
 * handle dragging + double-click-to-maximize. Windows rounded corners come
 * from DWM in Rust.
 *
 * Every variant mounts `titlebar` on <html> so the stylesheet reserves the
 * band (globals.css) and pushes the app content below it. Renders nothing
 * outside Tauri desktop.
 */
export function TitleBar() {
  const { t } = useTranslation()
  const platform = usePlatform()
  const [maximized, setMaximized] = useState(false)

  const visible = platform !== null && DESKTOP_PLATFORMS.has(platform)
  const hasCaption = platform === "windows" || platform === "linux"

  useMacDragRegion(visible && platform === "macos")

  useEffect(() => {
    if (!visible) return
    document.documentElement.classList.add("titlebar")
    return () => document.documentElement.classList.remove("titlebar")
  }, [visible])

  // Windows/Linux: track maximized state for the restore glyph.
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

  if (!visible || platform === "macos") return null

  return (
    <header
      data-tauri-drag-region
      className="native-glass fixed inset-x-0 top-0 z-50 flex select-none items-stretch justify-end"
      style={{ height: `${BAND_PX}px` }}
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
      className={`flex w-[46px] items-center justify-center text-muted-foreground transition-colors ${
        danger
          ? "hover:bg-red-600 hover:text-white"
          : "hover:bg-muted hover:text-foreground"
      }`}
    >
      {children}
    </button>
  )
}
