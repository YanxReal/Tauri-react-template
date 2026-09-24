import { invoke } from "@tauri-apps/api/core"
import { getCurrentWindow } from "@tauri-apps/api/window"
import { useEffect, useState } from "react"

/**
 * Alto de la banda de arrastre. Se mide del propio header (`.app-header`) en vez
 * de duplicar su clase de Tailwind: si la banda cambia (52px macOS, 44px
 * Win/Linux, 56px móvil) el arrastre la sigue sin tocar dos sitios. Los
 * fallbacks aplican si el header todavía no está montado.
 */
const FALLBACK_BAND_MAC = 52
const FALLBACK_BAND_DESKTOP = 44

function headerBandHeight(fallback: number): number {
  const header = document.querySelector(".app-header")
  const height = header?.getBoundingClientRect().height
  return height && height > 0 ? height : fallback
}

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
      if (event.clientY > headerBandHeight(FALLBACK_BAND_MAC)) return
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

/**
 * Win/Linux: la ventana lleva su propia barra (decorum en Windows, un
 * `GtkHeaderBar` CSD en Linux — ver `useNativeTheme`), pero el header de la app
 * sigue siendo la zona de arrastre personalizada (Prestly).
 * WebKitGTK y WebView2 a veces no respetan `data-tauri-drag-region` en hijos
 * (solo en el elemento directo) y en Linux el CSS `app-region:drag` no siempre
 * funciona, así que el JS rescata el arrastre limitándolo a la altura real del
 * header (`h-11` = 44px) y con la misma guarda `INTERACTIVE_SELECTOR`.
 */
function useWindowDragRegion(enabled: boolean): void {
  useEffect(() => {
    if (!enabled || !isTauriRuntime()) return
    const limit = headerBandHeight(FALLBACK_BAND_DESKTOP)
    const onMouseDown = (event: MouseEvent) => {
      if (event.button !== 0) return
      if (event.clientY > limit) return
      const target = event.target instanceof Element ? event.target : null
      if (target?.closest(INTERACTIVE_SELECTOR)) return
      // No prevenir default en botones no-interactivos; startDragging necesita el evento vivo
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

/**
 * Linux: la ventana usa un marco CSD "latched" (`install_linux_frame` en Rust):
 * una `GtkHeaderBar` oculta deja a GTK en modo cliente-decorado para que siga
 * dibujando su **sombra nativa**, con el fondo transparente para que la forma
 * la defina `.app-shell`. La titlebar visible la dibuja la app (header +
 * `WindowControls`), así que el tema del chrome lo controla el CSS.
 *
 * Aun así sincronizamos la variante de GTK: en Linux `window.setTheme()` acaba
 * en `gtk-application-prefer-dark-theme` (tao), y eso mantiene el marco y
 * cualquier superficie GTK (p. ej. el fondo de ventana si la regla transparente
 * no cargase) en el mismo claro/oscuro que la app.
 *
 * ¿Por qué no la titlebar nativa de mutter? Su variante clara/oscura se lee una
 * sola vez, al gestionar la ventana (`_GTK_THEME_VARIANT` con `LOAD_INIT` en
 * `mutter/src/x11/window-props.c`), y no cambia en runtime — ni con `set_theme`,
 * ni escribiendo la propiedad con `xprop`, ni remapeando la ventana (los tres
 * comprobados en GNOME 46).
 *
 * Solo Linux: en macOS `set_theme` cambia la apariencia de NSApp (vibrancy +
 * traffic lights) y en Windows el modo oscuro de toda la app; el chrome de
 * ambos ya sigue al tema por otras vías (vibrancy-provider / caption buttons).
 */
function useNativeTheme(enabled: boolean): void {
  useEffect(() => {
    if (!enabled || !isTauriRuntime()) return
    const appWindow = getCurrentWindow()
    // Se observa la clase de <html> (no el contexto de tema) para cubrir
    // también el caso "system": si el OS cambia de claro a oscuro,
    // ThemeProvider reescribe `.dark` y el HeaderBar tiene que seguirlo.
    const apply = () => {
      const dark = document.documentElement.classList.contains("dark")
      void appWindow.setTheme(dark ? "dark" : "light").catch(() => {})
    }
    apply()
    const observer = new MutationObserver(apply)
    observer.observe(document.documentElement, {
      attributes: true,
      attributeFilter: ["class"],
    })
    return () => observer.disconnect()
  }, [enabled])
}

type ResizeEdge =
  | "North"
  | "South"
  | "West"
  | "East"
  | "NorthWest"
  | "NorthEast"
  | "SouthWest"
  | "SouthEast"

const RESIZE_CURSOR: Record<ResizeEdge, string> = {
  North: "ns-resize",
  South: "ns-resize",
  West: "ew-resize",
  East: "ew-resize",
  NorthWest: "nwse-resize",
  SouthEast: "nwse-resize",
  NorthEast: "nesw-resize",
  SouthWest: "nesw-resize",
}

/** Borde bajo el puntero, o null si está lejos de los cantos. */
function resizeEdgeAt(x: number, y: number, band: number): ResizeEdge | null {
  const w = window.innerWidth
  const h = window.innerHeight
  const top = y <= band
  const bottom = y >= h - band
  const left = x <= band
  const right = x >= w - band

  if (top && left) return "NorthWest"
  if (top && right) return "NorthEast"
  if (bottom && left) return "SouthWest"
  if (bottom && right) return "SouthEast"
  if (top) return "North"
  if (bottom) return "South"
  if (left) return "West"
  if (right) return "East"
  return null
}

/**
 * Linux: la ventana CSD **no trae agarres de resize**. GTK delega el borde en
 * el gestor de ventanas, pero una ventana cliente-decorada no lleva marco del
 * WM, así que no hay nada que arrastrar (comprobado también con una ventana CSD
 * de referencia: tampoco redimensiona). Tauri 2.11 tampoco expone un
 * `startResizing`, así que el borde lo detecta la app y lo ejecuta Rust con el
 * mismo `gtk_window_begin_resize_drag` que usaría GTK (`start_window_resize`).
 *
 * El cursor del borde también es cosa nuestra: con CSD lo pondría GTK y aquí no
 * hay zona del WM que lo active.
 */
function useWindowResizeEdges(enabled: boolean): void {
  useEffect(() => {
    if (!enabled || !isTauriRuntime()) return
    // Banda de agarre, en px CSS. 6 da margen al ratón sin comerse la UI.
    const BAND = 6

    const onMouseDown = (event: MouseEvent) => {
      if (event.button !== 0) return
      const edge = resizeEdgeAt(event.clientX, event.clientY, BAND)
      if (!edge) return
      // Capturamos: el arrastre lo lleva GTK, no el DOM.
      event.preventDefault()
      void invoke("start_window_resize", { direction: edge }).catch(() => {})
    }
    const onMouseMove = (event: MouseEvent) => {
      const edge = resizeEdgeAt(event.clientX, event.clientY, BAND)
      document.documentElement.style.cursor = edge ? RESIZE_CURSOR[edge] : ""
    }

    document.addEventListener("mousedown", onMouseDown, true)
    document.addEventListener("mousemove", onMouseMove)
    return () => {
      document.removeEventListener("mousedown", onMouseDown, true)
      document.removeEventListener("mousemove", onMouseMove)
      document.documentElement.style.cursor = ""
    }
  }, [enabled])
}

export {
  isTauriRuntime,
  useMacDragRegion,
  useNativeTheme,
  usePlatform,
  useWindowDragRegion,
  useWindowResizeEdges,
}
