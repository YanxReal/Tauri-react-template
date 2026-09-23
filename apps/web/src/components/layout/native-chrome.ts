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
 * Linux: la barra de título es un `GtkHeaderBar` (CSD) que instala Rust, así que
 * SÍ puede seguir al tema de la app — pero hay que avisarle. En Linux
 * `window.setTheme()` termina en `gtk-application-prefer-dark-theme` (tao), que
 * repinta el HeaderBar al instante.
 *
 * ¿Por qué CSD y no la decoración nativa de mutter? La variante clara/oscura de
 * la SSD la decide mutter **una sola vez**, al gestionar la ventana: la
 * propiedad `_GTK_THEME_VARIANT` está registrada con `LOAD_INIT` en
 * `mutter/src/x11/window-props.c`, así que no cambia en runtime — ni con
 * `set_theme`, ni escribiendo la propiedad con `xprop`, ni remapeando la
 * ventana (los tres comprobados). Con el HeaderBar la barra la pinta GTK en
 * proceso y sigue al tema sin más.
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

export {
  isTauriRuntime,
  useMacDragRegion,
  useNativeTheme,
  usePlatform,
  useWindowDragRegion,
}
