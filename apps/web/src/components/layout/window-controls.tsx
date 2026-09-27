import { invoke } from "@tauri-apps/api/core"
import { getCurrentWindow } from "@tauri-apps/api/window"
import { Copy, Minus, Square, X } from "lucide-react"
import { useCallback, useEffect, useRef, useState } from "react"
import { useTranslation } from "react-i18next"

import { usePlatform } from "./native-chrome"

/** Hover delay before the Snap Layouts flyout opens — Windows 11 uses ~600ms. */
const SNAP_OVERLAY_DELAY_MS = 620

function CaptionButton({
  label,
  danger,
  onClick,
  onMouseEnter,
  onMouseLeave,
  children,
}: {
  label: string
  danger?: boolean
  onClick: () => void
  onMouseEnter?: () => void
  onMouseLeave?: () => void
  children: React.ReactNode
}) {
  return (
    <button
      type="button"
      aria-label={label}
      title={label}
      onClick={onClick}
      onMouseEnter={onMouseEnter}
      onMouseLeave={onMouseLeave}
      // `decorum-tb-btn` stops the plugin from injecting its own controls if
      // `withGlobalTauri` is ever enabled (see app-providers/docs/native-feel).
      className={`decorum-tb-btn flex h-full w-[46px] items-center justify-center transition-colors ${
        danger
          ? "text-foreground hover:bg-[#e81123] hover:text-white dark:text-white dark:hover:bg-[#e81123]"
          : "text-foreground hover:bg-black/10 hover:text-foreground dark:text-white dark:hover:bg-white/10 dark:hover:text-white"
      }`}
    >
      {children}
    </button>
  )
}

/**
 * Caption buttons (minimize / maximize-restore / close).
 *
 * Windows (`decorations:false` + decorum overlay) y Linux (`decorations:false`,
 * frameless) dibujan su propia titlebar, así que este componente aporta los
 * controles y la banda fija de 44px del header queda como franja arrastrable
 * fusionada (`data-tauri-drag-region` + `useWindowDragRegion`). macOS conserva
 * los traffic lights nativos, por eso `Header` solo lo renderiza en Win/Linux.
 *
 * Hovering *maximize* opens the Windows 11 Snap Layouts flyout through
 * decorum's `show_snap_overlay` (Win+Z) — Windows only: the plugin is a
 * `cfg(windows)` dependency, so on Linux the hover does nothing.
 * Chromium gets the hover flyout by answering `WM_NCHITTEST` with
 * `HTMAXBUTTON`; tao does not expose that hook, so Win+Z is the closest
 * available equivalent.
 */
export function WindowControls() {
  const { t } = useTranslation()
  const platform = usePlatform()
  const isWindows = platform === "windows"
  const [maximized, setMaximized] = useState(false)
  const snapTimer = useRef<number | null>(null)

  useEffect(() => {
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
  }, [])

  const clearSnapTimer = useCallback(() => {
    if (snapTimer.current !== null) {
      window.clearTimeout(snapTimer.current)
      snapTimer.current = null
    }
  }, [])

  useEffect(() => clearSnapTimer, [clearSnapTimer])

  const scheduleSnapOverlay = () => {
    // Snap Layouts es Windows 11 (decorum): en Linux el hover no hace nada.
    if (!isWindows) return
    clearSnapTimer()
    snapTimer.current = window.setTimeout(() => {
      snapTimer.current = null
      const appWindow = getCurrentWindow()
      void appWindow
        .setFocus()
        .then(() => invoke("plugin:decorum|show_snap_overlay"))
        .catch(() => {})
    }, SNAP_OVERLAY_DELAY_MS)
  }

  const runWindowAction = (action: "minimize" | "maximize" | "close") => {
    const appWindow = getCurrentWindow()
    if (action === "minimize") void appWindow.minimize()
    else if (action === "maximize") void appWindow.toggleMaximize()
    else void appWindow.close()
  }

  return (
    // Sin padding derecho: el botón de cerrar tiene que quedar pegado al borde
    // de la ventana, como Edge/Chrome (al hacer hover el rojo llega hasta la
    // esquina y DWM lo recorta con el radio).
    <div className="relative z-20 flex h-full shrink-0 items-stretch">
      <CaptionButton
        label={t("header.minimize")}
        onClick={() => runWindowAction("minimize")}
      >
        <Minus className="size-3.5" />
      </CaptionButton>
      <CaptionButton
        label={maximized ? t("header.restore") : t("header.maximize")}
        onClick={() => {
          clearSnapTimer()
          runWindowAction("maximize")
        }}
        onMouseEnter={scheduleSnapOverlay}
        onMouseLeave={clearSnapTimer}
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
    </div>
  )
}
